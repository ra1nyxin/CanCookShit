local G = GLOBAL
local lines = require "can_cook_shit_speech"

local RPC_NAMESPACE = "cancookshit_shift"
local HOLD_INTERVAL = 5
local REPAIR_TAG = "cancookshit_repairable"
local MANURE_LOYALTY_DURATION = 12 * 60 * 60

print("[CanCookShit] startup: ActionHandler=" .. type(G.ActionHandler)
    .. ", AddAction=" .. type(AddAction)
    .. ", AddStategraphActionHandler=" .. type(AddStategraphActionHandler))

local function IsManure(item)
    return item ~= nil and (item.prefab == "poop" or item.prefab == "guano")
end

local function GetRepairKind(target)
    if target == nil or target.components == nil then return nil end
    local finiteuses = target.components.finiteuses
    if finiteuses ~= nil and finiteuses.total ~= nil and finiteuses.total > 0
        and finiteuses.current ~= nil and finiteuses.current < finiteuses.total then
        return "finiteuses"
    end
    local fueled = target.components.fueled
    if fueled ~= nil and fueled.maxfuel ~= nil and fueled.maxfuel > 0
        and fueled.currentfuel ~= nil and fueled.currentfuel < fueled.maxfuel then
        return "fueled"
    end
    local armor = target.components.armor
    if armor ~= nil and armor.maxcondition ~= nil and armor.maxcondition > 0
        and armor.condition ~= nil and armor.condition < armor.maxcondition then
        return "armor"
    end
end

local function RefreshRepairTag(inst)
    if inst == nil or not inst:IsValid() or not G.TheWorld.ismastersim then return end
    inst:AddOrRemoveTag(REPAIR_TAG, GetRepairKind(inst) ~= nil)
end

AddPrefabPostInitAny(function(inst)
    if not G.TheWorld.ismastersim or inst == nil or inst.components == nil then return end
    if inst.components.finiteuses ~= nil or inst.components.fueled ~= nil or inst.components.armor ~= nil then
        inst:ListenForEvent("percentusedchange", RefreshRepairTag)
        inst:DoTaskInTime(0, RefreshRepairTag)
    end
end)

local repair_action = AddAction("CANCOOKSHIT_REPAIR", "用屎修补", function(act)
    local target, manure = act.target, act.invobject
    if target == nil or not target:IsValid() or not IsManure(manure) then return false end
    local kind = GetRepairKind(target)
    local inventory = act.doer ~= nil and act.doer.components.inventory or nil
    if kind == nil or inventory == nil then return false end
    local removed = inventory:RemoveItem(manure)
    if removed == nil then return false end
    local repaired = false
    if kind == "finiteuses" then
        target.components.finiteuses:Repair(target.components.finiteuses.total * .5)
        repaired = true
    elseif kind == "fueled" then
        target.components.fueled:DoDelta(target.components.fueled.maxfuel * .5, act.doer)
        repaired = true
    elseif kind == "armor" then
        target.components.armor:Repair(target.components.armor.maxcondition * .5)
        repaired = true
    end
    if repaired then
        if removed:IsValid() then removed:Remove() end
        RefreshRepairTag(target)
        return true
    end
    inventory:GiveItem(removed)
    return false
end)
repair_action.rmb = true
repair_action.mount_valid = true
AddStategraphActionHandler("wilson", G.ActionHandler(repair_action, "dolongaction"))
AddStategraphActionHandler("wilson_client", G.ActionHandler(repair_action, "dolongaction"))
AddModRPCHandler(RPC_NAMESPACE, "drop", function(player)
    if player == nil or not player:IsValid() or player:HasTag("playerghost")
        or player.components.health == nil or player.components.health:IsDead() then return end
    local item = G.SpawnPrefab("poop")
    if item ~= nil and item:IsValid() and item.Physics ~= nil then
        G.Launch2(item, player, 1, 1, .2, .1, 2)
    elseif item ~= nil and item:IsValid() then
        item:Remove()
    end
end)

local function StartLocalShiftMonitor(inst)
    if inst.DoPeriodicTask == nil or G.TheNet:IsDedicated() then return end
    local next_drop
    inst:DoPeriodicTask(.2, function(player)
        if G.ThePlayer ~= player then next_drop = nil; return end
        local held = player:IsValid() and not player:HasTag("playerghost")
            and player.HUD ~= nil and G.TheFrontEnd ~= nil
            and G.TheFrontEnd:GetActiveScreen() == player.HUD
            and G.TheInput ~= nil and G.TheInput:IsKeyDown(G.KEY_SHIFT)
        local now = G.GetTime()
        if not held then
            next_drop = nil
        elseif next_drop == nil then
            next_drop = now + HOLD_INTERVAL
        elseif now >= next_drop then
            SendModRPCToServer(GetModRPC(RPC_NAMESPACE, "drop"))
            next_drop = now + HOLD_INTERVAL
        end
    end)
end

AddIngredientValues({ "poop" }, { meat = .5, monster = .5 })
AddIngredientValues({ "guano" }, { monster = .5, dairy = .5 })

local function OnEaten(item, eater)
    if eater ~= nil and eater:HasTag("player") then
        if eater.components.manurebuff ~= nil then
            eater.components.manurebuff:Apply(item.prefab)
        end
        local speech = lines[eater.prefab] or lines.generic
        if eater.components.talker ~= nil then eater.components.talker:Say(speech[item.prefab]) end
    end
end

for _, name in ipairs({ "poop", "guano" }) do
    AddPrefabPostInit(name, function(inst)
        inst:AddTag("edible_" .. G.FOODTYPE.GENERIC)
        inst:AddTag("saltbox_valid")
        inst:AddTag("icebox_valid")
        if not G.TheWorld.ismastersim then return end
        if inst.components.tradable == nil then inst:AddComponent("tradable") end
        inst.components.tradable.goldvalue = name == "poop" and 3 or 5
        inst:AddComponent("edible")
        inst.components.edible.healthvalue = 0
        inst.components.edible.hungervalue = name == "poop" and 8 or 6
        inst.components.edible.sanityvalue = name == "poop" and -15 or -25
        -- FEEDPLAYER rejects badfood outside PvP; this food is intentionally feedable.
        inst:RemoveTag("badfood")
        inst.components.edible:SetOnEatenFn(OnEaten)
    end)
end

AddComponentAction("INVENTORY", "inventoryitem", function(inst, doer, actions)
    if IsManure(inst) and doer:HasTag("player") and not G.table.contains(actions, G.ACTIONS.EAT) then
        table.insert(actions, G.ACTIONS.EAT)
    end
end)

AddComponentAction("USEITEM", "inventoryitem", function(inst, doer, target, actions, right)
    if right and IsManure(inst) and target:HasTag("player") and not target:HasTag("playerghost")
        and not G.table.contains(actions, G.ACTIONS.FEEDPLAYER) then
        table.insert(actions, G.ACTIONS.FEEDPLAYER)
    end
    if right and IsManure(inst) and target.prefab == "beefalo" and target:HasTag("trader")
        and not G.table.contains(actions, G.ACTIONS.FEED) then
        table.insert(actions, G.ACTIONS.FEED)
    end
    if right and IsManure(inst) and target ~= nil and target:HasTag(REPAIR_TAG)
        and not G.table.contains(actions, repair_action) then
        table.insert(actions, repair_action)
    end
end)

AddPrefabPostInit("pigman", function(inst)
    if not G.TheWorld.ismastersim or inst.components == nil then return end
    local trader = inst.components.trader
    if trader == nil then return end
    local old_test, old_accept = trader.test, trader.onaccept
    trader.test = function(pig, item, giver, ...)
        if IsManure(item) then
            local follower = pig.components.follower
            return item.components.edible ~= nil and follower ~= nil and
                (follower:GetLeader() == nil or follower:GetLoyaltyPercent() <= G.TUNING.PIG_FULL_LOYALTY_PERCENT)
        end
        return old_test == nil or old_test(pig, item, giver, ...)
    end
    trader.onaccept = function(pig, giver, item, ...)
        if old_accept ~= nil then old_accept(pig, giver, item, ...) end
        if not IsManure(item) or giver == nil or not giver:IsValid() or giver.components == nil then return end
        local follower, combat = pig.components.follower, pig.components.combat
        local inventoryitem = item.components ~= nil and item.components.inventoryitem or nil
        if follower == nil or combat == nil or inventoryitem == nil then return end
        local received = item:IsValid() and inventoryitem:GetGrandOwner() == pig
        if not received and not item:IsValid() and pig.components.inventory ~= nil then
            received = pig.components.inventory:FindItem(function(obj)
                return obj.prefab == item.prefab and obj.components.stackable ~= nil
                    and obj.components.stackable:IsStack()
            end) ~= nil
        end
        if not received then return end
        if combat:TargetIs(giver) then
            combat:SetTarget(nil)
        elseif giver.components.leader ~= nil and not (pig:HasTag("guard") or giver:HasTag("monster") or giver:HasTag("merm"))
            and giver.components.minigame_participator == nil then
            giver:PushEvent("makefriend")
            giver.components.leader:AddFollower(pig)
            local old_max = follower.maxfollowtime
            follower.maxfollowtime = math.max(old_max or 0, MANURE_LOYALTY_DURATION)
            follower:AddLoyaltyTime(MANURE_LOYALTY_DURATION)
            follower.maxfollowtime = old_max
        end
    end
end)

local function ExtendMermManureLoyalty(inst)
    if not G.TheWorld.ismastersim or inst.components == nil then return end
    local trader, follower = inst.components.trader, inst.components.follower
    if trader == nil or follower == nil or trader.onaccept == nil then return end
    local old_accept = trader.onaccept
    trader.onaccept = function(merm, giver, item, ...)
        old_accept(merm, giver, item, ...)
        if not IsManure(item) or giver == nil or not giver:IsValid() then return end
        if follower:GetLeader() ~= giver then return end
        follower.maxfollowtime = MANURE_LOYALTY_DURATION
        follower:AddLoyaltyTime(MANURE_LOYALTY_DURATION)
    end
end

AddPrefabPostInit("merm", ExtendMermManureLoyalty)
AddPrefabPostInit("mermguard", ExtendMermManureLoyalty)

AddPrefabPostInit("beefalo", function(inst)
    if not G.TheWorld.ismastersim or inst.components.eater == nil then return end
    local eater = inst.components.eater
    local old_can_eat, old_prefers, old_on_eat = eater.CanEat, eater.PrefersToEat, eater.oneatfn
    eater.CanEat = function(self, food, ...)
        return IsManure(food) or old_can_eat(self, food, ...)
    end
    eater.PrefersToEat = function(self, food, ...)
        return IsManure(food) or old_prefers(self, food, ...)
    end
    eater:SetOnEatFn(function(beefalo, food, feeder)
        if not IsManure(food) then
            if old_on_eat ~= nil then old_on_eat(beefalo, food, feeder) end
            return
        end
        local poop = food.prefab == "poop"
        local domesticatable = beefalo.components.domesticatable
        if domesticatable ~= nil then
            domesticatable:DeltaObedience(poop and .05 or .03)
            domesticatable:DeltaDomestication(poop and .012 or .01, feeder)
            domesticatable:TryBecomeDomesticated()
        end
        if beefalo.components.health ~= nil then
            beefalo.components.health:DoDelta(poop and 6 or 4, nil, food.prefab)
        end
        if beefalo.components.hunger ~= nil then
            beefalo.components.hunger:DoDelta(2)
        end
        beefalo:PushEvent("eat", { full = beefalo.components.hunger:GetPercent() >= 1, food = food })
        if beefalo.components.knownlocations ~= nil then
            beefalo.components.knownlocations:RememberLocation("loiteranchor", beefalo:GetPosition())
        end
    end)
end)

AddPlayerPostInit(function(inst)
    StartLocalShiftMonitor(inst)
    if not G.TheWorld.ismastersim or inst.components.eater == nil then return end
    inst:AddComponent("manurebuff")
    local eater = inst.components.eater
    local old_can_eat, old_prefers = eater.CanEat, eater.PrefersToEat
    eater.CanEat = function(self, food, ...)
        return IsManure(food) or old_can_eat(self, food, ...)
    end
    eater.PrefersToEat = function(self, food, ...)
        return IsManure(food) or old_prefers(self, food, ...)
    end
end)

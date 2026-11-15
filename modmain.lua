local G = GLOBAL
local lines = require "can_cook_shit_speech"

local RPC_NAMESPACE = "cancookshit_shift"
local HOLD_INTERVAL = 5
local LEASE_SECONDS = 2

local function StopPooping(player)
    if player._cancookshit_task ~= nil then
        player._cancookshit_task:Cancel()
        player._cancookshit_task = nil
    end
    player._cancookshit_until = nil
    player._cancookshit_next = nil
end

AddModRPCHandler(RPC_NAMESPACE, "hold", function(player, holding)
    if player == nil or not player:IsValid() or type(holding) ~= "boolean" then return end
    if not holding or player:HasTag("playerghost") or player.components.health == nil
        or player.components.health:IsDead() then
        StopPooping(player)
        return
    end
    player._cancookshit_until = G.GetTime() + LEASE_SECONDS
    if player._cancookshit_task == nil then
        player._cancookshit_next = G.GetTime() + HOLD_INTERVAL
        player._cancookshit_task = player:DoPeriodicTask(.25, function(inst)
            if not inst:IsValid() or inst:HasTag("playerghost") or inst.components.health == nil
                or inst.components.health:IsDead() or inst._cancookshit_until == nil
                or G.GetTime() > inst._cancookshit_until then
                StopPooping(inst)
                return
            end
            if G.GetTime() >= inst._cancookshit_next then
                inst._cancookshit_next = G.GetTime() + HOLD_INTERVAL
                local item = G.SpawnPrefab("poop")
                if item ~= nil and item:IsValid() and item.Physics ~= nil then
                    G.Launch2(item, inst, 1, 1, .2, .1, 2)
                elseif item ~= nil and item:IsValid() then
                    item:Remove()
                end
            end
        end)
    end
end)

local function StartLocalShiftMonitor(inst)
    if inst.DoPeriodicTask == nil or G.TheNet:IsDedicated() then return end
    local active, lastsend = false, 0
    inst:DoPeriodicTask(.2, function(player)
        if G.ThePlayer ~= player then return end
        local held = player:IsValid() and not player:HasTag("playerghost")
            and player.HUD ~= nil and G.TheFrontEnd ~= nil
            and G.TheFrontEnd:GetActiveScreen() == player.HUD
            and G.TheInput ~= nil and G.TheInput:IsKeyDown(G.KEY_SHIFT)
        local now = G.GetTime()
        if held ~= active or (held and now - lastsend >= .5) then
            SendModRPCToServer(GetModRPC(RPC_NAMESPACE, "hold"), held)
            active, lastsend = held, now
        end
    end)
end

AddIngredientValues({ "poop" }, { meat = .5, monster = .5 })
AddIngredientValues({ "guano" }, { meat = .5, monster = .5, dairy = .5 })

local function IsManure(item)
    return item ~= nil and (item.prefab == "poop" or item.prefab == "guano")
end

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
            local duration = item.prefab == "poop" and 7200 or 14400
            follower.maxfollowtime = math.max(old_max or 0, 14400)
            follower:AddLoyaltyTime(duration)
            follower.maxfollowtime = old_max
        end
    end
end)

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
            domesticatable:DeltaObedience(poop and .04 or .02)
            domesticatable:DeltaDomestication(poop and .01 or .008, feeder)
            domesticatable:TryBecomeDomesticated()
        end
        if beefalo.components.health ~= nil then
            beefalo.components.health:DoDelta(poop and 5 or 3, nil, food.prefab)
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

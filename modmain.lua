local G = GLOBAL
local lines = require "can_cook_shit_speech"

AddIngredientValues({ "poop", "guano" }, { meat = .5, monster = .5 })

local function IsManure(item)
    return item ~= nil and (item.prefab == "poop" or item.prefab == "guano")
end

local function OnEaten(item, eater)
    if eater ~= nil and eater:HasTag("player") and eater.components.talker ~= nil then
        local speech = lines[eater.prefab] or lines.generic
        eater.components.talker:Say(speech[item.prefab])
    end
end

for _, name in ipairs({ "poop", "guano" }) do
    AddPrefabPostInit(name, function(inst)
        inst:AddTag("edible_" .. G.FOODTYPE.GENERIC)
        inst:AddTag("saltbox_valid")
        inst:AddTag("icebox_valid")
        if not G.TheWorld.ismastersim then return end
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
            domesticatable:DeltaDomestication(poop and .003 or .0015, feeder)
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
    if not G.TheWorld.ismastersim or inst.components.eater == nil then return end
    local eater = inst.components.eater
    local old_can_eat, old_prefers = eater.CanEat, eater.PrefersToEat
    eater.CanEat = function(self, food, ...)
        return IsManure(food) or old_can_eat(self, food, ...)
    end
    eater.PrefersToEat = function(self, food, ...)
        return IsManure(food) or old_prefers(self, food, ...)
    end
end)

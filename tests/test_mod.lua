local prefabs, actions, playerinit, ingredients, repair_action = {}, {}, nil, {}, nil
GLOBAL = { FOODTYPE = { GENERIC = 'GENERIC' }, TheWorld = { ismastersim = true }, ACTIONS = { EAT = {}, FEED = {}, FEEDPLAYER = {} }, table = { contains = function(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end } }
AddIngredientValues = function(names, tags) for _, name in ipairs(names) do ingredients[name] = tags end end
AddModRPCHandler = function() end
AddAction = function(_, _, fn) repair_action = { fn = fn }; return repair_action end
GLOBAL.ActionHandler = function(action, state) return { action = action, state = state } end
local handlers = {}
AddStategraphActionHandler = function(graph, handler) handlers[graph] = handler end
AddPrefabPostInitAny = function(fn) _G.anypostinit = fn end
AddPrefabPostInit = function(name, fn) prefabs[name] = fn end
AddComponentAction = function(kind, component, fn) actions[kind] = fn end
AddPlayerPostInit = function(fn) playerinit = fn end
package.path = 'scripts/?.lua;' .. package.path
dofile('modmain.lua')
assert(handlers.wilson.action == repair_action and handlers.wilson.state == 'dolongaction')
assert(handlers.wilson_client.action == repair_action and handlers.wilson_client.state == 'dolongaction')
assert(ingredients.poop.meat == .5 and ingredients.poop.monster == .5 and ingredients.poop.dairy == nil)
assert(ingredients.guano.meat == nil and ingredients.guano.monster == .5 and ingredients.guano.dairy == .5)
for _, name in ipairs({'poop', 'guano'}) do
    local tags = {}
    local item = { prefab = name, components = {} }
    function item:AddTag(tag) tags[tag] = true end
    function item:RemoveTag(tag) tags[tag] = nil end
    function item:AddComponent(name) self.components[name] = { SetOnEatenFn = function(self, fn) self.oneaten = fn end } end
    prefabs[name](item)
    local e = item.components.edible
    assert(item.components.tradable.goldvalue == (name == 'poop' and 3 or 5))
    assert(e.hungervalue == (name == 'poop' and 8 or 6))
    assert(e.sanityvalue == (name == 'poop' and -15 or -25) and e.healthvalue == 0)
    assert(tags.saltbox_valid and tags.icebox_valid and tags.edible_GENERIC and not tags.badfood)
    local player = { prefab = 'wurt', HasTag = function(_, tag) return tag == 'player' end, components = { talker = { Say = function(_, text) assert(type(text) == 'string' and #text > 0) end } } }
    e.oneaten(item, player)
    local available = {}; actions.INVENTORY(item, player, available); assert(available[1] == GLOBAL.ACTIONS.EAT)
    available = {}; actions.USEITEM(item, player, player, available, true); assert(available[1] == GLOBAL.ACTIONS.FEEDPLAYER)
    local eater = { CanEat = function() return false end, PrefersToEat = function() return false end }
    player.components.eater = eater; player.AddComponent = function() end; playerinit(player)
    assert(eater:CanEat(item) and eater:PrefersToEat(item))
    assert(not eater:CanEat({prefab='berries'}) and not eater:PrefersToEat({prefab='berries'}))
end
local speech = require 'can_cook_shit_speech'
GLOBAL.TUNING = { PIG_FULL_LOYALTY_PERCENT = .9 }
local loyalty, original = 0, 0
local follower = { maxfollowtime = 1200, GetLeader = function() return nil end,
    AddLoyaltyTime = function(self, n) assert(self.maxfollowtime >= n); loyalty = n end }
local trader = { test = function() return false end, onaccept = function() original = original + 1 end }
local pig = { components = { trader = trader, follower = follower,
    combat = { TargetIs = function() return false end } }, HasTag = function() return false end }
local giver = { components = { leader = { AddFollower = function() end } },
    IsValid = function() return true end, HasTag = function() return false end, PushEvent = function() end }
prefabs.pigman(pig)
for _, case in ipairs({ {'poop',43200}, {'guano',43200} }) do
    local item = { prefab = case[1], IsValid = function() return true end,
        components = { edible = {}, inventoryitem = { GetGrandOwner = function() return pig end } } }
    assert(trader.test(pig,item,giver)); trader.onaccept(pig,giver,item)
    assert(loyalty == case[2] and follower.maxfollowtime == 1200)
end
assert(original == 2 and trader.test(pig,{prefab='meat'},giver) == false)

for _, prefab in ipairs({ 'merm', 'mermguard' }) do
    local merm_loyalty, merm_original = 0, 0
    local merm_follower = {
        maxfollowtime = 2400,
        GetLeader = function() return giver end,
        AddLoyaltyTime = function(self, n)
            assert(self.maxfollowtime >= n)
            merm_loyalty = n
        end,
    }
    local merm_trader = {
        onaccept = function() merm_original = merm_original + 1 end,
    }
    local merm = { components = { trader = merm_trader, follower = merm_follower } }
    prefabs[prefab](merm)
    local item = { prefab = 'guano' }
    merm_trader.onaccept(merm, giver, item)
    assert(merm_original == 1 and merm_loyalty == 43200)
    assert(merm_follower.maxfollowtime == 43200)
end

for _, name in ipairs({'wilson','willow','wolfgang','wendy','wx78','wickerbottom','woodie','wes','waxwell','wathgrithr','webber','winona','warly','wortox','wormwood','wurt','walter','wanda','wonkey','generic'}) do
    assert(speech[name] and speech[name].poop and speech[name].guano, name)
end
local original_calls = 0
local eater = { CanEat = function() return false end, PrefersToEat = function() return false end,
    oneatfn = function() original_calls = original_calls + 1 end }
function eater:SetOnEatFn(fn) self.oneatfn = fn end
local effects = {}
local beefalo = { prefab = 'beefalo', components = { eater = eater,
    domesticatable = {
        DeltaObedience = function(_, n) effects.obedience = n end,
        DeltaDomestication = function(_, n, feeder) effects.domestication = n; effects.feeder = feeder end,
        TryBecomeDomesticated = function() effects.checked = true end,
    },
    health = { DoDelta = function(_, n) effects.health = n end },
    hunger = { GetPercent = function() return 1 end, DoDelta = function(_, n) effects.hunger = n end },
}, HasTag = function(_, tag) return tag == 'trader' end,
PushEvent = function(_, event, data) assert(event == 'eat' and data.full) end }
prefabs.beefalo(beefalo)
local feeder = {}
for _, test in ipairs({ {'poop', .05, .012, 6}, {'guano', .03, .01, 4} }) do
    local food = { prefab = test[1] }
    assert(eater:CanEat(food) and eater:PrefersToEat(food))
    local available = {}; actions.USEITEM(food, feeder, beefalo, available, true)
    assert(available[1] == GLOBAL.ACTIONS.FEED)
    eater.oneatfn(beefalo, food, feeder)
    assert(effects.obedience == test[2] and effects.domestication == test[3] and effects.health == test[4])
    assert(effects.hunger == 2)
    assert(effects.feeder == feeder and effects.checked)
end
eater.oneatfn(beefalo, {prefab = 'cutgrass'}, feeder)
assert(original_calls == 1)

local removed, finite_target = false, {
    components = { finiteuses = { total = 100, current = 0, Repair = function(self, amount) self.current = self.current + amount end } },
    IsValid = function() return true end,
    AddOrRemoveTag = function() end,
}
local manure = { prefab = 'poop', IsValid = function() return not removed end, Remove = function() removed = true end }
local repairer = { components = { inventory = {
    RemoveItem = function(_, item) assert(item == manure); return manure end,
    GiveItem = function() error('should not refund a successful repair') end,
} } }
assert(repair_action.fn({ target = finite_target, invobject = manure, doer = repairer }))
assert(finite_target.components.finiteuses.current == 50)
removed = true
local full_target = { components = { fueled = { maxfuel = 100, currentfuel = 100 } }, IsValid = function() return true end, AddOrRemoveTag = function() end }
assert(not repair_action.fn({ target = full_target, invobject = manure, doer = repairer }))
print('mod tests passed')

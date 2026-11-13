local prefabs, actions, playerinit, ingredients = {}, {}, nil, nil
GLOBAL = { FOODTYPE = { GENERIC = 'GENERIC' }, TheWorld = { ismastersim = true }, ACTIONS = { EAT = {}, FEEDPLAYER = {} }, table = { contains = function(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end } }
AddIngredientValues = function(names, tags) ingredients = { names = names, tags = tags } end
AddPrefabPostInit = function(name, fn) prefabs[name] = fn end
AddComponentAction = function(kind, component, fn) actions[kind] = fn end
AddPlayerPostInit = function(fn) playerinit = fn end
package.path = 'scripts/?.lua;' .. package.path
dofile('modmain.lua')
assert(ingredients.tags.meat == .5 and ingredients.tags.monster == .5)
for _, name in ipairs({'poop', 'guano'}) do
    local tags = {}
    local item = { prefab = name, components = {} }
    function item:AddTag(tag) tags[tag] = true end
    function item:RemoveTag(tag) tags[tag] = nil end
    function item:AddComponent(name) self.components[name] = { SetOnEatenFn = function(self, fn) self.oneaten = fn end } end
    prefabs[name](item)
    local e = item.components.edible
    assert(e.hungervalue == (name == 'poop' and 8 or 6))
    assert(e.sanityvalue == (name == 'poop' and -15 or -25) and e.healthvalue == 0)
    assert(tags.saltbox_valid and tags.icebox_valid and tags.edible_GENERIC and not tags.badfood)
    local player = { prefab = 'wurt', HasTag = function(_, tag) return tag == 'player' end, components = { talker = { Say = function(_, text) assert(type(text) == 'string' and #text > 0) end } } }
    e.oneaten(item, player)
    local available = {}; actions.INVENTORY(item, player, available); assert(available[1] == GLOBAL.ACTIONS.EAT)
    available = {}; actions.USEITEM(item, player, player, available, true); assert(available[1] == GLOBAL.ACTIONS.FEEDPLAYER)
    local eater = { CanEat = function() return false end, PrefersToEat = function() return false end }
    player.components.eater = eater; playerinit(player)
    assert(eater:CanEat(item) and eater:PrefersToEat(item))
    assert(not eater:CanEat({prefab='berries'}) and not eater:PrefersToEat({prefab='berries'}))
end
local speech = require 'can_cook_shit_speech'
for _, name in ipairs({'wilson','willow','wolfgang','wendy','wx78','wickerbottom','woodie','wes','waxwell','wathgrithr','webber','winona','warly','wortox','wormwood','wurt','walter','wanda','wonkey','generic'}) do
    assert(speech[name] and speech[name].poop and speech[name].guano, name)
end
print('mod tests passed')

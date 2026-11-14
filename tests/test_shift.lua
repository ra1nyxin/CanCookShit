local handler, tick, now, drops = nil, nil, 0, 0
GLOBAL = { FOODTYPE = { GENERIC = 'GENERIC' }, TheWorld = { ismastersim = true },
    GetTime = function() return now end,
    SpawnPrefab = function(name) assert(name == 'poop'); drops = drops + 1; return { Physics = {}, IsValid = function() return true end } end,
    Launch2 = function(item, player) assert(item.Physics and player) end }
package.path = 'scripts/?.lua;' .. package.path
AddModRPCHandler = function(_, _, fn) handler = fn end
AddIngredientValues = function() end
AddPrefabPostInit = function() end
AddComponentAction = function() end
AddPlayerPostInit = function() end
dofile('modmain.lua')
local dead, ghost, cancelled = false, false, 0
local player = { components = { health = { IsDead = function() return dead end } },
    IsValid = function() return true end,
    HasTag = function(_, tag) return tag == 'playerghost' and ghost end,
    DoPeriodicTask = function(_, interval, fn)
        assert(interval == .25); tick = fn
        return { Cancel = function() cancelled = cancelled + 1 end }
    end }
handler(player, true)
for i = 1, 40 do
    now = i * .25
    if i % 2 == 0 then handler(player, true) end
    tick(player)
end
assert(drops == 2)
handler(player, false); assert(cancelled == 1 and player._cancookshit_task == nil)
handler(player, true); now = now + 2.25; tick(player)
assert(cancelled == 2 and drops == 2)
handler(player, true); dead = true; tick(player)
assert(cancelled == 3 and drops == 2)
dead = false; ghost = true; handler(player, true)
assert(player._cancookshit_task == nil)
print('shift hold tests passed')

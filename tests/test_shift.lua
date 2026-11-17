local handler, playerinit, tick, now, requests, drops = nil, nil, nil, 0, 0, 0
local held, screen, dead, ghost = false, true, false, false
GLOBAL = { FOODTYPE = { GENERIC = 'GENERIC' }, TheWorld = { ismastersim = false }, KEY_SHIFT = 402,
    GetTime = function() return now end, TheNet = { IsDedicated = function() return false end },
    TheInput = { IsKeyDown = function() return held end },
    TheFrontEnd = { GetActiveScreen = function() return screen and GLOBAL.ThePlayer.HUD or nil end },
    SpawnPrefab = function() drops = drops + 1; return { Physics = {}, IsValid = function() return true end } end,
    Launch2 = function() end }
package.path = 'scripts/?.lua;' .. package.path
AddModRPCHandler = function(_, name, fn) assert(name == 'drop'); handler = fn end
AddIngredientValues = function() end
AddPrefabPostInit = function() end
AddPrefabPostInitAny = function() end
AddComponentAction = function() end
AddPlayerPostInit = function(fn) playerinit = fn end
AddAction = function(_, _, fn) return { fn = fn } end
ActionHandler = function() return {} end
AddStategraphActionHandler = function() end
GetModRPC = function() return {} end
SendModRPCToServer = function() requests = requests + 1 end
dofile('modmain.lua')
local player = { HUD = {}, components = { health = { IsDead = function() return dead end } },
    IsValid = function() return true end, HasTag = function(_, tag) return tag == 'playerghost' and ghost end,
    DoPeriodicTask = function(_, interval, fn) assert(interval == .2); tick = fn end }
GLOBAL.ThePlayer = player
playerinit(player)
held = true; tick(player)
now = 4.9; tick(player); assert(requests == 0)
now = 5; tick(player); assert(requests == 1)
now = 10; tick(player); assert(requests == 2)
held = false; tick(player); held = true; now = 11; tick(player)
now = 15.9; tick(player); assert(requests == 2)
screen = false; tick(player); screen = true; now = 16; tick(player)
now = 21; tick(player); assert(requests == 3)
handler(player); assert(drops == 1)
dead = true; handler(player); assert(drops == 1)
dead = false; ghost = true; handler(player); assert(drops == 1)
print('shift hold tests passed')

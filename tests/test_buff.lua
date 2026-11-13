Class = function(ctor)
    return setmetatable({}, { __call = function(class, inst)
        local obj = setmetatable({}, { __index = class }); ctor(obj, inst); return obj
    end })
end
local Buff = dofile('scripts/components/manurebuff.lua')
local temp = { current = -10, SetTemperature = function(self, value) self.current = value end }
local modifiers = { SetModifier = function(self, _, value, key) self[key] = value end,
    RemoveModifier = function(self, _, key) self[key] = nil end }
local player = { components = { temperature = temp, hunger = { burnratemodifiers = modifiers } },
    ListenForEvent = function(self, _, fn) self.death = fn end,
    StartUpdatingComponent = function(self) self.updating = true end,
    StopUpdatingComponent = function(self) self.updating = false end }
local buff = Buff(player)
buff:Apply('poop')
assert(temp.current == 25 and modifiers.cancookshit == .5)
assert(buff.temperature_remaining == 1800 and buff.hunger_remaining == 300)
temp:SetTemperature(90); assert(temp.current == 25)
buff:OnUpdate(120); buff:Apply('guano')
assert(buff.temperature_remaining == 300 and buff.hunger_remaining == 900)
buff:OnUpdate(300); assert(buff.temperature_remaining == 0 and modifiers.cancookshit == .5)
temp:SetTemperature(40); assert(temp.current == 40)
local saved = buff:OnSave(); buff:Clear(); assert(modifiers.cancookshit == nil)
buff:OnLoad(saved); assert(buff.hunger_remaining == 600 and modifiers.cancookshit == .5)
buff:OnUpdate(600); assert(modifiers.cancookshit == nil and not player.updating)
buff:Apply('poop'); player.death(); assert(buff:OnSave() == nil and modifiers.cancookshit == nil)
print('buff tests passed')

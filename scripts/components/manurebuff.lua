local NORMAL_TEMPERATURE = 25
local HUNGER_MULTIPLIER = .5

local ManureBuff = Class(function(self, inst)
    self.inst = inst
    self.temperature_remaining = 0
    self.hunger_remaining = 0
    self.temperature = inst.components.temperature
    if self.temperature ~= nil then
        local original = self.temperature.SetTemperature
        self.temperature.SetTemperature = function(component, value, ...)
            return original(component, self.temperature_remaining > 0 and NORMAL_TEMPERATURE or value, ...)
        end
    end
    inst:ListenForEvent("death", function() self:Clear() end)
end)

function ManureBuff:Apply(food)
    self.temperature_remaining = food == "poop" and 1800 or 300
    self.hunger_remaining = food == "poop" and 300 or 900
    self:Refresh()
end

function ManureBuff:Refresh()
    local hunger = self.inst.components.hunger
    if hunger ~= nil then
        if self.hunger_remaining > 0 then
            hunger.burnratemodifiers:SetModifier(self.inst, HUNGER_MULTIPLIER, "cancookshit")
        else
            hunger.burnratemodifiers:RemoveModifier(self.inst, "cancookshit")
        end
    end
    if self.temperature ~= nil and self.temperature_remaining > 0 then
        self.temperature:SetTemperature(NORMAL_TEMPERATURE)
    end
    if self.temperature_remaining > 0 or self.hunger_remaining > 0 then
        self.inst:StartUpdatingComponent(self)
    else
        self.inst:StopUpdatingComponent(self)
    end
end

function ManureBuff:OnUpdate(dt)
    local was_hungry = self.hunger_remaining > 0
    self.temperature_remaining = math.max(0, self.temperature_remaining - dt)
    self.hunger_remaining = math.max(0, self.hunger_remaining - dt)
    if self.temperature_remaining > 0 and self.temperature ~= nil then
        self.temperature:SetTemperature(NORMAL_TEMPERATURE)
    end
    if (was_hungry and self.hunger_remaining == 0) or
        (self.temperature_remaining == 0 and self.hunger_remaining == 0) then
        self:Refresh()
    end
end

function ManureBuff:Clear()
    self.temperature_remaining, self.hunger_remaining = 0, 0
    self:Refresh()
end

function ManureBuff:OnSave()
    if self.temperature_remaining > 0 or self.hunger_remaining > 0 then
        return { temperature = self.temperature_remaining, hunger = self.hunger_remaining }
    end
end

function ManureBuff:OnLoad(data)
    self.temperature_remaining = math.max(0, data.temperature or 0)
    self.hunger_remaining = math.max(0, data.hunger or 0)
    self:Refresh()
end

return ManureBuff

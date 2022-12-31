--[[

Mod: Auto Attack - OpenMW Lua
Author: Pharis

--]]

local core = require('openmw.core')
local input = require('openmw.input')
local self = require('openmw.self')
local storage = require('openmw.storage')
local time = require('openmw_aux.time')
local types = require('openmw.types')
local ui = require('openmw.ui')

-- Mod info
local modInfo = require('Scripts.Pharis.AutoAttack.modInfo')
local modName = modInfo.modName
local modVersion = modInfo.modVersion

-- Settings
local playerSettings = storage.playerSection('SettingsPlayer' .. modName)

-- Other Variables
local Player = types.Player
local Weapon = types.Weapon
local carriedRight = Player.EQUIPMENT_SLOT.CarriedRight

local autoAttackControl = false
local autoAttackState = 0
local timePassed = 0

local function debugMessage(msg, _)
	if not playerSettings:get('showDebugConf') then return end

	print('[' .. modName .. ']', string.format(msg, _))
end

local function message(msg)
	if not playerSettings:get('showMessagesConf') then return end

	ui.showMessage(msg)
end

local function toggleAutoAttack()
	if autoAttackControl then
		input.setControlSwitch(input.CONTROL_SWITCH.Fighting, true)
		autoAttackControl = false
		autoAttackState = 0
		self.controls.use = 0
		timePassed = 0
		message("Auto attack disabled.")
	else
		local equipment = Player.equipment(self)

		if playerSettings:get('marksmanOnlyModeConf') then
			if not equipment[carriedRight] then return end
			if Weapon.record(equipment[carriedRight]).type ~= Weapon.TYPE.MarksmanBow
				or Weapon.record(equipment[carriedRight]).type ~= Weapon.TYPE.MarksmanCrossbow
				or Weapon.record(equipment[carriedRight]).type ~= Weapon.TYPE.MarksmanThrown then
					goto continue
				else
					return
				end
		end
		::continue::
		input.setControlSwitch(input.CONTROL_SWITCH.Fighting, false)
		autoAttackControl = true
		message("Auto attack enabled.")
	end
end

local function autoAttack(dt)
	if not playerSettings:get('modEnableConf') then return end

	if Player.stance(self) ~= Player.STANCE.Weapon then return end

	if not autoAttackControl then return end

	if playerSettings:get('stopOnReleaseConf') then
		if playerSettings:get('attackBindingModeConf') and not input.isActionPressed(input.ACTION.Use) then
			toggleAutoAttack()
			return
		end
		if not playerSettings:get('attackBindingModeConf') and not input.isKeyPressed(playerSettings:get('modHotkeyConf')) then
			toggleAutoAttack()
			return
		end
	end

	timePassed = timePassed + dt
	debugMessage("Setting timePassed to %s", timePassed)

	local equipment = Player.equipment(self)

	if autoAttackState == 0 then
		self.controls.use = 0
		self.controls.use = 1

		autoAttackState = 1
		debugMessage("Setting autoAttackState to %s", autoAttackState)
	elseif autoAttackState == 1 and timePassed >= (playerSettings:get('attackTimerIntervalConf') * types.Weapon.record(equipment[carriedRight]).speed)then
		self.controls.use = 0

		autoAttackState = 0
		debugMessage("Setting autoAttackState to %s", autoAttackState)

		timePassed = 0
	end
end

local function onKeyPress(key)
	if key.code ~= playerSettings:get('modHotkeyConf') then return end

	if playerSettings:get('attackBindingModeConf') then return end

	if core.isWorldPaused() then return end

	toggleAutoAttack()

	debugMessage("Setting autoAttackControl to %s", autoAttackControl)
end

local function onInputAction(id)
	if id ~= input.ACTION.Use then return end

	if not playerSettings:get('attackBindingModeConf') then return end

	if core.isWorldPaused() then return end

	toggleAutoAttack()

	debugMessage("Setting autoAttackControl to %s", autoAttackControl)
end

return {
	engineHandlers = {
		onUpdate = autoAttack,
		onKeyPress = onKeyPress,
		onInputAction = onInputAction,
	}
}

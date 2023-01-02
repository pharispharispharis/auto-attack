--[[

Mod: Auto Attack - OpenMW Lua
Author: Pharis

--]]

local core = require('openmw.core')
local input = require('openmw.input')
local self = require('openmw.self')
local storage = require('openmw.storage')
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

local weaponWhitelist = require('Scripts.Pharis.AutoAttack.weaponWhitelist')

local function debugMessage(msg, _)
	if not playerSettings:get('showDebug') then return end

	print("[" .. modName .. "]", string.format(msg, _))
end

local function message(msg)
	if not playerSettings:get('showMessages') then return end

	ui.showMessage(msg)
end

local function toggleAutoAttack()
	if autoAttackControl then
		autoAttackControl = false
		debugMessage("Setting autoAttackControl to %s", autoAttackControl)

		autoAttackState = 0
		self.controls.use = 0
		timePassed = 0

		message("Auto attack disabled.")
	else
		local equipment = Player.equipment(self)

		if Player.stance(self) ~= Player.STANCE.Weapon then return end

		if playerSettings:get('useWhitelist') and not weaponWhitelist[equipment[carriedRight].recordId] then return end

		if playerSettings:get('marksmanOnlyMode') then
			if not equipment[carriedRight] then return end
			if Weapon.record(equipment[carriedRight]).type ~= Weapon.TYPE.MarksmanBow
			and Weapon.record(equipment[carriedRight]).type ~= Weapon.TYPE.MarksmanCrossbow
			and Weapon.record(equipment[carriedRight]).type ~= Weapon.TYPE.MarksmanThrown then
				return
			end
		end

		autoAttackControl = true
		debugMessage("Setting autoAttackControl to %s", autoAttackControl)

		message("Auto attack enabled.")
	end
end

local function autoAttack(dt)
	if not playerSettings:get('modEnable') then return end

	if not autoAttackControl then return end

	-- Disable auto attack if the player is no longer holding a weapon, avoids putting away weapon and forgetting it's on
	if Player.stance(self) ~= Player.STANCE.Weapon then
		toggleAutoAttack()
		return
	end

	if playerSettings:get('stopOnRelease') then
		if playerSettings:get('attackBindingMode') and not input.isActionPressed(input.ACTION.Use) then
			toggleAutoAttack()
			return
		end
		if not playerSettings:get('attackBindingMode') and not input.isKeyPressed(playerSettings:get('autoAttackHotkey')) then
			toggleAutoAttack()
			return
		end
	end

	timePassed = timePassed + dt

	-- This still isn't a good implementation, need to know how the formula for weapon speed works under the hood
	local equipment = Player.equipment(self)
	local weaponSpeed
	if equipment[carriedRight] then
		weaponSpeed = types.Weapon.record(equipment[carriedRight]).speed
	else
		weaponSpeed = 1
	end

	if autoAttackState == 0 then
		self.controls.use = 1
		debugMessage("Setting self.controls.use to %s", self.controls.use)

		autoAttackState = 1
		debugMessage("Setting autoAttackState to %s", autoAttackState)
	elseif autoAttackState == 1 and timePassed >= (playerSettings:get('attackTimerInterval') * (1 / weaponSpeed)) then
		self.controls.use = 0
		debugMessage("Setting self.controls.use to %s", self.controls.use)

		autoAttackState = 0
		debugMessage("Setting autoAttackState to %s", autoAttackState)

		timePassed = 0
	end
end

local function onKeyPress(key)
	if not playerSettings:get('modEnable') then return end

	if core.isWorldPaused() then return end

	if key.code ~= playerSettings:get('autoAttackHotkey') then return end

	if playerSettings:get('attackBindingMode') then return end

	toggleAutoAttack()
end

local function onInputAction(id)
	if not playerSettings:get('modEnable') then return end

	if core.isWorldPaused() then return end

	if id ~= input.ACTION.Use then return end

	if not playerSettings:get('attackBindingMode') then return end

	toggleAutoAttack()
end

return {
	engineHandlers = {
		onUpdate = autoAttack,
		onKeyPress = onKeyPress,
		onInputAction = onInputAction,
	}
}

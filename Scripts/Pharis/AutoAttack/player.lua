--[[

Mod: Auto Attack
Author: Pharis

--]]

local async = require('openmw.async')
local core = require('openmw.core')
local I = require('openmw.interfaces')
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
local userInterfaceSettings = storage.playerSection('SettingsPlayer' .. modName .. 'UI')
local controlsSettings = storage.playerSection('SettingsPlayer' .. modName .. 'Controls')
local gameplaySettings = storage.playerSection('SettingsPlayer' .. modName .. 'Gameplay')

-- Other Variables
local Actor = types.Actor
local Player = types.Player
local Weapon = types.Weapon
local carriedRight = Actor.EQUIPMENT_SLOT.CarriedRight

local autoAttackControl = false
local sheatheOnDisable = false
local autoAttackState = 0
local timePassed = 0
local autoAttackInterval = 1.0

local weaponWhitelist = require('Scripts.Pharis.AutoAttack.weaponWhitelist')

local weaponTypesMarksman = {
	[Weapon.TYPE.MarksmanBow] = true,
	[Weapon.TYPE.MarksmanCrossbow] = true,
	[Weapon.TYPE.MarksmanThrown] = true,
}

local function debugMessage(msg, _)
	if (not playerSettings:get('showDebug')) then return end

	print("[" .. modName .. "]", string.format(msg, _))
end

local function message(msg, _)
	if (not userInterfaceSettings:get('showMessages')) then return end

	ui.showMessage(string.format(msg, _))
end

local function isMarksmanWeapon(weapon)
	if (not weapon) then return false end -- Accounts for fists

	local weaponType = Weapon.record(weapon).type

	return weaponTypesMarksman[weaponType]
end

local function toggleAutoAttack()
	if (not playerSettings:get('modEnable')) then return end

	if (core.isWorldPaused()) then return end

	if (autoAttackControl) then
		autoAttackControl = false
		debugMessage("Set 'autoAttackControl' to: %s", autoAttackControl)

		I.Controls.overrideCombatControls(false)

		autoAttackState = 0
		self.controls.use = 0
		timePassed = 0

		if (sheatheOnDisable) or (gameplaySettings:get('sheatheOnDisable')) then
			async:newUnsavableSimulationTimer(1, function ()
				if (Actor.stance(self) ~= Actor.STANCE.Weapon) then return end
				Actor.setStance(self, Actor.STANCE.Nothing)
			end)
			sheatheOnDisable = false
		end

		message("Auto attack disabled.")
	else
		local equipment = Actor.equipment(self)
		local equippedWeapon = equipment[carriedRight]

		if (gameplaySettings:get('useWhitelist')) then
			if (not equippedWeapon) or (not weaponWhitelist[equippedWeapon.recordId]) then
				debugMessage("Weapon whitelist mode is active but equipped weapon is not on weapon whitelist. Aborting auto attack attempt.")
				return
			end
		end

		if (gameplaySettings:get('marksmanOnlyMode')) and (not isMarksmanWeapon(equippedWeapon)) then
			debugMessage("Marksman only mode is active but equipped weapon is not marksman weapon. Aborting auto attack attempt.")
			return
		end

		if (gameplaySettings:get('drawOnEnable')) and (Actor.stance(self) ~= Actor.STANCE.Weapon) then
			Actor.setStance(self, Actor.STANCE.Weapon)
		end

		if (Actor.stance(self) ~= Actor.STANCE.Weapon) then return end

		-- Overriding combat controls prevents weirdness with stopOnRelease and toggle weapon input action
		I.Controls.overrideCombatControls(true)

		autoAttackControl = true
		debugMessage("Set 'autoAttackControl' to: %s", autoAttackControl)

		message("Auto attack enabled.")
	end
end

local function autoAttack(dt)
	if (not playerSettings:get('modEnable')) then return end

	if (core.isWorldPaused()) then return end

	if (not autoAttackControl) then return end

	if (input.isKeyPressed(controlsSettings:get('decreaseAttackIntervalHotkey'))) then
		autoAttackInterval = autoAttackInterval - (0.5 * dt)
		debugMessage("Set 'autoAttackInterval' to: %s", autoAttackInterval)
	elseif (input.isKeyPressed(controlsSettings:get('increaseAttackIntervalHotkey'))) then
		autoAttackInterval = autoAttackInterval + (0.5 * dt)
		debugMessage("Set 'autoAttackInterval' to: %s", autoAttackInterval)
	end

	autoAttackInterval = math.max(autoAttackInterval, 0.0)

	-- Disable auto attack if the player is no longer holding a weapon, avoids putting away weapon and forgetting it's on
	-- or auto attack remaining enabled after a weapon breaks
	if (Actor.stance(self) ~= Actor.STANCE.Weapon) then
		toggleAutoAttack()
		return
	end

	if (controlsSettings:get('stopOnRelease')) then
		if (not input.isKeyPressed(controlsSettings:get('autoAttackHotkey'))) and (not input.isActionPressed(input.ACTION.Use)) then
			toggleAutoAttack()
			return
		end
	end

	local equipment = Actor.equipment(self)
	local equippedWeapon = equipment[carriedRight]

	-- Thanks to uramer and Petr Mikheev for fixing this part for me :)
	if (autoAttackState == 0) then
		self.controls.use = 1 -- start charging attack

		autoAttackState = 1
		debugMessage("Set 'autoAttackState' to: %s", autoAttackState)

		debugMessage("Attack interval: %s", autoAttackInterval)

	elseif (timePassed < autoAttackInterval) then
		self.controls.use = 1 -- continue charging attack (otherwise playercontrols.lua sets it to 0)

		timePassed = timePassed + dt

		return
	else
		self.controls.use = 0 -- finish attack

		autoAttackState = 0
		debugMessage("Set 'autoAttackState' to: %s", autoAttackState)

		timePassed = 0
	end
end

-- Functionally identical to how it was previously I just think it looks a little neater I guess
local inputActionHandler = {
	autoAttackHotkey = function ()
		if (controlsSettings:get('attackBindingMode')) then return end

		debugMessage("Input action 'autoAttackHotkey' detected.")

		toggleAutoAttack()
	end,
	attackBinding = function ()
		if (not controlsSettings:get('attackBindingMode')) then return end

		debugMessage("Input action 'attackBinding' detected.")

		toggleAutoAttack()
	end,
	toggleWeapon = function ()
		if (controlsSettings:get('stopOnRelease')) then return end

		if (not autoAttackControl) then return end

		debugMessage("Input action 'toggleWeapon' detected.")

		sheatheOnDisable = true

		toggleAutoAttack()
	end
}

local function onKeyPress(key)
	if (not playerSettings:get('modEnable')) then return end

	if (core.isWorldPaused()) then return end

	if (key.code == controlsSettings:get('autoAttackHotkey')) then
		inputActionHandler['autoAttackHotkey']()
	end
end

local function onInputAction(id)
	if (not playerSettings:get('modEnable')) then return end

	if (core.isWorldPaused()) then return end

	if (id == input.ACTION.Use) then
		inputActionHandler['attackBinding']()
	elseif (id == input.ACTION.ToggleWeapon) then
		inputActionHandler['toggleWeapon']()
	end
end

local function onSave()
	debugMessage("Saving data.")
	return {
		autoAttackInterval = autoAttackInterval
	}
end

local function onLoad(data)
	if (not data) then return end

	autoAttackInterval = data.autoAttackInterval

	debugMessage("Retrieved saved data.")
end

return {
	engineHandlers = {
		onFrame = autoAttack,
		onKeyPress = onKeyPress,
		onInputAction = onInputAction,
		onSave = onSave,
		onLoad = onLoad,
	}
}

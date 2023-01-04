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

local weaponWhitelist = require('Scripts.Pharis.AutoAttack.weaponWhitelist')

local weaponTypesMarksman = {
	false, -- Arrow
	false, -- AxeOneHand
	false, -- AxeTwoHand
	false, -- BluntOneHand
	false, -- BluntTwoClose
	false, -- BluntTwoWide
	false, -- Bolt
	false, -- LongBladeOneHand
	true, -- LongBladeTwoHand
	true, -- MarksmanBow
	true, -- MarksmanCrossbow
	false, -- MarksmanThrown
	false, -- ShortBladeOneHand
	false, -- SpearTwoWide
}

local function debugMessage(msg, _)
	if (not playerSettings:get('showDebug')) then return end

	print("[" .. modName .. "]", string.format(msg, _))
end

local function message(msg)
	if (not userInterfaceSettings:get('showMessages')) then return end

	ui.showMessage(msg)
end

local function isMarksmanWeapon(weapon)
	if (not weapon) then return false end
	local weaponType = Weapon.record(weapon).type
	return weaponTypesMarksman[weaponType + 1]
end

local function toggleAutoAttack(test)
	if (not playerSettings:get('modEnable')) then return end

	if (core.isWorldPaused()) then return end

	if (autoAttackControl) then
		autoAttackControl = false
		debugMessage("Set 'autoAttackControl' to: %s", autoAttackControl)

		I.Controls.overrideCombatControls(false)

		autoAttackState = 0
		self.controls.use = 0
		timePassed = 0

		-- This feels jank for some reason, maybe redo when I'm less lazy
		if (gameplaySettings:get('sheatheOnDisable')) then
			sheatheOnDisable = true
		end

		if (sheatheOnDisable) then
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
				debugMessage("Equipped weapon is not on weapon whitelist. Aborting auto attack attempt.")
				return
			end
		end

		if (gameplaySettings:get('marksmanOnlyMode')) and (not isMarksmanWeapon(equippedWeapon)) then
			debugMessage("Equipped weapon is not marksman weapon. Aborting auto attack attempt.")
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

	-- Disable auto attack if the player is no longer holding a weapon, avoids putting away weapon and forgetting it's on
	if (Actor.stance(self) ~= Actor.STANCE.Weapon) then
		toggleAutoAttack()
		return
	end

	if (controlsSettings:get('stopOnRelease')) then
		if (controlsSettings:get('attackBindingMode')) and not input.isActionPressed(input.ACTION.Use) then
			toggleAutoAttack()
			return
		elseif (not controlsSettings:get('attackBindingMode')) and (not input.isKeyPressed(controlsSettings:get('autoAttackHotkey'))) then
			toggleAutoAttack()
			return
		end
	end

	timePassed = timePassed + dt

	-- This still isn't a good implementation, need to know how the formula for weapon speed works under the hood
	local equipment = Actor.equipment(self)
	local equippedWeapon = equipment[carriedRight]

	if (equippedWeapon) then
		weaponSpeed = types.Weapon.record(equippedWeapon).speed
	else
		weaponSpeed = 1.2
	end

	-- Thanks to uramer and Petr Mikheev for fixing this part for me :)
	if (autoAttackState == 0) then
		self.controls.use = 1 -- start charging attack

		autoAttackState = 1
		debugMessage("Set 'autoAttackState' to: %s", autoAttackState)
	elseif (timePassed < gameplaySettings:get('attackChargePercentage') * (1.2 * (1 / weaponSpeed))) then
		self.controls.use = 1 -- continue charging attack (otherwise playercontrols.lua sets it to 0)
		return
	else
		self.controls.use = 0 -- finish attack

		autoAttackState = 0
		debugMessage("Set 'autoAttackState' to: %s", autoAttackState)

		timePassed = 0
	end
end

local function onKeyPress(key)
	if (not playerSettings:get('modEnable')) then return end

	if (core.isWorldPaused()) then return end

	if (key.code ~= controlsSettings:get('autoAttackHotkey')) then return end

	if (controlsSettings:get('attackBindingMode')) then return end

	toggleAutoAttack()
end

local function onInputAction(id)
	if (not playerSettings:get('modEnable')) then return end

	if (core.isWorldPaused()) then return end

	-- With stop on release active this is pointless and just another source of potential jank
	if (not controlsSettings:get('stopOnRelease')) then
		if (id == input.ACTION.ToggleWeapon) and (autoAttackControl) then
			sheatheOnDisable = true
			toggleAutoAttack()
			return
		end
	end

	if (id ~= input.ACTION.Use) then return end

	if (not controlsSettings:get('attackBindingMode')) then return end

	toggleAutoAttack()
end

return {
	engineHandlers = {
		onFrame = autoAttack,
		onKeyPress = onKeyPress,
		onInputAction = onInputAction,
	}
}

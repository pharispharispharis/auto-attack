--[[

Mod: Auto Attack
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
	if (not playerSettings:get('showMessages')) then return end

	ui.showMessage(msg)
end

local function isMarksmanWeapon(weapon)
	if not weapon then return false end
	local weaponType = Weapon.record(weapon).type
	return weaponTypesMarksman[weaponType + 1]
end

local function toggleAutoAttack()
	if (not playerSettings:get('modEnable')) then return end

	if (core.isWorldPaused()) then return end

	if (autoAttackControl) then
		autoAttackControl = false
		debugMessage("Set 'autoAttackControl' to: %s", autoAttackControl)

		autoAttackState = 0
		self.controls.use = 0
		timePassed = 0

		message("Auto attack disabled.")
	else
		local equipment = Player.equipment(self)
		local equippedWeapon = equipment[carriedRight]

		if (Player.stance(self) ~= Player.STANCE.Weapon) then return end

		if (playerSettings:get('useWhitelist')) then
			if (not equippedWeapon) or (not weaponWhitelist[equippedWeapon.recordId]) then
				debugMessage("Equipped weapon is not on weapon whitelist. Aborting auto attack attempt.")
				return
			end
		end

		if (playerSettings:get('marksmanOnlyMode')) and (not isMarksmanWeapon(equippedWeapon)) then
			debugMessage("Equipped weapon is not marksman weapon. Aborting auto attack attempt.")
			return
		end

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
	if (Player.stance(self) ~= Player.STANCE.Weapon) then
		toggleAutoAttack()
		return
	end

	if (playerSettings:get('stopOnRelease')) then
		if (playerSettings:get('attackBindingMode')) and not input.isActionPressed(input.ACTION.Use) then
			toggleAutoAttack()
			return
		elseif (not playerSettings:get('attackBindingMode')) and (not input.isKeyPressed(playerSettings:get('autoAttackHotkey'))) then
			toggleAutoAttack()
			return
		end
	end

	timePassed = timePassed + dt

	-- This still isn't a good implementation, need to know how the formula for weapon speed works under the hood
	local equipment = Player.equipment(self)
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
	elseif (timePassed < playerSettings:get('attackChargePercentage') * (1.2 * (1 / weaponSpeed))) then
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

	if (key.code ~= playerSettings:get('autoAttackHotkey')) then return end

	if (playerSettings:get('attackBindingMode')) then return end

	toggleAutoAttack()
end

local function onInputAction(id)
	if (not playerSettings:get('modEnable')) then return end

	if (core.isWorldPaused()) then return end

	if (id ~= input.ACTION.Use) then return end

	if (not playerSettings:get('attackBindingMode')) then return end

	toggleAutoAttack()
end

return {
	engineHandlers = {
		onFrame = autoAttack,
		onKeyPress = onKeyPress,
		onInputAction = onInputAction,
	}
}

--[[

Mod: Auto Attack
Author: Pharis

--]]

local async = require('openmw.async')
local core = require('openmw.core')
local I = require('openmw.interfaces')
local input = require('openmw.input')
local storage = require('openmw.storage')
local ui = require('openmw.ui')

-- Mod info
local modInfo = require('Scripts.Pharis.AutoAttack.modInfo')
local modName = modInfo.modName
local modVersion = modInfo.modVersion

-- General settings description(s)
local modEnableDescription = "To mod or not to mod."
local logDebugDescription = "Press F10 to see logged messages in-game.\nLeave disabled for normal gameplay."
local autoAttackHotkeyDescription = "Choose which key toggles auto attack."
local attackBindingModeDescription = "Binds auto attack to the attack button assigned in the controls menu (typically left click). Overrides hotkey setting."
local stopOnReleaseDescription = "Stops auto attacking when the hotkey is released."
local attackChargePercentageDescription = "How much each attack is charged."
local showMessagesDescription = "Show messages on screen when auto attack is toggled."
local marksmanOnlyDescription = "Limits auto attack to marksman weapons only. Implemented mostly in case it is useful for mods such as Starwind."
local useWhitelistDescription = "Allow auto attacking only for weapons on the whitelist. To add to the whitelist edit the provided 'weaponWhitelist.lua' file."

-- Other variables
local playerSettings = storage.playerSection('SettingsPlayer' .. modName)

local function setting(key, renderer, argument, name, description, default)
	return {
		key = key,
		renderer = renderer,
		argument = argument,
		name = name,
		description = description,
		default = default,
	}
end
--[[
local function updateModDisabled()
    local disabled = not playerSettings:get('modEnable')
    I.Settings.updateRendererArgument('SettingsPlayer' .. modName, 'showDebug', {disabled = disabled})
    I.Settings.updateRendererArgument('SettingsPlayer' .. modName, 'autoAttackHotkey', {disabled = disabled})
    I.Settings.updateRendererArgument('SettingsPlayer' .. modName, 'stopOnRelease', {disabled = disabled})
	I.Settings.updateRendererArgument('SettingsPlayer' .. modName, 'attackBindingMode', {disabled = disabled})
    I.Settings.updateRendererArgument('SettingsPlayer' .. modName, 'attackTimerInterval', {disabled = disabled})
	I.Settings.updateRendererArgument('SettingsPlayer' .. modName, 'showMessages', {disabled = disabled})
	I.Settings.updateRendererArgument('SettingsPlayer' .. modName, 'marksmanOnlyMode', {disabled = disabled})
	I.Settings.updateRendererArgument('SettingsPlayer' .. modName, 'useWhitelist', {disabled = disabled})
end

playerSettings:subscribe(async:callback(updateModDisabled))
]]
local function initSettings()
	I.Settings.registerRenderer('inputKeySelection', function(value, set)
		local name = "No Key Set"
		if value then
			if value == input.KEY.Escape then
				name = input.getKeyName(playerSettings:get('autoAttackHotkey'))
			else
				name = input.getKeyName(value)
			end
		end
		return {
			template = I.MWUI.templates.box,
			content = ui.content {
				{
					template = I.MWUI.templates.padding,
					content = ui.content {
						{
							template = I.MWUI.templates.textEditLine,
							props = {
								text = name,
							},
							events = {
								keyPress = async:callback(function(e)
									if e.code == input.KEY.Escape then return end
									set(e.code)
								end),
							},
						},
					},
				},
			},
		}
end)

	I.Settings.registerPage {
		key = modName,
		l10n = modName,
		name = "Auto Attack",
		description = "By Pharis"
	}

	I.Settings.registerGroup {
		key = 'SettingsPlayer' .. modName,
		page = modName,
		l10n = modName,
		name = "General Settings",
		permanentStorage = false,
		settings = {
			setting('modEnable', 'checkbox', {}, "Enable Mod", modEnableDescription, true),
			setting('showDebug', 'checkbox', {}, "Log Debug Messages", logDebugDescription, false),
			setting('autoAttackHotkey', 'inputKeySelection', {}, "Auto Attack Hotkey", autoAttackHotkeyDescription, input.KEY.G),
			setting('attackBindingMode', 'checkbox', {}, "Attack Binding Mode", attackBindingModeDescription, false),
			setting('stopOnRelease', 'checkbox', {}, "Stop On Release", stopOnReleaseDescription, false),
			setting('attackChargePercentage', 'number', {min = 0.0, max = 1.0}, "Attack Charge Percentage", attackChargePercentageDescription, 1.0),
			setting('showMessages', 'checkbox', {}, "Show Messages", showMessagesDescription, false),
			setting('marksmanOnlyMode', 'checkbox', {}, "Marksman Only Mode (Starwind Mode)", marksmanOnlyDescription, false),
			setting('useWhitelist', 'checkbox', {}, "Use Whitelist", useWhitelistDescription, false),
		}
	}

	print("[" .. modName .. "] Initialized v" .. modVersion)
end

return {
	engineHandlers = {
		onActive = initSettings,
	}
}

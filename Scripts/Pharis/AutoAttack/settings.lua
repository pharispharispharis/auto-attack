--[[

Mod: Auto Attack - OpenMW Lua
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
local modEnableConfDesc = "To mod or not to mod."
local logDebugConfDesc = "Press F10 to see logged messages in-game."
local modHotkeyConfDesc = "Choose which key toggles auto attack."
local attackTimerIntervalConfDesc = "Auto attack timer interval in seconds. Very low or high values will obviously be rather impractical."
local showMessagesConfDesc = "Show messages on screen when auto attack is toggled."
local stopOnReleaseConfDesc = "Stops auto attacking when the hotkey is released."
local attackBindingModeConfDesc = "Binds auto attack to the attack button assigned in the controls menu (typically left click). Overrides hotkey setting."
local marksmanOnlyConfDesc = "Limits auto attack to marksman weapons only. Implemented mostly in case it is useful for mods such as Starwind."

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

local function initSettings()
	I.Settings.registerRenderer('inputKeySelection', function(value, set)
		local name = "No Key Set"
		if value then
			if value == input.KEY.Escape then
				name = input.getKeyName(playerSettings:get('modHotkeyConf'))
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
		description = "By Pharis\n\nAuto attack with configurable speed."
	}

	I.Settings.registerGroup {
		key = 'SettingsPlayer' .. modName,
		page = modName,
		l10n = modName,
		name = "General Settings",
		permanentStorage = false,
		settings = {
			setting('modEnableConf', 'checkbox', {}, "Enable Mod", modEnableConfDesc, true),
			setting('showDebugConf', 'checkbox', {}, "Log Debug Messages", logDebugConfDesc, false),
			setting('modHotkeyConf', 'inputKeySelection', {}, "Auto Attack Hotkey", modHotkeyConfDesc, input.KEY.G),
			setting('attackTimerIntervalConf', 'number', {}, "Auto Attack Timer Interval", attackTimerIntervalConfDesc, 1),
			setting('showMessagesConf', 'checkbox', {}, "Show Messages", showMessagesConfDesc, false),
			setting('stopOnReleaseConf', 'checkbox', {}, "Stop On Release", stopOnReleaseConfDesc, false),
			setting('attackBindingModeConf', 'checkbox', {}, "Attack Binding Mode", attackBindingModeConfDesc, false),
			setting('marksmanOnlyModeConf', 'checkbox', {}, "Marksman Only Mode (Starwind Mode)", marksmanOnlyConfDesc, false),
		}
	}

	print("[" .. modName .. "] Initialized v" .. modVersion)
end

return {
	engineHandlers = {
		onActive = initSettings,
	}
}

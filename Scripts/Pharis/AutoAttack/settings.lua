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
local modEnableDescription = "To mod or not to mod."
local logDebugDescription = "Press F10 to see logged messages in-game."
local modHotkeyDescription = "Choose which key toggles auto attack."
local attackTimerIntervalDescription = "Auto attack timer interval in seconds. Very low or high values will obviously be rather impractical."
local showMessagesDescription = "Show messages on screen when auto attack is toggled."
local stopOnReleaseDescription = "Stops auto attacking when the hotkey is released."
local attackBindingModeDescription = "Binds auto attack to the attack button assigned in the controls menu (typically left click). Overrides hotkey setting."
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

local function updateModDisabled()
    local disabled = not playerSettings:get('modEnable')
    I.Settings.updateRendererArgument('SettingsPlayer' .. modName, 'showDebug', {disabled = disabled})
    I.Settings.updateRendererArgument('SettingsPlayer' .. modName, 'modHotkey', {disabled = disabled})
    I.Settings.updateRendererArgument('SettingsPlayer' .. modName, 'stopOnRelease', {disabled = disabled})
	I.Settings.updateRendererArgument('SettingsPlayer' .. modName, 'attackBindingMode', {disabled = disabled})
    I.Settings.updateRendererArgument('SettingsPlayer' .. modName, 'attackTimerInterval', {disabled = disabled})
	I.Settings.updateRendererArgument('SettingsPlayer' .. modName, 'showMessages', {disabled = disabled})
	I.Settings.updateRendererArgument('SettingsPlayer' .. modName, 'marksmanOnlyMode', {disabled = disabled})
	I.Settings.updateRendererArgument('SettingsPlayer' .. modName, 'useWhitelist', {disabled = disabled})
end

playerSettings:subscribe(async:callback(updateModDisabled))

local function initSettings()
	I.Settings.registerRenderer('inputKeySelection', function(value, set)
		local name = "No Key Set"
		if value then
			if value == input.KEY.Escape then
				name = input.getKeyName(playerSettings:get('modHotkey'))
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
			setting('modEnable', 'checkbox', {}, "Enable Mod", modEnableDescription, true),
			setting('showDebug', 'checkbox', {}, "Log Debug Messages", logDebugDescription, false),
			setting('modHotkey', 'inputKeySelection', {}, "Auto Attack Hotkey", modHotkeyDescription, input.KEY.G),
			setting('stopOnRelease', 'checkbox', {}, "Stop On Release", stopOnReleaseDescription, false),
			setting('attackBindingMode', 'checkbox', {}, "Attack Binding Mode", attackBindingModeDescription, false),
			setting('attackTimerInterval', 'number', {}, "Auto Attack Timer Interval", attackTimerIntervalDescription, 1),
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

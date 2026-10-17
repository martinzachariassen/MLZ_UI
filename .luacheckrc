-- luacheck config for MLZ UI (WoW Classic, Lua 5.1). Run: luacheck .
std = "lua51"
max_line_length = false
codes = true
exclude_files = { ".release/", "Libs/" }

ignore = {
    "212", -- unused argument (event handlers and methods keep their full signature)
    "42.", -- shadowing a local (short-lived inner locals such as `current`)
    "43.", -- shadowing an upvalue (`self` in nested script handlers)
}

-- The only globals MLZ UI may set (see CLAUDE.md > Code style)
globals = {
    "MLZUIDB", "MLZUI", "MLZUIScanTooltip", "GetMinimapShape",
    "SLASH_MLZUI1", "SlashCmdList",
    "MLZUI_OnAddonCompartmentClick", "MLZUI_OnAddonCompartmentEnter", "MLZUI_OnAddonCompartmentLeave",
    -- Blizzard chat tab alphas, set by Fade and restored on undo
    "CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA", "CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA",
    -- Key Bindings names for Bindings.xml (Modules/Group.lua)
    "BINDING_HEADER_MLZUI", "BINDING_NAME_MLZUI_PULL",
}

-- WoW API, frames and constants we read. Add new ones here when luacheck flags them.
read_globals = {
    -- Lua extensions in the WoW client
    "bit", "date", "time", "strlower", "strsplit", "strtrim", "tinsert", "wipe",
    "hooksecurefunc", "issecure", "issecretvalue",

    -- C_ namespaces and tables
    "C_ActionBar", "C_AddOns", "C_Container", "C_CVar", "C_EditMode", "C_EncodingUtil", "C_Item",
    "C_NamePlate", "C_PartyInfo", "C_PetBattles", "C_SpecializationInfo", "C_Spell", "C_Timer", "C_TooltipInfo",
    "C_UnitAuras", "Constants", "Enum", "EventRegistry", "Settings", "TooltipDataProcessor",

    -- Frames and fonts
    "ChatFontNormal", "DEFAULT_CHAT_FRAME", "EditModeManagerFrame", "EditModePresetLayoutManager",
    "EditModeSettingDisplayInfoManager", "GameTooltip", "InterfaceOptionsFrame", "NamePlateDriverFrame",
    "NumberFontNormal", "PlayerFrame", "SettingsPanel", "UIParent", "UISpecialFrames", "WorldFrame",

    -- Constants
    "COMBATLOG_OBJECT_AFFILIATION_MINE", "DEFAULT_CHATFRAME_ALPHA", "INVSLOT_MAINHAND", "INVSLOT_OFFHAND",
    "LE_ITEM_CLASS_WEAPON", "LE_PARTY_CATEGORY_INSTANCE", "MAX_PLAYER_LEVEL", "NUM_BAG_SLOTS",
    "NUM_CHAT_WINDOWS", "RAID_CLASS_COLORS", "STANDARD_TEXT_FONT",

    -- Functions
    "ActionButton_UpdateHotkeys", "ActionButton_UpdateUsable", "CanGuildBankRepair", "CanMerchantRepair",
    "CombatLogGetCurrentEventInfo", "CreateFont", "CreateFrame", "FCF_SetWindowAlpha",
    "GetActionBarToggles", "GetActionInfo", "GetActionText", "GetActionTexture", "GetAddOnInfo", "GetAddOnMetadata", "EnableAddOn",
    "GetBinding", "GetBindingAction", "GetBindingKey", "GetBuildInfo", "GetChatWindowInfo",
    "GetCoinTextureString", "GetContainerItemInfo", "GetContainerNumSlots", "GetCreatureDifficultyColor",
    "GetCurrentBindingSet", "GetCursorPosition", "GetCVar", "GetFramerate", "GetGuildBankWithdrawMoney",
    "GetInventoryItemCount", "GetInventoryItemDurability", "GetInventoryItemID", "GetInventoryItemTexture",
    "GetInventorySlotInfo", "GetItemCount", "GetItemIcon", "GetItemInfo", "GetItemInfoInstant",
    "GetMacroInfo", "GetMaxPlayerLevel", "GetMoney", "GetNetStats", "GetNumBindings",
    "GetNumShapeshiftForms", "GetNumSkillLines", "GetNumTalentTabs", "GetPetActionInfo",
    "GetPhysicalScreenSize", "GetQuestDifficultyColor", "GetRaidTargetIndex", "GetRealmName",
    "GetRepairAllCost", "GetScreenHeight", "GetScreenWidth", "GetShapeshiftForm", "GetShapeshiftFormID",
    "GetShapeshiftFormInfo", "GetSkillLineInfo", "GetSpellInfo", "GetSpellLink", "GetSpellTexture",
    "GetTalentTabInfo", "GetTime", "GetWeaponEnchantInfo", "GetXPExhaustion", "HasAction", "HideUIPanel",
    "InCombatLockdown", "InterfaceOptions_AddCategory", "IsActionInRange", "IsAddOnLoaded", "IsInGroup",
    "IsInGuild", "IsInInstance", "IsInRaid", "IsMounted", "IsPlayerAtEffectiveMaxLevel", "IsPlayerSpell",
    "IsResting", "IsShiftKeyDown", "IsSpellKnown", "IsUsableAction", "IsXPUserDisabled", "ReloadUI",
    "RepairAllItems", "SaveBindings", "SendChatMessage", "SetActionBarToggles", "SetBinding", "SetCVar",
    "SetRaidTargetIconTexture", "ShowUIPanel", "UnitAffectingCombat", "UnitAura", "UnitBuff",
    "UnitCanAttack", "UnitCastingInfo", "UnitChannelInfo", "UnitClass", "UnitClassification",
    "UnitEffectiveLevel", "UnitExists", "UnitGroupRolesAssigned", "UnitGUID", "UnitHasEffectivelyTankAura",
    "UnitHealth", "UnitHealthMax", "UnitIsConnected", "UnitIsDeadOrGhost", "UnitIsFriend", "UnitIsGroupAssistant", "UnitIsGroupLeader", "UnitIsPlayer", "UnitIsQuestBoss",
    "UnitIsTapDenied", "UnitIsUnit", "UnitLevel", "UnitName", "UnitNameplateShowsWidgetsOnly", "UnitOnTaxi",
    "UnitPlayerOrPetInParty", "UnitPlayerOrPetInRaid", "UnitPower", "UnitPowerMax", "UnitPowerType",
    "UnitReaction", "UnitThreatSituation", "UnitXP", "UnitXPMax", "UseContainerItem",

    -- Quests, popups, summons and pets (Modules/Automate.lua, Modules/Reminders.lua)
    "AcceptQuest", "AcceptResurrect", "C_GossipInfo", "C_SummonInfo", "CancelDuel", "CompleteQuest",
    "ConfirmLootSlot", "ConfirmSummon", "GetActiveTitle", "GetAvailableTitle", "GetQuestMoneyToGet", "GetNumActiveQuests", "GetNumAvailableQuests",
    "GetNumQuestChoices", "GetPetHappiness", "GetQuestReward", "GetSummonConfirmSummoner",
    "GetSummonConfirmTimeLeft", "IsQuestCompletable", "QuestGetAutoAccept", "SelectActiveQuest",
    "SelectAvailableQuest", "StaticPopup_Hide",

    -- Other addons we read settings from (only when they are loaded)
    "AtlasLoot", "AUCTIONATOR_CHARACTER_CONFIG", "AUCTIONATOR_CONFIG", "BAGANATOR_CONFIG",
    "BAGANATOR_CURRENT_PROFILE", "Bagnon_Sets", "Clique", "DBM", "DBM_MinimapIcon", "DBT", "Details",
    "LeaMapsDB", "LeaPlusDB", "Platynator", "PLATYNATOR_CONFIG", "PLATYNATOR_CURRENT_PROFILE", "Prat",
    "Questie", "TomTom",
}

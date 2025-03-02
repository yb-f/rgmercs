local mq           = require('mq')
local Combat       = require('utils.combat')
local Config       = require('utils.config')
local Core         = require("utils.core")
local Targeting    = require("utils.targeting")
local Casting      = require("utils.casting")
local DanNet       = require('lib.dannet.helpers')

local _ClassConfig = {
    _version              = "1.0 - Emu",
    _author               = "Algar, Derple, Lisie",
    ['ModeChecks']        = {
        IsHealing = function() return true end,
        IsCuring = function() return true end,
        IsRezing = function() return Config:GetSetting('DoBattleRez') or Targeting.GetXTHaterCount() == 0 end,
    },
    ['Modes']             = {
        'Heal',
    },
    ['Cures']             = {
        CureNow = function(self, type, targetId)
            if Casting.AAReady("Radiant Cure") then
                return Casting.UseAA("Radiant Cure", targetId)
            elseif Casting.AAReady("Purify Soul") then
                return Casting.UseAA("Purify Soul", targetId)
            end

            local cureSpell = Config:GetSetting('KeepCureMemmed') == 3 and Core.GetResolvedActionMapItem('GroupHealCure') or Core.GetResolvedActionMapItem('CureAll')

            if type:lower() == "disease" then
                if not cureSpell then
                    cureSpell = Core.GetResolvedActionMapItem('CureDisease')
                end
            elseif type:lower() == "poison" then
                if not cureSpell then
                    cureSpell = Core.GetResolvedActionMapItem('CurePoison')
                end
            elseif type:lower() == "curse" then
                if not cureSpell or cureSpell.Level() == (51 or 57 or 84) then --First two group cures and first cureall don't cure curse
                    cureSpell = Core.GetResolvedActionMapItem('CureCurse')
                end
            end

            if not cureSpell or not cureSpell() then return false end
            return Casting.UseSpell(cureSpell.RankName.Name(), targetId, true)
        end,
    },
    ['ItemSets']          = {
        ['Epic'] = {
            "Harmony of the Soul",
            "Aegis of Superior Divinity",
        },
    },
    ['AbilitySets']       = {
        ['HealingLight'] = {
            "Minor Healing",
            "Light Healing",
            "Healing",
            "Greater Healing",
            "Celestial Health",
            "Superior Healing",
            "Healing Light",
            "Divine Light",
            "Ethereal Light",
            "Supernal Light",
            "Holy Light",
            "Pious Light",
            "Ancient: Hallowed Light",
        },
        ['RemedyHeal'] = { -- Not great until 96/RoF (Graceful)
            "Remedy",
            "Ethereal Remedy",
            "Supernal Remedy",
            "Pious Remedy",
        },
        ['GroupHealCure'] = {
            "Word of Restoration",   -- Poi/Dis
            "Word of Replenishment", -- Poi/Dis/Curse
            "Word of Vivification",
        },
        ['GroupHealNoCure'] = {
            -----Group Heals No Cure Slot 5
            "Word of Health",
            "Word of Healing",
            "Word of Vigor",
            "Word of Restoration", -- No good NoCure in these level ranges using w/Cure... Note Word of Redemption omitted (12sec cast)
            "Word of Replenishment",
            "Word of Vivification",
        },
        ['DecreaseMarkDS'] = {
            -- Reverse Damage Shield
            "Mark of Karn",
            "Mark of Kings",
            "Mark of the Blameless"
        },
        ['ReverseMarkDS'] = {
            "Mark of Retribution",
            "Mark of the Righteous",
            "Mark of the Blameless",
        },
        ['SelfHPBuff'] = {
            --Self Buff for Mana Regen and armor
            "Armor of Protection",
            "Blessed Armor of the Risen",
            "Ancient: High Priest's Bulwark",
            "Armor of the Zealot",
            "Armor of the Pious",
        },
        ['AegoBuff'] = {
            ----Use HP Type one until Temperance at 40... Group Buff at 45 (Blessing of Temperance)
            "Courage",
            "Center",
            "Daring",
            "Bravery",
            "Valor",
            "Temperance",
            "Blessing of Temperance",
            "Aegolism",
            "Blessing of Aegolism",
            "Virtue",
            "Hand of Virtue",
            "Conviction",
            "Hand of Conviction",
        },
        ['ACBuff'] = { --Sometimes single, sometimes group, used on tank before Aego or until it is rolled into Unified (Symbol)
            "Ward of Valliance",
            "Ward of Gallantry",
            "Bulwark of Faith",
            "Shield of Words",
            "Armor of Faith",
            "Guard",
            "Spirit Armor",
            "Holy Armor",
        },
        ['SingleVieBuff'] = { -- Level 20-73
            "Panoply of Vie",
            "Bulwark of Vie",
            "Protection of Vie",
            "Guard of Vie",
            "Ward of Vie",
        },
        ['GroupSymbolBuff'] = {
            ----Group Symbols
            "Symbol of Transal",
            "Symbol of Ryltan",
            "Symbol of Pinzarn",
            "Symbol of Naltron",
            "Symbol of Marzin",
            "Naltron's Mark",
            "Marzin's Mark",
            "Symbol of Kazad",
            "Kazad's Mark",
            "Symbol of Balikor",
            "Balikor's Mark",
        },
        ['DivineBuff'] = {
            --Divine Buffs REQUIRES extra spell slot because of the 90s recast
            "Death Pact",
            "Divine Intervention",
        },
        ['RezSpell'] = {
            "Reviviscence",
            "Resurrection",
            "Restoration",
            "Resuscitate",
            "Renewal",
            "Revive",
            "Reparation",
            "Reconstitution",
            "Reanimation",
        },
        ['SingleElixir'] = {
            "Celestial Remedy", -- Level 19
            "Celestial Health",
            "Celestial Healing",
            "Celestial Elixir",
            "Supernal Elixir",
            "Holy Elixir",
            "Pious Elixir",
        },
        ['GroupElixir'] = {
            -- Group Hot Line - Elixirs No Cure
            "Ethereal Elixir", -- Level 59
        },
        ['SpellBlessing'] = {
            -- Spell Speed Blessings 15-92(112)Becomes Defunct due to Unifieds.)
            -- [] = "Benediction of Resplendence",
            "Blessing of Piety",
            "Blessing of Faith",
            "Blessing of Reverence",
            "Aura of Reverence",
            "Blessing of Devotion",
            "Aura of Devotion",
        },
        ['CureAll'] = {
            "Pure Blood", --Much better single cures occur after this one
        },
        ['CurePoison'] = {
            "Antidote",
            "Eradicate Poison",
            "Abolish Poison",
            "Counteract Poison",
            "Cure Poison",
        },
        ['CureDisease'] = {
            "Eradicate Disease",
            "Counteract Disease",
            "Cure Disease",
        },
        ['CureCurse'] = {
            "Remove Greater Curse",
            "Remove Curse",
            "Remove Lesser Curse",
            "Remove Minor Curse",
        },
        ['YaulpSpell'] = {
            "Yaulp V", -- Level 56, first rank with haste/mana regen
            "Yaulp VI",
            "Yaulp VII",
        },
        ['StunTimer6'] = { -- Timer 6 Stun, Fast Cast, Level 63+ (with ToT Heal 88+)
            "Sound of Divinity",
            "Sound of Might",
            --Filler before this
            "Tarnation",     -- Timer 4, up to Level 65
            "Force",         -- No Timer #, up to Level 58
            "Holy Might",    -- No Timer #, up to Level 55
        },
        ['LowLevelStun'] = { --Adding a second stun at low levels
            "Stun",
        },
        ['UndeadNuke'] = { -- Level 4+
            "Desolate Undead",
            "Destroy Undead",
            "Exile Undead",
            "Banish Undead",
            "Expel Undead",
            "Dismiss Undead",
            "Expulse Undead",
            "Ward Undead",
        },
        ['MagicNuke'] = {
            -- Basic Nuke
            "Strike",
            "Furor",
            "Smite",
            "Wrath",
            "Retribution",
            "Judgment",
            "Condemnation",
            "Order",
            "Reproach",
        },
        ['HammerPet'] = {
            "Unswerving Hammer of Faith",
            "Unswerving Hammer of Retribution",
        },
        ['CompleteHeal'] = {
            "Complete Heal",
        },
    }, -- end AbilitySets
    ['HelperFunctions']   = {
        DoRez = function(self, corpseId)
            local rezAction = false
            local rezSpell = self.ResolvedActionMap['RezSpell']

            if mq.TLO.Me.CombatState():lower() == "combat" and Config:GetSetting('DoBattleRez') then
                if mq.TLO.FindItem("Water Sprinkler of Nem Ankh")() and mq.TLO.Me.ItemReady("Water Sprinkler of Nem Ankh")() then
                    rezAction = Casting.UseItem("Water Sprinkler of Nem Ankh", corpseId)
                end
            end

            if mq.TLO.Me.CombatState():lower() == "active" or mq.TLO.Me.CombatState():lower() == "resting" then
                if Casting.SpellReady(rezSpell) then
                    rezAction = Casting.UseSpell(rezSpell, corpseId, true, true)
                end
            end

            if rezAction and mq.TLO.Spawn(corpseId).Distance3D() > 25 then
                Targeting.SetTarget(corpseId)
                Core.DoCmd("/corpse")
            end

            return rezAction
        end,
        GetMainAssistPctMana = function()
            local groupMember = mq.TLO.Group.Member(Config.Globals.MainAssist)
            if groupMember and groupMember() then
                return groupMember.PctMana() or 0
            end

            local ret = tonumber(DanNet.query(Config.Globals.MainAssist, "Me.PctMana", 1000))

            if ret and type(ret) == 'number' then return ret end

            return mq.TLO.Spawn(string.format("PC =%s", Config.Globals.MainAssist)).PctMana() or 0
        end,
    },
    -- These are handled differently from normal rotations in that we try to make some intelligent desicions about which spells to use instead
    -- of just slamming through the base ordered list.
    -- These will run in order and exit after the first valid spell to cast
    ['HealRotationOrder'] = {
        { -- Level 1-97
            name = 'GroupHeal(1-97)',
            state = 1,
            steps = 1,
            load_cond = function() return mq.TLO.Me.Level() < 98 end,
            cond = function(self, target)
                if not Targeting.GroupedWithTarget(target) then return false end
                return (mq.TLO.Group.Injured(Config:GetSetting('GroupHealPoint'))() or 0) >= Config:GetSetting('GroupInjureCnt')
            end,
        },
        { -- Level 1-70, includes BigHeal
            name = 'Heal(1-70)',
            state = 1,
            steps = 1,
            load_cond = function() return mq.TLO.Me.Level() < 70 end,
            cond = function(self, target)
                return (target.PctHPs() or 999) <= Config:GetSetting('MainHealPoint')
            end,
        },
    },
    ['HealRotations']     = {
        ["GroupHeal(1-97)"] = { --Level 1-97
            {
                name = "GroupHealNoCure",
                type = "Spell",
                cond = function(self, spell, target)
                    return Casting.GemReady(spell) and Casting.SpellReady(spell)
                end,
            },
            {
                name = "GroupHealCure",
                type = "Spell",
                cond = function(self, spell)
                    return Casting.GemReady(spell) and Casting.SpellReady(spell)
                end,
            },
            {
                name = "GroupElixir",
                type = "Spell",
                cond = function(self, spell, target)
                    if not Config:GetSetting('DoHealOverTime') then return false end
                    return Casting.GemReady(spell) and Casting.GroupBuffCheck(spell, target)
                end,
            },
            {
                name = "Celestial Regeneration",
                type = "AA",
                cond = function(self, aaName, target)
                    return Casting.AAReady(aaName)
                end,
            },
            {
                name = "Exquisite Benediction",
                type = "AA",
                cond = function(self, aaName)
                    return Casting.AAReady(aaName)
                end,
            },
        },
        ["Heal(1-70)"] = { --Level 1-69, includes Main and Big Healing
            {
                name = "Sanctuary",
                type = "AA",
                cond = function(self, aaName, target)
                    return (target.ID() or 0) == mq.TLO.Me.ID() and Casting.AAReady(aaName)
                end,
            },
            {
                name = "Divine Arbitration",
                type = "AA",
                cond = function(self, aaName, target)
                    if not Targeting.GroupedWithTarget(target) then return false end
                    return Casting.TargetedAAReady(aaName, target.ID(), true) and target.ID() == Core.GetMainAssistId and
                        (target.PctHPs() or 999) <= Config:GetSetting('BigHealPoint')
                end,
            },
            {
                name = "Epic",
                type = "Item",
                cond = function(self, itemName, target)
                    if mq.TLO.FindItemCount(itemName)() == 0 or not Targeting.GroupedWithTarget(target) then return false end
                    return mq.TLO.FindItem(itemName).TimerReady() == 0 and target.ID() == Core.GetMainAssistId and
                        (target.PctHPs() or 999) <= Config:GetSetting('BigHealPoint')
                end,
            },
            {
                name = "RemedyHeal",
                type = "Spell",
                cond = function(self, spell, target)
                    return Casting.GemReady(spell) and Casting.TargetedSpellReady(spell, target.ID(), true) and (target.PctHPs() or 999) <= Config:GetSetting('BigHealPoint')
                end,
            },
            {
                name = "SingleElixir",
                type = "Spell",
                cond = function(self, spell, target)
                    if not Config:GetSetting('DoHealOverTime') then return false end
                    return Casting.GemReady(spell) and Casting.GroupBuffCheck(spell, target)
                end,
            },
            {
                name = "CompleteHeal",
                type = "Spell",
                cond = function(self, spell, target)
                    if not Config:GetSetting("DoCompleteHeal") or target.ID() ~= Core.GetMainAssistId() then return false end
                    return (target.PctHPs() or 999) <= Config:GetSetting('CompleteHealPct') and Casting.GemReady(spell) and Casting.TargetedSpellReady(spell, target.ID(), true)
                end,
            },
            {
                name = "HealingLight",
                type = "Spell",
                cond = function(self, spell, target)
                    if Config:GetSetting("DoCompleteHeal") and target.ID() == Core.GetMainAssistId() then return false end
                    return Casting.GemReady(spell) and Casting.TargetedSpellReady(spell, target.ID(), true)
                end,
            },
        },

    },
    ['RotationOrder']     = {
        -- Downtime doesn't have state because we run the whole rotation at once.
        {
            name = 'Downtime',
            targetId = function(self) return { mq.TLO.Me.ID(), } end,
            cond = function(self, combat_state)
                return combat_state == "Downtime" and (not Core.IsModeActive('Heal') or Core.OkayToNotHeal()) and Casting.DoBuffCheck() and Casting.AmIBuffable()
            end,
        },
        { --Spells that should be checked on group members
            name = 'GroupBuff',
            timer = 60,
            targetId = function(self) return Casting.GetBuffableGroupIDs() end,
            cond = function(self, combat_state)
                return combat_state == "Downtime" and (not Core.IsModeActive('Heal') or Core.OkayToNotHeal()) and Casting.DoBuffCheck()
            end,
        },
        {
            name = 'Burn',
            state = 1,
            steps = 1,
            targetId = function(self) return mq.TLO.Target.ID() == Config.Globals.AutoTargetID and { Config.Globals.AutoTargetID, } or {} end,
            cond = function(self, combat_state)
                return combat_state == "Combat" and Casting.BurnCheck() and not Casting.IAmFeigning() and (not Core.IsModeActive('Heal') or Core.OkayToNotHeal())
            end,
        },
        {
            name = 'CombatDebuff',
            timer = 10,
            state = 1,
            steps = 2,
            load_cond = function(self) return self:GetResolvedActionMapItem('ReverseMarkDS') or self:GetResolvedActionMapItem('DecreaseMarkDS') end,
            targetId = function(self) return mq.TLO.Target.ID() == Config.Globals.AutoTargetID and { Config.Globals.AutoTargetID, } or {} end,
            cond = function(self, combat_state)
                return combat_state == "Combat" and not Casting.IAmFeigning() and (not Core.IsModeActive('Heal') or Core.OkayToNotHeal())
            end,
        },
        {
            name = 'DPS',
            state = 1,
            steps = 1,
            targetId = function(self) return mq.TLO.Target.ID() == Config.Globals.AutoTargetID and { Config.Globals.AutoTargetID, } or {} end,
            cond = function(self, combat_state)
                return combat_state == "Combat" and not Casting.IAmFeigning() and (not Core.IsModeActive('Heal') or Core.OkayToNotHeal())
            end,
        },
    },
    ['Rotations']         = {
        ['CombatDebuff'] = {
            {
                name = "ReverseMarkDS",
                type = "Spell",
                cond = function(self, spell, target)
                    if not Config:GetSetting('DoReverseDS') then return false end
                    return Casting.GemReady(spell) and Casting.DetSpellCheck(spell) and Casting.HaveManaToDebuff() and Casting.TargetedSpellReady(spell, target.ID())
                end,
            },
            {
                name = "DecreaseMarkDS",
                type = "Spell",
                cond = function(self, spell, target)
                    if not Config:GetSetting('DoReverseDS') then return false end
                    return Casting.GemReady(spell) and Casting.DetSpellCheck(spell) and Casting.HaveManaToDebuff() and Casting.TargetedSpellReady(spell, target.ID())
                end,
            },
        },
        ['Burn'] = {
            {
                name = "Celestial Hammer",
                type = "AA",
                cond = function(self, aaName, target)
                    return Casting.TargetedAAReady(aaName, target.ID())
                end,
            },
            {
                name = "Divine Avatar",
                type = "AA",
                cond = function(self, aaName)
                    return Casting.AAReady(aaName) and Config:GetSetting('DoMelee') and mq.TLO.Me.Combat()
                end,
            },
            { --homework: This is a defensive proc, likely need to add elsewhere
                name = "Divine Retribution",
                type = "AA",
                cond = function(self, aaName)
                    return Casting.AAReady(aaName) and Config:GetSetting('DoMelee') and mq.TLO.Me.Combat()
                end,
            },
            {
                name = "Intensity of the Resolute",
                type = "AA",
                cond = function(self, aaName)
                    if not Config:GetSetting('DoVetAA') then return false end
                    return Casting.AAReady(aaName)
                end,
            },
            {
                name = "Exquisite Benediction",
                type = "AA",
                cond = function(self, aaName)
                    return Casting.AAReady(aaName)
                end,
            },
        },
        ['DPS'] = {
            {
                name = "StunTimer6",
                type = "Spell",
                cond = function(self, spell, target)
                    if not Config:GetSetting('DoHealStun') or ((spell.Level() or 0) > 85 and Core.GetMainAssistPctHPs() > Config:GetSetting('LightHealPoint')) then return false end
                    return Casting.GemReady(spell) and Casting.DetSpellCheck(spell) and (Casting.HaveManaToNuke() or Casting.BurnCheck()) and
                        Casting.TargetedSpellReady(spell, target.ID())
                end,
            },
            {
                name = "YaulpSpell",
                type = "Spell",
                allowDead = true,
                cond = function(self, spell)
                    if Casting.CanUseAA("Yaulp") then return false end
                    return Casting.GemReady(spell) and Casting.SelfBuffCheck(spell)
                end,
            },
            {
                name = "GroupElixir",
                type = "Spell",
                allowDead = true,
                cond = function(self, spell)
                    if (mq.TLO.Me.Level() < 101 and not Casting.DetGOMCheck()) then return false end
                    return Casting.GemReady(spell) and Casting.SpellStacksOnMe(spell.RankName) and (mq.TLO.Me.Song(spell).Duration.TotalSeconds() or 0) < 15
                end,
            },
            {
                name = "LowLevelStun",
                type = "Spell",
                cond = function(self, spell, target)
                    if not Config:GetSetting('DoLLStun') then return false end
                    return Casting.GemReady(spell) and Casting.DetSpellCheck(spell) and Casting.HaveManaToDebuff() and Casting.TargetedSpellReady(spell, target.ID())
                end,
            },
            {
                name = "Turn Undead",
                type = "AA",
                cond = function(self, aaName, target)
                    if not Targeting.TargetBodyIs(target, "Undead") then return false end
                    return Casting.TargetedAAReady(aaName, target.ID()) and Casting.DetSpellCheck(mq.TLO.Me.AltAbility(aaName).Spell)
                end,
            },
            {
                name = "UndeadNuke",
                type = "Spell",
                cond = function(self, spell, target)
                    if not Config:GetSetting('DoUndeadNuke') or not Targeting.TargetBodyIs(target, "Undead") then return false end
                    return Casting.GemReady(spell) and (Casting.HaveManaToNuke() or Casting.BurnCheck()) and Casting.TargetedSpellReady(spell, target.ID())
                end,
            },
            {
                name = "MagicNuke",
                type = "Spell",
                cond = function(self, spell, target)
                    if not Config:GetSetting('DoMagicNuke') then return false end
                    return Casting.GemReady(spell) and (Casting.HaveManaToNuke() or Casting.BurnCheck()) and Casting.TargetedSpellReady(spell, target.ID())
                end,
            },
        },
        ['Downtime'] = {
            {
                name = "SelfHPBuff",
                type = "Spell",
                cond = function(self, spell)
                    if Config:GetSetting('AegoSymbol') == 3 then return false end
                    return Casting.SelfBuffCheck(spell)
                end,
            },
        },
        ['GroupBuff'] = {
            {
                name = "AegoBuff",
                type = "Spell",
                cond = function(self, spell, target)
                    if Config:GetSetting('AegoSymbol') > 2 then return false end
                    ---@diagnostic disable-next-line: undefined-field
                    return Casting.GroupBuffCheck(spell, target, mq.TLO.Me.Spell(spell).ID())
                end,
            },
            {
                name = "GroupSymbolBuff",
                type = "Spell",
                cond = function(self, spell, target)
                    if Config:GetSetting('AegoSymbol') == (1 or 4) or ((spell.TargetType() or ""):lower() == "single" and target.ID() ~= Core.GetMainAssistId()) then return false end
                    return Casting.GroupBuffCheck(spell, target)
                end,
            },
            {
                name = "SpellBlessing",
                type = "Spell",
                cond = function(self, spell, target)
                    if mq.TLO.Me.Level() > 91 then return false end
                    return Casting.GroupBuffCheck(spell, target)
                end,
            },
            {
                name = "ACBuff",
                type = "Spell",
                cond = function(self, spell, target)
                    if not Config:GetSetting('DoACBuff') or ((spell.TargetType() or ""):lower() == "single" and target.ID() ~= Core.GetMainAssistId()) then return false end
                    return Casting.GroupBuffCheck(spell, target)
                end,
            },
            {
                name = "SingleVieBuff",
                type = "Spell",
                cond = function(self, spell, target)
                    if not Config:GetSetting('DoVieBuff') or target.ID() ~= Core.GetMainAssistId() then return false end
                    return Casting.GroupBuffCheck(spell, target)
                end,
            },
            {
                name = "DivineBuff",
                type = "Spell",
                cond = function(self, spell, target)
                    if not Config:GetSetting('DoDivineBuff') or target.ID() ~= Core.GetMainAssistId() then return false end
                    return Casting.GemReady(spell) and Casting.GroupBuffCheck(spell, target) and Casting.ReagentCheck(spell)
                end,
            },
        },
    },
    ['Spells']            = {
        {
            gem = 1,
            spells = {
                { name = "HealingLight", }, -- Main Heal, Level 1-69
            },
        },
        {
            gem = 2,
            spells = {
                { name = "RemedyHeal", }, -- Emergency/fallback, 59-69, these aren't good until 96
            },
        },
        {
            gem = 3,
            spells = {
                { name = "CompleteHeal",  cond = function(self) return Config:GetSetting('DoCompleteHeal') end, }, -- Level 39
                { name = "SingleElixir",  cond = function(self) return Config:GetSetting('DoHealOverTime') end, }, -- Level 19-79
                --fallback
                { name = "CureAll",       cond = function(self) return Config:GetSetting('KeepCureMemmed') == 2 end, },
                { name = "GroupHealCure", cond = function(self) return Config:GetSetting('KeepCureMemmed') == 3 end, },
                { name = "MagicNuke",     cond = function(self) return Config:GetSetting('DoMagicNuke') end, },
                { name = "UndeadNuke",    cond = function(self) return Config:GetSetting('DoUndeadNuke') end, },
                { name = "SingleVieBuff", cond = function(self) return Config:GetSetting('DoVieBuff') end, },
                { name = "RezSpell",      cond = function(self) return true end, },
            },
        },
        {
            gem = 4,
            spells = {
                { name = "SingleElixir",  cond = function(self) return Config:GetSetting('DoHealOverTime') end, },
                --fallback
                { name = "CureAll",       cond = function(self) return Config:GetSetting('KeepCureMemmed') == 2 end, },
                { name = "CurePoison",    cond = function(self) return Config:GetSetting('KeepCureMemmed') == 2 and not Core.GetResolvedActionMapItem('CureAll') end, },
                { name = "CureDisease",   cond = function(self) return Config:GetSetting('KeepCureMemmed') == 2 and not Core.GetResolvedActionMapItem('CureAll') end, },
                { name = "GroupHealCure", cond = function(self) return Config:GetSetting('KeepCureMemmed') == 3 end, },
                { name = "MagicNuke",     cond = function(self) return Config:GetSetting('DoMagicNuke') end, },
                { name = "UndeadNuke",    cond = function(self) return Config:GetSetting('DoUndeadNuke') end, },
                { name = "SingleVieBuff", cond = function(self) return Config:GetSetting('DoVieBuff') end, },
                { name = "RezSpell",      cond = function(self) return true end, },
            },
        },
        {
            gem = 5,
            spells = {
                { name = "StunTimer6",     cond = function(self) return Config:GetSetting('DoHealStun') end, }, -- Level 16 - 76 (moved gems after)
                --fallback
                { name = "CureAll",        cond = function(self) return Config:GetSetting('KeepCureMemmed') == 2 end, },
                { name = "CurePoison",     cond = function(self) return Config:GetSetting('KeepCureMemmed') == 2 and not Core.GetResolvedActionMapItem('CureAll') end, },
                { name = "CureDisease",    cond = function(self) return Config:GetSetting('KeepCureMemmed') == 2 and not Core.GetResolvedActionMapItem('CureAll') end, },
                { name = "GroupHealCure",  cond = function(self) return Config:GetSetting('KeepCureMemmed') == 3 end, },
                { name = "MagicNuke",      cond = function(self) return Config:GetSetting('DoMagicNuke') end, },
                { name = "UndeadNuke",     cond = function(self) return Config:GetSetting('DoUndeadNuke') end, },
                { name = "SingleVieBuff",  cond = function(self) return Config:GetSetting('DoVieBuff') end },
                { name = "ReverseMarkDS",  cond = function(self) return Config:GetSetting('DoReverseDS') end },
                { name = "DecreaseMarkDS", cond = function(self) return Config:GetSetting('DoDecreaseDS') end },
                { name = "RezSpell",       cond = function(self) return true end, },
            },
        },
        {
            gem = 6,
            spells = {
                { name = "GroupHealNoCure", }, -- Level 30-97
                --fallback
                { name = "CureAll",         cond = function(self) return Config:GetSetting('KeepCureMemmed') == 2 end, },
                { name = "CurePoison",      cond = function(self) return Config:GetSetting('KeepCureMemmed') == 2 and not Core.GetResolvedActionMapItem('CureAll') end, },
                { name = "CureDisease",     cond = function(self) return Config:GetSetting('KeepCureMemmed') == 2 and not Core.GetResolvedActionMapItem('CureAll') end, },
                { name = "GroupHealCure",   cond = function(self) return Config:GetSetting('KeepCureMemmed') == 3 end, },
                { name = "MagicNuke",       cond = function(self) return Config:GetSetting('DoMagicNuke') end, },
                { name = "UndeadNuke",      cond = function(self) return Config:GetSetting('DoUndeadNuke') end, },
                { name = "SingleVieBuff",   cond = function(self) return Config:GetSetting('DoVieBuff') end, },
                { name = "ReverseMarkDS",   cond = function(self) return Config:GetSetting('DoReverseDS') end },
                { name = "DecreaseMarkDS",  cond = function(self) return Config:GetSetting('DoDecreaseDS') end },
                { name = "RezSpell",        cond = function(self) return true end, },
            },
        },
        {
            gem = 7,
            spells = {
                { name = "DivineBuff",     cond = function(self) return Config:GetSetting('DoDivineBuff') end, }, -- Level 51+
                --fallback
                { name = "StunTimer6",     cond = function(self) return Config:GetSetting('DoHealStun') end, },   -- 88+ has ToT heal
                { name = "CureAll",        cond = function(self) return Config:GetSetting('KeepCureMemmed') == 2 end, },
                { name = "CurePoison",     cond = function(self) return Config:GetSetting('KeepCureMemmed') == 2 and not Core.GetResolvedActionMapItem('CureAll') end, },
                { name = "CureDisease",    cond = function(self) return Config:GetSetting('KeepCureMemmed') == 2 and not Core.GetResolvedActionMapItem('CureAll') end, },
                { name = "GroupHealCure",  cond = function(self) return Config:GetSetting('KeepCureMemmed') == 3 end, },
                { name = "MagicNuke",      cond = function(self) return Config:GetSetting('DoMagicNuke') end, },
                { name = "UndeadNuke",     cond = function(self) return Config:GetSetting('DoUndeadNuke') end, },
                { name = "SingleVieBuff",  cond = function(self) return Config:GetSetting('DoVieBuff') end, },
                { name = "ReverseMarkDS",  cond = function(self) return Config:GetSetting('DoReverseDS') end },
                { name = "DecreaseMarkDS", cond = function(self) return Config:GetSetting('DoDecreaseDS') end },
                { name = "RezSpell",       cond = function(self) return true end, },
            },
        },
        {
            gem = 8,
            spells = {
                { name = "YaulpSpell",     cond = function(self) return not Casting.CanUseAA("Yaulp") end, },   -- Level 56-75
                --fallback
                { name = "StunTimer6",     cond = function(self) return Config:GetSetting('DoHealStun') end, }, -- 88+ has ToT heal                                                                   -- Level 97
                { name = "CureAll",        cond = function(self) return Config:GetSetting('KeepCureMemmed') == 2 end, },
                { name = "CurePoison",     cond = function(self) return Config:GetSetting('KeepCureMemmed') == 2 and not Core.GetResolvedActionMapItem('CureAll') end, },
                { name = "CureDisease",    cond = function(self) return Config:GetSetting('KeepCureMemmed') == 2 and not Core.GetResolvedActionMapItem('CureAll') end, },
                { name = "GroupHealCure",  cond = function(self) return Config:GetSetting('KeepCureMemmed') == 3 end, },
                { name = "MagicNuke",      cond = function(self) return Config:GetSetting('DoMagicNuke') end, },
                { name = "UndeadNuke",     cond = function(self) return Config:GetSetting('DoUndeadNuke') end, },
                { name = "SingleVieBuff",  cond = function(self) return Config:GetSetting('DoVieBuff') end, },
                { name = "ReverseMarkDS",  cond = function(self) return Config:GetSetting('DoReverseDS') end },
                { name = "DecreaseMarkDS", cond = function(self) return Config:GetSetting('DoDecreaseDS') end },
                { name = "RezSpell",       cond = function(self) return true end, },
            },
        },
        { --55, we will use this and allow GroupElixir to be poofed by buffing if it happens from 60-74.
            gem = 9,
            cond = function(self, gem) return mq.TLO.Me.NumGems() >= gem end,
            spells = {
                -- Leve 56-59 free
                { name = "GroupElixir",    cond = function(self) return Config:GetSetting('DoHealOverTime') end, }, -- Level 60+, gets better from 70 on, this may be overwritten before 75
                --fallback
                { name = "StunTimer6",     cond = function(self) return Config:GetSetting('DoHealStun') end, },     -- 88+ has ToT heal                                                                          -- Level 97
                { name = "CureAll",        cond = function(self) return Config:GetSetting('KeepCureMemmed') == 2 end, },
                { name = "CurePoison",     cond = function(self) return Config:GetSetting('KeepCureMemmed') == 2 and not Core.GetResolvedActionMapItem('CureAll') end, },
                { name = "CureDisease",    cond = function(self) return Config:GetSetting('KeepCureMemmed') == 2 and not Core.GetResolvedActionMapItem('CureAll') end, },
                { name = "GroupHealCure",  cond = function(self) return Config:GetSetting('KeepCureMemmed') == 3 end, },
                { name = "MagicNuke",      cond = function(self) return Config:GetSetting('DoMagicNuke') end, },
                { name = "UndeadNuke",     cond = function(self) return Config:GetSetting('DoUndeadNuke') end, },
                { name = "SingleVieBuff",  cond = function(self) return Config:GetSetting('DoVieBuff') end, },
                { name = "ReverseMarkDS",  cond = function(self) return Config:GetSetting('DoReverseDS') end },
                { name = "DecreaseMarkDS", cond = function(self) return Config:GetSetting('DoDecreaseDS') end },
                { name = "RezSpell",       cond = function(self) return true end, },
            },
        },
    },
    ['DefaultConfig']     = {
        ['Mode']            = {
            DisplayName = "Mode",
            Category = "Combat",
            Tooltip = "Select the Combat Mode for this Toon",
            Type = "Custom",
            RequiresLoadoutChange = true,
            Default = 1,
            Min = 1,
            Max = 1,
            FAQ = "What is the difference between Heal and Hybrid Modes?",
            Answer = "Heal Mode is for when you are the primary healer in a group.\n" ..
                "Hybrid Mode is for when you are the secondary healer in a group and need to do some DPS. (Temp Disabled)",
        },
        --Buffs/Debuffs
        ['AegoSymbol']      = {
            DisplayName = "Aego/Symbol Choice:",
            Category = "Buffs/Debuffs",
            Index = 1,
            Tooltip =
            "Choose whether to use the Aegolism or Symbol Line of HP Buffs.\nPlease note using both is supported for party members who block buffs, but these buffs do not stack once we transition from using a HP Type-One buff in place of Aegolism.",
            Type = "Combo",
            ComboOptions = { 'Aegolism', 'Both (See Tooltip!)', 'Symbol', 'None', },
            Default = 1,
            Min = 1,
            Max = 4,
            FAQ = "Why aren't I using Aego and/or Symbol buffs?",
            Answer = "Please set which buff you would like to use on the Buffs/Debuffs tab.",
        },
        ['DoACBuff']        = {
            DisplayName = "Use AC Buff",
            Category = "Buffs/Debuffs",
            Index = 2,
            Tooltip =
                "Use your single-slot AC Buff on the Main Assist. USE CASES:\n" ..
                "You have Aegolism selected and are below level 60 (We are still using a HP Type One buff).\n" ..
                "You have Symbol selected and you are below level 95 (We don't have Unified Symbols yet).\n" ..
                "Leaving this on in other cases is not likely to cause issue, but may cause unnecessary buff checking.",
            Default = false,
            FAQ = "Why aren't I used my AC Buff Line?",
            Answer =
            "You may need to select the option in Buffs/Debuffs. Alternatively, this line does not stack with Aegolism, and it is automatically included in \"Unified\" Symbol buffs.",
        },
        ['DoVieBuff']       = {
            DisplayName = "Use Vie Buff",
            Category = "Buffs/Debuffs",
            Index = 3,
            Tooltip = "Use your Melee Damage absorb (Vie) line.",
            Default = true,
            FAQ = "Why am I using the Vie and Shining buffs together when the melee gaurd does not stack?",
            Answer = "We will always use the Shining line on the tank, but if selected, we will also use the Vie Buff on the Group.\n" ..
                "Before we have the Shining Buff, we will use our single-target Vie buff only on the tank.",
        },
        ['DoReverseDS']     = {
            DisplayName = "Use Reverse DS",
            Category = "Buffs/Debuffs",
            Index = 4,
            Tooltip = "Use reverse DS spells. (Debuff on mob that damages them when they attack)",
            Default = false,
            FAQ = "What is a reverse DS and how do i enable it?",
            Answer = "A reverse DS is a debuff cast on a hostile mob that causes them to take damage when they attack.\n" ..
                "You can enable this by setting Use Reverse DS to on.",
        },
        ['DoDecreaseDS']    = {
            DisplayName = "Use Decrease DS",
            Category = "Buffs/Debuffs",
            Index = 5,
            Tooltip = "Use decrease DS spells (Debuff on mob that causes players to be healed when attacking.)",
            Default = false,
            FAQ = "What is a decrease DS spell and how do I enable it?",
            Answer = "A decrease DS spell is a debuff cast on a hostile mob that can cause attacks against the mob to act as small heals.\n" ..
                "You can enable this by setting Use Decrease DS to on.",
        },
        ['DoVetAA']         = {
            DisplayName = "Use Vet AA",
            Category = "Buffs/Debuffs",
            Index = 6,
            Tooltip = "Use Veteran AA's in emergencies or during Burn. (See FAQ)",
            Default = true,
            FAQ = "What Vet AA's does CLR use?",
            Answer = "If Use Vet AA is enabled, Intensity of the Resolute will be used on burns. Clerics have tools that largely leave Armor of Experience unused.",
        },
        --Combat
        ['DoHealStun']      = {
            DisplayName = "ToT-Heal Stun",
            Category = "Combat",
            Index = 3,
            Tooltip = "Use the Timer 6 HoT Stun (\"Sound of\" Line).",
            RequiresLoadoutChange = true,
            Default = true,
            FAQ = "Which stun spells does the Cleric use?",
            Answer =
                "At low levels, we will use the \"Stun\" spell (until 58, if selected) and either \"Holy Might\", \"Force\", or \"Tarnation\" until level 65.\n" ..
                "After that, we transition to the Timer 6 stuns (\"Sound of\" line), which have a ToT heal from Level 88.\n" ..
                "Please note that the low level spell named \"Stun\" is controlled by the Low Level Stun option.",
        },
        ['DoLLStun']        = {
            DisplayName = "Low Level Stun",
            Category = "Combat",
            Index = 4,
            Tooltip = "Use the Level 2 \"Stun\" spell, as long as it is level-appropriate (works on targets up to Level 58).",
            RequiresLoadoutChange = true,
            Default = true,
            ConfigType = "Advanced",
            FAQ = "Why is a Cleric stunning? It should be healing!?",
            Answer =
            "At low levels, Cleric stuns are often more efficient than healing the damage an non-stunned mob would cause.",
        },
        ['DoUndeadNuke']    = {
            DisplayName = "Do Undead Nuke",
            Category = "Combat",
            Index = 5,
            Tooltip = "Use the Undead nuke line.",
            RequiresLoadoutChange = true,
            Default = false,
            FAQ = "How can I use my Undead Nuke?",
            Answer = "You can enable the undead nuke line in the Spells and Abilities tab.",
        },
        ['DoMagicNuke']     = {
            DisplayName = "Do Magic Nuke",
            Category = "Combat",
            Index = 6,
            Tooltip = "Use the Undead nuke line.",
            RequiresLoadoutChange = true,
            Default = false,
            FAQ = "How can I use my Magic Nuke?",
            Answer = "You can enable the magic nuke line in the Spells and Abilities tab.",
        },

        --Spells and Abilities
        ['DoHealOverTime']  = {
            DisplayName = "Use HoTs",
            Category = "Spells and Abilities",
            Index = 3,
            Tooltip = "Use the Elixir Line (Low Level: Single, Mid-Level: Both (situationally), High Level: Group).",
            RequiresLoadoutChange = true,
            Default = true,
            ConfigType = "Advanced",
            FAQ = "Why isn't my Cleric using the Group Elixir HoT?",
            Answer = "Before Level 100, we will only use the Group Elixir if we have a GOM proc or the if the \"Group Injured Count\" is met (See Heal settings in RGMain config).",
        },
        ['DoDivineBuff']    = {
            DisplayName = "Do Divine Buff",
            Category = "Spells and Abilities",
            Index = 4,
            Tooltip = "Use your Divine Intervention line (death save) on the MA.",
            RequiresLoadoutChange = true,
            Default = true,
            ConfigType = "Advanced",
            FAQ = "Why isn't my Cleric using the Divine Intervention buff?",
            Answer = "The Divine Intervention buff line requires a pair of emeralds.",
        },
        ['DoCompleteHeal']  = {
            DisplayName = "Use Complete Heal",
            Category = "Spells and Abilities",
            Index = 5,
            Tooltip = "Use Complete Heal on the MA (instead of the healing Light line).",
            RequiresLoadoutChange = true,
            Default = false,
            ConfigType = "Advanced",
            FAQ = "Why isn't my cleric using Complete Heal?",
            Answer =
            "Complete Heal use can be enabled in the Spells and Abilities tab. Please note that, if enabled, we will not use the healing Light line on the MA.",
        },
        ['CompleteHealPct'] = {
            DisplayName = "Complete Heal Pct",
            Category = "Spells and Abilities",
            Index = 6,
            Tooltip = "Pct we will use Complete Heal on the MA.",
            Default = 80,
            Min = 1,
            Max = 99,
            ConfigType = "Advanced",
            FAQ = "How can I stagger my clerics to use Complete Heal at different times?",
            Answer = "Adjust the Complete Heal Pct on the Spells and Abilities tab to different amounts to help stagger Complete Heals.",
        },
        ['KeepCureMemmed']  = {
            DisplayName = "Mem Cure:",
            Category = "Spells and Abilities",
            Index = 7,
            Tooltip = "Select your preference of a Cure spell to keep loaded (if a gem is availabe). \n" ..
                "Please note that we will still memorize a cure out-of-combat if needed, and AA will always be used if available.",
            RequiresLoadoutChange = true,
            Type = "Combo",
            ComboOptions = { 'None (Suggested for most cases)', 'Mem cure spells when possible', 'Mem GroupHealCure (\"Word of\" Line) when possible', },
            Default = 1,
            Min = 1,
            Max = 3,
            ConfigType = "Advanced",
            FAQ = "Why don't the Mem Cure options include low-level curse cure?",
            Answer =
            "We simply don't have the slots without serious concessions elsewhere. Before the \"Blood\" line is learned, feel free to memorize any remove curse you'd like in an open gem! It will be used, if appropriate.",
        },
    },
}

return _ClassConfig

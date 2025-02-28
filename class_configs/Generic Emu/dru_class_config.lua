local mq           = require('mq')
local Config       = require('utils.config')
local Core         = require("utils.core")
local Targeting    = require("utils.targeting")
local Casting      = require("utils.casting")

local _ClassConfig = {
    _version              = "1.0 - Emu",
    _author               = "Derple, Grimmier, Lisie",
    ['ModeChecks']        = {
        IsHealing  = function() return true end,
        IsCuring   = function() return Core.IsModeActive("Heal") end,
        IsRezing   = function() return Config:GetSetting('DoBattleRez') or Targeting.GetXTHaterCount() == 0 end,
        CanCharm   = function() return true end,
        IsCharming = function() return (Config:GetSetting('CharmOn') and mq.TLO.Pet.ID() == 0) end,
    },
    ['Modes']             = {
        'Heal',
        'Mana',
    },
    ['Cures']             = {
        CureNow = function(self, type, targetId)
            if Casting.AAReady("Radiant Cure") then
                return Casting.UseAA("Radiant Cure", targetId)
            end
            local cureSpell = Core.GetResolvedActionMapItem('SingleTgtCure')
            if not cureSpell or not cureSpell() then return false end
            return Casting.UseSpell(cureSpell.RankName.Name(), targetId, true)
        end,
    },
    ['ItemSets']          = {
        ['Epic'] = {
            "Staff of Living Brambles",
            "Staff of Everliving Brambles",
        },
    },
    ['AbilitySets']       = {
        ['SingleTgtCure'] = {
            "Pure Blood",
        },
        ['CharmSpell'] = {
            -- Updated to 125
            -- Charm Spells >= 14
            "Nature's Beckon",
            "Command of Tunare",
            "Tunare's Request",
            "Call of Karana",
            "Allure of the Wild",
            "Beguile Animals",
            "Charm Animals",
            "Befriend Animal",
        },
        ['LongHeal1'] = {
            -- Updated to 125
            -- Long Heal >= 1 -- skipped 10s cast heals.
            "Chlorotrope",
            "Sylvan Infusion",
            "Nature's Infusion",
            "Nature's Touch",
            "Chloroblast",
            "Forest's Renewal",
            "Superior Healing",
            "Nature's Renewal",
            "Healing Water",
            "Greater Healing",
            "Healing",
            "Light Healing",
            "Minor Healing",
        },
        ['LongHeal2'] = {
            -- Updated to 125
            -- Long Heal >= 1 -- skipped 10s cast heals.
            "Chlorotrope",
            "Sylvan Infusion",
            "Nature's Infusion",
            "Nature's Touch",
            "Chloroblast",
            "Forest's Renewal",
            "Superior Healing",
            "Nature's Renewal",
            "Healing Water",
            "Greater Healing",
            "Healing",
            "Light Healing",
            "Minor Healing",
        },
        ['RoDebuff'] = {
            -- Updated to 125
            -- Ro Debuff Series -- >= 37LVL -- AA Starts at LVL (Single Target) -- On Bar Until AA
            "Sun's Corona",
            "Ro's Illumination",
            "Ro's Smoldering Disjunction",
            "Fixation of Ro",
            "Ro's Fiery Sundering",
        },
        ['IceBreathDebuff'] = {
            -- Updated to 125
            -- Ice Breath Series >= 63LVL -- On Bar
            "Glacier Breath",
            "E`ci's Frosty Breath",
        },
        ['HordeDot'] = {
            -- Updated to 125
            -- Horde Dots >= 10LVL -- On Bar
            "Wasp Swarm",
            "Swarming Death",
            "Winged Death",
            "Drifting Death",
            "Drones of Doom",
            "Creeping Crud",
            "Stinging Swarm",
        },
        ['SunDot'] = {
            -- Updated to 125
            -- SUN Dot Line >= 49LVL -- On Bar
            "Vengeance of the Sun",
            "Vengeance of Tunare",
            "Vengeance of Nature",
            "Vengeance of the Wild",
        },
        ['SunrayDot'] = {
            -- Updated to 125
            -- Sunray Line >= 1 LVL
            "Immolation of the Sun",
            "Sylvan Embers",
            "Immolation of Ro",
            "Breath of Ro",
            "Immolate",
            "Flame Lick",
        },
        ['QuickRoarDD'] = {
            -- Updated to 125
            -- Quick Cast Roar Series -- will be replaced by roar at lvl 93
            "Stormwatch",
            "Storm's Fury",
            "Dustdevil",
            "Fury of Air",
        },
        ['WinterFireDD'] = {
            -- Updated to 125
            -- Winters Fire DD Line >= 73LVL -- Using for Low level Fire DD as well
            "Solstice Strike",
            "Sylvan Fire",
            "Summer's Flame",
            "Wildfire",
            "Scoriae",
            "Starfire",
            "Firestrike",
            "Combust",
            "Ignite",
            "Burst of Fire",
            "Burst of Flame",
        },
        ['RootSpells'] = {
            -- Root Spells
            "Savage Roots",
            "Earthen Roots",
            "Entrapping Roots",
            "Engorging Roots",
            "Engulfing Roots",
            "Enveloping Roots",
            "Ensnaring Roots",
            "Grasping Roots",
        },
        ['SnareSpells'] = {
            -- Snare Spells
            "Serpent Vines",
            "Entangle",
            "Mire Thorns",
            "Bonds of Tunare",
            "Ensnare",
            "Snare",
            "Tangling Weeds",
        },
        ['IceNuke'] = {
            -- Updated to 125
            --Ice Nuke
            "Ice",
            "Frost",
            "Moonfire",
            "Winter's Frost",
            "Glitterfrost",
        },
        ['IceRainNuke'] = {
            -- Updated to 125
            "Cascade of Hail",
            "Pogonip",
            "Avalanche",
            "Blizzard",
            "Winter's Storm",
            "Tempest Wind",
        },
        ['IceDD'] = {
            -- Ice Nuke DD --Gap Filler
            "Moonfire",
            "Frost",
        },
        ['SelfShield'] = {
            -- Updated to 125
            -- Self Shield Buff
            "Nettlecoat",
            "Brackencoat",
            "Bladecoat",
            "Thorncoat",
            "Spikecoat",
            "Bramblecoat",
            "Barbcoat",
            "Thistlecoat",
        },
        ['SelfManaRegen'] = {
            -- Updated to 125
            -- Self mana Regen Buff
            "Mask of the Wild",
            "Mask of the Forest",
            "Mask of the Stalker",
            "Mask of the Hunter",
        },
        ['HPTypeOneGroup'] = {
            -- Updated to 125
            -- Opaline Group Health
            "Blessing of Steeloak",
            "Blessing of the Nine",
            "Protection of the Glades",
            "Protection of Nature",
            "Protection of Diamond",
            "Protection of Steel",
            "Protection of Rock",
            "Protection of Wood",
            'Skin like Wood',
        },
        ['GroupRegenBuff'] = {
            -- Updated to 125
            -- Group Regen BuffAll Have Long Duration HP Regen Buffs. Not Short term Heal.
            "Pack Regeneration",
            "Pack Chloroplast",
            "Regrowth of the Grove",
            "Blessing of Replenishment",
            "Blessing of Oak",
        },
        ['AtkBuff'] = {
            -- Single Target Attack Buff for MeleeGuard
            "Lion's Strength",
            "Nature's Might",
            "Girdle of Karana",
            "Storm Strength",
            "Strength of Stone",
            "Strength of Earth",
        },
        ['GroupDmgShield'] = {
            -- Updated to 125
            -- Group Damage Shield -- Focus on the tank
            "Legacy of Nettles",
            "Legacy of Bracken",
            "Legacy of Thorn",
            "Legacy of Spike",
        },
        ['MoveSpells'] = {
            "Spirit of Wolf",
            "Pack Spirit",
        },
        ['MoveLevSpells'] = {
            "Spirit of Eagle",
            "Flight of Eagles",
        },
        ['PetSpell'] = {
            "Nature Walker's Behest",
        },
        ['SingleDS'] = {
            -- Updated to 125
            --Single Target Damage Shield
            "Shield of Thistles",
            "Shield of Barbs",
            "Shield of Brambles",
            "Shield of Spikes",
            "Shield of Thorns",
            "Shield of Blades",
            "Shield of Bracken",
            "Nettle Shield",
        },
    },
    ['HealRotationOrder'] = {
        {
            name = 'MainHealPoint',
            state = 1,
            steps = 1,
            cond = function(self, target) return (target.PctHPs() or 999) < Config:GetSetting('MainHealPoint') end,
        },
    },
    ['HealRotations']     = {
        ["MainHealPoint"] = {
            {
                name = "LongHeal1",
                type = "Spell",
                cond = function(self, spell)
                    return Casting.SpellReady(spell)
                end,
            },
            {
                name = "LongHeal2",
                type = "Spell",
                cond = function(self, spell)
                    return Casting.SpellReady(spell)
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
                return combat_state == "Downtime" and Casting.DoBuffCheck() and Casting.AmIBuffable()
            end,
        },
        { --Summon pet even when buffs are off on emu
            name = 'PetSummon',
            targetId = function(self) return { mq.TLO.Me.ID(), } end,
            load_cond = function(self) return Core.OnEMU() end,
            cond = function(self, combat_state)
                if not Config:GetSetting('DoPet') or mq.TLO.Me.Pet.ID() ~= 0 then return false end
                return combat_state == "Downtime" and (not Core.IsModeActive('Heal') or Core.OkayToNotHeal()) and Casting.DoPetCheck() and Casting.AmIBuffable()
            end,
        },
        {
            name = 'GroupBuff',
            timer = 60, -- only run every 60 seconds top.
            targetId = function(self)
                return Casting.GetBuffableGroupIDs()
            end,
            cond = function(self, combat_state)
                return combat_state == "Downtime" and Casting.DoBuffCheck()
            end,
        },
        {
            name = 'Debuff',
            state = 1,
            steps = 1,
            targetId = function(self) return mq.TLO.Target.ID() == Config.Globals.AutoTargetID and { Config.Globals.AutoTargetID, } or {} end,
            cond = function(self, combat_state)
                return combat_state == "Combat" and not Casting.IAmFeigning() and Casting.DebuffConCheck()
            end,
        },
        {
            name = 'Burn',
            state = 1,
            steps = 1,
            targetId = function(self) return mq.TLO.Target.ID() == Config.Globals.AutoTargetID and { Config.Globals.AutoTargetID, } or {} end,
            cond = function(self, combat_state)
                return combat_state == "Combat" and
                    Casting.BurnCheck() and not Casting.IAmFeigning()
            end,
        },
        {
            name = 'DPS',
            state = 1,
            steps = 1,
            targetId = function(self) return mq.TLO.Target.ID() == Config.Globals.AutoTargetID and { Config.Globals.AutoTargetID, } or {} end,
            cond = function(self, combat_state)
                return combat_state == "Combat" and not Casting.IAmFeigning()
            end,
        },

    },
    ['Rotations']         = {
        ['DPS'] = {
            {
                name = "SunrayDot",
                type = "Spell",
                cond = function(self, spell)
                    return Core.IsModeActive("Heal")
                        and Config:GetSetting('DoFire')
                        and Casting.DotSpellCheck(spell) and
                        Config:GetSetting('DoDot') and
                        mq.TLO.FindItemCount(spell.NoExpendReagentID(1)())() >= 1
                end,
            },
            {
                name = mq.TLO.Me.Inventory("Chest").Name(),
                type = "Item",
                cond = function(self)
                    local item = mq.TLO.Me.Inventory("Chest")
                    return Core.IsModeActive("Mana") and Config:GetSetting('DoChestClick') and item() and
                        item.Spell.Stacks() and item.TimerReady() == 0
                end,
            },
            {
                name = "SunDot",
                type = "Spell",
                cond = function(self, spell)
                    return Core.IsModeActive("Mana") or (Core.IsModeActive("Heal")
                            and Config:GetSetting('DoFire')) and Casting.DotSpellCheck(spell)
                        and Config:GetSetting('DoDot')
                end,
            },
            {
                name = "HordeDot",
                type = "Spell",
                cond = function(self, spell)
                    return Core.IsModeActive("Mana")
                        and Casting.DotSpellCheck(spell) and
                        Config:GetSetting('DoDot')
                end,
            },
            {
                name = "WinterFireDD",
                type = "Spell",
                cond = function(self, spell)
                    return Core.IsModeActive("Mana")
                        and Casting.DetSpellCheck(spell) and Config:GetSetting('DoFire') and
                        (Casting.HaveManaToNuke() or Casting.BurnCheck())
                end,
            },
            {
                name = "IceRainNuke",
                type = "Spell",
                cond = function(self, spell)
                    return Core.IsModeActive("Mana")
                        and Casting.DetSpellCheck(spell) and not Config:GetSetting('DoFire') and
                        Config:GetSetting('DoRain') and
                        (Casting.HaveManaToNuke() or Casting.BurnCheck())
                end,
            },
            {
                name = "IceNuke",
                type = "Spell",
                cond = function(self, spell)
                    return Core.IsModeActive("Mana")
                        and Casting.DetSpellCheck(spell) and not Config:GetSetting('DoFire') and
                        (Casting.HaveManaToNuke() or Casting.BurnCheck())
                end,
            },
        },
        ['Burn'] = {
            {
                name = mq.TLO.Me.Inventory("Chest").Name(),
                type = "Item",
                cond = function(self)
                    local item = mq.TLO.Me.Inventory("Chest")
                    return Config:GetSetting('DoChestClick') and item() and item.Spell.Stacks() and
                        item.TimerReady() == 0
                end,
            },
            {
                name = "Nature's Boon",
                type = "AA",
                cond = function(self, aaName)
                    return true
                end,
            },
            {
                name = "Spirit of the Wood",
                type = "AA",
                cond = function(self, aaName)
                    return true
                end,
            },
        },
        ['Debuff'] = {
            {
                name = "RoDebuff",
                type = "Spell",
                cond = function(self, spell) return Casting.DotSpellCheck(spell) end,
            },
            {
                name = "IceBreathDebuff",
                type = "Spell",
                cond = function(self, spell, target)
                    return not Config:GetSetting('DoFire') and Casting.DetSpellCheck(spell) and
                        Targeting.GetTargetPctHPs(target) < Config:GetSetting('NukePct') and
                        Config:GetSetting('DoNuke')
                end,
            },
            {
                name = "Entrap",
                tooltip = "AA: Snare",
                type = "AA",
                cond = function(self, aaName)
                    return Config:GetSetting('DoSnare') and Casting.DetSpellCheck(mq.TLO.Me.AltAbility(aaName).Spell)
                end,
            },
            {
                name = "SnareSpells",
                type = "Spell",
                cond = function(self, spell, target)
                    return Config:GetSetting('DoSnare') and Casting.DetSpellCheck(spell) and Targeting.GetTargetPctHPs(target) < 50 and not mq.TLO.Me.AltAbility("Entrap")()
                end,
            },
        },
        ['GroupBuff'] = {
            {
                name = "GroupDmgShield",
                type = "Spell",
                active_cond = function(self, spell) return Casting.BuffActiveByID(spell.ID()) end,
                cond = function(self, spell, target)
                    return Casting.GroupBuffCheck(spell, target)
                end,
            },
            {
                name = "MoveSpells",
                type = "Spell",
                active_cond = function(self, spell) return Casting.BuffActiveByID(spell.ID()) end,
                cond = function(self, spell, target)
                    if not Config:GetSetting("DoRunSpeed") or Config:GetSetting("DoLevRun") then return false end
                    return Casting.GroupBuffCheck(spell, target)
                end,
            },
            {
                name = "MoveLevSpells",
                type = "Spell",
                active_cond = function(self, spell) return Casting.BuffActiveByID(spell.ID()) end,
                cond = function(self, spell, target)
                    if not Config:GetSetting("DoRunSpeed") or not Config:GetSetting("DoLevRun") then return false end
                    return Casting.GroupBuffCheck(spell, target)
                end,
            },
            {
                name = "AtkBuff",
                type = "Spell",
                active_cond = function(self, spell) return Casting.BuffActiveByID(spell.ID()) end,
                cond = function(self, spell, target)
                    return Config.Constants.RGMelee:contains(target.Class.ShortName()) and Casting.GroupBuffCheck(spell, target)
                end,
            },
            {
                name = "HPTypeOneGroup",
                type = "Spell",
                active_cond = function(self, spell) return Casting.BuffActiveByID(spell.ID()) end,
                cond = function(self, spell, target)
                    if not Config:GetSetting('DoHPBuff') then return false end
                    return Casting.GroupBuffCheck(spell, target)
                end,
            },
            {
                name = "GroupRegenBuff",
                type = "Spell",
                active_cond = function(self, spell) return Casting.BuffActiveByID(spell.ID()) end,
                cond = function(self, spell, target)
                    if not Config:GetSetting('DoGroupRegen') then return false end
                    return Casting.GroupBuffCheck(spell, target)
                end,
            },
            {
                name = "Wrath of the Wild",
                type = "AA",
                active_cond = function(self, aaName) return true end,
                cond = function(self, aaName, target)
                    return target.ID() == Core.GetMainAssistId() and Casting.GroupBuffCheck(mq.TLO.Me.AltAbility(aaName).Spell, target)
                end,
            },
        },
        ['Downtime'] = {
            {
                name = "SelfShield",
                type = "Spell",
                active_cond = function(self, spell) return Casting.BuffActiveByID(spell.ID()) end,
                cond = function(self, spell) return Casting.SelfBuffCheck(spell) end,
            },
            {
                name = "SelfManaRegen",
                type = "Spell",
                active_cond = function(self, spell) return Casting.BuffActiveByID(spell.ID()) end,
                cond = function(self, spell) return Casting.SelfBuffCheck(spell) and not (spell.Name() == "Mask of the Hunter" and mq.TLO.Zone.Indoor()) end,
            },
        },
        ['PetSummon'] = {
            {
                name = "PetSpell",
                type = "Spell",
                active_cond = function() return mq.TLO.Me.Pet.ID() ~= 0 end,
                cond = function() return true end,
            },
        },
    },
    ['Spells']            = {
        {
            gem = 1,
            spells = {
                { name = "LongHeal1", },
            },
        },
        {
            gem = 2,
            spells = {
                -- [ MANA MODE ] --
                {
                    name = "SnareSpells",
                    cond = function(self)
                        return Config:GetSetting('DoSnare') and Core.IsModeActive("Mana") and not mq.TLO.Me.AltAbility("Entrap")()
                    end,
                },
                -- [ HEAL MODE ] --
                { name = "LongHeal2",    cond = function(self) return Core.IsModeActive("Heal") == 1 end, },
                -- [ Fall Back ]--
                { name = "WinterFireDD", cond = function(self) return Config:GetSetting("DoFire") end, },
                { name = "IceNuke",      cond = function(self) return true end, },

            },
        },
        {
            gem = 3,
            spells = {
                -- [ MANA MODE ] --
                { name = "WinterFireDD", cond = function(self) return Core.IsModeActive("Mana") end, },
                -- [ HEAL MODE ] --
                { name = "CharmSpell",   cond = function(self) return Config:GetSetting('CharmOn') end, },
                { name = "QuickRoarDD",  cond = function(self) return true end, },
                -- [ Fall Back ]--
                { name = "IceRainNuke",  cond = function(self) return true end, },
            },
        },
        {
            gem = 4,
            spells = {
                -- [ BOTH MODES ] --
                -- [ MANA MODE ] --
                { name = "QuickRoarDD",     cond = function(self) return Core.IsModeActive("Mana") end, },
                -- [ HEAL MODE ] --
                { name = "HordeDot",        cond = function(self) return true end, },
                -- [ Fall Back ]--
                { name = "RoDebuff",        cond = function(self) return Config:GetSetting("DoFire") end, },
                { name = "IceBreathDebuff", cond = function(self) return true end, },
            },
        },
        {
            gem = 5,
            spells = {
                -- [ MANA MODE ] --
                { name = "HordeDot",  cond = function(self) return Core.IsModeActive("Mana") end, },
                -- [ HEAL MODE ] --
                { name = "SunrayDot", cond = function(self) return true end, },
                { name = "SunDot",    cond = function(self) return true end, },
                -- [ Fall Back ]--
            },
        },
        {
            gem = 6,
            spells = {
                -- [ BOTH MODES ] --
                -- [ MANA MODE ] --
                { name = "RoDebuff",    cond = function(self) return Core.IsModeActive("Mana") end, },
                -- [ HEAL MODE ] --
                { name = "SunDot",      cond = function(self) return true end, },
                { name = "SnareSpells", cond = function(self) return Config:GetSetting('DoSnare') and not mq.TLO.Me.AltAbility("Entrap")() end, },
                -- [ Fall Back ]--
                { name = "HordeDot",    cond = function(self) return true end },
                { name = "CharmSpell",  cond = function(self) return Config:GetSetting('CharmOn') end, },

            },
        },
        {
            gem = 7,
            spells = {
                -- [ MANA MODE ] --
                -- [ HEAL MODE ] --
                { name = "RoDebuff",    cond = function(self) return true end, },
                -- [ Fall Back ]--
                { name = "HordeDot",    cond = function(self) return true end, },
                { name = "SnareSpells", cond = function(self) return Config:GetSetting('DoSnare') and not mq.TLO.Me.AltAbility("Entrap")() end },
                { name = "SunDot",      cond = function(self) return true end },
                { name = "RootSpells",  cond = function(self) return Core.IsModeActive("Mana") and Config:GetSetting('DoRoot') end, },
            },
        },
        {
            gem = 8,
            spells = {
                -- [ MANA MODE ] --
                {
                    name = "IceBreathDebuff",
                    cond = function(self)
                        return mq.TLO.Me.Level() >= 63 and
                            Core.IsModeActive("Mana")
                    end,
                    { name = "IceDD", cond = function(self) return Core.IsModeActive("Mana") end, },
                },
            },
        },
        {
            gem = 9,
            cond = function(self, gem) return mq.TLO.Me.NumGems() >= gem end,
            spells = {
                -- [ MANA MODE ] --
                { name = "IceDD", cond = function(self) return Core.IsModeActive("Mana") end, },
                -- [ HEAL MODE ] --
            },
        },
    },
    ['HelperFunctions']   = {
        DoRez = function(self, corpseId)
            local rezAction = false

            if mq.TLO.Me.CombatState():lower() == "combat" and Config:GetSetting('DoBattleRez') then
                if mq.TLO.FindItem("Staff of Forbidden Rites")() and mq.TLO.Me.ItemReady("Staff of Forbidden Rites")() then
                    rezAction = Casting.UseItem("Staff of Forbidden Rites", corpseId)
                elseif Casting.AAReady("Call of the Wild") and corpseId ~= mq.TLO.Me.ID() then
                    rezAction = Casting.UseAA("Call of the Wild", corpseId, true, 1)
                end
            end

            if rezAction and mq.TLO.Spawn(corpseId).Distance3D() > 25 then
                Targeting.SetTarget(corpseId)
                Core.DoCmd("/corpse")
            end

            return rezAction
        end,
    },
    --TODO: These are nearly all in need of Display and Tooltip updates.
    ['DefaultConfig']     = {
        ['Mode']         = {
            DisplayName = "Mode",
            Category = "Combat",
            Tooltip = "Select the Combat Mode for this Toon",
            Type = "Custom",
            RequiresLoadoutChange = true,
            Default = 1,
            Min = 1,
            Max = 3,
            FAQ = "What do the different Modes Do?",
            Answer = "Heal Mode will focus on healing and buffing.\nMana Mode will focus on DPS and Mana Management.",
        },
        --TODO: This is confusing because it is actually a choice between fire and ice and should be rewritten (need time to update conditions above)
        ['DoFire']       = {
            DisplayName = "Cast Fire Spells",
            Category = "Spells and Abilities",
            Tooltip = "if Enabled Use Fire Spells, Disabled Use Ice Spells",
            RequiresLoadoutChange = true,
            Default = true,
            FAQ = "Can I choose between Fire or Ice based Nukes?",
            Answer = "Yes, you can choose between Fire and Ice based Nukes by toggling [DoFire].\n" ..
                "When [DoFire] is enabled, we will use Fire based Nukes.\n" ..
                "When [DoFire] is disabled, we will use Ice based Nukes.",
        },
        ['DoRain']       = {
            DisplayName = "Cast Rain Spells",
            Category = "Spells and Abilities",
            Tooltip = "Use Rain Spells",
            Default = true,
            FAQ = "I like Rain spells, can I use them?",
            Answer = "Yes, you can enable [DoRain] to use Rain spells.",
        },
        ['DoRunSpeed']   = {
            DisplayName = "Use Movement Buffs",
            Category = "Spells and Abilities",
            Tooltip = "Use Run buffs.",
            Default = true,
            FAQ = "Sometimes I group with a bard and don't need to worry about Run Speed, can I disable it?",
            Answer = "Yes, you can disable [DoRunSpeed] to prevent casting Run Speed spells.",
        },
        ['DoLevRun']     = {
            DisplayName = "Use Spirit of Eagles line instead of Spirit of Wolf line.",
            Category = "Spells and Abilities",
            Tooltip = "Use run/lev buffs (DoRunSpeed must be enabled as well).",
            Default = false,
        },
        ['DoNuke']       = {
            DisplayName = "Cast Spells",
            Category = "Spells and Abilities",
            Tooltip = "Use Spells",
            Default = true,
            FAQ = "Why am I not Nuking?",
            Answer = "Make sure [DoNuke] is enabled. If you are in Heal Mode, you may not be nuking.\n" ..
                "Also double check [NukePct] to ensure you are nuking at the correct health percentage.",
        },
        ['NukePct']      = {
            DisplayName = "Cast Spells",
            Category = "Spells and Abilities",
            Tooltip = "Use Spells",
            Default = 90,
            Min = 1,
            Max = 100,
            FAQ = "Why am I nuking at 10% health?",
            Answer = "Make sure [NukePct] is set to the correct health percentage you want to start nuking at.",
        },
        ['DoSnare']      = {
            DisplayName = "Cast Snares",
            Category = "Spells and Abilities",
            Tooltip = "Enable casting Snare spells.",
            Default = true,
            FAQ = "Why am I not Snaring?",
            Answer = "Make sure [DoSnare] is enabled. If you are in Heal Mode, you may not be snaring.",
        },
        ['DoRoot']       = {
            DisplayName = "Cast Roots",
            Category = "Spells and Abilities",
            Tooltip = "Enable casting root spells (if we happen to have the right spell slot free)",
            Default = false,
        },
        ['DoChestClick'] = {
            DisplayName = "Do Chest Click",
            Category = "Utilities",
            Tooltip = "Click your chest item",
            Default = mq.TLO.MacroQuest.BuildName() ~= "Emu",
            FAQ = "Why am I not clicking my chest item?",
            Answer = "Make sure [DoChestClick] is enabled. If you are in Heal Mode, you may not be clicking your chest item.",
        },
        ['DoDot']        = {
            DisplayName = "Cast DOTs",
            Category = "Spells and Abilities",
            Tooltip = "Enable casting Damage Over Time spells.",
            Default = true,
            FAQ = "Why am I not DOTing?",
            Answer = "Make sure [DoDot] is enabled. If you are in Heal Mode, you may not be DOTing.",
        },
        ['DoHPBuff']     = {
            DisplayName = "Group HP Buff",
            Category = "Spells and Abilities",
            Tooltip = "Use your group HP Buff. Disable as desired to prevent conflicts with CLR or PAL buffs.",
            Default = true,
            FAQ = "Why am I in a buff war with my Paladin or Druid? We are constantly overwriting each other's buffs.",
            Answer = "Disable [DoHPBuff] to prevent issues with Aego/Symbol lines overwriting. Alternatively, you can adjust the settings for the other class instead.",
        },
        ['DoGroupRegen'] = {
            DisplayName = "Group Regen Buff",
            Category = "Spells and Abilities",
            Tooltip = "Use your Group Regen buff.",
            Default = true,
            FAQ = "Why am I spamming my Group Regen buff?",
            Answer = "Certain Shaman and Druid group regen buffs report cross-stacking. You should deselect the option on one of the PCs if they are grouped together.",
        },
    },
}

return _ClassConfig

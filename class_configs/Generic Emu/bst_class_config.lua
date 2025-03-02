local mq        = require('mq')
local Combat    = require('utils.combat')
local Config    = require('utils.config')
local Core      = require("utils.core")
local Targeting = require("utils.targeting")
local Casting   = require("utils.casting")
local Logger    = require("utils.logger")

return {
    _version              = "1.0 - Emu",
    _author               = "Derple, Algar, Lisie",
    ['Modes']             = {
        'DPS',
    },
    ['ModeChecks']        = {
        IsHealing = function() return true end,
    },
    ['ItemSets']          = {                  --TODO: Add Omens Chest
        ['Epic'] = {
            "Savage Lord's Totem",             -- Epic    -- Epic 1.5
            "Spiritcaller Totem of the Feral", -- Epic    -- Epic 2.0
        },
        ['OoW_Chest'] = {
            "Beast Tamer's Jerkin",
            "Savagesoul Jerkin of the Wilds",
        },
    },
    ['AbilitySets']       = { --TODO/Under Consideration: Add AoE Roar line, add rotation entry (tie it to Do AoE setting), swap in instead of lance 2, especially since the last lance2 is level 112
        ['Icelance1'] = {
            -- Lance 1 Timer 7 Ice Nuke Fast Cast
            "Blast of Frost",        -- Level 12 - Timer 7
            "Frost Shard",           -- Level 47 - Timer 7
            "Blizzard Blast",        -- Level 59 - Timer ???
            "Frost Spear",           -- Level 63 - Timer 7
            "Ancient: Frozen Chaos", -- Level 65 - Timer 7
            "Ancient: Savage Ice",   -- Level 70 - Timer 7
        },
        ['Icelance2'] = {
            -- Lance 2 Timer 11 Ice Nuke Fast Cast
            "Ice Spear",       -- Level 33 - Timer 11
            "Ice Shard",       -- Level 54 - Timer 11
            "Trushar's Frost", -- Level 65 - Timer 11
            "Glacier Spear",   -- Level 69 - Timer 11
        },
        ['EndemicDot'] = {
            -- Disease DoT Instant Cast
            "Sicken",           -- Level 14
            "Malaria",          -- Level 40
            "Plague",           -- Level 65
            "Festering Malady", -- Level 70
        },
        ['BloodDot'] = {
            -- Poison DoT Instant Cast
            "Tainted Breath",     -- Level 19
            "Envenomed Breath",   -- Level 35
            "Venom of the Snake", -- Level 52
            "Scorpion Venom",     -- Level 61
            "Turepta Blood",      -- Level 65
            "Chimera Blood",      -- Level 66
        },
        ['SlowSpell'] = {
            -- Slow Spell
            "Drowsy",          -- Level 20
            "Sha's Lethargy",  -- Level 50
            "Sha's Advantage", -- Level 60
            "Sha's Revenge",   -- Level 65
            "Sha's Legacy",    -- Level 70
        },
        ['HealSpell'] = {
            "Salve",             -- Level 1
            "Minor Healing",     -- Level 6
            "Light Healing",     -- Level 18
            "Healing",           -- Level 28
            "Greater Healing",   -- Level 38
            "Spirit Salve",      -- Level 48
            "Chloroblast",       -- Level 59
            "Trushar's Mending", -- Level 65
            "Muada's Mending",   -- Level 67
        },
        ['PetHealSpell'] = {
            "Sharik's Replenishing",   -- Level 9
            "Keshuval's Rejuvenation", -- Level 15
            "Herikol's Soothing",      -- Level 27
            "Yekan's Recovery",        -- Level 36
            "Vigor of Zehkes",         -- Level 49
            "Aid of Khurenz",          -- Level 52
            "Sha's Restoration",       -- Level 55
            "Healing of Sorsha",       -- Level 61
            "Healing of Mikkily",      -- Level 66
        },
        ['PetSpell'] = {
            "Spirit of Sharik",    -- Level 8
            "Spirit of Khaliz",    -- Level 15
            "Spirit of Keshuval",  -- Level 21
            "Spirit of Herikol",   -- Level 30
            "Spirit of Yekan",     -- Level 39
            "Spirit of Kashek",    -- Level 46
            "Spirit of Omakin",    -- Level 54
            "Spirit of Zehkes",    -- Level 56
            "Spirit of Khurenz",   -- Level 58
            "Spirit of Khati Sha", -- Level 60
            "Spirit of Arag",      -- Level 62
            "Spirit of Sorsha",    -- Level 64
            "Spirit of Alladnu",   -- Level 68
            "Spirit of Rashara",   -- Level 70
        },
        ['PetHaste'] = {
            --Pet Haste*
            "Yekan's Quickening",
            "Bond of The Wild",
            "Omakin's Alacrity",
            "Sha's Ferocity",
            "Arag's Celerity",
            "Growl of the Beast",
        },
        ['PetGrowl'] = {
            --Pet Growl Buff* 69-115
            "Growl of the Panther",
        },
        ['PetDamageProc'] = {
            "Spirit of Lightning",
            "Spirit of the Blizzard",
            "Spirit of Inferno",
            "Spirit of the Scorpion",
            "Spirit of Vermin",
            "Spirit of Wind",
            "Spirit of the Storm",
            "Spirit of Snow",
            "Spirit of Flame",
            "Spirit of Rellic",
            "Spirit of Irionu",
        },
        ['RunSpeedBuff'] = {
            "Spirit of wolf",
            -- Spirit of the Shrew Is Only 30% Speed Flat So Removed it from the List as its too slow
            --   [] = "Spirit of the Shrew"],
            --   [] = "Pack Shrew"].
        },
        ['ManaRegenBuff'] = {
            --Mana/Hp/End Regen Buff*
            "Spiritual Light",
            "Spiritual Radiance",
            "Spiritual Purity",
            "Spiritual Dominion",
            "Spiritual Ascendance",
        },
        ['PetBlockSpell'] = {
            "Ward of Calliav",       -- Level 49
            "Guard of Calliav",      -- Level 58
            "Protection of Calliav", -- Level 64
            "Feral Guard",           -- Level 69
        },
        ['AvatarSpell'] = {
            -- Str Stam Dex Buff
            "Infusion of Spirit", -- Level 61
        },
        ['FocusSpell'] = {
            -- Single target Talismans ( Like Focus)
            "Inner Fire",
            "Talisman of Tnarg",
            "Talisman of Altuna",
            "Talisman of Kragg",
            "Focus of Alladnu",
            -- Group Focus Spells
        },
        ['AtkHPBuff'] = {
            -- Group Attack+ Hp Buff
            "Spiritual Vitality",
            --Single Target Atk+HP Buff* - Does Not Stack with Pally brells or Ranger Buff - is Middle ground Buff has HP & Atk
            "Spiritual Brawn",
            "Spiritual Strength",
        },
        ['AtkBuff'] = {
            -- - Single Ferocity
            "Savagery",           -- Level 60
            "Ferocity",           -- Level 65
            "Ferocity of Irionu", -- Level 70
        },
        ['DmgModDisc'] = {
            --All Skills Damage Modifier*
            "Bestial Fury Discipline",
        },
    },
    ['HealRotationOrder'] = {
        {
            name = 'PetHealAA',
            state = 1,
            steps = 1,
            load_cond = function() return Casting.CanUseAA("Mend Companion") end,
            cond = function(self, target) return target.ID() == mq.TLO.Me.Pet.ID() and mq.TLO.Me.Pet.PctHPs() <= Config:GetSetting('MainHealPoint') end,
        },
        {
            name = 'PetHealSpell',
            state = 1,
            steps = 1,
            load_cond = function() return Config:GetSetting('DoPetHeals') end,
            cond = function(self, target) return target.ID() == mq.TLO.Me.Pet.ID() and mq.TLO.Me.Pet.PctHPs() <= Config:GetSetting('BigHealPoint') end,
        },
        {
            name = 'MainHealPoint',
            state = 1,
            steps = 1,
            load_cond = function() return Config:GetSetting('DoHeals') end,
            cond = function(self, target) return (target.PctHPs() or 999) < Config:GetSetting('MainHealPoint') end,
        },
    },
    ['HealRotations']     = {
        ["PetHealAA"] = {
            {
                name = "Mend Companion",
                type = "AA",
                cond = function(self, aaName, target)
                    return Casting.TargetedAAReady(aaName, target.ID(), true)
                end,
            },
        },
        ["PetHealSpell"] = {
            {
                name = "PetHealSpell",
                type = "Spell",
                cond = function(self, spell, target)
                    return Casting.TargetedSpellReady(spell, target.ID(), true)
                end,
            },
        },
        ["MainHealPoint"] = {
            {
                name = "HealSpell",
                type = "Spell",
                cond = function(self, spell, target) return Casting.TargetedSpellReady(spell, target.ID(), true) end,
            },
        },
    },
    ['RotationOrder']     = {
        -- Downtime doesn't have state because we run the whole rotation at once.
        { --Downtime
            name = 'Downtime',
            targetId = function(self) return { mq.TLO.Me.ID(), } end,
            cond = function(self, combat_state)
                return combat_state == "Downtime" and Casting.DoBuffCheck() and Casting.AmIBuffable()
            end,
        },
        {               -- GroupBuff
            name = 'GroupBuff',
            timer = 60, -- only run every 60 seconds top.
            targetId = function(self)
                return Casting.GetBuffableGroupIDs()
            end,
            cond = function(self, combat_state)
                return combat_state == "Downtime" and Casting.DoBuffCheck()
            end,
        },
        { -- PetSummon - Summon pet even when buffs are off on emu
            name = 'PetSummon',
            targetId = function(self) return { mq.TLO.Me.ID(), } end,
            cond = function(self, combat_state)
                return combat_state == "Downtime" and mq.TLO.Me.Pet.ID() == 0 and Casting.DoPetCheck() and Casting.AmIBuffable()
            end,
        },
        { -- PetBuff - Pet Buffs if we have one, timer because we don't need to constantly check this
            name = 'PetBuff',
            timer = 30,
            targetId = function(self) return mq.TLO.Me.Pet.ID() > 0 and { mq.TLO.Me.Pet.ID(), } or {} end,
            cond = function(self, combat_state)
                return combat_state == "Downtime" and mq.TLO.Me.Pet.ID() > 0 and Casting.DoPetCheck()
            end,
        },
        { -- Emergancy
            name = 'Emergency',
            state = 1,
            steps = 1,
            doFullRotation = true,
            targetId = function(self) return mq.TLO.Target.ID() == Config.Globals.AutoTargetID and { Config.Globals.AutoTargetID, } or {} end,
            cond = function(self, combat_state)
                return Targeting.GetXTHaterCount() > 0 and not Casting.IAmFeigning() and
                    (mq.TLO.Me.PctHPs() <= Config:GetSetting('EmergencyStart') or (Targeting.IsNamed(mq.TLO.Target) and mq.TLO.Me.PctAggro() > 99))
            end,
        },
        { -- Slow
            name = 'Slow',
            state = 1,
            steps = 1,
            load_cond = function() return Config:GetSetting('DoSlow') end,
            targetId = function(self) return mq.TLO.Target.ID() == Config.Globals.AutoTargetID and { Config.Globals.AutoTargetID, } or {} end,
            cond = function(self, combat_state)
                return combat_state == "Combat" and not Casting.IAmFeigning() and Casting.DebuffConCheck()
            end,
        },
        { -- Burn
            name = 'Burn',
            state = 1,
            steps = 1,
            targetId = function(self) return mq.TLO.Target.ID() == Config.Globals.AutoTargetID and { Config.Globals.AutoTargetID, } or {} end,
            cond = function(self, combat_state)
                return combat_state == "Combat" and Casting.BurnCheck() and not Casting.IAmFeigning()
            end,
        },
        { -- DPS
            name = 'DPS',
            state = 1,
            steps = 1,
            targetId = function(self) return mq.TLO.Target.ID() == Config.Globals.AutoTargetID and { Config.Globals.AutoTargetID, } or {} end,
            cond = function(self, combat_state)
                return combat_state == "Combat" and not Casting.IAmFeigning()
            end,
        },
        { -- Weaves
            name = 'Weaves',
            state = 1,
            steps = 1,
            targetId = function(self) return mq.TLO.Target.ID() == Config.Globals.AutoTargetID and { Config.Globals.AutoTargetID, } or {} end,
            cond = function(self, combat_state)
                return combat_state == "Combat" and not Casting.IAmFeigning()
            end,
        },
    },
    ['HelperFunctions']   = {
        DmgModActive = function(self) --Song active by name will check both Bestial Alignments (Self and Group)
            local disc = self.ResolvedActionMap['DmgModDisc']
            return Casting.SongActiveByName("Bestial Alignment") or (disc and disc() and Casting.SongActiveByName(disc.Name()))
                or Casting.BuffActiveByName("Ferociousness")
        end,
        --function to make sure we don't have non-hostiles in range before we use AE damage or non-taunt AE hate abilities
        AETargetCheck = function(printDebug)
            local haters = mq.TLO.SpawnCount("NPC xtarhater radius 80 zradius 50")()
            local haterPets = mq.TLO.SpawnCount("NPCpet xtarhater radius 80 zradius 50")()
            local totalHaters = haters + haterPets
            if totalHaters < Config:GetSetting('AETargetCnt') or totalHaters > Config:GetSetting('MaxAETargetCnt') then return false end

            if Config:GetSetting('SafeAEDamage') then
                local npcs = mq.TLO.SpawnCount("NPC radius 80 zradius 50")()
                local npcPets = mq.TLO.SpawnCount("NPCpet radius 80 zradius 50")()
                if totalHaters < (npcs + npcPets) then
                    if printDebug then
                        Logger.log_verbose("AETargetCheck(): %d mobs in range but only %d xtarget haters, blocking AE damage actions.", npcs + npcPets, haters + haterPets)
                    end
                    return false
                end
            end

            return true
        end,
    },
    ['Rotations']         = {
        ['Burn'] = {
            {
                name = "Companion's Fury",
                type = "AA",
                cond = function(self, aaName)
                    return Casting.AAReady(aaName)
                end,
            },
            {
                name = mq.TLO.Me.Inventory("Chest").Name(),
                type = "Item",
                active_cond = function(self)
                    local item = mq.TLO.Me.Inventory("Chest")
                    return item() and Casting.TargetHasBuff(item.Spell, mq.TLO.Me)
                end,
                cond = function(self)
                    local item = mq.TLO.Me.Inventory("Chest")
                    return Config:GetSetting('DoChestClick') and item() and Casting.SpellStacksOnMe(item.Spell) and item.TimerReady() == 0
                end,
            },
            {
                name = "BloodDot",
                type = "Spell",
                cond = function(self, spell, target)
                    local vinDisc = self.ResolvedActionMap['VinDisc']
                    if not vinDisc then return false end
                    return Casting.BuffActive(vinDisc) and Casting.TargetedSpellReady(spell, target.ID())
                end,
            },
            {
                name = "DmgModDisc",
                type = "Disc",
                cond = function(self, discSpell)
                    return Casting.DiscReady(discSpell) and not self.ClassConfig.HelperFunctions.DmgModActive(self)
                end,
            },
            {
                name = "Bestial Alignment",
                type = "AA",
                cond = function(self, aaName)
                    return Casting.AAReady(aaName) and not self.ClassConfig.HelperFunctions.DmgModActive(self)
                end,
            },
            {
                name = "OoW_Chest",
                type = "Item",
                cond = function(self, itemName)
                    return mq.TLO.FindItemCount(itemName)() ~= 0 and mq.TLO.FindItem(itemName).TimerReady() == 0 and not self.ClassConfig.HelperFunctions.DmgModActive(self)
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
        },
        ['Slow'] = {
            {
                name = "SlowSpell",
                type = "Spell",
                cond = function(self, spell, target)
                    if Casting.CanUseAA("Sha's Reprisal") then return false end
                    return Casting.DetSpellCheck(spell) and (spell.RankName.SlowPct() or 0) > (Targeting.GetTargetSlowedPct()) and
                        Casting.TargetedSpellReady(spell, target.ID())
                end,
            },
        },
        ['Emergency'] = {
            {
                name = "Armor of Experience",
                type = "AA",
                cond = function(self, aaName)
                    if not Config:GetSetting('DoVetAA') then return false end
                    return mq.TLO.Me.PctHPs() < 35 and Casting.AAReady(aaName)
                end,
            },
        },
        ['DPS'] = {
            {
                name = "PetSpell",
                type = "Spell",
                cond = function(self, spell)
                    return mq.TLO.Me.Pet.ID() == 0
                end,
            },
            {
                name = "Paragon of Spirit",
                type = "AA",
                cond = function(self, aaName)
                    if not Config:GetSetting('DoParagon') then return false end
                    return (mq.TLO.Group.LowMana(Config:GetSetting('ParaPct'))() or -1) > 0 and Casting.AAReady(aaName)
                end,
            },
            {
                name = "BloodDot",
                type = "Spell",
                cond = function(self, spell, target)
                    if not Config:GetSetting('DoDot') then return false end
                    return Casting.DotSpellCheck(spell) and (Casting.DotHaveManaToNuke() or Casting.BurnCheck()) and Casting.TargetedSpellReady(spell, target.ID())
                end,
            },
            {
                name = "EndemicDot",
                type = "Spell",
                cond = function(self, spell, target)
                    if not Config:GetSetting('DoDot') then return false end
                    return Casting.DotSpellCheck(spell) and (Casting.DotHaveManaToNuke() or Casting.BurnCheck()) and Casting.TargetedSpellReady(spell, target.ID())
                end,
            },
            {
                name = "Icelance1",
                type = "Spell",
                cond = function(self, spell, target)
                    return (Casting.HaveManaToNuke() or Casting.BurnCheck()) and Casting.TargetedSpellReady(spell, target.ID())
                end,
            },
            {
                name = "Icelance2",
                type = "Spell",
                cond = function(self, spell, target)
                    return (Casting.HaveManaToNuke() or Casting.BurnCheck()) and Casting.TargetedSpellReady(spell, target.ID())
                end,
            },
        },
        ['Weaves'] = {
            {
                name = "Round Kick",
                type = "Ability",
                cond = function(self, abilityName, target)
                    return Casting.CanUseAA("Feral Swipe") and mq.TLO.Me.AbilityReady(abilityName)() and Casting.AbilityRangeCheck(target)
                end,
            },
            {
                name = "Kick",
                type = "Ability",
                cond = function(self, abilityName, target)
                    return not Casting.CanUseAA("Feral Swipe") and mq.TLO.Me.AbilityReady(abilityName)() and Casting.AbilityRangeCheck(target)
                end,
            },
            {
                name = "Tiger Claw",
                type = "Ability",
                cond = function(self, abilityName, target)
                    return mq.TLO.Me.AbilityReady(abilityName)() and Casting.AbilityRangeCheck(target)
                end,
            },
        },
        ['GroupBuff'] = {
            {
                name = "RunSpeedBuff",
                type = "Spell",
                cond = function(self, spell, target)
                    if not Config:GetSetting('DoRunSpeed') then return false end
                    return Casting.GroupBuffCheck(spell, target)
                end,
            },
            {
                name = "AvatarSpell",
                type = "Spell",
                cond = function(self, spell, target)
                    if not Config:GetSetting('DoAvatar') or not Config.Constants.RGMelee:contains(target.Class.ShortName()) then return false end
                    return Casting.GroupBuffCheck(spell, target)
                end,
            },
            {
                name = "AtkBuff",
                type = "Spell",
                cond = function(self, spell, target)
                    -- Make sure this is gemmed due to long refresh, and only use the single target versions on classes that need it.
                    if (spell and spell() and ((spell.TargetType() or ""):lower() ~= "group v2")) and (not Casting.GemReady(spell)
                            or not Config.Constants.RGMelee:contains(target.Class.ShortName())) then
                        return false
                    end
                    return Casting.GroupBuffCheck(spell, target)
                end,
            },
            {
                name = "ManaRegenBuff",
                type = "Spell",
                cond = function(self, spell, target)
                    return Casting.GroupBuffCheck(spell, target)
                end,
            },
            {
                name = "AtkHPBuff",
                type = "Spell",
                cond = function(self, spell, target)
                    -- Only use the single target versions on classes that need it
                    if (spell and spell() and ((spell.TargetType() or ""):lower() ~= "group v2"))
                        and not Config.Constants.RGMelee:contains(target.Class.ShortName()) then
                        return false
                    end
                    return Casting.GroupBuffCheck(spell, target)
                end,
            },
            {
                name = "FocusSpell",
                type = "Spell",
                cond = function(self, spell, target)
                    -- Only use the single target versions on classes that need it
                    if (spell and spell() and ((spell.TargetType() or ""):lower() ~= "group v2"))
                        and not Config.Constants.RGMelee:contains(target.Class.ShortName()) then
                        return false
                    end
                    return Casting.GroupBuffCheck(spell, target)
                end,
            },
        },
        ['PetSummon'] = {
            {
                name = "PetSpell",
                type = "Spell",
                cond = function(self, spell)
                    return mq.TLO.Me.Pet.ID() == 0
                end,
            },
        },
        ['Downtime'] = {
        },
        ['PetBuff'] = {
            {
                name = "Epic",
                type = "Item",
                cond = function(self, itemName)
                    return Config:GetSetting('DoEpic') and
                        mq.TLO.FindItem(itemName)() and mq.TLO.Me.ItemReady(itemName)() and
                        (mq.TLO.Me.PetBuff("Savage Wildcaller's Blessing")() == nil and mq.TLO.Me.PetBuff("Might of the Wild Spirits")() == nil)
                end,
            },
            {
                name = "Hobble of Spirits",
                type = "AA",
                cond = function(self, aaName, target)
                    return Config:GetSetting('DoPetSnare') and
                        mq.TLO.Me.PetBuff(mq.TLO.Me.AltAbility(aaName).Spell.RankName.Name())() == nil
                end,
            },
            {
                name = "AvatarSpell",
                type = "Spell",
                cond = function(self, spell)
                    return Config:GetSetting('DoAvatar') and Casting.SelfBuffPetCheck(spell)
                end,
            },
            {
                name = "RunSpeedBuff",
                type = "Spell",
                cond = function(self, spell)
                    return Config:GetSetting('DoRunSpeed') and Casting.SelfBuffPetCheck(spell)
                end,
            },
            {
                name = "PetHaste",
                type = "Spell",
                cond = function(self, spell)
                    return Casting.SelfBuffPetCheck(spell)
                end,
            },
            {
                name = "PetDamageProc",
                type = "Spell",
                cond = function(self, spell)
                    return (not Config:GetSetting('DoTankPet')) and Casting.SelfBuffPetCheck(spell)
                end,
            },
            {
                name = "PetGrowl",
                type = "Spell",
                cond = function(self, spell)
                    return not Casting.SongActive(spell)
                end,
            },
        },
    },
    ['Spells']            = {
        {
            gem = 1,
            spells = {
                { name = "HealSpell",    cond = function(self) return Config:GetSetting('DoHeals') end, },
                { name = "PetHealSpell", cond = function(self) return Config:GetSetting('DoPetHeals') end, },
                { name = "Icelance1", },

            },
        },
        {
            gem = 2,
            spells = {
                { name = "PetHealSpell", cond = function(self) return Config:GetSetting('DoPetHeals') end, },
                { name = "Icelance1", },
                { name = "Icelance2", },
            },
        },
        {
            gem = 3,
            spells = {
                { name = "Icelance1", },
                { name = "Icelance2", },
                { name = "BloodDot",  cond = function(self) return Config:GetSetting('DoDot') end, },
            },
        },
        {
            gem = 4,
            spells = {
                { name = "Icelance2", },
                { name = "BloodDot",   cond = function(self) return Config:GetSetting('DoDot') end },
                { name = "EndemicDot", cond = function(self) return Config:GetSetting('DoDot') end, },

            },
        },
        {
            gem = 5,
            spells = {
                { name = "BloodDot",   cond = function(self) return Config:GetSetting('DoDot') end, },
                { name = "EndemicDot", cond = function(self) return Config:GetSetting('DoDot') end },
                { name = "AtkBuff" },
                { name = "SlowSpell",  cond = function(self) return Config:GetSetting('DoSlow') and not Casting.CanUseAA("Sha's Reprisal") end },
                { name = "PetGrowl", },
            },
        },
        {
            gem = 6,
            spells = {
                { name = "EndemicDot", cond = function(self) return Config:GetSetting('DoDot') end, }, --todo
                { name = "AtkBuff" },
                { name = "SlowSpell",  cond = function(self) return Config:GetSetting('DoSlow') and not Casting.CanUseAA("Sha's Reprisal") end },
                { name = "PetGrowl", },
            },
        },
        {
            gem = 7,
            spells = {
                { name = "AtkBuff" },
                { name = "SlowSpell", cond = function(self) return Config:GetSetting('DoSlow') and not Casting.CanUseAA("Sha's Reprisal") end },
                { name = "PetGrowl", },
            },
        },
        {
            gem = 8,
            spells = {
                { name = "SlowSpell", cond = function(self) return Config:GetSetting('DoSlow') and not Casting.CanUseAA("Sha's Reprisal") end },
                { name = "PetGrowl", },
            },
        },
        {
            gem = 9,
            cond = function(self, gem) return mq.TLO.Me.NumGems() >= gem end,
            spells = {
                { name = "PetGrowl", },
            },
        },
    },
    ['PullAbilities']     = {
        {
            id = 'SlowSpell',
            Type = "Spell",
            DisplayName = function() return Core.GetResolvedActionMapItem('SlowSpell')() or "" end,
            AbilityName = function() return Core.GetResolvedActionMapItem('SlowSpell')() or "" end,
            AbilityRange = 150,
            cond = function(self)
                local resolvedSpell = Core.GetResolvedActionMapItem('SlowSpell')
                if not resolvedSpell then return false end
                return mq.TLO.Me.Gem(resolvedSpell.RankName.Name() or "")() ~= nil
            end,
        },
    },
    ['DefaultConfig']     = { --TODO: Condense pet proc options into a combo box and update entry conditions appropriately
        ['Mode']           = {
            DisplayName = "Mode",
            Category = "Combat",
            Tooltip = "Select the Combat Mode for this Toon",
            Type = "Custom",
            RequiresLoadoutChange = true,
            Default = 1,
            Min = 1,
            Max = 1,
            FAQ = "What is the difference between the modes?",
            Answer = "Beastlords currently only have one Mode. This may change in the future.",
        },
        --Mana Management
        ['DoParagon']      = {
            DisplayName = "Use Paragon",
            Category = "Mana Mgmt.",
            Index = 1,
            Tooltip = "Use Group or Focused Paragon AAs.",
            RequiresLoadoutChange = true,
            Default = true,
            ConfigType = "Advanced",
            FAQ = "How do I use my Paragon of Spirit(s) abilities?",
            Answer = "Make sure you have [DoParagon] enabled.\n" ..
                "Set the [ParaPct] to the minimum mana % before we use Paragon of Spirit.\n" ..
                "Set the [FParaPct] to the minimum mana % before we use Focused Paragon.\n" ..
                "If you want to use Focused Paragon outside of combat, enable [DowntimeFP].",
        },
        ['ParaPct']        = {
            DisplayName = "Paragon %",
            Category = "Mana Mgmt.",
            Index = 2,
            Tooltip = "Minimum mana % before we use Paragon of Spirit.",
            Default = 80,
            Min = 1,
            Max = 99,
            ConfigType = "Advanced",
            FAQ = "Why am I not using my Paragon Abilities?",
            Answer = "Make sure you have [DoParagon] enabled.\n" ..
                "Set the [ParaPct] to the minimum mana % before we use Paragon of Spirit.\n" ..
                "Set the [FParaPct] to the minimum mana % before we use Focused Paragon.\n" ..
                "If you want to use Focused Paragon outside of combat, enable [DowntimeFP].",
        },
        --Pets
        ['DoTankPet']      = {
            DisplayName = "Do Tank Pet",
            Category = "Pet Mgmt.",
            Index = 1,
            Tooltip = "Use abilities designed for your pet to tank.",
            Default = false,
            FAQ = "Why am I not giving my pet tank buffs?",
            Answer = "Enable [DoTankPet] to use abilities designed for your pet to tank.\n" ..
                "Disable [DoTankPet] to use abilities designed for your pet to DPS.",
        },
        ['DoPetHeals']     = {
            DisplayName = "Do Pet Heals",
            Category = "Pet Mgmt.",
            Index = 2,
            Tooltip = "Mem and cast your Pet Heal (Salve) spell. AA Pet Heals are always used in emergencies.",
            Default = true,
            RequiresLoadoutChange = true,
            FAQ = "My Pet Keeps Dying, What Can I Do?",
            Answer = "Make sure you have [DoPetHeals] enabled.\n" ..
                "If your pet is still dying, consider using [PetHealPct] to adjust the pet heal threshold.",
        },
        ['DoPetSnare']     = {
            DisplayName = "Pet Snare Proc",
            Category = "Pet Mgmt.",
            Index = 4,
            Tooltip = "Use your Pet Snare Proc Buff (does not stack with Pet Damage or Slow Proc Buff).",
            Default = false,
            FAQ = "Why am I continually buffing my pet?",
            Answer = "Pet proc buffs do not stack, you should only select one.\n" ..
                "If neither Snare nor Slow proc are selected, the Damage proc will be used.",
        },
        ['DoEpic']         = {
            DisplayName = "Do Epic",
            Category = "Pet Mgmt.",
            Index = 8,
            Tooltip = "Click your Epic Weapon.",
            Default = false,
            FAQ = "How do I use my Epic Weapon?",
            Answer = "Enable Do Epic to click your Epic Weapon.",
        },
        --Spells/Abilities
        ['DoHeals']        = {
            DisplayName = "Do Heals",
            Category = "Spells and Abilities",
            Index = 1,
            Tooltip = "Mem and cast your Mending spell.",
            Default = true,
            RequiresLoadoutChange = true,
            FAQ = "I want to help with healing, what can I do?",
            Answer = "Make sure you have [DoHeals] enabled.\n" ..
                "If you want to help with pet healing, enable [DoPetHeals].",
        },
        ['DoSlow']         = {
            DisplayName = "Do Slow",
            Category = "Spells and Abilities",
            Index = 2,
            Tooltip = "Use your slow spell or AA.",
            Default = true,
            RequiresLoadoutChange = true,
            FAQ = "Why is my BST slowing, when I have a SHM in group?",
            Answer = "Simply deselect the option to Do Slow.",
        },
        ['DoDot']          = {
            DisplayName = "Cast DOTs",
            Category = "Spells and Abilities",
            Index = 3,
            Tooltip = "Enable casting Damage Over Time spells.",
            Default = true,
            RequiresLoadoutChange = true,
            FAQ = "Why am I using so many DOTs? I'm always running low mana!",
            Answer = "Generally, BST DoT spells are worth using at all levels of play.\n" ..
                "Dots have additional settings in the RGMercs Main config, such as the min mana% to use them, or mob HP to stop using them",
        },
        ['DoRunSpeed']     = {
            DisplayName = "Do Run Speed",
            Category = "Spells and Abilities",
            Index = 4,
            Tooltip = "Do Run Speed Spells/AAs",
            Default = true,
            FAQ = "Why are my buffers in a run speed buff war?",
            Answer = "Many run speed spells freely stack and overwrite each other, you will need to disable Run Speed Buffs on some of the buffers.",
        },
        ['DoAvatar']       = {
            DisplayName = "Do Avatar",
            Category = "Spells and Abilities",
            Index = 5,
            Tooltip = "Buff Group/Pet with Infusion of Spirit",
            Default = false,
            FAQ = "How do I use my Avatar Buffs?",
            Answer = "Make sure you have [DoAvatar] enabled.\n" ..
                "Also double check [DoBuffs] is enabled so you can cast on others.",
        },
        ['DoVetAA']        = {
            DisplayName = "Use Vet AA",
            Category = "Spells and Abilities",
            Index = 6,
            Tooltip = "Use Veteran AA's in emergencies or during Burn. (See FAQ)",
            Default = true,
            FAQ = "What Vet AA's does SHD use?",
            Answer = "If Use Vet AA is enabled, Intensity of the Resolute will be used on burns and Armor of Experience will be used in emergencies.",
        },
        --Combat
        ['DoAEDamage']     = {
            DisplayName = "Do AE Damage",
            Category = "Combat",
            Index = 1,
            Tooltip = "**WILL BREAK MEZ** Use AE damage Spells and AA. **WILL BREAK MEZ**\n" ..
                "This is a top-level setting that governs all AE damage, and can be used as a quick-toggle to enable/disable abilities without reloading spells.",
            Default = false,
            FAQ = "Why am I using AE damage when there are mezzed mobs around?",
            Answer = "It is not currently possible to properly determine Mez status without direct Targeting. If you are mezzing, consider turning this option off.",
        },
        ['AETargetCnt']    = {
            DisplayName = "AE Target Count",
            Category = "Combat",
            Index = 3,
            Tooltip = "Minimum number of valid targets before using AE Disciplines or AA.",
            Default = 2,
            Min = 1,
            Max = 10,
            FAQ = "Why am I using AE abilities on only a couple of targets?",
            Answer =
            "You can adjust the AE Target Count to control when you will use actions with AE damage attached.",
        },
        ['MaxAETargetCnt'] = {
            DisplayName = "Max AE Targets",
            Category = "Damage Spells",
            Index = 4,
            Tooltip =
            "Maximum number of valid targets before using AE Spells, Disciplines or AA.\nUseful for setting up AE Mez at a higher threshold on another character in case you are overwhelmed.",
            Default = 5,
            Min = 2,
            Max = 30,
            FAQ = "How do I take advantage of the Max AE Targets setting?",
            Answer =
            "By limiting your max AE targets, you can set an AE Mez count that is slightly higher, to allow for the possiblity of mezzing if you are being overwhelmed.",
        },
        ['SafeAEDamage']   = {
            DisplayName = "AE Proximity Check",
            Category = "Combat",
            Index = 5,
            Tooltip = "Check to ensure there aren't neutral mobs in range we could aggro if AE damage is used. May result in non-use due to false positives.",
            Default = false,
            FAQ = "Can you better explain the AE Proximity Check?",
            Answer = "If the option is enabled, the script will use various checks to determine if a non-hostile or not-aggroed NPC is present and avoid use of the AE action.\n" ..
                "Unfortunately, the script currently does not discern whether an NPC is (un)attackable, so at times this may lead to the action not being used when it is safe to do so.\n" ..
                "PLEASE NOTE THAT THIS OPTION HAS NOTHING TO DO WITH MEZ!",
        },
        ['EmergencyStart'] = {
            DisplayName = "Emergency HP%",
            Category = "Combat",
            Index = 6,
            Tooltip = "Your HP % before we begin to use emergency mitigation abilities.",
            Default = 50,
            Min = 1,
            Max = 100,
            ConfigType = "Advanced",
            FAQ = "How do I use my Emergency Mitigation Abilities?",
            Answer = "Make sure you have [EmergencyStart] set to the HP % before we begin to use emergency mitigation abilities.",
        },
        ['DoChestClick']   = {
            DisplayName = "Do Chest Click",
            Category = "Combat",
            Index = 9,
            Tooltip = "Click your chest item during burns.",
            Default = mq.TLO.MacroQuest.BuildName() ~= "Emu",
            ConfigType = "Advanced",
            FAQ = "What is a Chest Click?",
            Answer = "Most Chest slot items after level 75ish have a clickable effect.\n" ..
                "BST is set to use theirs during burns, so long as the item equipped has a clicky effect.",
        },
    },
}

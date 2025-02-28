local mq           = require('mq')
local Config       = require('utils.config')
local Targeting    = require("utils.targeting")
local Casting      = require("utils.casting")
local Logger       = require("utils.logger")
local Core         = require("utils.core")

local _ClassConfig = {
    _version            = "1.0 - Emu",
    _author             = "Algar, Derple, Lisie",
    ['Modes']           = {
        'DPS',
    },
    ['ItemSets']        = {
        ['Epic'] = {
            "Transcended Fistwraps of Immortality",
            "Fistwraps of Celestial Discipline",
        },
    },
    ['AbilitySets']     = {
        ['Fang'] = {
            "Dragon Fang",
        },
        ['EarthDisc'] = {
            -- EarthDisc - Melee Mitigation
            "Earthwalk Discipline",
        },
        ['FistDisc'] = {
            "Ashenhand Discipline",
        },
        ['Heel'] = {
            "Rapid Kick Discipline",
        },
        ['Speed'] = {
            "Hundred Fists Discipline",
            "Speed Focus Discipline",
        },
        ['Palm'] = {
            "Innerflame Discipline",
        },
    },
    ['HelperFunctions'] = {
        BurnDiscCheck = function(self)
            if mq.TLO.Me.PctHPs() < Config:GetSetting('EmergencyStart') then return false end
            local burnDisc = { "Speed", "FistDisc", "Palm", }
            for _, buffName in ipairs(burnDisc) do
                local resolvedDisc = self:GetResolvedActionMapItem(buffName)
                if resolvedDisc and resolvedDisc.RankName() == mq.TLO.Me.ActiveDisc.Name() then return false end
            end
            return true
        end,
        --function to make sure we don't have non-hostiles in range before we use AE damage
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
    ['RotationOrder']   = {
        {
            name = 'Downtime',
            targetId = function(self) return { mq.TLO.Me.ID(), } end,
            cond = function(self, combat_state)
                return combat_state == "Downtime" and Casting.DoBuffCheck() and Casting.AmIBuffable()
            end,
        },
        {
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
        {
            name = 'Burn',
            state = 1,
            steps = 1,
            targetId = function(self) return mq.TLO.Target.ID() == Config.Globals.AutoTargetID and { Config.Globals.AutoTargetID, } or {} end,
            cond = function(self, combat_state)
                return combat_state == "Combat" and Casting.BurnCheck() and not Casting.IAmFeigning()
            end,
        },
        {
            name = 'CombatBuff',
            state = 1,
            steps = 1,
            targetId = function(self) return mq.TLO.Target.ID() == Config.Globals.AutoTargetID and { Config.Globals.AutoTargetID, } or {} end,
            cond = function(self, combat_state)
                return combat_state == "Combat" and not Casting.IAmFeigning()
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
    ['Rotations']       = {
        ['Downtime'] = {
            {
                name = "Mend",
                type = "Ability",
                cond = function(self, abilityName)
                    return mq.TLO.Me.AbilityReady(abilityName)() and mq.TLO.Me.PctHPs() < 50
                end,
            },
        },
        ['Emergency'] = {
            {
                name = "Feign Death",
                type = "Ability",
                cond = function(self, abilityName)
                    if not Config:GetSetting('AggroFeign') then return false end
                    return Targeting.IHaveAggro(95) and mq.TLO.Me.AbilityReady(abilityName)() and not Core.IAmMA
                end,
            },
            {
                name = "Armor of Experience",
                type = "AA",
                cond = function(self, aaName)
                    if not Config:GetSetting('DoVetAA') then return false end
                    return mq.TLO.Me.PctHPs() < 35 and Casting.AAReady(aaName)
                end,
            },
            {
                name = "Mend",
                type = "Ability",
                cond = function(self, abilityName)
                    return mq.TLO.Me.AbilityReady(abilityName)() and mq.TLO.Me.PctHPs() < Config:GetSetting('EmergencyStart')
                end,
            },
            {
                name = "Epic",
                type = "Item",
                cond = function(self, itemName)
                    return mq.TLO.FindItem(itemName).TimerReady() == 0
                end,
            },
        },
        ['Burn'] = {

            {
                name = "Speed",
                type = "Disc",
                cond = function(self, discSpell)
                    return Casting.DiscReady(discSpell) and self.ClassConfig.HelperFunctions.BurnDiscCheck(self)
                end,
            },
            {
                name = "FistDisc",
                type = "Disc",
                cond = function(self, discSpell)
                    return Casting.DiscReady(discSpell) and self.ClassConfig.HelperFunctions.BurnDiscCheck(self)
                end,
            },
            {
                name = "Palm",
                type = "Disc",
                cond = function(self, discSpell)
                    return Casting.DiscReady(discSpell) and self.ClassConfig.HelperFunctions.BurnDiscCheck(self)
                end,
            },
            {
                name = mq.TLO.Me.Inventory("Chest").Name(),
                type = "Item",
                cond = function(self)
                    if not Config:GetSetting('DoChestClick') then return false end
                    local item = mq.TLO.Me.Inventory("Chest")
                    return item() and item.TimerReady() == 0 and Casting.SpellStacksOnMe(item.Spell)
                end,
            },
            { --pairs with Speed Focus Disc, AE, T2
                name = "Destructive Force",
                type = "AA",
                cond = function(self, aaName)
                    local speedDisc = self:GetResolvedActionMapItem("Speed")
                    if not Config:GetSetting("DoAEDamage") or not speedDisc then return false end
                    return Casting.AAReady(aaName) and mq.TLO.Me.ActiveDisc.Name() == speedDisc.RankName() and self.ClassConfig.HelperFunctions.AETargetCheck()
                end,
            },
            { --pairs with Speed Focus Disc, single target, T2
                name = "Focused Destructive Force",
                type = "AA",
                cond = function(self, aaName)
                    local speedDisc = self:GetResolvedActionMapItem("Speed")
                    if Config:GetSetting("DoAEDamage") or not speedDisc then return false end
                    return Casting.AAReady(aaName) and mq.TLO.Me.ActiveDisc.Name() == speedDisc.RankName()
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
        ['CombatBuff'] = {
            {
                name = "EarthDisc",
                type = "Disc",
                cond = function(self, discSpell)
                    return Casting.DiscReady(discSpell) and not mq.TLO.Me.ActiveDisc.ID()
                end,
            },
        },
        ['DPS'] = {
            {
                name = "Fang",
                type = "Disc",
                cond = function(self, discSpell)
                    return Casting.TargetedDiscReady(discSpell)
                end,
            },
            {
                name = "Intimidation",
                type = "Ability",
                cond = function(self, abilityName)
                    if (mq.TLO.Me.AltAbility("Intimidation").Rank() or 0) < 2 then return false end
                    return mq.TLO.Me.AbilityReady(abilityName)()
                end,
            },
            {
                name = "Flying Kick",
                type = "Ability",
                cond = function(self, abilityName, target)
                    return mq.TLO.Me.AbilityReady(abilityName)() and Casting.AbilityRangeCheck(target)
                end,
            },
            {
                name = "Eagle Strike",
                type = "Ability",
                cond = function(self, abilityName, target)
                    if mq.TLO.Me.PctEndurance() > 25 then return false end
                    return mq.TLO.Me.AbilityReady(abilityName)() and Casting.AbilityRangeCheck(target)
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
    },
    ['PullAbilities']   = {
        {
            id = 'Distant Strike',
            Type = "AA",
            DisplayName = 'Distant Strike',
            AbilityName = 'Distant Strike',
            AbilityRange = 300,
            cond = function(self)
                return mq.TLO.Me.AltAbility('Distant Strike')
            end,
        },
    },
    ['DefaultConfig']   = {
        ['Mode']           = {
            DisplayName = "Mode",
            Category = "Combat",
            Tooltip = "Select the Combat Mode for this Toon",
            Type = "Custom",
            RequiresLoadoutChange = true,
            Default = 1,
            Min = 1,
            Max = 1,
            FAQ = "What do the different Modes Do?",
            Answer = "Currently there is only DPS mode for Monks, more modes may be added in the future.",
        },
        ['DoIntimidation'] = {
            DisplayName = "Orphaned",
            Type = "Custom",
            Category = "Orphaned",
            Tooltip = "Orphaned setting from live, no longer used in this config.",
            Default = false,
            FAQ = "Why do I see orphaned settings?",
            Answer = "To avoid deletion of settings when moving between configs, our beta or experimental configs keep placeholders for live settings\n" ..
                "These tabs or settings will be removed if and when the config is made the default.",
        },
        ['DoVetAA']        = {
            DisplayName = "Use Vet AA",
            Category = "Abilities",
            Index = 8,
            Tooltip = "Use Veteran AA's in emergencies or during Burn. (See FAQ)",
            Default = true,
            FAQ = "What Vet AA's does MNK use?",
            Answer = "If Use Vet AA is enabled, Intensity of the Resolute will be used on burns and Armor of Experience will be used in emergencies.",
        },
        ['DoAEDamage']     = {
            DisplayName = "Do AE Damage",
            Category = "Abilities",
            Index = 1,
            Tooltip = "**WILL BREAK MEZ** Use AE damage Discs and AA. **WILL BREAK MEZ**",
            Default = false,
            FAQ = "Why am I using AE damage when there are mezzed mobs around?",
            Answer = "It is not currently possible to properly determine Mez status without direct Targeting. If you are mezzing, consider turning this option off.",
        },
        ['AETargetCnt']    = {
            DisplayName = "AE Target Count",
            Category = "Abilities",
            Index = 2,
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
            Index = 3,
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
            Category = "Abilities",
            Index = 5,
            Tooltip = "Check to ensure there aren't neutral mobs in range we could aggro if AE damage is used. May result in non-use due to false positives.",
            Default = false,
            FAQ = "Can you better explain the AE Proximity Check?",
            Answer = "If the option is enabled, the script will use various checks to determine if a non-hostile or not-aggroed NPC is present and avoid use of the AE action.\n" ..
                "Unfortunately, the script currently does not discern whether an NPC is (un)attackable, so at times this may lead to the action not being used when it is safe to do so.\n" ..
                "PLEASE NOTE THAT THIS OPTION HAS NOTHING TO DO WITH MEZ!",
        },
        ['AggroFeign']     = {
            DisplayName = "Emergency Feign",
            Category = "Abilities",
            Index = 9,
            Tooltip = "Use your Feign AA when you have aggro at low health or aggro on a RGMercsNamed/SpawnMaster mob.",
            Default = true,
            FAQ = "How do I use my Feign Death?",
            Answer = "Make sure you have [AggroFeign] enabled.\n" ..
                "This will use your Feign Death AA when you have aggro at low health or aggro on a RGMercsNamed/SpawnMaster mob.",
        },
        ['EmergencyStart'] = {
            DisplayName = "Emergency HP%",
            Category = "Abilities",
            Index = 10,
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
            Category = "Abilities",
            Index = 8,
            Tooltip = "Click your chest item during burns.",
            Default = mq.TLO.MacroQuest.BuildName() ~= "Emu",
            ConfigType = "Advanced",
            FAQ = "What is a Chest Click?",
            Answer = "Most Chest slot items after level 75ish have a clickable effect.\n" ..
                "MNK is set to use theirs during burns, so long as the item equipped has a clicky effect.",
        },
    },
}

return _ClassConfig

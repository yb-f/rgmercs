local mq        = require('mq')
local Config    = require('utils.config')
local Core      = require("utils.core")
local Targeting = require("utils.targeting")
local Casting   = require("utils.casting")
local Strings   = require("utils.strings")
local Logger    = require("utils.logger")

return {
    _version            = "1.0 - Emu",
    _author             = "Derple, Algar, Lisie",
    ['Modes']           = {
        'DPS',
    },
    ['ItemSets']        = {
        ['Epic'] = {
            "Fatestealer",
            "Nightshade, Blade of Entropy",
        },
    },
    ['AbilitySets']     = {
        ["Executioner"] = {
            "Duelist Discipline",      -- Level 59
            "Kinesthetics Discipline", -- Level 57
        },
        ["Twisted"] = {
            "Twisted Chance Discipline", -- Level 65
            "Deadeye Discipline",        -- Level 54
        },
        ["Frenzied"] = {
            "Frenzied Stabbing Discipline", -- Level 70
        },
        ["SneakAttack"] = {
            "Daggerfall",            -- Level 69
            "Ancient: Chaos Strike", -- Level 65
            "Kyv Strike",            -- Level 65
            "Assassin's Strike",     -- Level 63
            "Thief's Vengeance",     -- Level 52
            "Sneak Attack",          -- Level 20
        },
        ["CADisc"] = {
            "Counterattack Discipline",
        },
        ["AimDisc"] = {
            "Deadly Aim Discipline", --  Level 68
        },
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
        ['Burn'] = {
            {
                name = "Frenzied",
                type = "Disc",
                cond = function(self, discSpell)
                    return Casting.DiscReady(discSpell) and self.ClassConfig.HelperFunctions.BurnDiscCheck(self)
                end,
            },
            {
                name = "Twisted",
                type = "Disc",
                cond = function(self, discSpell)
                    return Casting.DiscReady(discSpell) and self.ClassConfig.HelperFunctions.BurnDiscCheck(self)
                end,
            },
            {
                name = "Executioner",
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
            {
                name = "Shadow's Flanking",
                type = "AA",
                cond = function(self, aaName)
                    return Casting.AAReady(aaName)
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
                name = "Epic",
                type = "Item",
                cond = function(self, itemName)
                    if Config:GetSetting('UseEpic') == 1 then return false end
                    return (Config:GetSetting('UseEpic') == 3 or (Config:GetSetting('UseEpic') == 2 and Casting.BurnCheck())) and mq.TLO.FindItem(itemName)() and
                        mq.TLO.FindItem(itemName).TimerReady() == 0
                end,
            },
            {
                name = "PoisonName",
                type = "ClickyItem",
                cond = function(self, _)
                    local poisonItem = mq.TLO.FindItem(Config:GetSetting('PoisonName'))
                    return poisonItem and poisonItem() and poisonItem.Timer.TotalSeconds() == 0 and
                        not Casting.BuffActiveByID(poisonItem.Spell.ID())
                end,
            },
        },
        ['DPS'] = {
            {
                name = "Backstab",
                type = "Ability",
                cond = function(self, abilityName, target)
                    if not Casting.CanUseAA("Chaotic Stab") and not mq.TLO.Stick.Behind() then return false end
                    return mq.TLO.Me.AbilityReady(abilityName)() and Casting.AbilityRangeCheck(target)
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
                name = "Fade",
                type = "CustomFunc",
                cond = function(self) return mq.TLO.Target.PctAggro() >= 50 end,
                custom_func = function(_)
                    mq.cmd("/attack off")
                    if mq.TLO.Me.AbilityReady("hide")() then Core.DoCmd("/doability hide") end
                    mq.cmd("/attack on")
                    return true
                end,
            },
        },
        ['Emergency'] = {
            {
                name = "Escape",
                type = "AA",
                cond = function(self, aaName)
                    return Casting.AAReady(aaName) and Targeting.IHaveAggro(100)
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
                name = "CADisc",
                type = "Disc",
                cond = function(self, discSpell)
                    return Casting.DiscReady(discSpell) and Targeting.IHaveAggro(100)
                end,
            },
        },
        ['Downtime'] = {
            {
                name = "PoisonClicky",
                type = "ClickyItem",
                active_cond = function(self, _)
                    return (mq.TLO.FindItemCount(Config:GetSetting('PoisonName'))() or 0) >= Config:GetSetting('PoisonItemCount')
                end,
                cond = function(self, _)
                    return (mq.TLO.FindItemCount(Config:GetSetting('PoisonName'))() or 0) < Config:GetSetting('PoisonItemCount') and
                        mq.TLO.Me.ItemReady(Config:GetSetting('PoisonClicky'))()
                end,
            },
            {
                name = "PoisonName",
                type = "ClickyItem",
                active_cond = function(self, _)
                    local poisonItem = mq.TLO.FindItem(Config:GetSetting('PoisonName'))
                    return poisonItem and poisonItem() and Casting.BuffActiveByID(poisonItem.Spell.ID() or 0)
                end,
                cond = function(self, _)
                    local poisonItem = mq.TLO.FindItem(Config:GetSetting('PoisonName'))
                    return mq.TLO.Me.ItemReady(Config:GetSetting('PoisonName'))() and
                        not Casting.BuffActiveByID(poisonItem.Spell.ID())
                end,
            },

            {
                name = "Hide & Sneak",
                type = "CustomFunc",
                active_cond = function(self)
                    return mq.TLO.Me.Invis() and mq.TLO.Me.Sneaking()
                end,
                cond = function(self)
                    return Config:GetSetting('DoHideSneak')
                end,
                custom_func = function(_)
                    if Config:GetSetting('ChaseOn') then
                        if mq.TLO.Me.Sneaking() then
                            Core.DoCmd("/doability sneak")
                        end
                    else
                        if mq.TLO.Me.AbilityReady("hide")() then Core.DoCmd("/doability hide") end
                        if mq.TLO.Me.AbilityReady("sneak")() then Core.DoCmd("/doability sneak") end
                    end
                    return true
                end,
            },
        },
    },
    ['HelperFunctions'] = {
        PreEngage = function(target)
            local openerAbility = Core.GetResolvedActionMapItem('SneakAttack')

            Logger.log_debug("\ayPreEngage(): Testing Opener ability = %s", openerAbility or "None")

            if openerAbility and mq.TLO.Me.CombatAbilityReady(openerAbility)() and mq.TLO.Me.AbilityReady("Hide")() and Config:GetSetting("DoOpener") and mq.TLO.Me.Invis() then
                Casting.UseDisc(openerAbility, target)
                Logger.log_debug("\agPreEngage(): Using Opener ability = %s", openerAbility or "None")
            else
                Logger.log_debug("\arPreEngage(): NOT using Opener ability = %s, DoOpener = %s, Hide Ready = %s, Invis = %s", openerAbility or "None",
                    Strings.BoolToColorString(Config:GetSetting("DoOpener")), Strings.BoolToColorString(mq.TLO.Me.AbilityReady("Hide")()),
                    Strings.BoolToColorString(mq.TLO.Me.Invis()))
            end
        end,
        BurnDiscCheck = function(self)
            if mq.TLO.Me.ActiveDisc.Name() == "Counterattack Discipline" or mq.TLO.Me.PctHPs() < Config:GetSetting('EmergencyStart') then return false end
            local burnDisc = { "Frenzied", "Twisted", "Executioner", }
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
        UnwantedAggroCheck = function(self) --Self-Explanatory. Add isTanking to this if you ever make a mode for bardtanks!
            if Targeting.GetXTHaterCount() == 0 or Core.IAmMA() or mq.TLO.Group.Puller.ID() == mq.TLO.Me.ID() then return false end
            return Targeting.IHaveAggro(100)
        end,
    },
    ['DefaultConfig']   = {
        ['Mode']            = {
            DisplayName = "Mode",
            Category = "Combat",
            Tooltip = "Select the Combat Mode for this Toon",
            Type = "Custom",
            RequiresLoadoutChange = true,
            Default = 1,
            Min = 1,
            Max = 1,
            FAQ = "What do the different Modes do?",
            Answer = "Currently Rogues only have DPS mode, this may change in the future",
        },
        -- Poison
        ['PoisonName']      = {
            DisplayName = "Poison Item",
            Category = "Poison",
            Tooltip = "Click the poison you want to use here",
            Type = "ClickyItem",
            Default = "",
            FAQ = "Can I specify the poison I want to use?",
            Answer = "Yes you set your poison item by placing its name into the [PoisonName] field.\n" ..
                "You can drag and drop the poison item from your inventory into the field.",
        },
        ['PoisonClicky']    = {
            DisplayName = "Poison Clicky",
            Category = "Poison",
            Tooltip = "Click the poison summoner you want to use here",
            Type = "ClickyItem",
            Default = "",
            FAQ = "I want to use a clicky item to summon my poisons, how do I do that?",
            Answer = "You can set your poison summoner by placing its name into the [PoisonClicky] field.\n" ..
                "You can drag and drop the poison summoner item from your inventory into the field.",
        },
        ['PoisonItemCount'] = {
            DisplayName = "Poison Item Count",
            Category = "Poison",
            Tooltip = "Min number of poison before we start summoning more",
            Default = 3,
            Min = 1,
            Max = 50,
            FAQ = "I am always summoning more poison, how can I make sure to summon enough the first time?",
            Answer = "You can set the minimum number of poisons you want to have before summoning more by setting the [PoisonItemCount] field.",
        },
        -- Abilities
        ['DoHideSneak']     = {
            DisplayName = "Do Hide/Sneak Click",
            Category = "Abilities",
            Index = 1,
            Tooltip = "Use Hide/Sneak during Downtime",
            Default = true,
            FAQ = "How can I make sure to always be sneaking / hiding for maximum DPS?",
            Answer = "Enable [DoHideSneak] if you want to use Hide/Sneak during Downtime.\n" ..
                "This will keep you ready to ambush or backstab at a moments notice.",
        },
        ['DoOpener']        = {
            DisplayName = "Use Openers",
            Category = "Abilities",
            Index = 2,
            Tooltip = "Use Sneak Attack line to start combat (e.g, Daggerslash).",
            Default = true,
            FAQ = "Why would I not want to use Openers?",
            Answer = "Enable [DoOpener] if you want to use the opener ability.",
        },
        ['DoAEDamage']      = {
            DisplayName = "Do AE Damage",
            Category = "Abilities",
            Index = 3,
            Tooltip = "**WILL BREAK MEZ** Use AE damage Discs and AA. **WILL BREAK MEZ**",
            Default = false,
            FAQ = "Why am I using AE damage when there are mezzed mobs around?",
            Answer = "It is not currently possible to properly determine Mez status without direct Targeting. If you are mezzing, consider turning this option off.",
        },
        ['AETargetCnt']     = {
            DisplayName = "AE Target Count",
            Category = "Abilities",
            Index = 4,
            Tooltip = "Minimum number of valid targets before using AE Disciplines or AA.",
            Default = 2,
            Min = 1,
            Max = 10,
            FAQ = "Why am I using AE abilities on only a couple of targets?",
            Answer =
            "You can adjust the AE Target Count to control when you will use actions with AE damage attached.",
        },
        ['MaxAETargetCnt']  = {
            DisplayName = "Max AE Targets",
            Category = "Damage Spells",
            Index = 5,
            Tooltip =
            "Maximum number of valid targets before using AE Spells, Disciplines or AA.\nUseful for setting up AE Mez at a higher threshold on another character in case you are overwhelmed.",
            Default = 5,
            Min = 2,
            Max = 30,
            FAQ = "How do I take advantage of the Max AE Targets setting?",
            Answer =
            "By limiting your max AE targets, you can set an AE Mez count that is slightly higher, to allow for the possiblity of mezzing if you are being overwhelmed.",
        },
        ['SafeAEDamage']    = {
            DisplayName = "AE Proximity Check",
            Category = "Abilities",
            Index = 6,
            Tooltip = "Check to ensure there aren't neutral mobs in range we could aggro if AE damage is used. May result in non-use due to false positives.",
            Default = false,
            FAQ = "Can you better explain the AE Proximity Check?",
            Answer = "If the option is enabled, the script will use various checks to determine if a non-hostile or not-aggroed NPC is present and avoid use of the AE action.\n" ..
                "Unfortunately, the script currently does not discern whether an NPC is (un)attackable, so at times this may lead to the action not being used when it is safe to do so.\n" ..
                "PLEASE NOTE THAT THIS OPTION HAS NOTHING TO DO WITH MEZ!",
        },
        ['EmergencyStart']  = {
            DisplayName = "Emergency HP%",
            Category = "Abilities",
            Index = 7,
            Tooltip = "Your HP % before we begin to use emergency mitigation abilities.",
            Default = 50,
            Min = 1,
            Max = 100,
            ConfigType = "Advanced",
            FAQ = "How do I use my Emergency Mitigation Abilities?",
            Answer = "Make sure you have [EmergencyStart] set to the HP % before we begin to use emergency mitigation abilities.",
        },
        ['DoVetAA']         = {
            DisplayName = "Use Vet AA",
            Category = "Abilities",
            Index = 8,
            Tooltip = "Use Veteran AA's in emergencies or during Burn. (See FAQ)",
            Default = true,
            FAQ = "What Vet AA's does MNK use?",
            Answer = "If Use Vet AA is enabled, Intensity of the Resolute will be used on burns and Armor of Experience will be used in emergencies.",
        },
        --Equipment
        ['UseEpic']         = {
            DisplayName = "Epic Use:",
            Category = "Equipment",
            Index = 1,
            Tooltip = "Use Epic 1-Never 2-Burns 3-Always",
            Type = "Combo",
            ComboOptions = { 'Never', 'Burns Only', 'All Combat', },
            Default = 3,
            Min = 1,
            Max = 3,
            ConfigType = "Advanced",
            FAQ = "Why is my BRD using Epic on these trash mobs?",
            Answer = "By default, we use the Epic in any combat, as saving it for burns ends up being a DPS loss over a long frame of time.\n" ..
                "This can be adjusted in the Utility/Items/Misc tab.",
        },
        ['DoChestClick']    = {
            DisplayName = "Do Chest Click",
            Category = "Equipment",
            Index = 2,
            Tooltip = "Click your chest item during burns.",
            Default = mq.TLO.MacroQuest.BuildName() ~= "Emu",
            ConfigType = "Advanced",
            FAQ = "What is a Chest Click?",
            Answer = "Most Chest slot items after level 75ish have a clickable effect.\n" ..
                "ROG is set to use theirs during burns, so long as the item equipped has a clicky effect.",
        },
        --Orphaned (remove when config goes default)
        ['DoEpic']          = {
            DisplayName = "Orphaned",
            Type = "Custom",
            Category = "Orphaned",
            Tooltip = "Orphaned setting from live, no longer used in this config.",
            Default = false,
            FAQ = "Why do I see orphaned settings?",
            Answer = "To avoid deletion of settings when moving between configs, our beta or experimental configs keep placeholders for live settings\n" ..
                "These tabs or settings will be removed if and when the config is made the default.",
        },
    },
}

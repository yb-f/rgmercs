local mq           = require('mq')
local Config       = require('utils.config')
local Logger       = require("utils.logger")
local Core         = require("utils.core")
local Modules      = require("utils.modules")
local Targeting    = require("utils.targeting")
local Casting      = require("utils.casting")

local _ClassConfig = {
    _version            = "1.0 - Emu",
    _author             = "Derple, Grimmier, Algar, Lisie",
    ['ModeChecks']      = {
        CanMez     = function() return true end,
        CanCharm   = function() return true end,
        IsCharming = function() return Config:GetSetting('CharmOn') end,
        IsMezzing  = function() return true end,
    },
    ['Modes']           = {
        'Default',
    },
    ['ItemSets']        = {
        ['Epic'] = {
            "Staff of Eternal Eloquence",
            "Oculus of Persuasion",
        },
    },
    ['AbilitySets']     = {
        -- Buffs
        ['HasteBuff'] = {
            "Hastening of Salik",
            "Vallon's Quickening",
            "Speed of the Brood",
            "Speed of Novak",
            "Speed of Salik",
            "Speed of Vallon",
            "Visions of Grandeur",
            "Wondrous Rapidity",
            "Aanya's Quickening",
            "Swift Like the Wind",
            "Celerity",
            "Augmentation",
            "Alacrity",
            "Quickness",
        },
        ['ManaRegen'] = {
            "Voice of Clairvoyance",
            "Voice of Quellious",
            "Tranquility",
            -- [] = ["Gift of Brilliance", -- Removed because the Map Defaults to it Instead of Koadics
            "Koadic's Endless Intellect",
            "Gift of Pure Thought",
            "Clairvoyance",
            "Gift of Insight",
            "Clarity II",
            "Clarity",
            "Breeze",
        },
        ['NdtBuff'] = {
            "Night's Dark Terror",
            "Boon of the Garou",
        },
        ['SelfHPBuff'] = {
            "Mystic Shield",
            "Shield of Maelin",
            "Shield of the Arcane",
            "Shield of the Magi",
            "Arch Shielding",
            "Greater Shielding",
            "Major Shielding",
            "Shielding",
            "Lesser Shielding",
            "Minor Shielding",
        },
        ['SelfRune1'] = {
            "Ethereal Rune",
            "Arcane Rune",
        },
        ['SingleRune'] = {
            "Rune of Salik",
            "Rune of Zebuxoruk",
            "Rune V",
            "Rune IV",
            "Rune III",
            "Rune II",
            "Rune I",
        },
        ['GroupRune'] = {
            "Rune of Rikkukin",
            "Rune of the Scale",
        },
        ['AggroBuff'] = {
            "Horrifying Visage",
            "Haunting Visage",
        },
        ['SingleSpellShield'] = {
            "Wall of Alendar",
            "Bulwark of Alendar",
            "Protection of Alendar",
            "Guard of Alendar",
            "Ward of Alendar",
        },
        ['GroupSpellShield'] = {
            "Circle of Alendar",
        },
        -- Combat
        ['PBAEStunSpell'] = {
            "Color Snap",
            "Color Cloud",
            "Color Slant",
            "Color Skew",
            "Color Shift",
            "Color Flux",
        },
        ['SingleStunSpell1'] = {
            "Largarn's Lamentation",
            "Dyn's Dizzying Draught",
            "Whirl till you hurl",
        },
        ['JoltSpell'] = {
            "Boggle",
        },
        ['CharmSpell'] = {
            -- [] = "Ancient Voice of Muram",
            "True Name",
            "Compel",
            "Command of Druzzil",
            "Beckon",
            "Dictate",
            "Boltran's Agacerie",
            "Ordinance",
            "Allure",
            "Cajoling Whispers",
            "Beguile",
            "Charm",
        },
        ['CrippleSpell'] = {
            "Synapsis Spasm",
            "Cripple",
            "Incapacitate",
            "Listless Power",
            "Disempower",
            "Enfeeblement",
        },
        ['SlowSpell'] = {
            -- Slow - lvl88 and above this is also cripple spell Starting @ Level 88  Combines With Cripple.
            "Desolate Deeds",
            "Dreary Deeds",
            "Forlorn Deeds",
            "Shiftless Deeds",
            "Tepid Deeds",
            "Languid Pace",
        },
        ['StripBuffSpell'] = {
            "Recant Magic",
            "Pillage Enchantment",
            "Nullify Magic",
            "Strip Enchantment",
            "Cancel Magic",
            "Taper Enchantment",
        },
        ['TashSpell'] = {
            "Howl of Tashan",
            "Tashanian",
            "Tashania",
            "Tashani",
            "Tashina",
        },
        ['ManaDrainSpell'] = {
            "Torment of Scio",
            "Torment of Argli",
            "Scryer's Trespass",
            "Wandering Mind",
            "Mana Sieve",
        },
        ['DotSpell1'] = {
            ---DoT 1 -- >=LVL1
            "Arcane Noose",
            "Strangle",
            "Asphyxiate",
            "Gasping Embrace",
            "Suffocate",
            "Choke",
            "Suffocating Sphere",
            "Shallow Breath",
        },
        ['NukeSpell'] = {
            --- Nuke 1 -- >= LVL7
            "Psychosis",
            "Insanity",
            "Dementing Visions",
            "Dementia",
            "Discordant Mind",
            "Anarchy",
            "Chaos Flux",
            "Sanity Warp",
            "Chaotic Feedback",
            "Chromarcana",
            "Ancient: Neurosis",
            "Ancient: Chaos Madness",
            "Ancient: Chaotic Visions",
        },
        ['PetSpell'] = {
            "Salik's Animation",
            "Aeldorb's Animation",
            "Zumaik's Animation",
            "Kintaz's Animation",
            "Yegoreff's Animation",
            "Aanya's Animation",
            "Boltran's Animation",
            "Uleen's Animation",
            "Sagar's Animation",
            "Sisna's Animation",
            "Shalee's Animation",
            "Kilan's Animation",
            "Mircyl's Animation",
            "Juli's Animation",
            "Pendril's Animation",
        },
        ['PetBuffSpell'] = {
            ---Pet Buff Spell * Var Name: PetBuffSpell string outer
            "Speed of Vallon",
            "Visions of Grandeur",
            "Wondrous Rapidity",
            "Aanya's Quickening",
            "Swift Like the Wind",
            "Celerity",
            "Augmentation",
            "Alacrity",
            "Quickness",
            --- Speed of the Brood won't take effect properly on pets. Unless u Purchase the AA
        },
        ['MezAESpell'] = {
            ---AE Mez * Var Name:,string outer
            "Wake of Felicity",
            "Bliss of the Nihil",
            "Fascination",
            "Mesmerization",
        },
        ['MezPBAESpell'] = {
            "Circle of Dreams",
            "Word of Morell",
            "Entrancing Lights",
        },
        ['MezSpell'] = {
            "Euphoria",
            "Felicity",
            "Bliss",
            "Sleep",
            "Apathy",
            "Ancient: Eternal Rapture",
            "Rapture",
            "Glamour of Kintaz",
            "Enthrall",
            "Mesmerize",
        },
        ['BlurSpell'] = {
            "Memory Flux",
            "Reoccurring Amnesia",
            "Memory Blur",
        },
        ['AEBlurSpell'] = {
            "Blanket of Forgetfulness",
            "Mind Wipe",
        },
        ['CalmSpell'] = {
            ---Calm Spell -- >= LVL1
            "Placate",
            "Pacification",
            "Pacify",
            "Calm",
            "Soothe",
            "Lull",
        },
        ['FearSpell'] = {
            ---Fear Spell * Var Name:, string outer >= LVL3
            "Anxiety Attack",
            "Jitterskin",
            "Phobia",
            "Trepidation",
            "Invoke Fear",
            "Chase the Moon",
            "Fear",
        },
        ['RootSpell'] = {
            "Greater Fetter",
            "Fetter",
            "Paralyzing Earth",
            "Immobilize",
            "Instill",
            "Root",
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
            name = 'GroupBuff',
            timer = 60, -- only run every 60 seconds top.
            targetId = function(self)
                return Casting.GetBuffableGroupIDs()
            end,
            cond = function(self, combat_state)
                return combat_state == "Downtime" and Casting.DoBuffCheck()
            end,
        },
        { --Summon pet even when buffs are off on emu
            name = 'PetSummon',
            targetId = function(self) return { mq.TLO.Me.ID(), } end,
            cond = function(self, combat_state)
                return combat_state == "Downtime" and mq.TLO.Me.Pet.ID() == 0 and Casting.DoPetCheck() and not Core.IsCharming() and Casting.AmIBuffable()
            end,
        },
        { --Pet Buffs if we have one, timer because we don't need to constantly check this
            name = 'PetBuff',
            timer = 60,
            targetId = function(self) return mq.TLO.Me.Pet.ID() > 0 and { mq.TLO.Me.Pet.ID(), } or {} end,
            cond = function(self, combat_state)
                return combat_state == "Downtime" and mq.TLO.Me.Pet.ID() > 0 and Casting.DoPetCheck()
            end,
        },
        { --Slow and Tash separated so we use both before we start DPS
            name = 'Tash',
            state = 1,
            steps = 1,
            load_cond = function() return Config:GetSetting('DoTash') end,
            targetId = function(self) return mq.TLO.Target.ID() == Config.Globals.AutoTargetID and { Config.Globals.AutoTargetID, } or {} end,
            cond = function(self, combat_state, targetId)
                return combat_state == "Combat" and Casting.DebuffConCheck() and not Casting.IAmFeigning() and
                    (Casting.HaveManaToDebuff() or Targeting.IsNamed(mq.TLO.Spawn(targetId)))
            end,
        },
        { --Slow and Tash separated so we use both before we start DPS
            name = 'CripSlow',
            state = 1,
            steps = 1,
            load_cond = function() return Config:GetSetting('DoSlow') or Config:GetSetting('DoCripple') end,
            targetId = function(self) return mq.TLO.Target.ID() == Config.Globals.AutoTargetID and { Config.Globals.AutoTargetID, } or {} end,
            cond = function(self, combat_state, targetId)
                return combat_state == "Combat" and Casting.DebuffConCheck() and not Casting.IAmFeigning() and
                    (Casting.HaveManaToDebuff() or Targeting.IsNamed(mq.TLO.Spawn(targetId)))
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
        { --AA Stuns, Runes, etc, moved from previous home in DPS
            name = 'CombatSupport',
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
            load_cond = function() return Core.IsModeActive("Default") end,
            targetId = function(self) return mq.TLO.Target.ID() == Config.Globals.AutoTargetID and { Config.Globals.AutoTargetID, } or {} end,
            cond = function(self, combat_state)
                return combat_state == "Combat" and not Casting.IAmFeigning()
            end,
        },
    },
    ['HelperFunctions'] = { --used to autoinventory our azure crystal after summon
        -- Space for rent
    },
    ['Rotations']       = {
        ['Downtime'] = {
            {
                name = "SelfRune1",
                type = "Spell",
                active_cond = function(self, spell) return Casting.BuffActiveByID(spell.ID()) end,
                cond = function(self, spell)
                    if not Config:GetSetting("DoSelfRune") or Casting.CanUseAA('Eldritch Rune') then return false end
                    return Casting.SelfBuffCheck(spell)
                end,
            },
            {
                name = "SelfHPBuff",
                type = "Spell",
                active_cond = function(self, spell) return Casting.BuffActiveByID(spell.ID()) end,
                cond = function(self, spell) return Casting.SelfBuffCheck(spell) end,
            },
            {
                name = "Eldritch Rune",
                type = "AA",
                active_cond = function(self, aaName) return Casting.BuffActiveByName(aaName) end,
                cond = function(self, aaName)
                    if not Config:GetSetting('DoSelfRune') then return false end
                    return Casting.SelfBuffAACheck(aaName)
                end,
            },
            {
                name = "Gather Mana",
                type = "AA",
                active_cond = function(self, aaName) return Casting.AAReady(aaName) end,
                cond = function(self, aaName) return mq.TLO.Me.PctMana() < 60 and Casting.AAReady(aaName) end,
            },
        },
        ['GroupBuff'] = {
            {
                name = "ManaRegen",
                type = "Spell",
                active_cond = function(self, spell) return mq.TLO.Me.FindBuff("id " .. tostring(spell.ID()))() ~= nil end,
                cond = function(self, spell, target)
                    if not Config.Constants.RGCasters:contains(target.Class.ShortName()) then return false end
                    return Casting.GroupBuffCheck(spell, target)
                end,
            },
            {
                name = "HasteBuff",
                type = "Spell",
                active_cond = function(self, spell) return mq.TLO.Me.FindBuff("id " .. tostring(spell.ID()))() ~= nil end,
                cond = function(self, spell, target)
                    return Config.Constants.RGMelee:contains(target.Class.ShortName()) and Casting.GroupBuffCheck(spell, target)
                end,
            },
            {
                name = "GroupSpellShield",
                type = "Spell",
                active_cond = function(self, spell) return mq.TLO.Me.FindBuff("id " .. tostring(spell.ID()))() ~= nil end,
                cond = function(self, spell, target)
                    return Casting.GroupBuffCheck(spell, target) and Casting.ReagentCheck(spell)
                end,
            },
            {
                name = "NdtBuff",
                type = "Spell",
                active_cond = function(self, spell) return mq.TLO.Me.FindBuff("id " .. tostring(spell.ID()))() ~= nil end,
                cond = function(self, spell, target)
                    --NDT will not be cast or memorized if it isn't already on the bar due to a very long refresh time
                    if not Config:GetSetting('DoNDTBuff') or not Casting.GemReady(spell) then return false end
                    --Single target versions of the spell will only be used on Melee, group versions will be cast if they are missing from any groupmember
                    if (spell and spell() and ((spell.TargetType() or ""):lower() ~= "group v2"))
                        and not Config.Constants.RGMelee:contains(target.Class.ShortName()) then
                        return false
                    end
                    return Casting.GroupBuffCheck(spell, target)
                end,
            },
            {
                name = "GroupRune",
                type = "Spell",
                active_cond = function(self, spell) return mq.TLO.Me.FindBuff("id " .. tostring(spell.ID()))() ~= nil end,
                cond = function(self, spell, target)
                    if Config:GetSetting('RuneChoice') ~= 2 then return false end
                    return Casting.GroupBuffCheck(spell, target) and Casting.ReagentCheck(spell)
                end,
            },
            {
                name = "SingleRune",
                type = "Spell",
                active_cond = function(self, spell) return mq.TLO.Me.FindBuff("id " .. tostring(spell.ID()))() ~= nil end,
                cond = function(self, spell, target)
                    if Config:GetSetting('RuneChoice') ~= 1 then return false end
                    if Config:GetSetting('RuneTargets') == 1 then return false end
                    if Config:GetSetting('RuneTargets') == 1 and Config:GetSetting('DoSelfRune') then return false end
                    local short_name = target.Class.ShortName()
                    if Config:GetSetting('RuneTargets') == 3 and
                        (short_name == 'CLR' or short_name == 'DRU' or short_name == 'SHM' or
                            target.ID() == Core:GetGroupMainAssistID()) then
                        return false
                    end
                    if Config:GetSetting('RuneTargets') == 4 and target.ID() ~= Core:GetMainAssistId() then return false end
                    return Casting.GroupBuffCheck(spell, target) and Casting.ReagentCheck(spell)
                end,
            },
            {
                name = "AggroBuff",
                type = "Spell",
                active_cond = function(self, spell) return mq.TLO.Group.MainAssist.FindBuff("id" .. tostring(spell.ID()))() ~= nil end,
                cond = function(self, spell, target)
                    -- Could alternatively use `not Config.Constants.RGTank:contains(target.Class.ShortName())`
                    -- But I prefer it going ony to the MA.
                    if Config:GetSetting('DoAggroBuff') == false or target.ID() ~= Core:GetMainAssistId() then return false end
                    return Casting.GroupBuffCheck(spell, target)
                end,
            }
        },
        ['PetSummon'] = {
            {
                name = "PetSpell",
                type = "Spell",
                active_cond = function(self, _) return mq.TLO.Me.Pet.ID() > 0 end,
                cond = function(self, spell) return Casting.ReagentCheck(spell) end,
            },
        },
        ['PetBuff'] = {
            {
                name = "PetBuffSpell",
                type = "Spell",
                active_cond = function(self, spell) return mq.TLO.Me.PetBuff(spell.ID()).ID() end,
                cond = function(self, spell) return Casting.SelfBuffPetCheck(spell) end,
            },
        },
        ['CombatSupport'] = {
            {
                name = "Doppelganger",
                type = "AA",
                cond = function(self, aaName)
                    return Targeting.IHaveAggro(100) and mq.TLO.Me.PctHPs() <= 60 and Casting.AAReady(aaName)
                end,

            },
        },
        ['Tash'] = {
            {
                name = "TashSpell",
                type = "Spell",
                cond = function(self, spell, target)
                    return Config:GetSetting('DoTash') and Casting.DetSpellCheck(spell) and not mq.TLO.Target.Tashed()
                        and Casting.TargetedSpellReady(spell, target.ID())
                end,
            },
        },
        ['CripSlow'] = {
            {
                name = "SlowSpell",
                type = "Spell",
                cond = function(self, spell, target)
                    if not Config:GetSetting('DoSlow') then return false end
                    return Casting.DetSpellCheck(spell) and (spell.RankName.SlowPct() or 0) > (Targeting.GetTargetSlowedPct()) and
                        Casting.TargetedSpellReady(spell, target.ID())
                end,
            },
            {
                name = "CrippleSpell",
                type = "Spell",
                cond = function(self, spell, target)
                    if not Config:GetSetting('DoCripple') then return false end
                    return Casting.DetSpellCheck(spell) and Casting.TargetedSpellReady(spell, target.ID())
                end,
            },
            {
                name = "StripBuffSpell",
                type = "Spell",
                cond = function(self, spell, target)
                    if not Config:GetSetting('DoStripBuff') then return false end
                    return mq.TLO.Target.Beneficial() and Casting.TargetedSpellReady(spell, target.ID())
                end,
            },
        },
        ['DPS'] = {
            {
                name = "DotSpell1",
                type = "Spell",
                cond = function(self, spell, target)
                    if not Config:GetSetting('DoDot') then return false end
                    return Casting.DotSpellCheck(spell) and (Casting.DotHaveManaToNuke() or Casting.BurnCheck()) and Casting.TargetedSpellReady(spell, target.ID())
                end,
            },
            {
                name = "NukeSpell",
                type = "Spell",
                cond = function(self, spell, target)
                    return (Casting.HaveManaToNuke() or Casting.BurnCheck()) and Casting.TargetedSpellReady(spell, target.ID())
                end,
            },
            {
                name = "ManaDrainSpell",
                type = "Spell",
                cond = function(self, spell, target)
                    if not Config:GetSetting('DoManaDrain') then return false end
                    return (mq.TLO.Target.CurrentMana() or 0) > 10 and (Casting.HaveManaToNuke() or Casting.BurnCheck()) and Casting.TargetedSpellReady(spell, target.ID())
                end,
            },
        },
        ['Burn'] = {
            {
                name = mq.TLO.Me.Inventory("Chest").Name(),
                type = "Item",
                active_cond = function(self)
                    local item = mq.TLO.Me.Inventory("Chest")
                    return Casting.SongActive(item.Spell)
                end,
                cond = function(self)
                    local item = mq.TLO.Me.Inventory("Chest")
                    if not Config:GetSetting('DoChestClick') or not item or not item() then return false end
                    return not Casting.SongActive(item.Spell) and Casting.SpellStacksOnMe(item.Spell) and item.TimerReady() == 0
                end,
            },
        },
    },
    ['Spells']          = {
        {
            gem = 1,
            spells = {
                { name = "MezSpell", },
            },
        },
        {
            gem = 2,
            spells = {
                { name = "MezAESpell", },
            },
        },
        {
            gem = 3,
            spells = {
                { name = "CharmSpell",     cond = function(self) return Config:GetSetting('CharmOn') end, },
                { name = "StripBuffSpell", cond = function(self) return Config:GetSetting('DoStripBuff') end, },
                { name = "TashSpell",      cond = function(self) return Config:GetSetting('DoTash') end },
                { name = "SlowSpell",      cond = function(self) return Config:GetSetting('DoSlow') end },
                { name = "CrippleSpell",   cond = function(self) return Config:GetSetting('DoCripple') end, },
                { name = "DotSpell1",      cond = function(self) return Config:GetSetting('DoDot') end },
                { name = "NukeSpell", },
                { name = "ManaDrainSpell", cond = function(self) return Config:GetSetting('DoManaDrain') end },
                { name = "NdtBuff",        cond = function(self) return Config:GetSetting('DoNDTBuff') end },
                { name = "JoltSpell",      cond = function(self) return Config:GetSetting('DoJolt') end },
            },
        },
        {
            gem = 4,
            spells = {
                { name = "StripBuffSpell", cond = function(self) return Config:GetSetting('DoStripBuff') end, },
                { name = "TashSpell",      cond = function(self) return Config:GetSetting('DoTash') end },
                { name = "SlowSpell",      cond = function(self) return Config:GetSetting('DoSlow') end },
                { name = "CrippleSpell",   cond = function(self) return Config:GetSetting('DoCripple') end, },
                { name = "DotSpell1",      cond = function(self) return Config:GetSetting('DoDot') end },
                { name = "NukeSpell", },
                { name = "ManaDrainSpell", cond = function(self) return Config:GetSetting('DoManaDrain') end },
                { name = "NdtBuff",        cond = function(self) return Config:GetSetting('DoNDTBuff') end },
                { name = "JoltSpell",      cond = function(self) return Config:GetSetting('DoJolt') end },
            },
        },
        {
            gem = 5,
            spells = {
                { name = "TashSpell",      cond = function(self) return Config:GetSetting('DoTash') end },
                { name = "SlowSpell",      cond = function(self) return Config:GetSetting('DoSlow') end },
                { name = "CrippleSpell",   cond = function(self) return Config:GetSetting('DoCripple') end, },
                { name = "DotSpell1",      cond = function(self) return Config:GetSetting('DoDot') end },
                { name = "NukeSpell", },
                { name = "ManaDrainSpell", cond = function(self) return Config:GetSetting('DoManaDrain') end },
                { name = "NdtBuff",        cond = function(self) return Config:GetSetting('DoNDTBuff') end },
                { name = "JoltSpell",      cond = function(self) return Config:GetSetting('DoJolt') end },
            },
        },
        {
            gem = 6,
            spells = {
                { name = "SlowSpell",      cond = function(self) return Config:GetSetting('DoSlow') end },
                { name = "CrippleSpell",   cond = function(self) return Config:GetSetting('DoCripple') end, },
                { name = "DotSpell1",      cond = function(self) return Config:GetSetting('DoDot') end },
                { name = "NukeSpell", },
                { name = "ManaDrainSpell", cond = function(self) return Config:GetSetting('DoManaDrain') end },
                { name = "NdtBuff",        cond = function(self) return Config:GetSetting('DoNDTBuff') end },
                { name = "JoltSpell",      cond = function(self) return Config:GetSetting('DoJolt') end },
            },
        },
        {
            gem = 7,
            spells = {
                { name = "CrippleSpell",   cond = function(self) return Config:GetSetting('DoCripple') end, },
                { name = "DotSpell1",      cond = function(self) return Config:GetSetting('DoDot') end },
                { name = "NukeSpell", },
                { name = "ManaDrainSpell", cond = function(self) return Config:GetSetting('DoManaDrain') end },
                { name = "NdtBuff",        cond = function(self) return Config:GetSetting('DoNDTBuff') end },
                { name = "JoltSpell",      cond = function(self) return Config:GetSetting('DoJolt') end },
            },
        },
        {
            gem = 8,
            spells = {
                { name = "DotSpell1",      cond = function(self) return Config:GetSetting('DoDot') end },
                { name = "NukeSpell", },
                { name = "ManaDrainSpell", cond = function(self) return Config:GetSetting('DoManaDrain') end },
                { name = "NdtBuff",        cond = function(self) return Config:GetSetting('DoNDTBuff') end },
                { name = "JoltSpell",      cond = function(self) return Config:GetSetting('DoJolt') end },
            },
        },
        {
            gem = 9,
            cond = function(self, gem) return mq.TLO.Me.NumGems() >= gem end,
            spells = {
                { name = "NukeSpell", },
                { name = "ManaDrainSpell", cond = function(self) return Config:GetSetting('DoManaDrain') end },
                { name = "NdtBuff",        cond = function(self) return Config:GetSetting('DoNDTBuff') end },
                { name = "JoltSpell",      cond = function(self) return Config:GetSetting('DoJolt') end },
            },
        },
    },
    ['PullAbilities']   = {
        {
            id = 'TashSpell',
            Type = "Spell",
            DisplayName = function() return Core.GetResolvedActionMapItem('TashSpell').RankName.Name() or "" end,
            AbilityName = function() return Core.GetResolvedActionMapItem('TashSpell').RankName.Name() or "" end,
            AbilityRange = 200,
            cond = function(self)
                local resolvedSpell = Core.GetResolvedActionMapItem('TashSpell')
                if not resolvedSpell then return false end
                return mq.TLO.Me.Gem(resolvedSpell.RankName.Name() or "")() ~= nil
            end,
        },
        {
            id = 'StripBuffSpell',
            Type = "Spell",
            DisplayName = function() return Core.GetResolvedActionMapItem('StripBuffSpell').RankName.Name() or "" end,
            AbilityName = function() return Core.GetResolvedActionMapItem('StripBuffSpell').RankName.Name() or "" end,
            AbilityRange = 200,
            cond = function(self)
                local resolvedSpell = Core.GetResolvedActionMapItem('StripBuffSpell')
                if not resolvedSpell then return false end
                return mq.TLO.Me.Gem(resolvedSpell.RankName.Name() or "")() ~= nil
            end,
        },
    },
    ['DefaultConfig']   = {
        ['Mode']          = {
            DisplayName = "Mode",
            Category = "Combat",
            Tooltip = "Select the Combat Mode for this PC. Default: The original RGMercs Config. ModernEra: DPS rotation and spellset aimed at modern live play (~90+)",
            Type = "Custom",
            RequiresLoadoutChange = true,
            Default = 1,
            Min = 1,
            Max = 1,
            FAQ = "What are the different Modes about?",
            Answer = "There is only one mode in the emulator Enchanter config.",
        },
        -- Debuffs
        ['AESlowCount']   = {
            DisplayName = "AE Slow Count",
            Category = "Debuffs",
            Tooltip = "Number of XT Haters before we start AE slowing",
            Index = 3,
            Min = 1,
            Default = 2,
            Max = 10,
            FAQ = "Why am I not AE slowing?",
            Answer = "The [AESlowCount] setting determines the number of XT Haters before we start AE slowing.\n" ..
                "If you are not AE slowing, you may need to adjust the [AESlowCount] setting.",
        },
        ['DoTash']        = {
            DisplayName = "Do Tash",
            Category = "Debuffs",
            Tooltip = "Cast Tash Spells",
            Index = 1,
            RequiresLoadoutChange = true,
            Default = true,
            FAQ = "Why am I not Tashing?",
            Answer = "The [DoTash] setting determines whether or not your PC will cast Tash Spells.\n" ..
                "If you are not Tashing, you may need to Enable the [DoTash] setting.",
        },
        ['DoSlow']        = {
            DisplayName = "Cast Slow",
            Category = "Debuffs",
            Tooltip = "Enable casting Slow spells.",
            Index = 2,
            RequiresLoadoutChange = true,
            Default = true,
            FAQ = "Why am I not Slowing?",
            Answer = "The [DoSlow] setting determines whether or not your PC will cast Slow spells.\n" ..
                "If you are not Slowing, you may need to Enable the [DoSlow] setting.",
        },
        ['DoCripple']     = {
            DisplayName = "Cast Cripple",
            Category = "Debuffs",
            Tooltip = "Enable casting Cripple spells.",
            Index = 5,
            RequiresLoadoutChange = true,
            Default = true,
            FAQ = "Why am I not Crippling?",
            Answer = "The [DoCripple] setting determines whether or not your PC will cast Cripple spells.\n" ..
                "If you are not Crippling, you may need to Enable the [DoCripple] setting.\n" ..
                "Please note that eventually, Cripple and Slow lines are merged together in the Helix line.",
        },
        ['DoStripBuff']   = {
            DisplayName = "Do Strip Buffs",
            Category = "Debuffs",
            Tooltip = "Enable removing beneficial enemy effects.",
            Index = 4,
            Default = true,
            FAQ = "Why am I not stripping buffs?",
            Answer = "The [DoStripBuff] setting determines whether or not your PC will remove beneficial enemy effects.\n" ..
                "If you are not stripping buffs, you may need to Enable the [DoStripBuff] setting.",
        },
        -- Combat
        ['DoDot']         = {
            DisplayName = "Cast DOTs",
            Category = "Combat",
            Tooltip = "Enable casting Damage Over Time spells. (Dots always used for ModernEra Mode)",
            Default = true,
            FAQ = "I turned Cast DOTS off, why am I still using them?",
            Answer = "The Modern Era mode does not respect this setting, as DoTs are integral to the DPS rotation.",
        },
        ['DoChestClick']  = {
            DisplayName = "Do Chest Click",
            Category = "Combat",
            Tooltip = "Click your equipped chest item during burns.",
            Default = mq.TLO.MacroQuest.BuildName() ~= "Emu",
            FAQ = "Why am I not clicking my chest item?",
            Answer = "Most Chest slot items after level 75ish have a clickable effect.\n" ..
                "ENC is set to use theirs during burns, so long as the item equipped has a clicky effect.",
        },
        ['DoManaDrain']   = {
            DisplayName = "Cast Mana Drain",
            Category = "Combat",
            Tooltip = "Enable casting use Mana Drains.",
            RequiresLoadoutChange = false,
            Default = false,
            FAQ = "Why am I not using mana drains?",
            Answer = "You will need to enable the Cast Mana Drain option in the enchanter class config.",
        },
        ['DoJolt']        = {
            DisplayName = "Use Jolt Spell",
            Category = "Combat",
            Tooltip = "Enable use of Jolt spells.",
            default = false,
            FAQ = "Why am I not using my Jolt spell?",
            Answer = "Enable Use Jolt Spell in your class configuration under combat.",
        },
        -- Buffs
        ['DoNDTBuff']     = {
            DisplayName = "Cast NDT",
            Category = "Buffs",
            Tooltip = "Enable casting use Melee Proc Buff (Night's Dark Terror Line).",
            RequiresLoadoutChange = true,
            Default = true,
            FAQ = "Why am I not using NDT?",
            Answer = "The [DoNDTBuff] setting determines whether or not your PC will cast the Night's Dark Terror Line.\n" ..
                "Please note that the single target versions are only set to be used on melee.",
        },
        ['DoSelfRune']    = {
            DisplayName = "Use Self Rune",
            Category = "Buffs",
            Tooltip = "Enable use of self-only rune.",
            Default = false,
            FAQ = "Why aren't I using my self rune?",
            Answer = "Enable Use Self Rune to use them."
        },
        ['RuneTargets']   = {
            DisplayName = "Rune Targets:",
            Category = "Buffs",
            Tooltip = "What group members for single target runes.",
            Type = "Combo",
            ComboOptions = { 'None', 'All', 'Tank + Healer', 'Tank' },
            Default = 1,
            Min = 1,
            Max = 4,
            FAQ = "How can I choose who I cast my single target rune spells on?",
            Answer = "You can set the valid targets for your single target rune spells by using the Rune Targets dropdown.",
        },
        ['RuneChoice']    = {
            DisplayName = "Rune Selection:",
            Category = "Buffs",
            Index = 1,
            Tooltip = "Select which line of Rune spells you prefer to use.",
            Type = "Combo",
            ComboOptions = { 'Single Target', 'Group', 'Off', },
            Default = 2,
            Min = 1,
            Max = 3,
            RequiresLoadoutChange = true,
            FAQ = "Why am I putting an aggro-reducing buff on the tank?",
            Answer =
            "You can configure your rune selections to use a single-target hate increasing rune on the tank, while using group (hate reducing) or single target runes on others.",
        },
        ['DoAggroBuff']   = {
            DisplayName = "Use Aggro Buff",
            Category = "Buffs",
            Tooltip = "Use aggro buff line on tank.",
            Default = false,
            FAQ = "Why am I not using an aggro buff on my tank?",
            Answer = "You can enable the use of aggro buffs by enabling them in the class configuration Buffs tab.",
        },
        ['DoSpellShield'] = {
            DisplayName = "Cast Spellshield",
            Category = "Buffs",
            Tooltip = "Use single/group Spellshield line.",
            Default = false,
            FAQ = "Why am I not using spellshields?",
            Answer = "You can enable the use of spellshields by enabling them in the class configuration Buffs tab.",
        },
    },
}

return _ClassConfig

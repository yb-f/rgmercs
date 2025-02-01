--[[
lootnscoot.lua v1.7 - aquietone, grimmier

This is a port of the RedGuides copy of ninjadvloot.inc with some updates as well.
I may have glossed over some of the events or edge cases so it may have some issues
around things like:
- lore items
- full inventory
- not full inventory but no slot large enough for an item
- ...
Or those things might just work, I just haven't tested it very much using lvl 1 toons
on project lazarus.

Settings are saved per character in config\LootNScoot_[ServerName]_[CharName].ini
if you would like to use a global settings file. you can Change this inside the above file to point at your global file instead.
example= SettingsFile=D:\MQ_EMU\Config/LootNScoot_GlobalSettings.ini

This script can be used in two ways:
    1. Included within a larger script using require, for example if you have some KissAssist-like lua script:
        To loot mobs, call lootutils.lootMobs():

            local mq = require 'mq'
            local lootutils = require 'lootnscoot'
            while true do
                lootutils.lootMobs()
                mq.delay(1000)
            end

        lootUtils.lootMobs() will run until it has attempted to loot all corpses within the defined radius.

        To sell to a vendor, call lootutils.sellStuff():

            local mq = require 'mq'
            local lootutils = require 'lootnscoot'
            local doSell = false
            local function binds(...)
                local args = {...}
                if args[1] == 'sell' then doSell = true end
            end
            mq.bind('/myscript', binds)
            while true do
                lootutils.lootMobs()
                if doSell then lootutils.sellStuff() doSell = false end
                mq.delay(1000)
            end

        lootutils.sellStuff() will run until it has attempted to sell all items marked as sell to the targeted vendor.

        Note that in the above example, loot.sellStuff() isn't being called directly from the bind callback.
        Selling may take some time and includes delays, so it is best to be called from your main loop.

        Optionally, configure settings using:
            Set the radius within which corpses should be looted (radius from you, not a camp location)
                lootutils.CorpseRadius = number
            Set whether loot.ini should be updated based off of sell item events to add manually sold items.
                lootutils.AddNewSales = boolean
            Several other settings can be found in the "loot" table defined in the code.

    2. Run as a standalone script:
        /lua run lootnscoot standalone
            Will keep the script running, checking for corpses once per second.
        /lua run lootnscoot once
            Will run one iteration of loot.lootMobs().
        /lua run lootnscoot sell
            Will run one iteration of loot.sellStuff().
        /lua run lootnscoot cleanup
            Will run one iteration of loot.cleanupBags().

The script will setup a bind for "/lootutils":
    /lootutils <action> "${Cursor.Name}"
        Set the loot rule for an item. "action" may be one of:
            - Keep
            - Bank
            - Sell
            - Tribute
            - Ignore
            - Destroy
            - Quest|#

    /lootutils reload
        Reload the contents of Loot.ini
    /lootutils bank
        Put all items from inventory marked as Bank into the bank
    /lootutils tsbank
        Mark all tradeskill items in inventory as Bank

If running in standalone mode, the bind also supports:
    /lootutils sellstuff
        Runs lootutils.sellStuff() one time
    /lootutils tributestuff
        Runs lootutils.tributeStuff() one time
    /lootutils cleanup
        Runs lootutils.cleanupBags() one time

The following events are used:
    - eventCantLoot - #*#may not loot this corpse#*#
        Add corpse to list of corpses to avoid for a few minutes if someone is already looting it.
    - eventSell - #*#You receive#*# for the #1#(s)#*#
        Set item rule to Sell when an item is manually sold to a vendor
    - eventInventoryFull - #*#Your inventory appears full!#*#
        Stop attempting to loot once inventory is full. Note that currently this never gets set back to false
        even if inventory space is made available.
    - eventNovalue - #*#give you absolutely nothing for the #1#.#*#
        Warn and move on when attempting to sell an item which the merchant will not buy.

This does not include the buy routines from ninjadvloot. It does include the sell routines
but lootly sell routines seem more robust than the code that was in ninjadvloot.inc.
The forage event handling also does not handle fishing events like ninjadvloot did.
There is also no flag for combat looting. It will only loot if no mobs are within the radius.

]]

local mq                             = require 'mq'
local PackageMan                     = require('mq.PackageMan')
local SQLite3                        = PackageMan.Require('lsqlite3')
local Icons                          = require('mq.ICONS')
--local success, Logger = pcall(require, 'lib.Write')
local Logger                         = require("utils.logger")
-- if not success then
--     printf('\arERROR: Write.lua could not be loaded\n%s\ax', Logger)
--     return
-- end
local eqServer                       = string.gsub(mq.TLO.EverQuest.Server(), ' ', '_')
-- Check for looted module, if found use that. else fall back on our copy, which may be outdated.

local Config                         = require('utils.config')
local Core                           = require("utils.core")
local Comms                          = require("utils.comms")
local Targeting                      = require("utils.targeting")
local Files                          = require("utils.files")
local Modules                        = require("utils.modules")

local eqServer                       = string.gsub(mq.TLO.EverQuest.Server(), ' ', '_')
-- Check for looted module, if found use that. else fall back on our copy, which may be outdated.

local version                        = 5
local Config                         = require('utils.config')
local Core                           = require("utils.core")
local Comms                          = require("utils.comms")
local Targeting                      = require("utils.targeting")
local Files                          = require("utils.files")
local Modules                        = require("utils.modules")
local SettingsFile                   = mq.configDir .. '/LootNScoot_' .. eqServer .. '_' .. Config.Globals.CurLoadedChar .. '.ini'
local LootFile                       = mq.configDir .. '/Loot.ini'
local imported                       = true
local lootDBUpdateFile               = mq.configDir .. '/DB_Updated_' .. eqServer .. '.lua'
local zoneID, newItemsCount          = 0, 0
local lootedCorpses                  = {}
local tmpRules, tmpClasses, tmpLinks = {}, {}, {}

-- Public default settings, also read in from Loot.ini [Settings] section
local loot                           = {
    Settings = {
        Version = '"' .. tostring(version) .. '"',
        LootFile = mq.configDir .. '/Loot.ini',
        SettingsFile = mq.configDir .. '/LootNScoot_' .. eqServer .. '_' .. Config.Globals.CurLoadedChar .. '.ini',
        GlobalLootOn = true,                       -- Enable Global Loot Items. not implimented yet
        CombatLooting = false,                     -- Enables looting during combat. Not recommended on the MT
        CorpseRadius = 100,                        -- Radius to activly loot corpses
        MobsTooClose = 40,                         -- Don't loot if mobs are in this range.
        SaveBagSlots = 3,                          -- Number of bag slots you would like to keep empty at all times. Stop looting if we hit this number
        TributeKeep = false,                       -- Keep items flagged Tribute
        MinTributeValue = 100,                     -- Minimun Tribute points to keep item if TributeKeep is enabled.
        MinSellPrice = -1,                         -- Minimum Sell price to keep item. -1 = any
        StackPlatValue = 0,                        -- Minimum sell value for full stack
        StackableOnly = false,                     -- Only loot stackable items
        AlwaysEval = false,                        -- Re-Evaluate all *Non Quest* items. useful to update loot.ini after changing min sell values.
        BankTradeskills = true,                    -- Toggle flagging Tradeskill items as Bank or not.
        DoLoot = true,                             -- Enable auto looting in standalone mode
        LootForage = true,                         -- Enable Looting of Foraged Items
        LootNoDrop = false,                        -- Enable Looting of NoDrop items.
        LootNoDropNew = false,                     -- Enable looting of new NoDrop items.
        LootQuest = false,                         -- Enable Looting of Items Marked 'Quest', requires LootNoDrop on to loot NoDrop quest items
        DoDestroy = false,                         -- Enable Destroy functionality. Otherwise 'Destroy' acts as 'Ignore'
        AlwaysDestroy = false,                     -- Always Destroy items to clean corpese Will Destroy Non-Quest items marked 'Ignore' items REQUIRES DoDestroy set to true
        QuestKeep = 10,                            -- Default number to keep if item not set using Quest|# format.
        LootChannel = "dgt",                       -- Channel we report loot to.
        GroupChannel = "dgae",                     -- Channel we use for Group Commands
        ReportLoot = true,                         -- Report loot items to group or not.
        SpamLootInfo = false,                      -- Echo Spam for Looting
        LootForageSpam = false,                    -- Echo spam for Foraged Items
        AddNewSales = true,                        -- Adds 'Sell' Flag to items automatically if you sell them while the script is running.
        AddNewTributes = true,                     -- Adds 'Tribute' Flag to items automatically if you Tribute them while the script is running.
        GMLSelect = true,                          -- not implimented yet
        ExcludeBag1 = "Extraplanar Trade Satchel", -- Name of Bag to ignore items in when selling
        NoDropDefaults = "Quest|Keep|Ignore",      -- not implimented yet
        LootLagDelay = 0,                          -- not implimented yet
        CorpseRotTime = "440s",                    -- not implimented yet
        HideNames = false,                         -- Hides names and uses class shortname in looted window
        LookupLinks = false,                       -- Enables Looking up Links for items not on that character. *recommend only running on one charcter that is monitoring.
        RecordData = false,                        -- Enables recording data to report later.
        AutoTag = false,                           -- Automatically tag items to sell if they meet the MinSellPrice
        AutoRestock = false,                       -- Automatically restock items from the BuyItems list when selling
        LootMyCorpse = false,                      -- Loot your own corpse if its nearby (Does not check for REZ)
        LootAugments = false,                      -- Loot Augments
        CheckCorpseOnce = false,                   -- Check Corpse once and move on. Ignore the next time it is in range if enabled
        AutoShowNewItem = false,                   -- Automatically show new items in the looted window
    },
}
loot.MyClass                         = Config.Globals.CurLoadedClass:lower()
-- SQL information
local ItemsDB                        = string.format('%s/LootRules_%s.db', mq.configDir, eqServer)
local newItem                        = nil
loot.guiLoot                         = require('lib.lootnscoot.loot_hist')
if loot.guiLoot ~= nil then
    loot.UseActors = true
    loot.guiLoot.GetSettings(loot.HideNames, loot.LookupLinks, loot.RecordData, true, loot.UseActors, 'lootnscoot')
end
local Actors                            = require('actors')
local iconAnimation                     = mq.FindTextureAnimation('A_DragItem')
-- Internal settings
local lootData, cantLootList = {}, {}
local areFull = false
local cantLootID = 0
-- Constants
local spawnSearch = '%s radius %d zradius 50'
-- If you want destroy to actually loot and destroy items, change DoDestroy=false to DoDestroy=true in the Settings Ini.
-- Otherwise, destroy behaves the same as ignore.
local shouldLootActions                 = { CanUse = false, Ask = false, Keep = true, Bank = true, Sell = true, Destroy = false, Ignore = false, Tribute = false, }
local validActions                      = {
    canuse = "CanUse",
    ask = "Ask",
    keep = 'Keep',
    bank = 'Bank',
    sell = 'Sell',
    ignore = 'Ignore',
    destroy = 'Destroy',
    quest = 'Quest',
    tribute =
    'Tribute',
}
local saveOptionTypes                   = { string = 1, number = 1, boolean = 1, }
local NEVER_SELL                        = { ['Diamond Coin'] = true, ['Celestial Crest'] = true, ['Gold Coin'] = true, ['Taelosian Symbols'] = true, ['Planar Symbols'] = true, }
local tmpCmd                            = loot.GroupChannel or 'dgae'
loot.showNewItem                        = false

-- local Actors                            = require('actors')
loot.BuyItemsTable                      = {}
loot.ALLITEMS                           = {}
loot.GlobalItemsRules                   = {}
loot.NormalItemsRules                   = {}
loot.NormalItemsClasses                 = {}
loot.GlobalItemsClasses                 = {}
loot.NormalItemsLink                    = {}
loot.GlobalItemsLink                    = {}
loot.NewItems                           = {}
loot.TempSettings                       = {}
loot.PersonalItemsRules                 = {}
loot.PersonalItemsClasses               = {}
loot.PersonalItemsLink                  = {}
loot.NewItemDecisions                   = nil
loot.ItemNames                          = {}
loot.NewItemsCount                      = 0
loot.TempItemClasses                    = "All"
loot.itemSelectionPending               = false -- Flag to indicate an item selection is in progress
loot.pendingItemData                    = nil   -- Temporary storage for item data
loot.doImportInventory                  = false
loot.TempModClass                       = false
loot.ShowUI                             = false
loot.Terminate                          = true
loot.Boxes                              = {}
loot.PersonalTableName                  = string.format("%s_Rules", MyName)
-- FORWARD DECLARATIONS

-- local loot.eventForage, loot.eventSell, loot.eventCantLoot, loot.eventTribute, loot.eventNoSlot

-- UTILITIES
--- Returns a table containing all the data from the INI file.
--@param fileName The name of the INI file to parse. [string]
--@return The table containing all data from the INI file. [table]
function loot.load(fileName, sec)
    if sec == nil then sec = "items" end
    -- this came from Knightly's LIP.lua
    assert(type(fileName) == 'string', 'Parameter "fileName" must be a string.');
    local file = assert(io.open(fileName, 'r'), 'Error loading file : ' .. fileName);
    local data = {};
    local section;
    local count = 0
    for line in file:lines() do
        local tempSection = line:match('^%[([^%[%]]+)%]$');
        if (tempSection) then
            -- print(tempSection)
            section = tonumber(tempSection) and tonumber(tempSection) or tempSection;
            -- data[section] = data[section] or {};
            count = 0
        end
        local param, value = line:match("^([%w|_'.%s-]+)=%s-(.+)$");

        if (param and value ~= nil) then
            if (tonumber(value)) then
                value = tonumber(value);
            elseif (value == 'true') then
                value = true;
            elseif (value == 'false') then
                value = false;
            end
            if (tonumber(param)) then
                param = tonumber(param);
            end
            if string.find(tostring(param), 'Spawn') then
                count = count + 1
                param = string.format("Spawn%d", count)
            end
            if sec == "items" and param ~= nil then
                if section ~= "Settings" and section ~= "GlobalItems" then
                    data[param] = value;
                end
            elseif section == sec and param ~= nil then
                data[param] = value;
            end
        end
    end
    file:close();
    Logger.log_debug("Loot::load()")
    return data;
end

function loot.writeSettings()
    for option, value in pairs(loot.Settings) do
        local valueType = type(value)
        if saveOptionTypes[valueType] then
            Core.DoCmd('/ini "%s" "%s" "%s" "%s"', SettingsFile, 'Settings', option, value)
            loot.Settings[option] = value
        end
    end
    for option, value in pairs(loot.BuyItems) do
        local valueType = type(value)
        if saveOptionTypes[valueType] then
            Core.DoCmd('/ini "%s" "%s" "%s" "%s"', SettingsFile, 'BuyItems', option, value)
            loot.BuyItems[option] = value
        end
    end
    for option, value in pairs(loot.GlobalItems) do
        local valueType = type(value)
        if saveOptionTypes[valueType] then
            Core.DoCmd('/ini "%s" "%s" "%s" "%s"', LootFile, 'GlobalItems', option, value)
            loot.modifyItem(option, value, 'Global_Rules')
            loot.GlobalItems[option] = value
        end
    end
    Logger.log_debug("Loot::writeSettings()")
    Modules:ExecModule("Loot", "ModifyLootSettings")
end

function loot.split(input, sep)
    if sep == nil then
        sep = "|"
    end
    local t = {}
    for str in string.gmatch(input, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

function loot.UpdateDB()
    loot.NormalItems = loot.load(LootFile, 'items')
    loot.GlobalItems = loot.load(LootFile, 'GlobalItems')

    local db = SQLite3.open(ItemsDB)
    local batchSize = 500
    local count = 0

    db:exec("BEGIN TRANSACTION") -- Start transaction for NormalItems

    -- Insert NormalItems in batches
    for k, v in pairs(loot.NormalItems) do
        local stmt, err = db:prepare("INSERT INTO Normal_Rules (item_name, item_rule) VALUES (?, ?)")
        stmt:bind_values(k, v)
        stmt:step()
        stmt:finalize()

        count = count + 1
        if count % batchSize == 0 then
            Logger.log_debug("Inserted " .. count .. " NormalItems so far...")
            db:exec("COMMIT")
            db:exec("BEGIN TRANSACTION")
        end
    end

    db:exec("COMMIT")
    Logger.log_debug("Inserted all " .. count .. " NormalItems.")

function loot.LoadRuleDB()
    -- Create the database and its table if it doesn't exist
    -- local db = SQLite3.open(RulesDB)
    -- db:exec([[
    --     CREATE TABLE IF NOT EXISTS Global_Rules (
    --     "item_id" INTEGER PRIMARY KEY NOT NULL UNIQUE,
    --     "item_name" TEXT NOT NULL,
    --     "item_rule" TEXT NOT NULL,
    --     "item_rule_classes" TEXT,
    --     "item_link" TEXT
    --     );
    --     CREATE TABLE IF NOT EXISTS Normal_Rules (
    --     "item_id" INTEGER PRIMARY KEY NOT NULL UNIQUE,
    --     "item_name" TEXT NOT NULL,
    --     "item_rule" TEXT NOT NULL,
    --     "item_rule_classes" TEXT,
    --     "item_link" TEXT
    --     );
    --     ]])
    -- db:close()
    local db = SQLite3.open(RulesDB)
    local charTableName = string.format("%s_Rules", MyName)

    local createTablesQuery = string.format([[
        CREATE TABLE IF NOT EXISTS Global_Rules (
            "item_id" INTEGER PRIMARY KEY NOT NULL UNIQUE,
            "item_name" TEXT NOT NULL,
            "item_rule" TEXT NOT NULL,
            "item_rule_classes" TEXT,
            "item_link" TEXT
        );
        CREATE TABLE IF NOT EXISTS Normal_Rules (
            "item_id" INTEGER PRIMARY KEY NOT NULL UNIQUE,
            "item_name" TEXT NOT NULL,
            "item_rule" TEXT NOT NULL,
            "item_rule_classes" TEXT,
            "item_link" TEXT
        );
        CREATE TABLE IF NOT EXISTS %s (
            "item_id" INTEGER PRIMARY KEY NOT NULL UNIQUE,
            "item_name" TEXT NOT NULL,
            "item_rule" TEXT NOT NULL,
            "item_rule_classes" TEXT,
            "item_link" TEXT
        );
    ]], charTableName)

    db:exec(createTablesQuery)
    db:close()

    db:exec("BEGIN TRANSACTION")

    -- Insert GlobalItems in batches
    for k, v in pairs(loot.GlobalItems) do
        local stmt, err = db:prepare("INSERT INTO Global_Rules (item_name, item_rule) VALUES (?, ?)")
        stmt:bind_values(k, v)
        stmt:step()
        stmt:finalize()

        count = count + 1
        if count % batchSize == 0 then
            Logger.log_debug("Inserted " .. count .. " GlobalItems so far...")
            db:exec("COMMIT")
            db:exec("BEGIN TRANSACTION")
        end
    end
    stmt:finalize()
    stmt = db:prepare("SELECT * FROM Normal_Rules")
    for row in stmt:nrows() do
        loot.NormalItemsRules[row.item_id]   = row.item_rule
        loot.NormalItemsClasses[row.item_id] = row.item_rule_classes ~= nil and row.item_rule_classes or 'All'
        loot.NormalItemsLink[row.item_id]    = row.item_link ~= nil and row.item_link or 'NULL'
        loot.ItemNames[row.item_id]          = row.item_name
    end
    stmt:finalize()
    local persQuery = string.format("SELECT * FROM %s", charTableName)
    stmt = db:prepare(persQuery)
    for row in stmt:nrows() do
        loot.PersonalItemsRules[row.item_id]   = row.item_rule
        loot.PersonalItemsClasses[row.item_id] = row.item_rule_classes ~= nil and row.item_rule_classes or 'All'
        loot.PersonalItemsLink[row.item_id]    = row.item_link ~= nil and row.item_link or 'NULL'
        loot.ItemNames[row.item_id]            = row.item_name
    end
    stmt:finalize()
    db:close()
end

---comment
---@param firstRun boolean|nil if passed true then we will load the DB's again
---@return boolean
function loot.loadSettings(firstRun)
    if firstRun == nil then firstRun = false end
    if firstRun then
        loot.NormalItemsRules     = {}
        loot.GlobalItemsRules     = {}
        loot.NormalItemsClasses   = {}
        loot.GlobalItemsClasses   = {}
        loot.NormalItemsLink      = {}
        loot.GlobalItemsLink      = {}
        loot.BuyItemsTable        = {}
        loot.PersonalItemsRules   = {}
        loot.PersonalItemsClasses = {}
        loot.PersonalItemsLink    = {}
        loot.ItemNames            = {}
        loot.ALLITEMS             = {}
    end
    local needDBUpdate = false
    local needSave = false
    local tmpSettings = loot.load(SettingsFile, 'Settings')

    -- check if the DB structure needs updating
    if not Files.file_exists(lootDBUpdateFile) then
        needDBUpdate = true
        tmpSettings.Version = version
        needSave = true
    else
        local tmp = dofile(lootDBUpdateFile)
        if tmp.version < version then
            needDBUpdate = true
            tmpSettings.Version = version
            needSave = true
        end
    end

    -- SQL setup
    if not Files.file_exists(ItemsDB) then
        Logger.log_warn("\ayLoot Rules Database \arNOT found\ax, \atCreating it now\ax. Please run \at/rgl lootimport\ax to Import your \atloot.ini \axfile.")
        Logger.log_warn("\arOnly run this one One Character\ax. use \at/rgl lootreload\ax to update the data on the other characters.")
    else
        Logger.log_info("Loot Rules Database found, loading it now.")
    end

    if not needDBUpdate then
        -- Create the database and its table if it doesn't exist
        local db = SQLite3.open(ItemsDB)
        db:exec([[
                CREATE TABLE IF NOT EXISTS Global_Rules (
                    "item_name" TEXT PRIMARY KEY NOT NULL UNIQUE,
                    "item_rule" TEXT NOT NULL,
                    "item_classes" TEXT
                );
                    CREATE TABLE IF NOT EXISTS Normal_Rules (
                    "item_name" TEXT PRIMARY KEY NOT NULL UNIQUE,
                    "item_rule" TEXT NOT NULL,
                    "item_classes" TEXT,
                    "item_link" TEXT,
                    "item_id" INTEGER
                );
            ]])
        db:close()
    else -- DB needs to be updated
        local db = SQLite3.open(ItemsDB)
        db:exec([[
                CREATE TABLE IF NOT EXISTS my_table_copy(
                    "item_name" TEXT PRIMARY KEY NOT NULL UNIQUE,
                    "item_rule" TEXT NOT NULL,
                    "item_classes" TEXT,
                    "item_link" TEXT,
                    "item_id" INTEGER
                );
                INSERT INTO my_table_copy (item_name,item_rule,item_classes)
                    SELECT item_name, item_rule, item_classes FROM Normal_Rules;
                DROP TABLE Normal_Rules;
                ALTER TABLE my_table_copy RENAME TO Normal_Rules;

                CREATE TABLE IF NOT EXISTS my_table_copy(
                    "item_name" TEXT PRIMARY KEY NOT NULL UNIQUE,
                    "item_rule" TEXT NOT NULL,
                    "item_classes" TEXT
                );
                INSERT INTO my_table_copy (item_name,item_rule,item_classes)
                    SELECT item_name, item_rule, item_classes FROM Global_Rules;
                DROP TABLE Global_Rules;
                ALTER TABLE my_table_copy RENAME TO Global_Rules;
                );
            ]])
        db:close()
        mq.pickle(lootDBUpdateFile, { version = 5, })
        Logger.log_info("DB Version less than %s, Updating it now.", version)
        needDBUpdate = false
    end

    -- process the loaded data
    local db = SQLite3.open(ItemsDB)
    local stmt = db:prepare("SELECT * FROM Global_Rules")
    for row in stmt:nrows() do
        loot.GlobalItems[row.item_name] = row.item_rule
        loot.GlobalItemsClasses[row.item_name] = row.item_classes ~= nil and row.item_classes or 'All'
    end
    stmt:finalize()

    return rowsFetched
end

function loot.addMyInventoryToDB()
    local counter = 0
    local counterBank = 0
    Logger.log_info("\atImporting Inventory\ax into the DB")

    for i = 1, 22 do
        if i < 11 then
            -- Items in Bags and Main Inventory
            local bagSlot       = mq.TLO.InvSlot('pack' .. i).Item
            local containerSize = bagSlot.Container()
            if bagSlot() ~= nil then
                loot.addToItemDB(bagSlot)
                counter = counter + 1
                if containerSize then
                    mq.delay(5) -- Delay to prevent spamming the DB
                    for j = 1, containerSize do
                        local item = bagSlot.Item(j)
                        if item and item.ID() then
                            loot.addToItemDB(item)
                            counter = counter + 1
                            mq.delay(10)
                        end
                    end
                end
            end
        else
            -- Worn Items
            local invItem = mq.TLO.Me.Inventory(i)
            if invItem() ~= nil then
                loot.addToItemDB(invItem)
                counter = counter + 1
                mq.delay(10) -- Delay to prevent spamming the DB
            end
        end
    end
    -- Banked Items
    for i = 1, 24 do
        local bankSlot = mq.TLO.Me.Bank(i)
        local bankBagSize = bankSlot.Container()
        if bankSlot() ~= nil then
            loot.addToItemDB(bankSlot)
            counterBank = counterBank + 1
            if bankBagSize then
                mq.delay(5) -- Delay to prevent spamming the DB
                for j = 1, bankBagSize do
                    local item = bankSlot.Item(j)
                    if item and item.ID() then
                        loot.addToItemDB(item)
                        counterBank = counterBank + 1
                        mq.delay(10)
                    end
                end
            end
        end
    end
    Logger.log_info("\at%s \axImported \ag%d\ax items from \aoInventory\ax, and \ag%d\ax items from the \ayBank\ax, into the DB", MyName, counter, counterBank)
    loot.report(string.format("%s Imported %d items from Inventory, and %d items from the Bank, into the DB", MyName, counter, counterBank))
    loot.lootActor:send({ mailbox = 'lootnscoot', },
        { who = MyName, Server = eqServer, action = 'ItemsDB_UPDATE', })
end

function loot.addToItemDB(item)
    if item == nil then
        if mq.TLO.Cursor() ~= nil then
            item = mq.TLO.Cursor
        else
            Logger.log_error("Item is \arnil.")
            return
        end
    end
    if loot.ItemNames[item.ID()] ~= nil then return end

    -- insert the item into the database

    local db = SQLite3.open(lootDB)
    if not db then
        Logger.log_error("\arFailed to open\ax loot database.")
        return
    end

    local sql  = [[
        INSERT INTO Items (
        item_id, name, nodrop, notrade, tradeskill, quest, lore, augment,
        stackable, sell_value, tribute_value, stack_size, clickable, augtype,
        strength, dexterity, agility, stamina, intelligence, wisdom,
        charisma, mana, hp, ac, regen_hp, regen_mana, haste, link, weight, classes, class_list,
        svfire, svcold, svdisease, svpoison, svcorruption, svmagic, spelldamage, spellshield, races, race_list, collectible,
        attack, damage, weightreduction, item_size, icon, strikethrough, heroicagi, heroiccha, heroicdex, heroicint,
        heroicsta, heroicstr, heroicsvcold, heroicsvcorruption, heroicsvdisease, heroicsvfire, heroicsvmagic, heroicsvpoison,
        heroicwis
        )
        VALUES (
        ?,?,?,?,?,?,?,?,?,?,
        ?,?,?,?,?,?,?,?,?,?,
        ?,?,?,?,?,?,?,?,?,?,
        ?,?,?,?,?,?,?,?,?,?,
        ?,?,?,?,?,?,?,?,?,?,
        ?,?,?,?,?,?,?,?,?,?,
        ?
        )
        ON CONFLICT(item_id) DO UPDATE SET
        name                                    = excluded.name,
        nodrop                                    = excluded.nodrop,
        notrade                                    = excluded.notrade,
        tradeskill                                    = excluded.tradeskill,
        quest                                    = excluded.quest,
        lore                                    = excluded.lore,
        augment                                    = excluded.augment,
        stackable                                    = excluded.stackable,
        sell_value                                    = excluded.sell_value,
        tribute_value                                    = excluded.tribute_value,
        stack_size                                    = excluded.stack_size,
        clickable                                    = excluded.clickable,
        augtype                                    = excluded.augtype,
        strength                                    = excluded.strength,
        dexterity                                    = excluded.dexterity,
        agility                                    = excluded.agility,
        stamina                                    = excluded.stamina,
        intelligence                                    = excluded.intelligence,
        wisdom                                    = excluded.wisdom,
        charisma                                    = excluded.charisma,
        mana                                    = excluded.mana,
        hp                                    = excluded.hp,
        ac                                    = excluded.ac,
        regen_hp                                    = excluded.regen_hp,
        regen_mana                                    = excluded.regen_mana,
        haste                                    = excluded.haste,
        link                                    = excluded.link,
        weight                                    = excluded.weight,
        item_size                                    = excluded.item_size,
        classes                                    = excluded.classes,
        class_list                                    = excluded.class_list,
        svfire                                    = excluded.svfire,
        svcold                                    = excluded.svcold,
        svdisease                                    = excluded.svdisease,
        svpoison                                    = excluded.svpoison,
        svcorruption                                    = excluded.svcorruption,
        svmagic                                    = excluded.svmagic,
        spelldamage                                    = excluded.spelldamage,
        spellshield                                    = excluded.spellshield,
        races                                    = excluded.races,
        race_list                               = excluded.race_list,
        collectible                                    = excluded.collectible,
        attack                                    = excluded.attack,
        damage                                    = excluded.damage,
        weightreduction                                    = excluded.weightreduction,
        strikethrough                                    = excluded.strikethrough,
        heroicagi                                    = excluded.heroicagi,
        heroiccha                                    = excluded.heroiccha,
        heroicdex                                    = excluded.heroicdex,
        heroicint                                    = excluded.heroicint,
        heroicsta                                    = excluded.heroicsta,
        heroicstr                                    = excluded.heroicstr,
        heroicsvcold                                    = excluded.heroicsvcold,
        heroicsvcorruption                                    = excluded.heroicsvcorruption,
        heroicsvdisease                                    = excluded.heroicsvdisease,
        heroicsvfire                                    = excluded.heroicsvfire,
        heroicsvmagic                                    = excluded.heroicsvmagic,
        heroicsvpoison                                    = excluded.heroicsvpoison,
        heroicwis                                    = excluded.heroicwis
        ]]

    local stmt = db:prepare(sql)
    if not stmt then
        Logger.log_error("\arFailed to prepare \ax[\ayINSERT\ax] \aoSQL\ax statement: \at%s", db:errmsg())
        db:close()
        return
    end

    local success, errmsg = pcall(function()
        stmt:bind_values(
            item.ID(),
            item.Name(),
            item.NoDrop() and 1 or 0,
            item.NoTrade() and 1 or 0,
            item.Tradeskills() and 1 or 0,
            item.Quest() and 1 or 0,
            item.Lore() and 1 or 0,
            item.AugType() > 0 and 1 or 0,
            item.Stackable() and 1 or 0,
            item.Value() or 0,
            item.Tribute() or 0,
            item.StackSize() or 0,
            item.Clicky() or nil,
            item.AugType() or 0,
            item.STR() or 0,
            item.DEX() or 0,
            item.AGI() or 0,
            item.STA() or 0,
            item.INT() or 0,
            item.WIS() or 0,
            item.CHA() or 0,
            item.Mana() or 0,
            item.HP() or 0,
            item.AC() or 0,
            item.HPRegen() or 0,
            item.ManaRegen() or 0,
            item.Haste() or 0,
            item.ItemLink('CLICKABLE')() or nil,
            (item.Weight() or 0) * 10,
            item.Classes() or 0,
            loot.retrieveClassList(item),
            item.svFire() or 0,
            item.svCold() or 0,
            item.svDisease() or 0,
            item.svPoison() or 0,
            item.svCorruption() or 0,
            item.svMagic() or 0,
            item.SpellDamage() or 0,
            item.SpellShield() or 0,
            item.Races() or 0,
            loot.retrieveRaceList(item),
            item.Collectible() and 1 or 0,
            item.Attack() or 0,
            item.Damage() or 0,
            item.WeightReduction() or 0,
            item.Size() or 0,
            item.Icon() or 0,
            item.StrikeThrough() or 0,
            item.HeroicAGI() or 0,
            item.HeroicCHA() or 0,
            item.HeroicDEX() or 0,
            item.HeroicINT() or 0,
            item.HeroicSTA() or 0,
            item.HeroicSTR() or 0,
            item.HeroicSvCold() or 0,
            item.HeroicSvCorruption() or 0,
            item.HeroicSvDisease() or 0,
            item.HeroicSvFire() or 0,
            item.HeroicSvMagic() or 0,
            item.HeroicSvPoison() or 0,
            item.HeroicWIS() or 0
        )
        stmt:step()
    end)

    if not success then
        Logger.log_error("Error executing SQL statement: %s", errmsg)
    end

    stmt:finalize()
    db:close()

    -- process settings file

    local itemID                             = item.ID()
    loot.ItemNames[itemID]                   = item.Name()
    loot.ALLITEMS[itemID]                    = {}
    loot.ALLITEMS[itemID].Name               = item.Name()
    loot.ALLITEMS[itemID].NoDrop             = item.NoDrop()
    loot.ALLITEMS[itemID].NoTrade            = item.NoTrade()
    loot.ALLITEMS[itemID].Tradeskills        = item.Tradeskills()
    loot.ALLITEMS[itemID].Quest              = item.Quest()
    loot.ALLITEMS[itemID].Lore               = item.Lore()
    loot.ALLITEMS[itemID].Augment            = item.AugType() > 0
    loot.ALLITEMS[itemID].Stackable          = item.Stackable()
    loot.ALLITEMS[itemID].Value              = loot.valueToCoins(item.Value())
    loot.ALLITEMS[itemID].Tribute            = item.Tribute()
    loot.ALLITEMS[itemID].StackSize          = item.StackSize()
    loot.ALLITEMS[itemID].Clicky             = item.Clicky()
    loot.ALLITEMS[itemID].AugType            = item.AugType()
    loot.ALLITEMS[itemID].STR                = item.STR()
    loot.ALLITEMS[itemID].DEX                = item.DEX()
    loot.ALLITEMS[itemID].AGI                = item.AGI()
    loot.ALLITEMS[itemID].STA                = item.STA()
    loot.ALLITEMS[itemID].INT                = item.INT()
    loot.ALLITEMS[itemID].WIS                = item.WIS()
    loot.ALLITEMS[itemID].CHA                = item.CHA()
    loot.ALLITEMS[itemID].Mana               = item.Mana()
    loot.ALLITEMS[itemID].HP                 = item.HP()
    loot.ALLITEMS[itemID].AC                 = item.AC()
    loot.ALLITEMS[itemID].HPRegen            = item.HPRegen()
    loot.ALLITEMS[itemID].ManaRegen          = item.ManaRegen()
    loot.ALLITEMS[itemID].Haste              = item.Haste()
    loot.ALLITEMS[itemID].Classes            = item.Classes()
    loot.ALLITEMS[itemID].ClassList          = loot.retrieveClassList(item)
    loot.ALLITEMS[itemID].svFire             = item.svFire()
    loot.ALLITEMS[itemID].svCold             = item.svCold()
    loot.ALLITEMS[itemID].svDisease          = item.svDisease()
    loot.ALLITEMS[itemID].svPoison           = item.svPoison()
    loot.ALLITEMS[itemID].svCorruption       = item.svCorruption()
    loot.ALLITEMS[itemID].svMagic            = item.svMagic()
    loot.ALLITEMS[itemID].SpellDamage        = item.SpellDamage()
    loot.ALLITEMS[itemID].SpellShield        = item.SpellShield()
    loot.ALLITEMS[itemID].Damage             = item.Damage()
    loot.ALLITEMS[itemID].Weight             = item.Weight()
    loot.ALLITEMS[itemID].Size               = item.Size()
    loot.ALLITEMS[itemID].WeightReduction    = item.WeightReduction()
    loot.ALLITEMS[itemID].Races              = item.Races() or 0
    loot.ALLITEMS[itemID].RaceList           = loot.retrieveRaceList(item)
    loot.ALLITEMS[itemID].Icon               = item.Icon()
    loot.ALLITEMS[itemID].Attack             = item.Attack()
    loot.ALLITEMS[itemID].Collectible        = item.Collectible()
    loot.ALLITEMS[itemID].StrikeThrough      = item.StrikeThrough()
    loot.ALLITEMS[itemID].HeroicAGI          = item.HeroicAGI()
    loot.ALLITEMS[itemID].HeroicCHA          = item.HeroicCHA()
    loot.ALLITEMS[itemID].HeroicDEX          = item.HeroicDEX()
    loot.ALLITEMS[itemID].HeroicINT          = item.HeroicINT()
    loot.ALLITEMS[itemID].HeroicSTA          = item.HeroicSTA()
    loot.ALLITEMS[itemID].HeroicSTR          = item.HeroicSTR()
    loot.ALLITEMS[itemID].HeroicSvCold       = item.HeroicSvCold()
    loot.ALLITEMS[itemID].HeroicSvCorruption = item.HeroicSvCorruption()
    loot.ALLITEMS[itemID].HeroicSvDisease    = item.HeroicSvDisease()
    loot.ALLITEMS[itemID].HeroicSvFire       = item.HeroicSvFire()
    loot.ALLITEMS[itemID].HeroicSvMagic      = item.HeroicSvMagic()
    loot.ALLITEMS[itemID].HeroicSvPoison     = item.HeroicSvPoison()
    loot.ALLITEMS[itemID].HeroicWIS          = item.HeroicWIS()
    loot.ALLITEMS[itemID].Link               = item.ItemLink('CLICKABLE')()
end

function loot.valueToCoins(sellVal)
    local platVal   = math.floor(sellVal / 1000)
    local goldVal   = math.floor((sellVal % 1000) / 100)
    local silverVal = math.floor((sellVal % 100) / 10)
    local copperVal = sellVal % 10
    return string.format("%s pp %s gp %s sp %s cp", platVal, goldVal, silverVal, copperVal)
end

function loot.checkSpells(item_name)
    if string.find(item_name, "Spell: ") then
        return true
    end

    tmpCmd = loot.Settings.GroupChannel or 'dgae'
    if tmpCmd == string.find(tmpCmd, 'dg') then
        tmpCmd = '/' .. tmpCmd
    elseif tmpCmd == string.find(tmpCmd, 'bc') then
        tmpCmd = '/' .. tmpCmd .. ' /'
    end
    shouldLootActions.Destroy = loot.Settings.DoDestroy
    shouldLootActions.Tribute = loot.Settings.TributeKeep
    loot.BuyItems = loot.load(SettingsFile, 'BuyItems')

    -- Retrieve the itemID from corpseItem
    local itemID = corpseItem.ID()
    if not itemID then
        Logger.log_warn("\arFailed to retrieve \axitemID\ar for corpseItem:\ax %s", tostring(corpseItem.Name()))
        return
    end
    if loot.NewItems[itemID] ~= nil then return end
    local isNoDrop        = corpseItem.NoDrop()
    loot.TempItemClasses  = loot.retrieveClassList(corpseItem)
    loot.TempItemRaces    = loot.retrieveRaceList(corpseItem)
    -- Add the new item to the loot.NewItems table
    loot.NewItems[itemID] = {
        Name       = corpseItem.Name(),
        ItemID     = itemID, -- Include itemID for display and handling
        Link       = itemLink,
        Rule       = isNoDrop and "CanUse" or itemRule,
        NoDrop     = isNoDrop,
        Icon       = corpseItem.Icon(),
        Lore       = corpseItem.Lore(),
        Tradeskill = corpseItem.Tradeskills(),
        Aug        = corpseItem.AugType() > 0,
        Stackable  = corpseItem.Stackable(),
        MaxStacks  = corpseItem.StackSize() or 0,
        SellPrice  = loot.valueToCoins(corpseItem.Value()),
        Classes    = loot.TempItemClasses,
        Races      = loot.TempItemRaces,
        CorpseID   = corpseID,
    }

    -- Increment the count of new items
    loot.NewItemsCount    = loot.NewItemsCount + 1

    if loot.Settings.AutoShowNewItem then
        loot.showNewItem = true
    end

    -- Notify the loot actor of the new item
    Logger.log_info("\agNew Loot\ay Item Detected! \ax[\at %s\ax ]\ao Sending actors", corpseItem.Name())
    loot.lootActor:send(
        { mailbox = 'lootnscoot', },
        {
            who        = MyName,
            action     = 'new',
            item       = corpseItem.Name(),
            itemID     = itemID,
            Server     = eqServer,
            rule       = isNoDrop and "CanUse" or itemRule,
            classes    = loot.retrieveClassList(corpseItem),
            races      = loot.retrieveRaceList(corpseItem),
            link       = itemLink,
            lore       = corpseItem.Lore(),
            icon       = corpseItem.Icon(),
            aug        = corpseItem.AugType() > 0 and true or false,
            noDrop     = isNoDrop,
            tradeskill = corpseItem.Tradeskills(),
            stackable  = corpseItem.Stackable(),
            maxStacks  = corpseItem.StackSize() or 0,
            sellPrice  = loot.valueToCoins(corpseItem.Value()),
            corpse     = corpseID,
        }
    )

    Logger.log_info("\agAdding \ayNEW\ax item: \at%s \ay(\axID: \at%s\at) \axwith rule: \ag%s", corpseItem.Name(), itemID, itemRule)
end

function loot.checkCursor()
    local currentItem = nil
    while mq.TLO.Cursor() do
        -- can't do anything if there's nowhere to put the item, either due to no free inventory space
        -- or no slot of appropriate size
        if mq.TLO.Me.FreeInventory() == 0 or mq.TLO.Cursor() == currentItem then
            if loot.Settings.SpamLootInfo then Logger.log_debug('Inventory full, item stuck on cursor') end
            Core.DoCmd('/autoinv')
            return
        end
        currentItem = mq.TLO.Cursor()
        Core.DoCmd('/autoinv')
        mq.delay(100)
    end
end

function loot.navToID(spawnID)
    Core.DoCmd('/nav id %d log=off', spawnID)
    mq.delay(50)
    if mq.TLO.Navigation.Active() then
        local startTime = os.time()
        while mq.TLO.Navigation.Active() do
            mq.delay(100)
            if os.difftime(os.time(), startTime) > 5 then
                break
            end
        end
    end
end

---comment: Takes in an item to modify the rules for, You can add, delete, or modify the rules for an item.
---Upon completeion it will notify the loot actor to update the loot settings, for any other character that is using the loot actor.
---@param itemID integer The ID for the item we are modifying
---@param action string The action to perform (add, delete, modify)
---@param tableName string The table to modify (Normal_Rules, Global_Rules)
---@param classes string The classes to apply the rule to
---@param link string|nil The item link if available for the item
function loot.modifyItemRule(itemID, action, tableName, classes, link)
    if not itemID or not tableName or not action then
        Logger.log_warn("Invalid parameters for modifyItemRule. itemID: %s, tableName: %s, action: %s",
            tostring(itemID), tostring(tableName), tostring(action))
        return
    end

    local section = tableName == "Normal_Rules" and "NormalItems" or "GlobalItems"
    section = tableName == loot.PersonalTableName and 'PersonalItems' or section
    -- Validate RulesDB
    if not RulesDB or type(RulesDB) ~= "string" then
        Logger.log_warn("Invalid RulesDB path: %s", tostring(RulesDB))
        return
    end

    -- Retrieve the item name from loot.ALLITEMS
    local itemName = loot.ALLITEMS[itemID] and loot.ALLITEMS[itemID].Name
    if not itemName then
        Logger.log_warn("Item ID \at%s\ax \arNOT\ax found in \ayloot.ALLITEMS", tostring(itemID))
        return
    end

    -- Set default values
    if link == nil then
        link = loot.ALLITEMS[itemID].Link or 'NULL'
    end
    classes  = classes or 'All'

    -- Open the database
    local db = SQLite3.open(RulesDB)
    if not db then
        Logger.log_warn("Failed to open database.")
        return
    end
    if action == 'delete' then
        -- DELETE operation
        Logger.log_info("\aoloot.modifyItemRule\ax \arDeleting rule\ax for item \at%s\ax in table \at%s", itemName, tableName)
        sql = string.format("DELETE FROM %s WHERE item_id = ?", tableName)
        stmt = db:prepare(sql)

        if stmt then
            stmt:bind_values(itemID)
        end
    else
        -- UPSERT operation
        -- if tableName == "Normal_Rules" then
        sql  = string.format([[
                INSERT INTO %s
                (item_id, item_name, item_rule, item_rule_classes, item_link)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(item_id) DO UPDATE SET
                item_name                                    = excluded.item_name,
                item_rule                                    = excluded.item_rule,
                item_rule_classes                                    = excluded.item_rule_classes,
                item_link                                    = excluded.item_link
                ]], tableName)
        stmt = db:prepare(sql)
        if stmt then
            stmt:bind_values(itemID, itemName, action, classes, link)
        end
        -- elseif tableName == "Global_Rules" then
        --     sql  = [[
        --         INSERT INTO Global_Rules
        --         (item_id, item_name, item_rule, item_rule_classes, item_link)
        --         VALUES (?, ?, ?, ?, ?)
        --         ON CONFLICT(item_id) DO UPDATE SET
        --         item_name                                    = excluded.item_name,
        --         item_rule                                    = excluded.item_rule,
        --         item_rule_classes                                    = excluded.item_rule_classes,
        --         item_link                                    = excluded.item_link
        --         ]]
        --     stmt = db:prepare(sql)
        --     if stmt then
        --         stmt:bind_values(itemID, itemName, action, classes, link)
        --     end
        -- end
    end

    db:close()

    if success then
        -- Notify other actors about the rule change
        loot.lootActor:send({ mailbox = 'lootnscoot', }, {
            who     = MyName,
            Server  = eqServer,
            action  = action ~= 'delete' and 'addrule' or 'deleteitem',
            item    = itemName,
            itemID  = itemID,
            rule    = action,
            section = section,
            link    = link,
            classes = classes,
        })
    end
end

function loot.addRule(itemName, section, rule, classes, link)
    if link == nil then link = 'NULL' end
    if not lootData[section] then
        lootData[section] = {}
    end

    -- Retrieve the item name from loot.ALLITEMS
    local itemName = loot.ALLITEMS[itemID] and loot.ALLITEMS[itemID].Name or nil
    if not itemName then
        Logger.log_warn("Item ID \at%s\ax \arNOT\ax found in \ayloot.ALLITEMS", tostring(itemID))
        return false
    end

    -- Set default values for optional parameters
    classes                            = classes or 'All'
    link                               = link or 'NULL'

    -- Log the action
    -- Logger.log_info("\agAdding\ax rule for item \at%s\ax\ao (\ayID\ax:\ag %s\ax\ao)\ax in [section] \at%s \axwith [rule] \at%s\ax and [classes] \at%s",
    -- itemName, itemID, section, rule, classes)

    -- Update the in-memory data structure
    loot.ItemNames[itemID]             = itemName

    loot[section .. "Rules"][itemID]   = rule
    loot[section .. "Classes"][itemID] = classes
    loot[section .. "Link"][itemID]    = link
    local tblName                      = section == 'GlobalItems' and 'Global_Rules' or 'Normal_Rules'
    if section == 'PersonalItems' then
        tblName = loot.PersonalTableName
    end
    loot.modifyItemRule(itemID, rule, tblName, classes, link)

    Core.DoCmd('/ini "%s" "%s" "%s" "%s"', LootFile, section, itemName, rule)
    Modules:ExecModule("Loot", "ModifyLootSettings")
end

function loot.actorAddRule(itemID, itemName, tableName, rule, classes, link)
    loot.ItemNames[itemID]               = itemName

    loot[tableName .. "Rules"][itemID]   = rule
    loot[tableName .. "Classes"][itemID] = classes
    loot[tableName .. "Link"][itemID]    = link
    local tblName                        = tableName == 'GlobalItems' and 'Global_Rules' or 'Normal_Rules'
    if tableName == 'PersonalItems' then
        tblName = loot.PersonalTableName
    end
    loot.modifyItemRule(itemID, rule, tblName, classes, link)


    -- if tableName == 'GlobalItems' then
    --     loot.GlobalItemsRules[itemID]   = rule
    --     loot.GlobalItemsClasses[itemID] = classes
    --     loot.GlobalItemsLink[itemID]    = link
    --     loot.modifyItemRule(itemID, rule, 'Global_Rules', classes, link)
    -- else
    --     loot.NormalItemsRules[itemID]   = rule
    --     loot.NormalItemsLink[itemID]    = link
    --     loot.NormalItemsClasses[itemID] = classes
    --     loot.modifyItemRule(itemID, rule, 'Normal_Rules', classes, link)
    -- end
end

---@param itemID any
---@param tablename any|nil
---@return string rule
---@return string classes
---@return string link
function loot.lookupLootRule(itemID, tablename)
    if not itemID then
        return 'NULL', 'All', 'NULL'
    end

    if tablename == 'Global_Rules' then
        if loot.GlobalItemsRules[itemID] ~= nil then
            return loot.GlobalItemsRules[itemID], loot.GlobalItemsClasses[itemID], loot.GlobalItemsLink[itemID]
        end
    elseif tablename == 'Normal_Rules' then
        if loot.NormalItemsRules[itemID] ~= nil then
            return loot.NormalItemsRules[itemID], loot.NormalItemsClasses[itemID], loot.NormalItemsLink[itemID]
        end
    elseif tablename == loot.PersonalTableName then
        if loot.PersonalItemsRules[itemID] ~= nil then
            return loot.PersonalItemsRules[itemID], loot.PersonalItemsClasses[itemID], loot.PersonalItemsLink[itemID]
        end
    elseif tablename == nil then
        if loot.PersonalItemsRules[itemID] ~= nil then
            return loot.PersonalItemsRules[itemID], loot.PersonalItemsClasses[itemID], loot.PersonalItemsLink[itemID]
        end
        if loot.GlobalItemsRules[itemID] ~= nil then
            return loot.GlobalItemsRules[itemID], loot.GlobalItemsClasses[itemID], loot.GlobalItemsLink[itemID]
        end
        if loot.NormalItemsRules[itemID] ~= nil then
            return loot.NormalItemsRules[itemID], loot.NormalItemsClasses[itemID], loot.NormalItemsLink[itemID]
        end
    end

    local rule = 'NULL'
    local classes = 'All'
    local link    = 'NULL'

    if tablename == nil then
        -- check global rules
        local found = false
        found, rule, classes, link = checkDB(itemID, loot.PersonalTableName)
        if not found then
            found, rule, classes, link = checkDB(itemID, 'Global_Rules')
        end
        if not found then
            found, rule, classes, link = checkDB(itemID, 'Normal_Rules')
        end

        if not found then
            rule = 'NULL'
            classes = 'All'
            link = 'NULL'
        end
    else
        _, rule, classes, link = checkDB(itemID, tablename)
    end

    -- if SQL has the item add the rules to the lua table for next time

    if rule ~= 'NULL' then
        local localTblName                      = tablename == 'Global_Rules' and 'GlobalItems' or 'NormalItems'
        localTblName                            = tablename == loot.PersonalTableName and 'PersonalItems' or localTblName

        loot[localTblName .. 'Rules'][itemID]   = rule
        loot[localTblName .. 'Classes'][itemID] = classes
        loot[localTblName .. 'Link'][itemID]    = link
        loot.ItemNames[itemID]                  = loot.ALLITEMS[itemID].Name
    end
    return rule, classes, link
end

-- moved this function up so we can report Quest Items.
local reportPrefix = '/%s \a-t[\at%s\a-t][\ax\ayLootUtils\ax\a-t]\ax '
function loot.report(message, ...)
    if loot.Settings.ReportLoot then
        local prefixWithChannel = reportPrefix:format(loot.Settings.LootChannel, mq.TLO.Time())
        Core.DoCmd(prefixWithChannel .. message, ...)
    end
end

function loot.AreBagsOpen()
    local total = {
        bags = 0,
        open = 0,
    }
    for i = 23, 32 do
        local slot = mq.TLO.Me.Inventory(i)
        if slot and slot.Container() and slot.Container() > 0 then
            total.bags = total.bags + 1
            ---@diagnostic disable-next-line: undefined-field
            if slot.Open() then
                total.open = total.open + 1
            end
        end
    end
    if total.bags == total.open then
        return true
    else
        return false
    end
end

function loot.processPendingItem()
    if not loot.pendingItemData and not loot.pendingItemData.selectedItem then
        Logger.log_warn("No item selected for processing.")
        return
    end

    -- Extract the selected item and callback
    local selectedItem = loot.pendingItemData.selectedItem
    local callback     = loot.pendingItemData.callback

    -- Call the callback with the selected item
    if callback then
        callback(selectedItem)
    else
        Logger.log_warn("No callback defined for selected item.")
    end

    -- Clear pending data after processing
    loot.pendingItemData = nil
end

function loot.resolveDuplicateItems(itemName, duplicates, callback)
    loot.itemSelectionPending = true
    loot.pendingItemData      = { callback = callback, }

    -- Render the selection UI
    ImGui.SetNextWindowSize(400, 300, ImGuiCond.FirstUseEver)
    local open = ImGui.Begin("Resolve Duplicates", true)
    if open then
        ImGui.Text("Multiple items found for: " .. itemName)
        ImGui.Separator()

        for _, item in ipairs(duplicates) do
            if ImGui.Button("Select##" .. item.ID) then
                loot.itemSelectionPending         = false
                loot.pendingItemData.selectedItem = item.ID
                ImGui.CloseCurrentPopup()
                callback(item.ID) -- Trigger the callback with the selected ID
                break
            end
            ImGui.SameLine()
            ImGui.Text(item.Link)
        end
    end
    ImGui.End()
end

function loot.getMatchingItemsByName(itemName)
    local matches = {}
    for _, item in pairs(loot.ALLITEMS) do
        if item.Name == itemName then
            table.insert(matches, item)
        end
    end
    return matches
end

function loot.getRuleIndex(rule, ruleList)
    for i, v in ipairs(ruleList) do
        if v == rule then
            return i
        end
    end
    return 1 -- Default to the first rule if not found
end

function loot.retrieveClassList(item)
    local classList = ""
    local numClasses = item.Classes()
    if numClasses < 16 then
        for i = 1, numClasses do
            classList = string.format("%s %s", classList, item.Class(i).ShortName())
        end
    else
        classList = "All"
    end
    return classList
end

function loot.retrieveRaceList(item)
    local racesShort = {
        ['Human'] = 'HUM',
        ['Barbarian'] = 'BAR',
        ['Erudite'] = 'ERU',
        ['Wood Elf'] = 'ELF',
        ['High Elf'] = 'HIE',
        ['Dark Elf'] = 'DEF',
        ['Half Elf'] = 'HEF',
        ['Dwarf'] = 'DWF',
        ['Troll'] = 'TRL',
        ['Ogre'] = 'OGR',
        ['Halfling'] = 'HFL',
        ['Gnome'] = 'GNM',
        ['Iksar'] = 'IKS',
        ['Vah Shir'] = 'VAH',
        ['Froglok'] = 'FRG',
        ['Drakkin'] = 'DRK',
    }
    local raceList = ""
    local numRaces = item.Races()
    if numRaces < 16 then
        for i = 1, numRaces do
            local raceName = racesShort[item.Race(i).Name()] or ''
            raceList = string.format("%s %s", raceList, raceName)
        end
    else
        raceList = "All"
    end
    return raceList
end

---@param itemName string Item's Name
---@param allowDuplicates boolean|nil optional just return first matched item_id
---@return integer|nil ItemID or nil if no matches found
function loot.resolveItemIDbyName(itemName, allowDuplicates)
    if allowDuplicates == nil then allowDuplicates = false end
    local matches = {}

    local foundItems = loot.GetItemFromDB(itemName, 0)

    if foundItems > 1 and not allowDuplicates then
        printf("\ayMultiple \atMatches Found for ItemName: \am%s \ax #\ag%d\ax", itemName, foundItems)
    end

    for id, item in pairs(loot.ALLITEMS or {}) do
        if item.Name:lower() == itemName:lower() then
            if allowDuplicates and item.Value ~= '0 pp 0 gp 0 sp 0 cp' and item.Value ~= nil then
                table.insert(matches,
                    { ID = id, Link = item.Link, Name = item.Name, Value = item.Value, })
            else
                table.insert(matches,
                    { ID = id, Link = item.Link, Name = item.Name, Value = item.Value, })
            end
        end
    end

    if allowDuplicates then
        return matches[1].ID
    end

    if #matches == 0 then
        return nil           -- No matches found
    elseif #matches == 1 then
        return matches[1].ID -- Single match
    else
        -- Display a selection window to the user
        loot.resolveDuplicateItems(itemName, matches, function(selectedItemID)
            loot.pendingItemData.selectedItem = selectedItemID
        end)
        return nil -- Wait for user resolution
    end
end

function loot.sendMySettings()
    local tmpTable = {}
    for k, v in pairs(loot.Settings) do
        if type(v) == 'table' then
            tmpTable[k] = {}
            for kk, vv in pairs(v) do
                tmpTable[k][kk] = vv
            end
        else
            tmpTable[k] = v
        end
    end
    loot.lootActor:send({ mailbox = 'lootnscoot', }, {
        who      = MyName,
        action   = 'sendsettings',
        settings = tmpTable,
    })
    loot.Boxes[MyName] = {}
    for k, v in pairs(loot.Settings) do
        if type(v) == 'table' then
            loot.Boxes[MyName][k] = {}
            for kk, vv in pairs(v) do
                loot.Boxes[MyName][k][kk] = vv
            end
        else
            loot.Boxes[MyName][k] = v
        end
    end
end

--- Evaluate and return the rule for an item.
---@param item MQItem Item object
---@param from string Source of the of the callback (loot, bank, etc.)
---@return string Rule The Loot Rule or decision of no Rule
---@return integer Count The number of items to keep if Quest Item
---@return boolean newRule True if Item does not exist in the Rules Tables
---@return boolean|nil cantWear True if the item is not wearable by the character
function loot.getRule(item, from)
    if item == nil then return 'NULL', 0, false end
    local itemID = item.ID() or 0
    if itemID == 0 then return 'NULL', 0, false end

    -- Initialize values
    local lootDecision                    = 'Keep'
    local tradeskill                      = item.Tradeskills()
    local sellPrice                       = (item.Value() or 0) / 1000
    local stackable                       = item.Stackable()
    local augment                         = item.AugType() or 0
    local tributeValue                    = item.Tribute()
    local stackSize                       = item.StackSize()
    local countHave                       = mq.TLO.FindItemCount(item.Name())() + mq.TLO.FindItemBankCount(item.Name())()
    local itemName                        = item.Name()
    local newRule                         = false
    local alwaysAsk                       = false

    -- Lookup existing rule in the databases
    local lootRule, lootClasses, lootLink = loot.lookupLootRule(itemID)
    Logger.log_info("Item: %s, Rule: %s, Classes: %s, Link: %s", itemName, lootRule, lootClasses, lootLink)
    if lootRule == 'NULL' and item.NoDrop() then
        lootRule = "CanUse"
        loot.addRule(itemID, 'NormalItems', lootRule, lootClasses, item.ItemLink('CLICKABLE')())
    end


    if lootRule == 'Ask' then alwaysAsk = true end

    -- -- Update link if missing and rule exists
    -- if lootRule ~= "NULL" and lootLink == "NULL" then
    --     loot.addRule(itemID, 'NormalItems', lootRule, lootClasses, item.ItemLink('CLICKABLE')())
    -- end

    -- Re-evaluate settings if AlwaysEval is enabled
    if loot.Settings.AlwaysEval then
        local oldDecision = lootData[firstLetter][itemName] -- whats on file
        local resetDecision = 'NULL'
        if string.find(oldDecision, 'Quest') or oldDecision == 'Keep' or oldDecision == 'Destroy' then resetDecision = oldDecision end
        -- If sell price changed and item doesn't meet the new value re-evalute it otherwise keep it set to sell
        if oldDecision == 'Sell' and not stackable and sellPrice >= loot.Settings.MinSellPrice then resetDecision = oldDecision end
        -- -- Do the same for stackable items.
        if (oldDecision == 'Sell' and stackable) and (sellPrice * stackSize >= loot.Settings.StackPlatValue) then resetDecision = oldDecision end
        -- if banking tradeskills settings changed re-evaluate
        if oldDecision == 'Bank' and tradeskill and loot.Settings.BankTradeskills then resetDecision = oldDecision end
        lootData[firstLetter][itemName] = resetDecision -- pass value on to next check. Items marked 'NULL' will be treated as new and evaluated properly.
    end
    if lootData[firstLetter][itemName] == 'NULL' then
        if tradeskill and loot.Settings.BankTradeskills then lootDecision = 'Bank' end
        if not stackable and sellPrice < loot.Settings.MinSellPrice then lootDecision = 'Ignore' end -- added stackable check otherwise it would stay set to Ignore when checking Stackable items in next steps.
        if not stackable and loot.Settings.StackableOnly then lootDecision = 'Ignore' end
        if (stackable and loot.Settings.StackPlatValue > 0) and (sellPrice * stackSize < loot.Settings.StackPlatValue) then lootDecision = 'Ignore' end
        -- set Tribute flag if tribute value is greater than minTributeValue and the sell price is less than min sell price or has no value
        if tributeValue >= loot.Settings.MinTributeValue and (sellPrice < loot.Settings.MinSellPrice or sellPrice == 0) then lootDecision = 'Tribute' end
        if loot.Settings.AutoTag and lootDecision == 'Keep' then                                       -- Do we want to automatically tag items 'Sell'
            if not stackable and sellPrice > loot.Settings.MinSellPrice then lootDecision = 'Sell' end -- added stackable check otherwise it would stay set to Ignore when checking Stackable items in next steps.
            if (stackable and loot.Settings.StackPlatValue > 0) and (sellPrice * stackSize >= loot.Settings.StackPlatValue) then lootDecision = 'Sell' end
        end
        loot.addRule(itemName, firstLetter, lootDecision, lootClasses, item.ItemLink('CLICKABLE')())

        newRule = true
    end

    -- check this before quest item checks. so we have the proper rule to compare.
    -- Check if item is on global Items list, ignore everything else and use those rules insdead.
    local globalFound = false
    local globalClassSkip = false
    if loot.Settings.GlobalLootOn and globalItem ~= 'NULL' then
        if globalClasses:lower() ~= 'all' and from == 'loot' then
            if string.find(globalClasses:lower(), loot.MyClass) then
                lootData[firstLetter][itemName] = globalItem or lootData[firstLetter][itemName]
                Logger.log_info("Item \at%s\ax is \agIN GlobalItem \axclass list \ay%s", itemName, globalClasses)
            else
                lootData[firstLetter][itemName] = 'Ignore'
                Logger.log_info("Item \at%s\ax \arNOT in GlobalItem \axclass list \ay%s", itemName, globalClasses)
                globalClassSkip = true
            end
        else
            lootData[firstLetter][itemName] = globalItem or lootData[firstLetter][itemName]
        end
        globalFound = true
    end

    -- check Classes
    if lootClasses == nil then lootClasses = 'All' end
    if lootClasses:lower() ~= 'all' and not globalFound and from == 'loot' then
        if string.find(lootClasses:lower(), loot.MyClass) then
            lootDecision = lootData[firstLetter][itemName]
            Logger.log_info("Item \at%s\ax is \agIN \axclass list \ay%s", itemName, lootClasses)
        else
            Logger.log_info("Item \at%s\ax \arNOT in \axclass list \ay%s", itemName, lootClasses)
            lootDecision = 'Ignore'
        end
        return lootDecision, 0, newRule
    end
    if loot.Settings.LootAugments and augment > 0 then
        lootDecision = "Keep"
    end

    -- Check if item marked Quest
    if string.find(lootData[firstLetter][itemName], 'Quest') then
        local qVal = 'Ignore'
        -- do we want to loot quest items?
        if loot.Settings.LootQuest then
            --look to see if Quantity attached to Quest|qty
            local _, position = string.find(lootData[firstLetter][itemName], '|')
            if position then qKeep = string.sub(lootData[firstLetter][itemName], position + 1) else qKeep = '0' end
            -- if Quantity is tied to the entry then use that otherwise use default Quest Keep Qty.
            if qKeep == '0' then
                qKeep = tostring(loot.Settings.QuestKeep)
            end
            -- If we have less than we want to keep loot it.
            if countHave < tonumber(qKeep) then
                qVal = 'Keep'
            end
            if loot.Settings.AlwaysDestroy and qVal == 'Ignore' then qVal = 'Destroy' end
        end
        return qVal, tonumber(qKeep) or 0
    end

    if loot.Settings.AlwaysDestroy and lootData[firstLetter][itemName] == 'Ignore' and not globalClassSkip then return 'Destroy', 0 end

    return lootData[firstLetter][itemName], 0, newRule
end

-- EVENTS
function loot.RegisterActors()
    loot.lootActor = Comms.Actors.register('lootnscoot', function(message)
        local lootMessage = message()
        local who         = lootMessage.who or ''
        local action      = lootMessage.action or ''
        local itemID      = lootMessage.itemID or 0
        local rule        = lootMessage.rule or 'NULL'
        local section     = lootMessage.section or 'NormalItems'
        local server      = lootMessage.Server or 'NULL'
        local itemName    = lootMessage.item or 'NULL'
        local itemLink    = lootMessage.link or 'NULL'
        local itemClasses = lootMessage.classes or 'All'
        local itemRaces   = lootMessage.races or 'All'
        local boxSettings = lootMessage.settings or {}
        if itemName == 'NULL' then
            itemName = loot.ALLITEMS[itemID] and loot.ALLITEMS[itemID].Name or 'NULL'
        end
        if action == 'Hello' and who ~= MyName then
            loot.sendMySettings()
            return
        end
        -- Logger.log_info("loot.RegisterActors: \agReceived\ax message:\atSub \ay%s\aw, \atItem \ag%s\aw, \atRule \ag%s", action, itemID, rule)
        if action == 'sendsettings' and who ~= MyName then
            loot.Boxes[who] = {}
            for k, v in pairs(boxSettings) do
                if type(k) ~= 'table' then
                    loot.Boxes[who][k] = v
                else
                    loot.Boxes[who][k] = {}
                    for i, j in pairs(v) do
                        loot.Boxes[who][k][i] = j
                    end
                end
            end
        end

        if action == 'updatesettings' and who == MyName then
            for k, v in pairs(boxSettings) do
                if type(k) ~= 'table' then
                    loot.Settings[k] = v
                else
                    for i, j in pairs(v) do
                        loot.Settings[k][i] = j
                    end
                end
            end
            mq.pickle(SettingsFile, loot.Settings)
            loot.loadSettings()
            loot.sendMySettings()
        end
        if server ~= eqServer then return end

        -- Reload loot settings
        if action == 'lootreload' then
            loot.commandHandler('reload')
        end
        if who == Config.Globals.CurLoadedChar then return end
        if action == 'addrule' then
            local item = lootMessage.item
            local rule = lootMessage.rule
            local section = lootMessage.section
            if section == 'GlobalItems' then
                loot.GlobalItems[item] = rule
                loot.GlobalItemsClasses[item] = nil
            else
                loot.NormalItems[item] = rule
                loot.NormalItemsClasses[item] = itemClasses
                loot.NormalItemsLink[item] = itemLink
            end

            loot.NewItems[itemID] = nil
            loot.NewItemsCount = loot.NewItemsCount - 1
            Logger.log_info("loot.RegisterActors: \atNew Item Rule \ax\agConfirmed:\ax [\ay%s\ax] NewItemCount Remaining \ag%s\ax", itemLink, loot.NewItemsCount)
            return
        end

        if action == 'addrule' or action == 'modifyitem' then
            if section == 'PersonalItems' and who == MyName then
                loot.PersonalItemsRules[itemID]   = rule
                loot.PersonalItemsClasses[itemID] = itemClasses
                loot.PersonalItemsLink[itemID]    = itemLink
                loot.ItemNames[itemID]            = itemName
            elseif section == 'GlobalItems' then
                loot.GlobalItemsRules[itemID]   = rule
                loot.GlobalItemsClasses[itemID] = itemClasses
                loot.GlobalItemsLink[itemID]    = itemLink
                loot.ItemNames[itemID]          = itemName
            else
                loot.NormalItems[item] = nil
                loot.NormalItemsClasses[item] = nil
            end

            Logger.log_info("loot.RegisterActors: \atAction:\ax [\ay%s\ax] \ag%s\ax rule for item \at%s\ax", action, rule, lootMessage.item)
            if lootMessage.entered then
                if lootedCorpses[lootMessage.corpse] then
                    lootedCorpses[lootMessage.corpse] = nil
                end

                loot.NewItems[itemID] = nil
                loot.NewItemsCount = loot.NewItemsCount - 1
                Logger.log_info("loot.RegisterActors: \atNew Item Rule \ax\agUpdated:\ax [\ay%s\ax] NewItemCount Remaining \ag%s\ax", lootMessage.entered, loot.NewItemsCount)
            end

            local db = loot.OpenItemsSQL()
            loot.GetItemFromDB(itemName, itemID)
            db:close()
            loot.lookupLootRule(itemID)

            -- clean bags of items marked as destroy so we don't collect garbage
            if rule:lower() == 'destroy' then
                loot.cleanupBags()
            end
        elseif action == 'deleteitem' and who ~= MyName then
            loot[action .. 'Rules'][itemID]   = nil
            loot[action .. 'Classes'][itemID] = nil
            loot[action .. 'Link'][itemID]    = nil
            Logger.log_info("loot.RegisterActors: \atAction:\ax [\ay%s\ax] \ag%s\ax rule for item \at%s\ax", action, rule, lootMessage.item)
        elseif action == 'new' and who ~= MyName and loot.NewItems[itemID] == nil then
            loot.NewItems[itemID] = {
                Name       = lootMessage.item,
                Rule       = rule,
                Link       = itemLink,
                Lore       = lootMessage.lore,
                NoDrop     = lootMessage.noDrop,
                SellPrice  = lootMessage.sellPrice,
                Tradeskill = lootMessage.tradeskill,
                Aug = lootMessage.aug,
                Classes = 'All',
                CorpseID = lootMessage.corpse,
            }
            Logger.log_info("loot.RegisterActors: \atAction:\ax [\ay%s\ax] \ag%s\ax rule for item \at%s\ax", action, rule, lootMessage.item)
            loot.NewItemsCount = loot.NewItemsCount + 1
            if loot.Settings.AutoShowNewItem then
                loot.showNewItem = true
            end
        elseif action == 'ItemsDB_UPDATE' and who ~= MyName then
            -- loot.LoadItemsDB()
        end

        -- Notify modules of loot setting changes
        Modules:ExecModule("Loot", "ModifyLootSettings")
    end)
end

local itemNoValue = nil
function loot.eventNovalue(line, item)
    itemNoValue = item
end

function loot.setupEvents()
    mq.event("CantLoot", "#*#may not loot this corpse#*#", loot.eventCantLoot)
    mq.event("NoSlot", "#*#There are no open slots for the held item in your inventory#*#", loot.eventNoSlot)
    mq.event("Sell", "#*#You receive#*# for the #1#(s)#*#", loot.eventSell)
    -- if loot.Settings.LootForage then
    mq.event("ForageExtras", "Your forage mastery has enabled you to find something else!", loot.eventForage)
    mq.event("Forage", "You have scrounged up #*#", loot.eventForage)
    -- end
    mq.event("Novalue", "#*#give you absolutely nothing for the #1#.#*#", loot.eventNovalue)
    mq.event("Tribute", "#*#We graciously accept your #1# as tribute, thank you!#*#", loot.eventTribute)
end

-- BINDS
function loot.setBuyItem(item, qty)
    loot.BuyItems[item] = qty
    Core.DoCmd('/ini "%s" "BuyItems" "%s" "%s"', SettingsFile, item, qty)
    Modules:ExecModule("Loot", "ModifyLootSettings")
end

function loot.setGlobalItem(item, val, classes)
    loot.GlobalItems[item] = val ~= 'delete' and val or nil
    loot.GlobalItemsClasses[item] = classes or 'All'
    loot.modifyItem(item, val, 'Global_Rules', classes)
    Modules:ExecModule("Loot", "ModifyLootSettings")
end

function loot.ChangeClasses(item, classes, tableName)
    if tableName == 'GlobalItems' then
        loot.GlobalItemsClasses[item] = classes
        loot.modifyItem(item, loot.GlobalItems[item], 'Global_Rules', classes)
    elseif tableName == 'NormalItems' then
        loot.NormalItemsClasses[itemID] = classes
        loot.modifyItemRule(itemID, loot.NormalItemsRules[itemID], 'Normal_Rules', classes)
    elseif tableName == 'PersonalItems' then
        loot.PersonalItemsClasses[itemID] = classes
        loot.modifyItemRule(itemID, loot.PersonalItemsRules[itemID], loot.PersonalTableName, classes)
    end
    Modules:ExecModule("Loot", "ModifyLootSettings")
end

function loot.setNormalItem(item, val, classes, link)
    if link == nil then link = 'NULL' end
    loot.NormalItems[item] = val ~= 'delete' and val or nil
    loot.NormalItemsClasses[item] = classes or 'All'
    loot.NormalItemsLink[item] = link
    loot.modifyItem(item, val, 'Normal_Rules', classes, link)
    Modules:ExecModule("Loot", "ModifyLootSettings")
end

-- Sets a Normal Item rule
function loot.setNormalItem(itemID, val, classes, link)
    if itemID == nil then
        Logger.log_warn("Invalid itemID for setNormalItem.")
        return
    end
    loot.NormalItemsRules[itemID] = val ~= 'delete' and val or nil
    if val ~= 'delete' then
        loot.NormalItemsClasses[itemID] = classes or 'All'
        loot.NormalItemsLink[itemID]    = link or 'NULL'
    else
        loot.NormalItemsClasses[itemID] = nil
        loot.NormalItemsLink[itemID]    = nil
    end
    loot.modifyItemRule(itemID, val, 'Normal_Rules', classes, link)
end

function loot.setPersonalItem(itemID, val, classes, link)
    if itemID == nil then
        Logger.log_warn("Invalid itemID for setPersonalItem.")
        return
    end
    loot.PersonalItemsRules[itemID] = val ~= 'delete' and val or nil
    if val ~= 'delete' then
        loot.PersonalItemsClasses[itemID] = classes or 'All'
        loot.PersonalItemsLink[itemID]    = link or 'NULL'
    else
        loot.PersonalItemsClasses[itemID] = nil
        loot.PersonalItemsLink[itemID]    = nil
    end
    loot.modifyItemRule(itemID, val, loot.PersonalTableName, classes, link)
end

-- Sets a Global Item rule for the item currently on the cursor
function loot.setGlobalBind(value)
    loot.setGlobalItem(mq.TLO.Cursor(), value)
end

function loot.commandHandler(...)
    local args = { ..., }
    Logger.log_debug("arg1 %s, arg2 %s, arg3 %s", args[1], args[2], args[3])
    if #args == 1 then
        if args[1] == 'sellstuff' then
            loot.processItems('Sell')
        elseif args[1] == 'restock' then
            loot.processItems('Buy')
        elseif args[1] == 'reload' then
            lootData = {}
            local needSave = loot.loadSettings()
            if needSave then
                loot.writeSettings()
            end
            if loot.guiLoot ~= nil then
                loot.guiLoot.GetSettings(loot.Settings.HideNames, loot.Settings.LookupLinks, loot.Settings.RecordData, true, loot.Settings.UseActors,
                    'lootnscoot')
            end
            Logger.log_info("\ayReloaded Settings \axAnd \atLoot Files")
        elseif args[1] == "newitems" then
            showNewItem = not showNewItem
        elseif args[1] == 'update' then
            lootData = {}
            if loot.guiLoot ~= nil then
                loot.guiLoot.GetSettings(loot.Settings.HideNames, loot.Settings.LookupLinks, loot.Settings.RecordData, true, loot.Settings.UseActors,
                    'lootnscoot')
            end
            loot.UpdateDB()
            Logger.log_info("\ayUpdating the DB from loot.ini \ax and \at Reloading Settings")
        elseif args[1] == 'bankstuff' then
            loot.processItems('Bank')
        elseif args[1] == 'cleanup' then
            loot.processItems('Cleanup')
        elseif args[1] == 'gui' and loot.guiLoot ~= nil then
            loot.guiLoot.openGUI = not loot.guiLoot.openGUI
        elseif args[1] == 'report' and loot.guiLoot ~= nil then
            loot.guiLoot.ReportLoot()
        elseif args[1] == 'hidenames' and loot.guiLoot ~= nil then
            loot.guiLoot.hideNames = not loot.guiLoot.hideNames
        elseif args[1] == 'config' then
            local confReport = string.format("\ayLoot N Scoot Settings\ax")
            for key, value in pairs(loot.Settings) do
                if type(value) ~= "function" and type(value) ~= "table" then
                    confReport = confReport .. string.format("\n\at%s\ax = \ag%s\ax", key, tostring(value))
                end
            end
            Logger.log_info(confReport)
        elseif args[1] == 'tributestuff' then
            loot.processItems('Tribute')
        elseif command == 'shownew' or command == 'newitems' then
            loot.showNewItem = not loot.showNewItem
        elseif command == 'loot' then
            loot.lootMobs()
        elseif args[1] == 'tsbank' then
            loot.markTradeSkillAsBank()
        elseif validActions[args[1]] and mq.TLO.Cursor() then
            loot.addRule(mq.TLO.Cursor(), mq.TLO.Cursor():sub(1, 1):upper(), validActions[args[1]], 'All', mq.TLO.Cursor.ItemLink('CLICKABLE')())
            Logger.log_info(string.format("Setting \ay%s\ax to \ay%s\ax", mq.TLO.Cursor(), validActions[args[1]]))
        elseif string.find(args[1], "quest%|") and mq.TLO.Cursor() then
            local val = string.gsub(args[1], "quest", "Quest")
            loot.addRule(mq.TLO.Cursor(), mq.TLO.Cursor():sub(1, 1):upper(), val, 'All', mq.TLO.Cursor.ItemLink('CLICKABLE')())
            Logger.log_info(string.format("Setting \ay%s\ax to \ay%s\ax", mq.TLO.Cursor(), val))
        end
    elseif #args == 2 then
        if args[1] == 'quest' and mq.TLO.Cursor() then
            loot.addRule(mq.TLO.Cursor(), mq.TLO.Cursor():sub(1, 1):upper(), 'Quest|' .. args[2], 'All', mq.TLO.Cursor.ItemLink('CLICKABLE')())
            Logger.log_info("Setting \ay%s\ax to \ayQuest|%s\ax", mq.TLO.Cursor(), args[2])
        elseif args[1] == 'buy' and mq.TLO.Cursor() then
            loot.BuyItems[mq.TLO.Cursor()] = args[2]
            Core.DoCmd('/ini "%s" "BuyItems" "%s" "%s"', SettingsFile, mq.TLO.Cursor(), args[2])
            Logger.log_info("Setting \ay%s\ax to \ayBuy|%s\ax", mq.TLO.Cursor(), args[2])
        elseif args[1] == 'globalitem' and validActions[args[2]] and mq.TLO.Cursor() then
            loot.GlobalItems[mq.TLO.Cursor()] = validActions[args[2]]
            loot.addRule(mq.TLO.Cursor(), 'GlobalItems', validActions[args[2]])
            Logger.log_info("Setting \ay%s\ax to \agGlobal Item \ay%s\ax", mq.TLO.Cursor(), validActions[args[2]])
        elseif args[1] == 'classes' and mq.TLO.Cursor() then
            loot.ChangeClasses(mq.TLO.Cursor(), args[2], 'NormalItems')
        elseif args[1] == 'gclasses' and mq.TLO.Cursor() then
            loot.ChangeClasses(mq.TLO.Cursor(), args[2], 'GlobalItems')
        elseif validActions[args[1]] and args[2] ~= 'NULL' then
            loot.addRule(args[2], args[2]:sub(1, 1):upper(), validActions[args[1]])
            Logger.log_info("Setting \ay%s\ax to \ay%s\ax", args[2], validActions[args[1]])
        end
    elseif #args == 3 then
        if args[1] == 'globalitem' and args[2] == 'quest' and mq.TLO.Cursor() then
            loot.addRule(mq.TLO.Cursor(), 'GlobalItems', 'Quest|' .. args[3])
            Logger.log_info("Setting \ay%s\ax to \agGlobal Item \ayQuest|%s\ax", mq.TLO.Cursor(), args[3])
        elseif args[1] == 'globalitem' and validActions[args[2]] and args[3] ~= 'NULL' then
            loot.addRule(args[3], 'GlobalItems', validActions[args[2]])
            Logger.log_info("Setting \ay%s\ax to \agGlobal Item \ay%s\ax", args[3], validActions[args[2]])
        elseif args[1] == 'buy' then
            loot.BuyItems[args[2]] = args[3]
            Core.DoCmd('/ini "%s" "BuyItems" "%s" "%s"', SettingsFile, args[2], args[3])
            Logger.log_info("Setting \ay%s\ax to \ayBuy|%s\ax", args[2], args[3])
        elseif args[1] == 'classes' and args[2] ~= 'NULL' and args[3] ~= 'NULL' then
            local item = args[2]
            local classes = args[3]
            loot.ChangeClasses(item, classes, 'NormalItems')
        elseif args[1] == 'gclasses' and args[2] ~= 'NULL' and args[3] ~= 'NULL' then
            local item = args[2]
            local classes = args[3]
            loot.ChangeClasses(item, classes, 'GlobalItems')
        elseif validActions[args[1]] and args[2] ~= 'NULL' then
            loot.addRule(args[2], args[2]:sub(1, 1):upper(), validActions[args[1]] .. '|' .. args[3])
            Logger.log_info("Setting \ay%s\ax to \ay%s|%s\ax", args[2], validActions[args[1]], args[3])
        end
    elseif #args == 4 then
        if args[1] == 'globalitem' and validActions[args[2]] and args[3] ~= 'NULL' then
            loot.addRule(args[3], 'GlobalItems', validActions[args[2]] .. '|' .. args[4])
            Logger.log_info("Setting \ay%s\ax to \agGlobal Item \ay%s|%s\ax", args[3], validActions[args[2]], args[4])
        end
    end
    loot.writeSettings()
end

function loot.setupBinds()
    mq.bind('/lootutils', loot.commandHandler)
end

-- LOOTING

function loot.CheckBags()
    areFull = mq.TLO.Me.FreeInventory() <= loot.Settings.SaveBagSlots
end

function loot.eventCantLoot()
    cantLootID = mq.TLO.Target.ID()
end

function loot.eventNoSlot()
    -- we don't have a slot big enough for the item on cursor. Dropping it to the ground.
    local cantLootItemName = mq.TLO.Cursor()
    Core.DoCmd('/drop')
    mq.delay(1)
    loot.report("\ay[WARN]\arI can't loot %s, dropping it on the ground!\ax", cantLootItemName)
end

---@param index number @The current index we are looking at in loot window, 1-based.
---@param doWhat string @The action to take for the item.
---@param button string @The mouse button to use to loot the item. Currently only leftmouseup implemented.
---@param qKeep number @The count to keep, for quest items.
---@param allItems table @Table of all items seen so far on the corpse, left or looted.
function loot.lootItem(index, doWhat, button, qKeep, allItems)
    local eval = doWhat
    Logger.log_debug('Enter lootItem')
    local corpseItem = mq.TLO.Corpse.Item(index)
    if not shouldLootActions[doWhat] then
        table.insert(allItems, { Name = corpseItem.Name(), Action = 'Left', Link = corpseItem.ItemLink('CLICKABLE')(), Eval = doWhat, })
        return
    end
    local corpseItemID = corpseItem.ID()
    local itemName = corpseItem.Name()
    local itemLink = corpseItem.ItemLink('CLICKABLE')()
    local globalItem = (loot.Settings.GlobalLootOn and (loot.GlobalItems[itemName] ~= nil or loot.BuyItems[itemName] ~= nil)) and true or false

    Core.DoCmd('/nomodkey /shift /itemnotify loot%s %s', index, button)
    -- Looting of no drop items is currently disabled with no flag to enable anyways
    -- added check to make sure the cursor isn't empty so we can exit the pause early.-- or not mq.TLO.Corpse.Item(index).NoDrop()
    mq.delay(1) -- for good measure.
    mq.delay(5000, function() return mq.TLO.Window('ConfirmationDialogBox').Open() or mq.TLO.Cursor() == nil end)
    if mq.TLO.Window('ConfirmationDialogBox').Open() then Core.DoCmd('/nomodkey /notify ConfirmationDialogBox Yes_Button leftmouseup') end
    mq.delay(5000, function() return mq.TLO.Cursor() ~= nil or not mq.TLO.Window('LootWnd').Open() end)
    mq.delay(1) -- force next frame
    -- The loot window closes if attempting to loot a lore item you already have, but lore should have already been checked for
    if not mq.TLO.Window('LootWnd').Open() then return end
    if doWhat == 'Destroy' and mq.TLO.Cursor.ID() == corpseItemID then
        eval = globalItem and 'Global Destroy' or 'Destroy'
        Core.DoCmd('/destroy')
        table.insert(allItems, { Name = itemName, Action = 'Destroyed', Link = itemLink, Eval = eval, })
    end
    loot.checkCursor()
    if qKeep > 0 and doWhat == 'Keep' then
        eval = globalItem and 'Global Quest' or 'Quest'
        local countHave = mq.TLO.FindItemCount(string.format("%s", itemName))() + mq.TLO.FindItemBankCount(string.format("%s", itemName))()
        loot.report("\awQuest Item:\ag %s \awCount:\ao %s \awof\ag %s", itemLink, tostring(countHave), qKeep)
    else
        eval = globalItem and 'Global ' .. doWhat or doWhat
        loot.report('%sing \ay%s\ax', doWhat, itemLink)
    end
    if doWhat ~= 'Destroy' then
        if not string.find(eval, 'Quest') then
            eval = globalItem and 'Global ' .. doWhat or doWhat
        end
        table.insert(allItems, { Name = itemName, Action = 'Looted', Link = itemLink, Eval = eval, })
    end
    loot.CheckBags()
    if areFull then loot.report('My bags are full, I can\'t loot anymore! Turning OFF Looting Items until we sell.') end
end

function loot.lootCorpse(corpseID)
    Logger.log_debug('Enter lootCorpse')
    shouldLootActions.Destroy = loot.Settings.DoDestroy
    shouldLootActions.Tribute = loot.Settings.TributeKeep
    if mq.TLO.Cursor() then loot.checkCursor() end
    for i = 1, 3 do
        Core.DoCmd('/loot')
        mq.delay(1000, function() return mq.TLO.Window('LootWnd').Open() end)
        if mq.TLO.Window('LootWnd').Open() then break end
    end

    mq.doevents('CantLoot')
    mq.delay(3000, function() return cantLootID > 0 or mq.TLO.Window('LootWnd').Open() end)
    if not mq.TLO.Window('LootWnd').Open() then
        if mq.TLO.Target.CleanName() ~= nil then
            Logger.log_warn(('\awlootCorpse(): \ayCan\'t loot %s right now'):format(mq.TLO.Target.CleanName()))
            cantLootList[corpseID] = os.time()
        end
        return
    end
    mq.delay(1000, function() return (mq.TLO.Corpse.Items() or 0) > 0 end)
    local items = mq.TLO.Corpse.Items() or 0
    Logger.log_debug('\awlootCorpse(): \ayLoot window open. Items: %s', items)
    local corpseName = mq.TLO.Corpse.Name()
    if mq.TLO.Window('LootWnd').Open() and items > 0 then
        if mq.TLO.Corpse.DisplayName() == mq.TLO.Me.DisplayName() then
            if loot.Settings.LootMyCorpse then
                -- if its our own corpse and we want to loot our corpses then loot it all.
                Core.DoCmd('/lootall')
                -- dont return control to other functions until we are done looting.
                mq.delay("45s", function() return not mq.TLO.Window('LootWnd').Open() end)
            end
            return
        end
        local noDropItems = {}
        local loreItems = {}
        local allItems = {}
        for i = 1, items do
            local freeSpace = mq.TLO.Me.FreeInventory()
            local corpseItem = mq.TLO.Corpse.Item(i)
            local itemLink = corpseItem.ItemLink('CLICKABLE')()
            if corpseItem() then
                local corpseItemID = corpseItem.ID()
                local itemLink     = corpseItem.ItemLink('CLICKABLE')()
                local isNoDrop     = corpseItem.NoDrop()
                local newNoDrop    = false
                if loot.ItemNames[corpseItemID] == nil then
                    loot.addToItemDB(corpseItem)
                    if isNoDrop then
                        loot.addRule(corpseItemID, 'NormalItems', 'CanUse', 'All', itemLink)
                        newNoDrop = true
                    end
                end
                local itemRule, qKeep, newRule, cantWear = loot.getRule(corpseItem, 'loot')

                Logger.log_debug("LootCorpse(): itemID=\ao%s\ax, rule=\at%s\ax, qKeep=\ay%s\ax, newRule=\ag%s", corpseItemID, itemRule, qKeep, newRule)
                newRule         = newNoDrop == true and true or newRule

                local stackable = corpseItem.Stackable()
                local freeStack = corpseItem.FreeStack()
                if corpseItem.Lore() then
                    local haveItem = mq.TLO.FindItem(('=%s'):format(corpseItem.Name()))()
                    local haveItemBank = mq.TLO.FindItemBank(('=%s'):format(corpseItem.Name()))()
                    if haveItem or haveItemBank or freeSpace <= loot.Settings.SaveBagSlots then
                        table.insert(loreItems, itemLink)
                        loot.lootItem(i, 'Ignore', 'leftmouseup', 0, allItems)
                    elseif corpseItem.NoDrop() then
                        if loot.Settings.LootNoDrop then
                            if not newRule or (newRule and loot.Settings.LootNoDropNew) then
                                loot.lootItem(i, itemRule, 'leftmouseup', qKeep, allItems)
                            end
                        else
                            table.insert(noDropItems, itemLink)
                            loot.lootItem(i, 'Ignore', 'leftmouseup', 0, allItems)
                        end
                    else
                        loot.lootItem(i, itemRule, 'leftmouseup', qKeep, allItems)
                    end
                elseif corpseItem.NoDrop() then
                    if loot.Settings.LootNoDrop then
                        if not newRule or (newRule and loot.Settings.LootNoDropNew) then
                            loot.lootItem(i, itemRule, 'leftmouseup', qKeep, allItems)
                        end
                    else
                        table.insert(noDropItems, itemLink)
                        loot.lootItem(i, 'Ignore', 'leftmouseup', 0, allItems)
                    end
                elseif freeSpace > loot.Settings.SaveBagSlots or (stackable and freeStack > 0) then
                    loot.lootItem(i, itemRule, 'leftmouseup', qKeep, allItems)
                end
                if newRule then
                    local platVal = math.floor(corpseItem.Value() / 1000)
                    local goldVal = math.floor((corpseItem.Value() % 1000) / 100)
                    local silverVal = math.floor((corpseItem.Value() % 100) / 10)
                    local copperVal = corpseItem.Value() % 10

                    loot.NewItems[corpseItem.Name()] = {
                        Link       = itemLink,
                        Rule       = itemRule,
                        NoDrop     = corpseItem.NoDrop(),
                        Lore       = corpseItem.Lore(),
                        TradeSkill = corpseItem.Tradeskills(),
                        Aug        = corpseItem.AugType() or 0,
                        Stackable  = corpseItem.Stackable(),
                        SellPrice  = string.format("%s pp %s gp %s sp %s cp", platVal, goldVal, silverVal, copperVal),
                        Classes    = "All",
                        CorpseID   = corpseID,
                    }
                    newItemsCount = newItemsCount + 1
                    loot.lootActor:send({ mailbox = 'lootnscoot', },
                        {
                            who = Config.Globals.CurLoadedChar,
                            action = 'new',
                            item = corpseItem.Name(),
                            rule = itemRule,
                            link = itemLink,
                            lore = corpseItem.Lore(),
                            aug = corpseItem.AugType() or 0,
                            noDrop = corpseItem.NoDrop(),
                            tradeskill = corpseItem.Tradeskills(),
                            sellPrice = string.format("%s pp %s gp %s sp %s cp", platVal, goldVal, silverVal, copperVal),
                            corpse = corpseID,
                        })
                end
            end
            mq.delay(1)
            if mq.TLO.Cursor() then loot.checkCursor() end
            mq.delay(1)
            if not mq.TLO.Window('LootWnd').Open() then break end
        end
        if loot.Settings.ReportLoot and (#noDropItems > 0 or #loreItems > 0) then
            local skippedItems = '/%s Skipped loots (%s - %s) '
            for _, noDropItem in ipairs(noDropItems) do
                skippedItems = skippedItems .. ' ' .. noDropItem .. ' (nodrop) '
            end
            for _, loreItem in ipairs(loreItems) do
                skippedItems = skippedItems .. ' ' .. loreItem .. ' (lore) '
            end
            Core.DoCmd(skippedItems, loot.Settings.LootChannel, corpseName, corpseID)
        end
        if #allItems > 0 then
            -- send to self and others running lootnscoot
            loot.lootActor:send({ mailbox = 'looted', }, { ID = corpseID, Items = allItems, LootedAt = mq.TLO.Time(), LootedBy = Config.Globals.CurLoadedChar, })
            -- send to standalone looted gui
            loot.lootActor:send({ mailbox = 'looted', script = 'looted', },
                { ID = corpseID, Items = allItems, LootedAt = mq.TLO.Time(), LootedBy = Config.Globals.CurLoadedChar, })
        end
    end
    if mq.TLO.Cursor() then loot.checkCursor() end
    Core.DoCmd('/nomodkey /notify LootWnd LW_DoneButton leftmouseup')
    mq.delay(3000, function() return not mq.TLO.Window('LootWnd').Open() end)
    -- if the corpse doesn't poof after looting, there may have been something we weren't able to loot or ignored
    -- mark the corpse as not lootable for a bit so we don't keep trying
    if mq.TLO.Spawn(('corpse id %s'):format(corpseID))() then
        cantLootList[corpseID] = os.time()
    end

    if #allItems > 0 then
        loot.lootActor:send({ mailbox = 'looted', },
            { ID = corpseID, Items = allItems, Server = eqServer, LootedAt = mq.TLO.Time(), LootedBy = MyName, })
    end
end

function loot.corpseLocked(corpseID)
    if not cantLootList[corpseID] then return false end
    if os.difftime(os.time(), cantLootList[corpseID]) > 60 then
        cantLootList[corpseID] = nil
        return false
    end
    return true
end

function loot.lootMobs(limit)
    if zoneID ~= mq.TLO.Zone.ID() then
        zoneID = mq.TLO.Zone.ID()
        lootedCorpses = {}
    end
    Logger.log_verbose('\awlootMobs(): \ayEnter lootMobs')
    local deadCount = mq.TLO.SpawnCount(spawnSearch:format('npccorpse', loot.Settings.CorpseRadius))()
    local mobsNearby
    local corpseList = {}
    Logger.log_verbose('\awlootMobs(): \ayThere are %s corpses in range.', deadCount)
    ::continue::
    mobsNearby = Targeting.GetXTHaterCount()
    corpseList = {}

    -- check for own corpse
    local myCorpseCount = mq.TLO.SpawnCount(string.format("pccorpse %s radius %d zradius 100", mq.TLO.Me.CleanName(), loot.Settings.CorpseRadius))()

    if loot.Settings.LootMyCorpse then
        -- if we want to loot our own corpses then add them to the list and loot them first so we have bags to put items into
        for i = 1, (limit or myCorpseCount) do
            local corpse = mq.TLO.NearestSpawn(string.format("%d, pccorpse %s radius %d zradius 100", i, mq.TLO.Me.CleanName(), loot.Settings.CorpseRadius))
            Logger.log_debug('\awlootMobs(): \ayMy Corpse ID: %d', corpse.ID())
            table.insert(corpseList, corpse)
        end
    end
    -- options for combat looting or looting disabled
    if (deadCount + myCorpseCount) == 0 or ((mobsNearby > 0 or mq.TLO.Me.Combat()) and not loot.Settings.CombatLooting) then return false end

    -- only loot mobs if I have no corspses near.
    if myCorpseCount == 0 then
        for i = 1, (limit or deadCount) do
            local corpse = mq.TLO.NearestSpawn(('%d,' .. spawnSearch):format(i, 'npccorpse', loot.Settings.CorpseRadius))
            if lootedCorpses[corpse.ID()] == nil or not loot.Settings.CheckCorpseOnce then
                table.insert(corpseList, corpse)
            end
        end
    else
        Logger.log_debug('\awlootMobs(): \ayI have my own corpse nearby, not looting other corpses.')
    end

    local didLoot = false
    if #corpseList > 0 then
        Logger.log_debug('\awlootMobs(): \ayTrying to loot %d corpses.', #corpseList)
        for i = 1, #corpseList do
            if Config.Globals.PauseMain then break end
            local corpse = corpseList[i]
            local corpseID = corpse.ID()
            if lootedCorpses[corpseID] ~= nil and loot.Settings.CheckCorpseOnce then
                Logger.log_debug('\awlootMobs(): \ayCorpse ID: %d already looted.', corpseID)
                table.remove(corpseList, i)
                goto continue
            end
            if corpseID and corpseID > 0 and not loot.corpseLocked(corpseID) and
                (mq.TLO.Navigation.PathLength('spawn id ' .. tostring(corpseID))() or 100) < 60 and
                ((loot.Settings.CheckCorpseOnce and lootedCorpses[corpseID] == nil) or not loot.Settings.CheckCorpseOnce) then
                -- try to pull our corpse closer if possible.
                if corpse.DisplayName() == mq.TLO.Me.DisplayName() then
                    Logger.log_debug('\awlootMobs(): \ayPulilng my Corpse ID: %d', corpse.ID())
                    Core.DoCmd("/corpse")
                    mq.delay(10)
                end

                Logger.log_debug('\awlootMobs(): \atMoving to corpse ID=' .. tostring(corpseID))
                loot.navToID(corpseID)

                if Targeting.GetXTHaterCount() > 0 and not loot.Settings.CombatLooting then
                    Logger.log_debug('\awlootMobs(): \arLooting stopped early due to aggro!')
                    return didLoot
                end

                corpse.DoTarget()
                loot.lootCorpse(corpseID)
                didLoot = true
                lootedCorpses[corpseID] = true
            end
        end
        Logger.log_debug('\awlootMobs(): \agDone with corpse list.')
    end
    return didLoot
end

-- SELLING

function loot.eventSell(_, itemName)
    if NEVER_SELL[itemName] then return end
    local firstLetter = itemName:sub(1, 1):upper()
    if lootData[firstLetter] and lootData[firstLetter][itemName] == 'Sell' then return end
    if loot.lookupLootRule(firstLetter, itemName) == 'Sell' then
        lootData[firstLetter] = lootData[firstLetter] or {}
        lootData[firstLetter][itemName] = 'Sell'
        return
    end
    if loot.Settings.AddNewSales then
        Logger.log_info(string.format('Setting %s to Sell', itemName))
        if not lootData[firstLetter] then lootData[firstLetter] = {} end
        Core.DoCmd('/ini "%s" "%s" "%s" "%s"', LootFile, firstLetter, itemName, 'Sell')
        loot.modifyItem(itemName, 'Sell', 'Normal_Rules')
        lootData[firstLetter][itemName] = 'Sell'
        loot.NormalItems[itemName] = 'Sell'
        loot.lootActor:send({ mailbox = 'lootnscoot', },
            { who = Config.Globals.CurLoadedChar, action = 'modifyitem', item = itemName, rule = 'Sell', section = "NormalItems", })
        Modules:ExecModule("Loot", "ModifyLootSettings")
    end
end

function loot.goToVendor()
    if not mq.TLO.Target() then
        Logger.log_warn('Please target a vendor')
        return false
    end
    local vendorName = mq.TLO.Target.CleanName()

    Logger.log_info('Doing business with ' .. vendorName)
    if mq.TLO.Target.Distance() > 15 then
        loot.navToID(mq.TLO.Target.ID())
    end
    return true
end

function loot.openVendor()
    Logger.log_debug('Opening merchant window')
    Core.DoCmd('/nomodkey /click right target')
    Logger.log_debug('Waiting for merchant window to populate')
    mq.delay(1000, function() return mq.TLO.Window('MerchantWnd').Open() end)
    if not mq.TLO.Window('MerchantWnd').Open() then return false end
    mq.delay(5000, function() return mq.TLO.Merchant.ItemsReceived() end)
    return mq.TLO.Merchant.ItemsReceived()
end

function loot.SellToVendor(itemToSell, bag, slot, link)
    if link == nil then link = 'NULL' end
    if NEVER_SELL[itemToSell] then return end
    if mq.TLO.Window('MerchantWnd').Open() then
        Logger.log_info('Selling ' .. itemToSell)
        if slot == nil or slot == -1 then
            Core.DoCmd('/nomodkey /itemnotify %s leftmouseup', bag)
        else
            Core.DoCmd('/nomodkey /itemnotify in pack%s %s leftmouseup', bag, slot)
        end
        mq.delay(1000, function() return mq.TLO.Window('MerchantWnd/MW_SelectedItemLabel').Text() == itemToSell end)
        Core.DoCmd('/nomodkey /shiftkey /notify merchantwnd MW_Sell_Button leftmouseup')
        mq.doevents('eventNovalue')
        if itemNoValue == itemToSell then
            loot.addRule(itemToSell, itemToSell:sub(1, 1), 'Ignore', 'All', link)
            itemNoValue = nil
        end
        -- TODO: handle vendor not wanting item / item can't be sold
        mq.delay(1000, function() return mq.TLO.Window('MerchantWnd/MW_SelectedItemLabel').Text() == '' end)
    end
end

-- BUYING

function loot.RestockItems()
    local rowNum = 0
    for itemName, qty in pairs(loot.BuyItems) do
        local tmpVal = tonumber(qty) or 0
        rowNum = mq.TLO.Window("MerchantWnd/MW_ItemList").List(itemName, 2)() or 0
        mq.delay(20)
        local tmpQty = tmpVal - mq.TLO.FindItemCount(itemName)()
        if rowNum ~= 0 and tmpQty > 0 then
            mq.TLO.Window("MerchantWnd/MW_ItemList").Select(rowNum)()
            mq.delay(100)
            mq.TLO.Window("MerchantWnd/MW_Buy_Button").LeftMouseUp()
            mq.delay(500, function() return mq.TLO.Window("QuantityWnd").Open() end)
            mq.TLO.Window("QuantityWnd/QTYW_SliderInput").SetText(tostring(tmpQty))()
            mq.delay(100, function() return mq.TLO.Window("QuantityWnd/QTYW_SliderInput").Text() == tostring(tmpQty) end)
            Logger.log_info("\agBuying\ay " .. tmpQty .. "\at " .. itemName)
            mq.TLO.Window("QuantityWnd/QTYW_Accept_Button").LeftMouseUp()
            mq.delay(100)
        end
        mq.delay(500, function() return mq.TLO.FindItemCount(itemName)() == qty end)
    end
    -- close window when done buying
    return mq.TLO.Window('MerchantWnd').DoClose()
end

-- TRIBUTEING

function loot.openTribMaster()
    Logger.log_debug('Opening Tribute Window')
    Core.DoCmd('/nomodkey /click right target')
    Logger.log_debug('Waiting for Tribute Window to populate')
    mq.delay(1000, function() return mq.TLO.Window('TributeMasterWnd').Open() end)
    if not mq.TLO.Window('TributeMasterWnd').Open() then return false end
    return mq.TLO.Window('TributeMasterWnd').Open()
end

function loot.eventTribute(line, itemName)
    local firstLetter = itemName:sub(1, 1):upper()
    if lootData[firstLetter] and lootData[firstLetter][itemName] == 'Tribute' then return end
    if loot.lookupLootRule(firstLetter, itemName) == 'Tribute' then
        lootData[firstLetter] = lootData[firstLetter] or {}
        lootData[firstLetter][itemName] = 'Tribute'
        return
    end
    if loot.Settings.AddNewTributes then
        Logger.log_info(string.format('Setting %s to Tribute', itemName))
        if not lootData[firstLetter] then lootData[firstLetter] = {} end
        Core.DoCmd('/ini "%s" "%s" "%s" "%s"', LootFile, firstLetter, itemName, 'Tribute')

        loot.modifyItem(itemName, 'Tribute', 'Normal_Rules')
        lootData[firstLetter][itemName] = 'Tribute'
        loot.NormalItems[itemName] = 'Tribute'
        loot.lootActor:send({ mailbox = 'lootnscoot', },
            { who = Config.Globals.CurLoadedChar, action = 'modifyitem', item = itemName, rule = 'Tribute', section = "NormalItems", })
        Modules:ExecModule("Loot", "ModifyLootSettings")
    end
end

function loot.TributeToVendor(itemToTrib, bag, slot)
    if NEVER_SELL[itemToTrib.Name()] then return end
    if mq.TLO.Window('TributeMasterWnd').Open() then
        Logger.log_info('Tributeing ' .. itemToTrib.Name())
        loot.report('\ayTributing \at%s \axfor\ag %s \axpoints!', itemToTrib.Name(), itemToTrib.Tribute())
        Core.DoCmd('/shift /itemnotify in pack%s %s leftmouseup', bag, slot)
        mq.delay(1) -- progress frame

        mq.delay(5000, function()
            return mq.TLO.Window('TributeMasterWnd').Child('TMW_ValueLabel').Text() == tostring(itemToTrib.Tribute()) and
                mq.TLO.Window('TributeMasterWnd').Child('TMW_DonateButton').Enabled()
        end)

        mq.TLO.Window('TributeMasterWnd/TMW_DonateButton').LeftMouseUp()
        mq.delay(1)
        mq.delay(5000, function() return not mq.TLO.Window('TributeMasterWnd/TMW_DonateButton').Enabled() end)
        if mq.TLO.Window("QuantityWnd").Open() then
            mq.TLO.Window("QuantityWnd/QTYW_Accept_Button").LeftMouseUp()
            mq.delay(5000, function() return not mq.TLO.Window("QuantityWnd").Open() end)
        end
        mq.delay(1000) -- This delay is necessary because there is seemingly a delay between donating and selecting the next item.
    end
end

-- CLEANUP

function loot.DestroyItem(itemToDestroy, bag, slot)
    if NEVER_SELL[itemToDestroy.Name()] then return end
    Logger.log_info('!!Destroying!! ' .. itemToDestroy.Name())
    Core.DoCmd('/shift /itemnotify in pack%s %s leftmouseup', bag, slot)
    mq.delay(1) -- progress frame
    Core.DoCmd('/destroy')
    mq.delay(1)
    mq.delay(1000, function() return not mq.TLO.Cursor() end)
    mq.delay(1)
end

-- BANKING

function loot.markTradeSkillAsBank()
    for i = 1, 10 do
        local bagSlot = mq.TLO.InvSlot('pack' .. i).Item
        if bagSlot.Container() == 0 then
            if bagSlot.ID() then
                if bagSlot.Tradeskills() then
                    local itemToMark = bagSlot.Name()
                    loot.NormalItems[itemToMark] = 'Bank'
                    loot.addRule(itemToMark, itemToMark:sub(1, 1), 'Bank', 'All', bagSlot.ItemLink('CLICKABLE')())
                    Modules:ExecModule("Loot", "ModifyLootSettings")
                end
            end
        end
    end
    -- sell any items in bags which are marked as sell
    for i = 1, 10 do
        local bagSlot = mq.TLO.InvSlot('pack' .. i).Item
        local containerSize = bagSlot.Container()
        if containerSize and containerSize > 0 then
            for j = 1, containerSize do
                local item = bagSlot.Item(j)
                if item.ID() and item.Tradeskills() then
                    local itemToMark = bagSlot.Item(j).Name()
                    loot.NormalItems[itemToMark] = 'Bank'
                    loot.addRule(itemToMark, itemToMark:sub(1, 1), 'Bank', 'All', bagSlot.ItemLink('CLICKABLE')())
                    Modules:ExecModule("Loot", "ModifyLootSettings")
                end
            end
        end
    end
end

function loot.bankItem(itemName, bag, slot)
    if not slot or slot == -1 then
        Core.DoCmd('/shift /itemnotify %s leftmouseup', bag)
    else
        Core.DoCmd('/shift /itemnotify in pack%s %s leftmouseup', bag, slot)
    end
    mq.delay(100, function() return mq.TLO.Cursor() end)
    Core.DoCmd('/notify BigBankWnd BIGB_AutoButton leftmouseup')
    mq.delay(100, function() return not mq.TLO.Cursor() end)
end

-- FORAGING

function loot.eventForage()
    if not loot.Settings.LootForage then return end
    Logger.log_debug('Enter eventForage')
    -- allow time for item to be on cursor incase message is faster or something?
    mq.delay(1000, function() return mq.TLO.Cursor() end)
    -- there may be more than one item on cursor so go until its cleared
    while mq.TLO.Cursor() do
        local cursorItem = mq.TLO.Cursor
        local foragedItem = cursorItem.Name()
        local forageRule = loot.split(loot.getRule(cursorItem))
        local ruleAction = forageRule[1] -- what to do with the item
        local ruleAmount = forageRule[2] -- how many of the item should be kept
        local currentItemAmount = mq.TLO.FindItemCount('=' .. foragedItem)()
        -- >= because .. does finditemcount not count the item on the cursor?
        if not shouldLootActions[ruleAction] or (ruleAction == 'Quest' and currentItemAmount >= ruleAmount) then
            if mq.TLO.Cursor.Name() == foragedItem then
                if loot.Settings.LootForageSpam then Logger.log_info('Destroying foraged item ' .. foragedItem) end
                Core.DoCmd('/destroy')
                mq.delay(500)
            end
            -- will a lore item we already have even show up on cursor?
            -- free inventory check won't cover an item too big for any container so may need some extra check related to that?
        elseif (shouldLootActions[ruleAction] or currentItemAmount < ruleAmount) and (not cursorItem.Lore() or currentItemAmount == 0) and (mq.TLO.Me.FreeInventory() or (cursorItem.Stackable() and cursorItem.FreeStack())) then
            if loot.Settings.LootForageSpam then Logger.log_info('Keeping foraged item ' .. foragedItem) end
            Core.DoCmd('/autoinv')
        else
            if loot.Settings.LootForageSpam then Logger.log_warn('Unable to process item ' .. foragedItem) end
            break
        end
        mq.delay(50)
    end
end

-- Process Items

function loot.processItems(action)
    local flag = false
    local totalPlat = 0

    local function processItem(item, action, bag, slot)
        local rule = loot.getRule(item)
        if rule == action then
            if action == 'Sell' then
                if not mq.TLO.Window('MerchantWnd').Open() then
                    if not loot.goToVendor() then return end
                    if not loot.openVendor() then return end
                end
                --totalPlat = mq.TLO.Me.Platinum()
                local sellPrice = item.Value() and item.Value() / 1000 or 0
                if sellPrice == 0 then
                    Logger.log_warn(string.format('Item \ay%s\ax is set to Sell but has no sell value!', item.Name()))
                else
                    loot.SellToVendor(item.Name(), bag, slot, item.ItemLink('CLICKABLE')() or "NULL")
                    totalPlat = totalPlat + sellPrice
                    mq.delay(1)
                end
            elseif action == 'Tribute' then
                if not mq.TLO.Window('TributeMasterWnd').Open() then
                    if not loot.goToVendor() then return end
                    if not loot.openTribMaster() then return end
                end
                Core.DoCmd('/keypress OPEN_INV_BAGS')
                mq.delay(1)
                -- tributes requires the bags to be open
                mq.delay(1000, loot.AreBagsOpen)
                mq.delay(1)
                loot.TributeToVendor(item, bag, slot)
                mq.delay(1)
            elseif action == 'Destroy' then
                loot.DestroyItem(item, bag, slot)
                mq.delay(1)
            elseif action == 'Bank' then
                if not mq.TLO.Window('BigBankWnd').Open() then
                    Logger.log_warn('Bank window must be open!')
                    return
                end
                loot.bankItem(item.Name(), bag, slot)
                mq.delay(1)
            end
        end
    end

    if loot.Settings.AlwaysEval then
        flag, loot.Settings.AlwaysEval = true, false
    end

    for i = 1, 10 do
        local bagSlot = mq.TLO.InvSlot('pack' .. i).Item
        local containerSize = bagSlot.Container()

        if containerSize then
            for j = 1, containerSize do
                local item = bagSlot.Item(j)
                if item.ID() then
                    if action == 'Cleanup' then
                        processItem(item, 'Destroy', i, j)
                    elseif action == 'Sell' then
                        processItem(item, 'Sell', i, j)
                    elseif action == 'Tribute' then
                        processItem(item, 'Tribute', i, j)
                    elseif action == 'Bank' then
                        processItem(item, 'Bank', i, j)
                    end
                end
            end
        end
    end
    if action == 'Sell' and loot.Settings.AutoRestock then
        loot.RestockItems()
    end
    if action == 'Buy' then
        if not mq.TLO.Window('MerchantWnd').Open() then
            if not loot.goToVendor() then return end
            if not loot.openVendor() then return end
        end
        loot.RestockItems()
    end

    if flag then
        flag, loot.Settings.AlwaysEval = false, true
    end

    if action == 'Tribute' then
        mq.flushevents('Tribute')
        if mq.TLO.Window('TributeMasterWnd').Open() then
            mq.TLO.Window('TributeMasterWnd').DoClose()
            mq.delay(1)
        end
        Core.DoCmd('/keypress CLOSE_INV_BAGS')
        mq.delay(1)
    elseif action == 'Sell' then
        if mq.TLO.Window('MerchantWnd').Open() then
            mq.TLO.Window('MerchantWnd').DoClose()
            mq.delay(1)
        end
        mq.delay(1)
        totalPlat = math.floor(totalPlat)
        loot.report('Total plat value sold: \ag%s\ax', totalPlat)
    elseif action == 'Bank' then
        if mq.TLO.Window('BigBankWnd').Open() then
            mq.TLO.Window('BigBankWnd').DoClose()
            mq.delay(1)
        end
    end

    loot.CheckBags()
end

-- Legacy functions for backward compatibility

function loot.sellStuff()
    loot.processItems('Sell')
end

function loot.bankStuff()
    loot.processItems('Bank')
end

function loot.cleanupBags()
    loot.processItems('Cleanup')
end

function loot.tributeStuff()
    loot.processItems('Tribute')
end

function loot.guiExport()
    -- Define a new menu element function
    local function customMenu()
        if ImGui.BeginMenu('Loot N Scoot') then
            -- Add menu items here
            if ImGui.BeginMenu('Toggles') then
                -- Add menu items here
                _, loot.Settings.DoLoot = ImGui.MenuItem("DoLoot", nil, loot.Settings.DoLoot)
                if _ then loot.writeSettings() end
                _, loot.Settings.GlobalLootOn = ImGui.MenuItem("GlobalLootOn", nil, loot.Settings.GlobalLootOn)
                if _ then loot.writeSettings() end
                _, loot.Settings.CombatLooting = ImGui.MenuItem("CombatLooting", nil, loot.Settings.CombatLooting)
                if _ then loot.writeSettings() end
                _, loot.Settings.LootNoDrop = ImGui.MenuItem("LootNoDrop", nil, loot.Settings.LootNoDrop)
                if _ then loot.writeSettings() end
                _, loot.Settings.LootNoDropNew = ImGui.MenuItem("LootNoDropNew", nil, loot.Settings.LootNoDropNew)
                if _ then loot.writeSettings() end
                _, loot.Settings.LootForage = ImGui.MenuItem("LootForage", nil, loot.Settings.LootForage)
                if _ then loot.writeSettings() end
                _, loot.Settings.LootQuest = ImGui.MenuItem("LootQuest", nil, loot.Settings.LootQuest)
                if _ then loot.writeSettings() end
                _, loot.Settings.TributeKeep = ImGui.MenuItem("TributeKeep", nil, loot.Settings.TributeKeep)
                if _ then loot.writeSettings() end
                _, loot.Settings.BankTradeskills = ImGui.MenuItem("BankTradeskills", nil, loot.Settings.BankTradeskills)
                if _ then loot.writeSettings() end
                _, loot.Settings.StackableOnly = ImGui.MenuItem("StackableOnly", nil, loot.Settings.StackableOnly)
                if _ then loot.writeSettings() end
                ImGui.Separator()
                _, loot.Settings.AlwaysEval = ImGui.MenuItem("AlwaysEval", nil, loot.Settings.AlwaysEval)
                if _ then loot.writeSettings() end
                _, loot.Settings.AddNewSales = ImGui.MenuItem("AddNewSales", nil, loot.Settings.AddNewSales)
                if _ then loot.writeSettings() end
                _, loot.Settings.AddNewTributes = ImGui.MenuItem("AddNewTributes", nil, loot.Settings.AddNewTributes)
                if _ then loot.writeSettings() end
                _, loot.Settings.AutoTag = ImGui.MenuItem("AutoTagSell", nil, loot.Settings.AutoTag)
                if _ then loot.writeSettings() end
                _, loot.Settings.AutoRestock = ImGui.MenuItem("AutoRestock", nil, loot.Settings.AutoRestock)
                if _ then loot.writeSettings() end
                ImGui.Separator()
                _, loot.Settings.DoDestroy = ImGui.MenuItem("DoDestroy", nil, loot.Settings.DoDestroy)
                if _ then loot.writeSettings() end
                _, loot.Settings.AlwaysDestroy = ImGui.MenuItem("AlwaysDestroy", nil, loot.Settings.AlwaysDestroy)
                if _ then loot.writeSettings() end

                ImGui.EndMenu()
            end
            if ImGui.BeginMenu('Group Commands') then
                -- Add menu items here
                if ImGui.MenuItem("Sell Stuff##group") then
                    Core.DoCmd(string.format('/%s /rgl sell', tmpCmd))
                end

                if ImGui.MenuItem('Restock Items##group') then
                    Core.DoCmd(string.format('/%s /rgl buy', tmpCmd))
                end

                if ImGui.MenuItem("Tribute Stuff##group") then
                    Core.DoCmd(string.format('/%s /rgl tribute', tmpCmd))
                end

                if ImGui.MenuItem("Bank##group") then
                    Core.DoCmd(string.format('/%s /rgl bank', tmpCmd))
                end

                if ImGui.MenuItem("Cleanup##group") then
                    Core.DoCmd(string.format('/%s /rgl cleanbags', tmpCmd))
                end

                ImGui.Separator()

                if ImGui.MenuItem("Reload##group") then
                    Core.DoCmd(string.format('/%s /rgl lootreload', tmpCmd))
                end

                ImGui.EndMenu()
            end
            if ImGui.MenuItem('Sell Stuff') then
                Core.DoCmd('/rgl sell')
            end

            if ImGui.MenuItem('Restock') then
                Core.DoCmd('/rgl buy')
            end

            if ImGui.MenuItem('Tribute Stuff') then
                Core.DoCmd('/rgl tribute')
            end

            if ImGui.MenuItem('Bank') then
                Core.DoCmd('/rgl bank')
            end

            if ImGui.MenuItem('Cleanup') then
                Core.DoCmd('/rgl cleanbags')
            end

            ImGui.Separator()

            if ImGui.MenuItem('Reload') then
                Core.DoCmd('/rgl lootreload')
            end


            ImGui.EndMenu()
        end
    end
    -- Add the custom menu element function to the importGUIElements table
    if loot.guiLoot ~= nil then table.insert(loot.guiLoot.importGUIElements, customMenu) end
end

function loot.handleSelectedItem(itemID)
    -- Process the selected item (e.g., add to a rule, perform an action, etc.)
    local itemData = loot.ALLITEMS[itemID]
    if not itemData then
        Logger.log_error("Invalid item selected: " .. tostring(itemID))
        return
    end

    Logger.log_info("Item selected: " .. itemData.Name .. " (ID: " .. itemID .. ")")
    -- You can now use itemID for further actions
end

function loot.drawYesNo(decision)
    if decision then
        loot.drawIcon(4494, 20) -- Checkmark icon
    else
        loot.drawIcon(4495, 20) -- X icon
    end
end

function loot.SearchLootTable(search, key, value)
    if key == nil or value == nil then return false end
    search = search and search:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1") or ""
    if (search == nil or search == "") or key:lower():find(search:lower()) or value:lower():find(search:lower()) then
        return true
    else
        return false
    end
end

local fontScale = 1
local iconSize = 16
local tempValues = {}

function loot.SortItemTables()
    loot.TempSettings.SortedGlobalItemKeys = {}
    loot.TempSettings.SortedBuyItemKeys    = {}
    loot.TempSettings.SortedNormalItemKeys = {}
    loot.TempSettings.SortedSettingsKeys   = {}

    for k in pairs(loot.GlobalItemsRules) do
        table.insert(loot.TempSettings.SortedGlobalItemKeys, k)
    end
    table.sort(loot.TempSettings.SortedGlobalItemKeys, function(a, b) return a < b end)

    for k in pairs(loot.BuyItemsTable) do
        table.insert(loot.TempSettings.SortedBuyItemKeys, k)
    end
    table.sort(loot.TempSettings.SortedBuyItemKeys, function(a, b) return a < b end)

    for k in pairs(loot.NormalItemsRules) do
        table.insert(loot.TempSettings.SortedNormalItemKeys, k)
    end

    table.sort(loot.TempSettings.SortedNormalItemKeys, function(a, b) return a < b end)

    for k in pairs(loot.Settings) do
        if settingsNoDraw[k] == nil then
            table.insert(loot.TempSettings.SortedSettingsKeys, k)
        end
    end
    table.sort(loot.TempSettings.SortedSettingsKeys, function(a, b) return a < b end)
end

function loot.RenderModifyItemWindow()
    if not loot.TempSettings.ModifyItemRule then
        Logger.log_error("Item not found in ALLITEMS %s %s", loot.TempSettings.ModifyItemID, loot.TempSettings.ModifyItemTable)
        loot.TempSettings.ModifyItemRule = false
        loot.TempSettings.ModifyItemID = nil
        tempValues = {}
        return
    end
    if loot.TempSettings.ModifyItemTable == 'Personal_Items' then
        loot.TempSettings.ModifyItemTable = loot.PersonalTableName
    end
    local classes = loot.TempSettings.ModifyClasses
    local rule = loot.TempSettings.ModifyItemSetting
    local colCount, styCount = loot.guiLoot.DrawTheme()

    ImGui.SetNextWindowSizeConstraints(ImVec2(300, 200), ImVec2(-1, -1))
    local open, show = ImGui.Begin("Modify Item", nil, ImGuiWindowFlags.AlwaysAutoResize)
    if show then
        local tableList = {
            "Global_Items", "Normal_Items", loot.PersonalTableName,
        }
        local itemsToRemove = {} -- Temporary table to store items to remove

        if newItemsCount > 0 then
            if ImGui.BeginTable('##newItemTable', 9,
                    bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.ScrollX, ImGuiTableFlags.ScrollY, ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags
                        .Hideable)) then
                ImGui.TableSetupColumn('Item', ImGuiTableColumnFlags.WidthStretch)
                ImGui.TableSetupColumn('Rule', ImGuiTableColumnFlags.WidthFixed, 100)
                ImGui.TableSetupColumn('Classes', ImGuiTableColumnFlags.WidthFixed, 150)
                ImGui.TableSetupColumn('Value', ImGuiTableColumnFlags.WidthFixed, 120)
                ImGui.TableSetupColumn('NoDrop', ImGuiTableColumnFlags.WidthFixed, 50)
                ImGui.TableSetupColumn('Lore', ImGuiTableColumnFlags.WidthFixed, 50)
                ImGui.TableSetupColumn("Aug", ImGuiTableColumnFlags.WidthFixed, 50)
                ImGui.TableSetupColumn('TS', ImGuiTableColumnFlags.WidthFixed, 50)
                ImGui.TableSetupColumn("Save", ImGuiTableColumnFlags.WidthFixed, 90)
                ImGui.TableHeadersRow()

        if tempValues.Classes == nil and classes ~= nil then
            tempValues.Classes = classes
        end

        ImGui.SetNextItemWidth(100)
        tempValues.Classes = ImGui.InputTextWithHint("Classes", "who can loot or all ex: shm clr dru", tempValues.Classes)

        ImGui.SameLine()
        loot.TempModClass = ImGui.Checkbox("All", loot.TempModClass)

        if tempValues.Rule == nil and rule ~= nil then
            tempValues.Rule = rule
        end

        ImGui.SetNextItemWidth(100)
        if ImGui.BeginCombo("Rule", tempValues.Rule) then
            for i, v in ipairs(settingList) do
                if ImGui.Selectable(v, tempValues.Rule == v) then
                    tempValues.Rule = v
                end
            end
            ImGui.EndCombo()
        end

        if tempValues.Rule == "Quest" then
            ImGui.SameLine()
            ImGui.SetNextItemWidth(100)
            tempValues.Qty = ImGui.InputInt("QuestQty", tempValues.Qty, 1, 1)
            if tempValues.Qty > 0 then
                questRule = string.format("Quest|%s", tempValues.Qty)
            end
        end

        if ImGui.Button("Set Rule") then
            local newRule = tempValues.Rule == "Quest" and questRule or tempValues.Rule
            if tempValues.Classes == nil or tempValues.Classes == '' or loot.TempModClass then
                tempValues.Classes = "All"
            end
            -- loot.modifyItemRule(loot.TempSettings.ModifyItemID, newRule, loot.TempSettings.ModifyItemTable, tempValues.Classes, item.Link)
            if loot.TempSettings.ModifyItemTable == loot.PersonalTableName then
                loot.PersonalItemsRules[loot.TempSettings.ModifyItemID] = newRule
                loot.setPersonalItem(loot.TempSettings.ModifyItemID, newRule, tempValues.Classes, item.Link)
            elseif loot.TempSettings.ModifyItemTable == "Global_Items" then
                loot.GlobalItemsRules[loot.TempSettings.ModifyItemID] = newRule
                loot.setGlobalItem(loot.TempSettings.ModifyItemID, newRule, tempValues.Classes, item.Link)
            else
                loot.NormalItemsRules[loot.TempSettings.ModifyItemID] = newRule
                loot.setNormalItem(loot.TempSettings.ModifyItemID, newRule, tempValues.Classes, item.Link)
            end
            -- loot.setNormalItem(loot.TempSettings.ModifyItemID, newRule,  tempValues.Classes, item.Link)
            loot.TempSettings.ModifyItemRule = false
            loot.TempSettings.ModifyItemID = nil
            loot.TempSettings.ModifyItemTable = nil
            loot.TempSettings.ModifyItemClasses = 'All'
            loot.TempSettings.ModifyItemName = nil
            loot.TempSettings.ModifyItemLink = nil
            loot.TempModClass = false
            if colCount > 0 then ImGui.PopStyleColor(colCount) end
            if styCount > 0 then ImGui.PopStyleVar(styCount) end

            ImGui.End()
            return
        end
        ImGui.SameLine()

        ImGui.PushStyleColor(ImGuiCol.Button, ImVec4(1.0, 0.4, 0.4, 0.4))
        if ImGui.Button(Icons.FA_TRASH) then
            if loot.TempSettings.ModifyItemTable == loot.PersonalTableName then
                loot.PersonalItemsRules[loot.TempSettings.ModifyItemID] = nil
                loot.setPersonalItem(loot.TempSettings.ModifyItemID, 'delete', 'All', 'NULL')
            elseif loot.TempSettings.ModifyItemTable == "Global_Items" then
                -- loot.GlobalItemsRules[loot.TempSettings.ModifyItemID] = nil
                loot.setGlobalItem(loot.TempSettings.ModifyItemID, 'delete', 'All', 'NULL')
            else
                loot.setNormalItem(loot.TempSettings.ModifyItemID, 'delete', 'All', 'NULL')
            end
            loot.TempSettings.ModifyItemRule = false
            loot.TempSettings.ModifyItemID = nil
            loot.TempSettings.ModifyItemTable = nil
            loot.TempSettings.ModifyItemClasses = 'All'
            ImGui.PopStyleColor()
            if colCount > 0 then ImGui.PopStyleColor(colCount) end
            if styCount > 0 then ImGui.PopStyleVar(styCount) end

            ImGui.End()
            return
        end
        ImGui.PopStyleColor()

        ImGui.SameLine()
        if ImGui.Button("Cancel") then
            loot.TempSettings.ModifyItemRule = false
            loot.TempSettings.ModifyItemID = nil
            loot.TempSettings.ModifyItemTable = nil
            loot.TempSettings.ModifyItemClasses = 'All'
            loot.TempSettings.ModifyItemName = nil
            loot.TempSettings.ModifyItemLink = nil
        end
    end
    if not open then
        loot.TempSettings.ModifyItemRule = false
        loot.TempSettings.ModifyItemID = nil
        loot.TempSettings.ModifyItemTable = nil
        loot.TempSettings.ModifyItemClasses = 'All'
        loot.TempSettings.ModifyItemName = nil
        loot.TempSettings.ModifyItemLink = nil
    end
    if colCount > 0 then ImGui.PopStyleColor(colCount) end
    if styCount > 0 then ImGui.PopStyleVar(styCount) end
    ImGui.End()
end

function loot.drawNewItemsTable()
    local itemsToRemove = {}
    if loot.NewItems == nil then loot.showNewItem = false end
    if #loot.NewItems < 0 then
        loot.showNewItem = false
        loot.NewItemsCount = 0
    end
    if loot.NewItemsCount > 0 then
        if ImGui.BeginTable('##newItemTable', 3, bit32.bor(
                ImGuiTableFlags.Borders, ImGuiTableFlags.ScrollX,
                -- ImGuiTableFlags.ScrollY, -- ImGuiTableFlags.Resizable,
                ImGuiTableFlags.Reorderable,
                ImGuiTableFlags.RowBg)) then
            -- Setup Table Columns
            ImGui.TableSetupColumn('Item', bit32.bor(ImGuiTableColumnFlags.WidthStretch), 130)
            ImGui.TableSetupColumn('Classes', ImGuiTableColumnFlags.NoResize, 150)
            ImGui.TableSetupColumn('Rule', bit32.bor(ImGuiTableColumnFlags.NoResize), 90)
            ImGui.TableHeadersRow()

            -- Iterate Over New Items
            for itemID, item in pairs(loot.NewItems) do
                -- Ensure tmpRules has a default value
                if itemID == nil or item == nil then
                    Logger.log_error("Invalid item in NewItems table: %s", itemID)
                    loot.NewItemsCount = 0
                    break
                end
                ImGui.PushID(itemID)
                tmpRules[itemID] = tmpRules[itemID] or item.Rule or settingList[1]
                if loot.tempLootAll == nil then
                    loot.tempLootAll = {}
                end
                ImGui.TableNextRow()
                -- Item Name and Link
                ImGui.TableNextColumn()

                ImGui.Indent(2)

                loot.drawIcon(item.Icon, 20)
                if ImGui.IsItemHovered() and ImGui.IsMouseClicked(0) then
                    -- if ImGui.SmallButton(Icons.FA_EYE .. "##" .. itemID) then
                    mq.cmdf('/executelink %s', item.Link)
                end
                ImGui.SameLine()
                ImGui.Text(item.Name or "Unknown")

                ImGui.Unindent(2)
                ImGui.Indent(2)

                if ImGui.BeginTable("SellData", 2, bit32.bor(ImGuiTableFlags.Borders,
                        ImGuiTableFlags.Reorderable)) then
                    ImGui.TableSetupColumn('Value', ImGuiTableColumnFlags.WidthStretch)
                    ImGui.TableSetupColumn('Stacks', ImGuiTableColumnFlags.WidthFixed, 30)
                    ImGui.TableHeadersRow()
                    ImGui.TableNextRow()

                    -- Item Name and link
                    ImGui.TableNextColumn()
                    if ImGui.SmallButton(Icons.FA_EYE .. "##" .. name) then
                        Core.DoCmd('/executelink %s', tmpLinks[name])
                    end
                    ImGui.SameLine()
                    ImGui.Text(name)

                    -- Rule
                    ImGui.TableNextColumn()
                    if item.selectedIndex == nil then
                        for i, setting in ipairs(settingList) do
                            if item.Rule == setting then
                                item.selectedIndex = i
                                break
                            end
                        end
                    end
                    ImGui.EndCombo()
                end
                ImGui.Unindent(2)

                ImGui.Spacing()
                ImGui.Spacing()

                ImGui.SetCursorPosX(ImGui.GetCursorPosX() + (ImGui.GetColumnWidth(-1) / 6))
                ImGui.PushStyleColor(ImGuiCol.Button, ImVec4(0.040, 0.294, 0.004, 1.000))
                if ImGui.Button('Save Rule') then
                    local classes = loot.tempLootAll[itemID] and "All" or tmpClasses[itemID]


                    loot.addRule(itemID, "NormalItems", tmpRules[itemID], classes, item.Link)
                    loot.enterNewItemRuleInfo({
                        ID = itemID,
                        ItemName = item.Name,
                        Rule = tmpRules[itemID],
                        Classes = classes,
                        Link = item.Link,
                        CorpseID = item.CorpseID,
                    })
                    table.insert(itemsToRemove, itemID)
                    Logger.log_debug("\agSaving\ax --\ayNEW ITEM RULE\ax-- Item: \at%s \ax(ID:\ag %s\ax) with rule: \at%s\ax, classes: \at%s\ax, link: \at%s\ax",
                        item.Name, itemID, tmpRules[itemID], tmpClasses[itemID], item.Link)
                end
                ImGui.PopStyleColor()
                ImGui.PopID()
            end


            ImGui.EndTable()
        end
    end

    -- Remove Processed Items
    for _, itemID in ipairs(itemsToRemove) do
        loot.NewItems[itemID]    = nil
        tmpClasses[itemID]       = nil
        tmpRules[itemID]         = nil
        tmpLinks[itemID]         = nil
        loot.tempLootAll[itemID] = nil
        -- loot.NewItemsCount       = loot.NewItemsCount - 1
    end

    -- Update New Items Count
    if loot.NewItemsCount < 0 then loot.NewItemsCount = 0 end
    if loot.NewItemsCount == 0 then loot.showNewItem = false end
end

function loot.SafeText(write_value)
    local tmpValue = write_value
    if write_value == nil then
        tmpValue = "N/A"
    end
    if tostring(write_value) == 'true' then
        ImGui.TextColored(ImVec4(0.0, 1.0, 0.0, 1.0), "True")
    elseif tostring(write_value) == 'false' or tostring(write_value) == '0' or tostring(write_value) == 'None' then
    elseif tmpValue == "N/A" then
        ImGui.Indent()
        ImGui.TextColored(ImVec4(1.0, 0.0, 0.0, 1.0), tmpValue)
        ImGui.Unindent()
    else
        ImGui.Indent()
        ImGui.Text(tmpValue)
        ImGui.Unindent()
    end
end

function loot.drawTable(label)
    local varSub = label .. 'Items'
    if ImGui.BeginTabItem(varSub .. "##") then
        if loot.TempSettings.varSub == nil then
            loot.TempSettings.varSub = {}
        end
        if loot.TempSettings[varSub .. 'Classes'] == nil then
            loot.TempSettings[varSub .. 'Classes'] = {}
        end
        local sizeX, _ = ImGui.GetContentRegionAvail()
        ImGui.PushStyleColor(ImGuiCol.ChildBg, ImVec4(0.0, 0.6, 0.0, 0.1))
        if ImGui.BeginChild("Add Rule Drop Area", ImVec2(sizeX, 40), ImGuiChildFlags.Border) then
            ImGui.TextDisabled("Drop Item Here to Add to a %s Rule", label)
            if ImGui.IsWindowHovered() and ImGui.IsMouseClicked(0) then
                if mq.TLO.Cursor() ~= nil then
                    local itemCursor = mq.TLO.Cursor
                    loot.addToItemDB(mq.TLO.Cursor)
                    loot.TempSettings.ModifyItemRule = true
                    loot.TempSettings.ModifyItemName = itemCursor.Name()
                    loot.TempSettings.ModifyItemLink = itemCursor.ItemLink('CLICKABLE')() or "NULL"
                    loot.TempSettings.ModifyItemID = itemCursor.ID()
                    loot.TempSettings.ModifyItemTable = label .. "_Items"
                    loot.TempSettings.ModifyClasses = loot.ALLITEMS[itemCursor.ID()].ClassList or "All"
                    loot.TempSettings.ModifyItemSetting = "Ask"
                    tempValues = {}
                    mq.cmdf("/autoinv")
                end
            end
        end
        ImGui.EndChild()
        ImGui.PopStyleColor()

        ImGui.PushID(varSub .. 'Search')
        ImGui.SetNextItemWidth(180)
        loot.TempSettings['Search' .. varSub] = ImGui.InputTextWithHint("Search", "Search by Name or Rule",
            loot.TempSettings['Search' .. varSub]) or nil
        ImGui.PopID()
        if ImGui.IsItemHovered() and mq.TLO.Cursor() then
            loot.TempSettings['Search' .. varSub] = mq.TLO.Cursor()
            mq.cmdf("/autoinv")
        end

        ImGui.SameLine()

        if ImGui.SmallButton(Icons.MD_DELETE_SWEEP) then
            loot.TempSettings['Search' .. varSub] = nil
        end
        if ImGui.IsItemHovered() then ImGui.SetTooltip("Clear Search") end

        local col = 3
        col = math.max(3, math.floor(ImGui.GetContentRegionAvail() / 140))
        local colCount = col + (col % 3)
        if colCount % 3 ~= 0 then
            if (colCount - 1) % 3 == 0 then
                colCount = colCount - 1
            else
                colCount = colCount - 2
            end
        end

        local filteredItems = {}
        local filteredItemKeys = {}
        for id, rule in pairs(loot[varSub .. 'Rules']) do
            if loot.SearchLootTable(loot.TempSettings['Search' .. varSub], loot.ItemNames[id], rule) then
                local iconID = 0
                local itemLink = ''
                if loot.ALLITEMS[id] then
                    iconID = loot.ALLITEMS[id].Icon or 0
                    itemLink = loot.ALLITEMS[id].Link or ''
                end
                if loot[varSub .. 'Link'][id] then
                    itemLink = loot[varSub .. 'Link'][id]
                end
                table.insert(filteredItems, {
                    id = id,
                    data = loot.ItemNames[id],
                    setting = loot[varSub .. 'Rules'][id],
                    icon = iconID,
                    link = itemLink,
                })
                table.insert(filteredItemKeys, loot.ItemNames[id])
            end
        end
        table.sort(filteredItems, function(a, b) return a.data < b.data end)

        local totalItems = #filteredItems
        local totalPages = math.ceil(totalItems / ITEMS_PER_PAGE)

        -- Clamp CurrentPage to valid range
        loot.CurrentPage = math.max(1, math.min(loot.CurrentPage, totalPages))

        -- Navigation buttons
        if ImGui.Button(Icons.FA_BACKWARD) then
            loot.CurrentPage = 1
        end
        ImGui.SameLine()
        if ImGui.ArrowButton("##Previous", ImGuiDir.Left) and loot.CurrentPage > 1 then
            loot.CurrentPage = loot.CurrentPage - 1
        end
        ImGui.SameLine()
        ImGui.Text(("Page %d of %d"):format(loot.CurrentPage, totalPages))
        ImGui.SameLine()
        if ImGui.ArrowButton("##Next", ImGuiDir.Right) and loot.CurrentPage < totalPages then
            loot.CurrentPage = loot.CurrentPage + 1
        end
        ImGui.SameLine()
        if ImGui.Button(Icons.FA_FORWARD) then
            loot.CurrentPage = totalPages
        end

        ImGui.SameLine()
        ImGui.SetNextItemWidth(80)
        if ImGui.BeginCombo("Max Items", tostring(ITEMS_PER_PAGE)) then
            for i = 25, 100, 25 do
                if ImGui.Selectable(tostring(i), ITEMS_PER_PAGE == i) then
                    ITEMS_PER_PAGE = i
                end
            end
            ImGui.EndCombo()
        end
        -- Calculate the range of items to display
        local startIndex = (loot.CurrentPage - 1) * ITEMS_PER_PAGE + 1
        local endIndex = math.min(startIndex + ITEMS_PER_PAGE - 1, totalItems)


        if ImGui.BeginTable(label .. " Items", colCount, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.Resizable, ImGuiTableFlags.ScrollY), ImVec2(0.0, 0.0)) then
            ImGui.TableSetupScrollFreeze(colCount, 1)
            for i = 1, colCount / 3 do
                ImGui.TableSetupColumn("Item", ImGuiTableColumnFlags.WidthStretch)
                ImGui.TableSetupColumn("Rule", ImGuiTableColumnFlags.WidthFixed, 40)
                ImGui.TableSetupColumn('Classes', ImGuiTableColumnFlags.WidthFixed, 90)
            end
            ImGui.TableHeadersRow()

            if loot[label .. 'ItemsRules'] ~= nil then
                for i = startIndex, endIndex do
                    local itemID = filteredItems[i].id
                    local item = filteredItems[i].data
                    local setting = filteredItems[i].setting
                    local iconID = filteredItems[i].icon
                    local itemLink = filteredItems[i].link

                    ImGui.PushID(itemID)
                    local classes = loot[label .. 'ItemsClasses'][itemID] or "All"
                    local itemName = loot.ItemNames[itemID] or item.Name
                    if loot.SearchLootTable(loot.TempSettings['Search' .. varSub], item, setting) then
                        ImGui.TableNextColumn()
                        ImGui.Indent(2)
                        local btnColor, btnText = ImVec4(0.0, 0.6, 0.0, 0.4), Icons.FA_PENCIL
                        if loot.ALLITEMS[itemID] == nil then
                            btnColor, btnText = ImVec4(0.6, 0.0, 0.0, 0.4), Icons.MD_CLOSE
                        end
                        ImGui.PushStyleColor(ImGuiCol.Button, btnColor)
                        if ImGui.SmallButton(btnText) then
                            loot.TempSettings.ModifyItemRule = true
                            loot.TempSettings.ModifyItemName = itemName
                            loot.TempSettings.ModifyItemLink = itemLink
                            loot.TempSettings.ModifyItemID = itemID
                            loot.TempSettings.ModifyItemTable = label .. "_Items"
                            loot.TempSettings.ModifyClasses = classes
                            loot.TempSettings.ModifyItemSetting = setting
                            tempValues = {}
                        end
                        ImGui.PopStyleColor()

                        ImGui.SameLine()
                        if iconID then
                            loot.drawIcon(iconID, iconSize * fontScale) -- icon
                        else
                            loot.drawIcon(4493, iconSize * fontScale)   -- icon
                        end
                        if ImGui.IsItemHovered() and ImGui.IsMouseClicked(0) then
                            mq.cmdf('/executelink %s', itemLink)
                        end
                        ImGui.SameLine(0, 0)

                        ImGui.Text(itemName)
                        if ImGui.IsItemHovered() then
                            loot.DrawRuleToolTip(itemName, setting, classes:upper())

                            if ImGui.IsMouseClicked(1) and itemLink ~= nil then
                                mq.cmdf('/executelink %s', itemLink)
                            end
                            if isSelected then
                                tmpRules[name] = setting
                            end
                        end
                        ImGui.EndCombo()
                    end

                    -- Classes
                    ImGui.TableNextColumn()
                    ImGui.SetNextItemWidth(ImGui.GetColumnWidth(-1))
                    tmpClasses[name] = ImGui.InputText('##Classes' .. name, tmpClasses[name])

                    -- Value
                    ImGui.TableNextColumn()
                    ImGui.Text(item.SellPrice)

                    -- NoDrop
                    ImGui.TableNextColumn()
                    if item.NoDrop then
                        ImGui.TextColored(ImVec4(0.0, 1.0, 1.0, 1.0), 'Yes')
                    else
                        ImGui.TextColored(ImVec4(1.0, 0.0, 0.0, 1.0), 'No')
                    end

                    -- Lore
                    ImGui.TableNextColumn()
                    if item.Lore then
                        ImGui.TextColored(ImVec4(0.0, 1.0, 1.0, 1.0), 'Yes')
                    else
                        ImGui.TextColored(ImVec4(1.0, 0.0, 0.0, 1.0), 'No')
                    end

                    -- Augment
                    ImGui.TableNextColumn()
                    if item.Aug > 0 then
                        ImGui.TextColored(ImVec4(0.0, 1.0, 1.0, 1.0), 'Yes')
                    else
                        ImGui.TextColored(ImVec4(1.0, 0.0, 0.0, 1.0), 'No')
                    end

                    -- TradeSkill
                    ImGui.TableNextColumn()
                    if item.TradeSkill then
                        ImGui.TextColored(ImVec4(0.0, 1.0, 1.0, 1.0), 'Yes')
                    else
                        ImGui.TextColored(ImVec4(1.0, 0.0, 0.0, 1.0), 'No')
                    end

                    -- Save
                    ImGui.TableNextColumn()
                    if ImGui.Button('Save##' .. name) then
                        loot.addRule(name, "NormalItems", tmpRules[name], tmpClasses[name], tmpLinks[name])
                        loot.lootActor:send({
                            mailbox = 'lootnscoot',
                        }, {
                            who = Config.Globals.CurLoadedChar,
                            action = 'modifyitem',
                            section = "NormalItems",
                            item = name,
                            rule = tmpRules[name],
                            link = tmpLinks[name],
                            classes = tmpClasses[name],
                        })

                        if lootedCorpses[corpseID] then lootedCorpses[corpseID] = nil end
                        loot.setNormalItem(name, tmpRules[name], tmpClasses[name], tmpLinks[name])
                        loot.lootActor:send({ mailbox = 'lootnscoot', }, { who = Config.Globals.CurLoadedChar, action = 'entered', item = name, corpse = corpseID, })

                        table.insert(itemsToRemove, name) -- Add item to removal list
                    end
                end



            -- Normal Items
            loot.drawTable("Normal")

            -- Personal Items
            loot.drawTable("Personal")

            -- Lookup Items

            if loot.ALLITEMS ~= nil then
                if ImGui.BeginTabItem("Item Lookup") then
                    ImGui.TextWrapped("This is a list of All Items you have Rules for, or have looked up this session from the Items DB")
                    ImGui.Spacing()
                    ImGui.Text("Import your inventory to the DB with /rgl importinv")
                    local sizeX, sizeY = ImGui.GetContentRegionAvail()
                    ImGui.PushStyleColor(ImGuiCol.ChildBg, ImVec4(0.0, 0.6, 0.0, 0.1))
                    if ImGui.BeginChild("Add Item Drop Area", ImVec2(sizeX, 40), ImGuiChildFlags.Border) then
                        ImGui.TextDisabled("Drop Item Here to Add to DB")
                        if ImGui.IsWindowHovered() and ImGui.IsMouseClicked(0) then
                            if mq.TLO.Cursor() ~= nil then
                                loot.addToItemDB(mq.TLO.Cursor)
                                Logger.log_info("Added Item to DB: %s", mq.TLO.Cursor.Name())
                                mq.cmdf("/autoinv")
                            end
                        end
                    end
                    ImGui.EndChild()
                    ImGui.PopStyleColor()

                    -- search field
                    ImGui.PushID("DBLookupSearch")
                    ImGui.SetNextItemWidth(180)

                    loot.TempSettings.SearchItems = ImGui.InputTextWithHint("Search Items##AllItems", "Lookup Name or Filter Class",
                        loot.TempSettings.SearchItems) or nil
                    ImGui.PopID()
                    if ImGui.IsItemHovered() and mq.TLO.Cursor() then
                        loot.TempSettings.SearchItems = mq.TLO.Cursor.Name()
                        mq.cmdf("/autoinv")
                    end
                    ImGui.SameLine()

                    if ImGui.SmallButton(Icons.MD_DELETE_SWEEP) then
                        loot.TempSettings.SearchItems = nil
                    end
                    if ImGui.IsItemHovered() then ImGui.SetTooltip("Clear Search") end

                    ImGui.SameLine()

                    ImGui.PushStyleColor(ImGuiCol.Button, ImVec4(0.78, 0.20, 0.05, 0.6))
                    if ImGui.SmallButton("LookupItem##AllItems") then
                        loot.TempSettings.LookUpItem = true
                    end
                    ImGui.PopStyleColor()
                    if ImGui.IsItemHovered() then ImGui.SetTooltip("Lookup Item in DB") end

                    -- setup the filteredItems for sorting
                    local filteredItems = {}
                    for id, item in pairs(loot.ALLITEMS) do
                        if loot.SearchLootTable(loot.TempSettings.SearchItems, item.Name, item.ClassList) then
                            table.insert(filteredItems, { id = id, data = item, })
                        end
                    end
                    table.sort(filteredItems, function(a, b) return a.data.Name < b.data.Name end)
                    -- Calculate total pages
                    local totalItems = #filteredItems
                    local totalPages = math.ceil(totalItems / ITEMS_PER_PAGE)

                    -- Clamp CurrentPage to valid range
                    loot.CurrentPage = math.max(1, math.min(loot.CurrentPage, totalPages))

                    -- Navigation buttons
                    if ImGui.Button(Icons.FA_BACKWARD) then
                        loot.CurrentPage = 1
                    end
                    ImGui.SameLine()
                    if ImGui.ArrowButton("##Previous", ImGuiDir.Left) and loot.CurrentPage > 1 then
                        loot.CurrentPage = loot.CurrentPage - 1
                    end
                    ImGui.SameLine()
                    ImGui.Text(("Page %d of %d"):format(loot.CurrentPage, totalPages))
                    ImGui.SameLine()
                    if ImGui.ArrowButton("##Next", ImGuiDir.Right) and loot.CurrentPage < totalPages then
                        loot.CurrentPage = loot.CurrentPage + 1
                    end
                    ImGui.SameLine()
                    if ImGui.Button(Icons.FA_FORWARD) then
                        loot.CurrentPage = totalPages
                    end

                    ImGui.SameLine()
                    ImGui.SetNextItemWidth(80)
                    if ImGui.BeginCombo("Max Items", tostring(ITEMS_PER_PAGE)) then
                        for i = 25, 100, 25 do
                            if ImGui.Selectable(tostring(i), ITEMS_PER_PAGE == i) then
                                ITEMS_PER_PAGE = i
                            end
                        end
                        ImGui.EndCombo()
                    end

                    -- Calculate the range of items to display
                    local startIndex = (loot.CurrentPage - 1) * ITEMS_PER_PAGE + 1
                    local endIndex = math.min(startIndex + ITEMS_PER_PAGE - 1, totalItems)

                    -- Render the table
                    if ImGui.BeginTable("DB", 59, bit32.bor(ImGuiTableFlags.Borders,
                            ImGuiTableFlags.Hideable, ImGuiTableFlags.Resizable, ImGuiTableFlags.ScrollX, ImGuiTableFlags.ScrollY, ImGuiTableFlags.Reorderable)) then
                        -- Set up column headers
                        for idx, label in pairs(loot.AllItemColumnListIndex) do
                            if label == 'name' then
                                ImGui.TableSetupColumn(label, ImGuiTableColumnFlags.NoHide)
                            else
                                ImGui.TableSetupColumn(label, ImGuiTableColumnFlags.DefaultHide)
                            end
                        end
                        ImGui.TableSetupScrollFreeze(1, 1)
                        ImGui.TableHeadersRow()

                        -- Render only the current page's items
                        for i = startIndex, endIndex do
                            local id = filteredItems[i].id
                            local item = filteredItems[i].data

                            ImGui.PushID(id)

                            -- Render each column for the item
                            ImGui.TableNextColumn()
                            ImGui.Indent(2)
                            loot.drawIcon(item.Icon, iconSize * fontScale)
                            if ImGui.IsItemHovered() and ImGui.IsMouseClicked(0) then
                                mq.cmdf('/executelink %s', item.Link)
                            end
                            ImGui.SameLine()
                            if ImGui.Selectable(item.Name, false) then
                                loot.TempSettings.ModifyItemRule = true
                                loot.TempSettings.ModifyItemID = id
                                loot.TempSettings.ModifyClasses = item.ClassList
                                loot.TempSettings.ModifyItemRaceList = item.RaceList
                                tempValues = {}
                            end
                            if ImGui.IsItemHovered() and ImGui.IsMouseClicked(1) then
                                mq.cmdf('/executelink %s', item.Link)
                            end
                            ImGui.Unindent(2)
                            ImGui.TableNextColumn()
                            -- sell_value
                            if item.Value ~= '0 pp 0 gp 0 sp 0 cp' then
                                loot.SafeText(item.Value)
                            end
                            ImGui.TableNextColumn()
                            loot.SafeText(item.Tribute)     -- tribute_value
                            ImGui.TableNextColumn()
                            loot.SafeText(item.Stackable)   -- stackable
                            ImGui.TableNextColumn()
                            loot.SafeText(item.StackSize)   -- stack_size
                            ImGui.TableNextColumn()
                            loot.SafeText(item.NoDrop)      -- nodrop
                            ImGui.TableNextColumn()
                            loot.SafeText(item.NoTrade)     -- notrade
                            ImGui.TableNextColumn()
                            loot.SafeText(item.Tradeskills) -- tradeskill
                            ImGui.TableNextColumn()
                            loot.SafeText(item.Quest)       -- quest
                            ImGui.TableNextColumn()
                            loot.SafeText(item.Lore)        -- lore
                            ImGui.TableNextColumn()
                            loot.SafeText(item.Collectible) -- collectible
                            ImGui.TableNextColumn()
                            loot.SafeText(item.Augment)     -- augment
                            ImGui.TableNextColumn()
                            loot.SafeText(item.AugType)     -- augtype
                            ImGui.TableNextColumn()
                            loot.SafeText(item.Clicky)      -- clickable
                            ImGui.TableNextColumn()
                            local tmpWeight = item.Weight ~= nil and item.Weight or 0
                            loot.SafeText(tmpWeight)      -- weight
                            ImGui.TableNextColumn()
                            loot.SafeText(item.AC)        -- ac
                            ImGui.TableNextColumn()
                            loot.SafeText(item.Damage)    -- damage
                            ImGui.TableNextColumn()
                            loot.SafeText(item.STR)       -- strength
                            ImGui.TableNextColumn()
                            loot.SafeText(item.DEX)       -- dexterity
                            ImGui.TableNextColumn()
                            loot.SafeText(item.AGI)       -- agility
                            ImGui.TableNextColumn()
                            loot.SafeText(item.STA)       -- stamina
                            ImGui.TableNextColumn()
                            loot.SafeText(item.INT)       -- intelligence
                            ImGui.TableNextColumn()
                            loot.SafeText(item.WIS)       -- wisdom
                            ImGui.TableNextColumn()
                            loot.SafeText(item.CHA)       -- charisma
                            ImGui.TableNextColumn()
                            loot.SafeText(item.HP)        -- hp
                            ImGui.TableNextColumn()
                            loot.SafeText(item.HPRegen)   -- regen_hp
                            ImGui.TableNextColumn()
                            loot.SafeText(item.Mana)      -- mana
                            ImGui.TableNextColumn()
                            loot.SafeText(item.ManaRegen) -- regen_mana
                            ImGui.TableNextColumn()
                            loot.SafeText(item.Haste)     -- haste
                            ImGui.TableNextColumn()
                            loot.SafeText(item.Classes)   -- classes
                            ImGui.TableNextColumn()
                            -- class_list
                            local tmpClassList = item.ClassList ~= nil and item.ClassList or "All"
                            if tmpClassList:lower() ~= 'all' then
                                ImGui.Indent(2)
                                ImGui.TextColored(ImVec4(0, 1, 1, 0.8), tmpClassList)
                                ImGui.Unindent(2)
                            else
                                ImGui.Indent(2)
                                ImGui.TextDisabled(tmpClassList)
                                ImGui.Unindent(2)
                            end
                            if ImGui.IsItemHovered() then
                                ImGui.BeginTooltip()
                                ImGui.Text(item.Name)
                                ImGui.PushTextWrapPos(200)
                                ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(0, 1, 1, 0.8))
                                ImGui.TextWrapped("Classes: %s", tmpClassList)
                                ImGui.PopStyleColor()
                                ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(0.852, 0.589, 0.259, 1.000))
                                ImGui.TextWrapped("Races: %s", item.RaceList)
                                ImGui.PopStyleColor()
                                ImGui.PopTextWrapPos()
                                ImGui.EndTooltip()
                            end
                            ImGui.TableNextColumn()
                            loot.SafeText(item.svFire)          -- svfire
                            ImGui.TableNextColumn()
                            loot.SafeText(item.svCold)          -- svcold
                            ImGui.TableNextColumn()
                            loot.SafeText(item.svDisease)       -- svdisease
                            ImGui.TableNextColumn()
                            loot.SafeText(item.svPoison)        -- svpoison
                            ImGui.TableNextColumn()
                            loot.SafeText(item.svCorruption)    -- svcorruption
                            ImGui.TableNextColumn()
                            loot.SafeText(item.svMagic)         -- svmagic
                            ImGui.TableNextColumn()
                            loot.SafeText(item.SpellDamage)     -- spelldamage
                            ImGui.TableNextColumn()
                            loot.SafeText(item.SpellShield)     -- spellshield
                            ImGui.TableNextColumn()
                            loot.SafeText(item.Size)            -- item_size
                            ImGui.TableNextColumn()
                            loot.SafeText(item.WeightReduction) -- weightreduction
                            ImGui.TableNextColumn()
                            loot.SafeText(item.Races)           -- races
                            ImGui.TableNextColumn()
                            -- race_list
                            if item.RaceList ~= nil then
                                if item.RaceList:lower() ~= 'all' then
                                    ImGui.Indent(2)
                                    ImGui.TextColored(ImVec4(0.852, 0.589, 0.259, 1.000), item.RaceList)
                                    ImGui.Unindent(2)
                                else
                                    ImGui.Indent(2)
                                    ImGui.TextDisabled(item.RaceList)
                                    ImGui.Unindent(2)
                                end
                                if ImGui.IsItemHovered() then
                                    ImGui.BeginTooltip()
                                    ImGui.Text(item.Name)
                                    ImGui.PushTextWrapPos(200)
                                    ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(0, 1, 1, 0.8))
                                    ImGui.TextWrapped("Classes: %s", tmpClassList)
                                    ImGui.PopStyleColor()
                                    ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(0.852, 0.589, 0.259, 1.000))
                                    ImGui.TextWrapped("Races: %s", item.RaceList)
                                    ImGui.PopStyleColor()
                                    ImGui.PopTextWrapPos()
                                    ImGui.EndTooltip()
                                end
                            end
                            ImGui.TableNextColumn()

                            loot.SafeText(item.Range)              -- item_range
                            ImGui.TableNextColumn()
                            loot.SafeText(item.Attack)             -- attack
                            ImGui.TableNextColumn()
                            loot.SafeText(item.StrikeThrough)      -- strikethrough
                            ImGui.TableNextColumn()
                            loot.SafeText(item.HeroicAGI)          -- heroicagi
                            ImGui.TableNextColumn()
                            loot.SafeText(item.HeroicCHA)          -- heroiccha
                            ImGui.TableNextColumn()
                            loot.SafeText(item.HeroicDEX)          -- heroicdex
                            ImGui.TableNextColumn()
                            loot.SafeText(item.HeroicINT)          -- heroicint
                            ImGui.TableNextColumn()
                            loot.SafeText(item.HeroicSTA)          -- heroicsta
                            ImGui.TableNextColumn()
                            loot.SafeText(item.HeroicSTR)          -- heroicstr
                            ImGui.TableNextColumn()
                            loot.SafeText(item.HeroicSvCold)       -- heroicsvcold
                            ImGui.TableNextColumn()
                            loot.SafeText(item.HeroicSvCorruption) -- heroicsvcorruption
                            ImGui.TableNextColumn()
                            loot.SafeText(item.HeroicSvDisease)    -- heroicsvdisease
                            ImGui.TableNextColumn()
                            loot.SafeText(item.HeroicSvFire)       -- heroicsvfire
                            ImGui.TableNextColumn()
                            loot.SafeText(item.HeroicSvMagic)      -- heroicsvmagic
                            ImGui.TableNextColumn()
                            loot.SafeText(item.HeroicSvPoison)     -- heroicsvpoison
                            ImGui.TableNextColumn()
                            loot.SafeText(item.HeroicWIS)          -- heroicwis

                            ImGui.PopID()
                        end
                        ImGui.EndTable()
                    end
                    ImGui.EndTabItem()
                end
            end
        end
        -- Remove items after iteration
        for _, name in ipairs(itemsToRemove) do
            loot.NewItems[name] = nil
            tmpClasses[name] = nil
            tmpRules[name] = nil
            tmpLinks[name] = nil
            newItemsCount = newItemsCount - 1
        end

        if newItemsCount < 0 then newItemsCount = 0 end
        if newItemsCount == 0 then showNewItem = false end
    end

function loot.drawSwitch(settingName, who)
    if who == MyName then
        if loot.Settings[settingName] then
            ImGui.TextColored(0.3, 1.0, 0.3, 0.9, Icons.FA_TOGGLE_ON)
        else
            ImGui.TextColored(1.0, 0.3, 0.3, 0.8, Icons.FA_TOGGLE_OFF)
        end
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip("%s %s", settingName, loot.Settings[settingName] and "Enabled" or "Disabled")
        end
        if ImGui.IsItemHovered() and ImGui.IsMouseClicked(0) then
            loot.Settings[settingName] = not loot.Settings[settingName]
            loot.TempSettings.NeedSave = true
        end
    elseif loot.Boxes[who] ~= nil then
        if loot.Boxes[who][settingName] then
            ImGui.TextColored(0.3, 1.0, 0.3, 0.9, Icons.FA_TOGGLE_ON)
        else
            ImGui.TextColored(1.0, 0.3, 0.3, 0.8, Icons.FA_TOGGLE_OFF)
        end
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip("%s %s", settingName, loot.Boxes[who][settingName] and "Enabled" or "Disabled")
        end
        if ImGui.IsItemHovered() and ImGui.IsMouseClicked(0) then
            loot.Boxes[who][settingName] = not loot.Boxes[who][settingName]
        end
    end
end

loot.TempSettings.Edit = {}
function loot.renderSettingsSection(who)
    if who == nil then who = MyName end
    local col = 2
    col = math.max(2, math.floor(ImGui.GetContentRegionAvail() / 140))
    local colCount = col + (col % 2)
    if colCount % 2 ~= 0 then
        if (colCount - 1) % 2 == 0 then
            colCount = colCount - 1
        else
            colCount = colCount - 2
        end
    end
    ImGui.SameLine()
    if ImGui.SmallButton("Send Settings##LootnScoot") then
        if who == MyName then
            for k, v in pairs(loot.Boxes[MyName]) do
                if type(v) == 'table' then
                    for k2, v2 in pairs(v) do
                        loot.Settings[k][k2] = v2
                    end
                else
                    loot.Settings[k] = v
                end
            end
            loot.writeSettings()
            loot.sendMySettings()
        else
            local tmpSet = {}
            for k, v in pairs(loot.Boxes[who]) do
                if type(v) == 'table' then
                    tmpSet[k] = {}
                    for k2, v2 in pairs(v) do
                        tmpSet[k][k2] = v2
                    end
                else
                    tmpSet[k] = v
                end
            end
            loot.lootActor:send({ mailbox = 'lootnscoot', }, {
                action = 'updatesettings',
                who = who,
                settings = tmpSet,
            })
        end
    end
    ImGui.SeparatorText("Clone Settings")
    ImGui.SetNextItemWidth(120)
    if ImGui.BeginCombo('Who to Clone', loot.TempSettings.CloneWho) then
        for k, v in pairs(loot.Boxes) do
            if ImGui.Selectable(k, loot.TempSettings.CloneWho == k) then
                loot.TempSettings.CloneWho = k
            end
        end
        ImGui.EndCombo()
    end
    ImGui.SameLine()
    ImGui.SetNextItemWidth(120)
    if ImGui.BeginCombo('Clone To', loot.TempSettings.CloneTo) then
        for k, v in pairs(loot.Boxes) do
            if ImGui.Selectable(k, loot.TempSettings.CloneTo == k) then
                loot.TempSettings.CloneTo = k
            end
        end
        ImGui.EndCombo()
    end
    ImGui.SameLine()
    if ImGui.SmallButton("Clone Settings") then
        loot.Boxes[loot.TempSettings.CloneTo] = {}
        for k, v in pairs(loot.Boxes[loot.TempSettings.CloneWho]) do
            if type(v) == 'table' then
                loot.Boxes[loot.TempSettings.CloneTo][k] = {}
                for k2, v2 in pairs(v) do
                    loot.Boxes[loot.TempSettings.CloneTo][k][k2] = v2
                end
            else
                loot.Boxes[loot.TempSettings.CloneTo][k] = v
            end
        end
        local tmpSet = {}
        for k, v in pairs(loot.Boxes[loot.TempSettings.CloneTo]) do
            if type(v) == 'table' then
                tmpSet[k] = {}
                for k2, v2 in pairs(v) do
                    tmpSet[k][k2] = v2
                end
            else
                tmpSet[k] = v
            end
        end
        loot.lootActor:send({ mailbox = 'lootnscoot', }, {
            action = 'updatesettings',
            who = loot.TempSettings.CloneTo,
            settings = tmpSet,
        })
        loot.TempSettings.CloneTo = nil
    end

    local sorted_names = loot.SortTableColums(loot.Boxes[who], loot.TempSettings.SortedSettingsKeys, colCount / 2)

    if ImGui.BeginTable("Settings##1", colCount, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.Resizable, ImGuiTableFlags.ScrollY)) then
        ImGui.TableSetupScrollFreeze(colCount, 1)
        for i = 1, colCount / 2 do
            ImGui.TableSetupColumn("Setting", ImGuiTableColumnFlags.WidthStretch)
            ImGui.TableSetupColumn("Value", ImGuiTableColumnFlags.WidthFixed, 80)
        end
        ImGui.TableHeadersRow()

        for i, settingName in ipairs(sorted_names) do
            if settingsNoDraw[settingName] == nil or settingsNoDraw[settingName] == false then
                ImGui.PushID(i .. settingName)
                ImGui.TableNextColumn()
                ImGui.Indent(2)
                if ImGui.Selectable(settingName) then
                    if type(loot.Boxes[who][settingName]) == "boolean" then
                        loot.Boxes[who][settingName] = not loot.Boxes[who][settingName]
                        if who == MyName then
                            loot.Settings[settingName] = loot.Boxes[who][settingName]
                            loot.TempSettings.NeedSave = true
                        end
                    end
                end
                ImGui.Unindent(2)
                ImGui.TableNextColumn()

                if type(loot.Boxes[who][settingName]) == "boolean" then
                    local posX, posY = ImGui.GetCursorPos()
                    ImGui.SetCursorPosX(posX + (ImGui.GetColumnWidth(-1) / 2) - 5)
                    loot.drawSwitch(settingName, who)
                elseif type(loot.Boxes[who][settingName]) == "number" then
                    ImGui.SetNextItemWidth(ImGui.GetColumnWidth(-1))
                    loot.Boxes[who][settingName] = ImGui.InputInt("##" .. settingName, loot.Boxes[who][settingName])
                elseif type(loot.Boxes[who][settingName]) == "string" then
                    ImGui.SetNextItemWidth(ImGui.GetColumnWidth(-1))
                    loot.Boxes[who][settingName] = ImGui.InputText("##" .. settingName, loot.Boxes[who][settingName])
                end
                ImGui.PopID()
            end
        end
        ImGui.EndTable()
    end
end

function loot.renderNewItem()
    if ((loot.Settings.AutoShowNewItem and loot.NewItemsCount > 0) and loot.showNewItem) or loot.showNewItem then
        local colCount, styCount = loot.guiLoot.DrawTheme()

        ImGui.SetNextWindowSize(600, 400, ImGuiCond.FirstUseEver)
        local open, show = ImGui.Begin('New Items', true)
        if not open then
            show = false
            loot.showNewItem = false
        end
        if show then
            loot.drawNewItemsTable()
        end
        if colCount > 0 then ImGui.PopStyleColor(colCount) end
        if styCount > 0 then ImGui.PopStyleVar(styCount) end
        ImGui.End()
    end
end

local animMini       = mq.FindTextureAnimation("A_DragItem")
local EQ_ICON_OFFSET = 500


local function renderBtn()
    -- apply_style()
    local colCount, styCount = loot.guiLoot.DrawTheme()

    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, ImVec2(9, 9))
    local openBtn, showBtn = ImGui.Begin(string.format("LootNScoot##Mini"), true,
        bit32.bor(ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoCollapse))
    if not openBtn then
        showBtn = false
    end

    if showBtn then
        if loot.NewItemsCount > 0 then
            animMini:SetTextureCell(645 - EQ_ICON_OFFSET)
        else
            animMini:SetTextureCell(644 - EQ_ICON_OFFSET)
        end
        ImGui.DrawTextureAnimation(animMini, 34, 34, true)
    end
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text("LootnScoot")
        ImGui.Text("Click to Show/Hide")
        ImGui.Text("Right Click to Show New Items")
        ImGui.EndTooltip()
        if ImGui.IsMouseReleased(0) then
            loot.ShowUI = not loot.ShowUI
        elseif ImGui.IsMouseReleased(1) and loot.NewItemsCount > 0 then
            loot.showNewItem = not loot.showNewItem
        end
    end

    ImGui.PopStyleVar()
    if colCount > 0 then ImGui.PopStyleColor(colCount) end
    if styCount > 0 then ImGui.PopStyleVar(styCount) end
    ImGui.End()
end

function loot.RenderUIs()
    if loot.NewItemDecisions ~= nil then
        loot.enterNewItemRuleInfo(loot.NewItemDecisions)
        loot.NewItemDecisions = nil
    end
    if loot.TempSettings.ModifyItemRule then loot.RenderModifyItemWindow() end
    loot.renderNewItem()
    if loot.pendingItemData ~= nil then
        loot.processPendingItem()
    end
    loot.renderMainUI()
    renderBtn()
end

function loot.enterNewItemRuleInfo(data_table)
    if data_table == nil then
        if loot.NewItemDecisions == nil then return end
        data_table = loot.NewItemDecisions
    end

    if data_table.ID == nil then
        Logger.log_error("loot.enterNewItemRuleInfo \arInvalid item \atID \axfor new item rule.")
        return
    end
    Logger.log_debug(
        "\aoloot.enterNewItemRuleInfo() \axSending \agNewItem Data\ax message \aoMailbox\ax \atlootnscoot actor\ax: item\at %s \ax, ID\at %s \ax, rule\at %s\ax, classes\at %s\ax, link\at %s\ax, corpseID\at %s\ax",
        data_table.ItemName, data_table.ItemID, data_table.Rule, data_table.Classes, data_table.Link, data_table.CorpseID)

    local itemID     = data_table.ID
    local item       = data_table.ItemName
    local rule       = data_table.Rule
    local classes    = data_table.Classes
    local link       = data_table.Link
    local corpse     = data_table.CorpseID
    local modMessage = {
        who      = MyName,
        action   = 'modifyitem',
        section  = "NormalItems",
        item     = item,
        itemID   = itemID,
        rule     = rule,
        link     = link,
        classes  = classes,
        entered  = true,
        corpse   = corpse,
        noChange = false,
        Server   = eqServer,
    }
    if (classes == loot.NormalItemsClasses[itemID] and rule == loot.NormalItemsRules[itemID]) then
        modMessage.noChange = true

        Logger.log_debug("\ayNo Changes Made to Item: \at%s \ax(ID:\ag %s\ax) with rule: \at%s\ax, classes: \at%s\ax",
            link, itemID, rule, classes)
    else
        needsSave = loot.loadSettings()
    end
    loot.lootActor:send({ mailbox = 'lootnscoot', }, modMessage)
end

local showSettings = false

function loot.renderMainUI()
    if loot.ShowUI then
        local colCount, styCount = loot.guiLoot.DrawTheme()
        ImGui.SetNextWindowSize(800, 600, ImGuiCond.FirstUseEver)
        local open, show = ImGui.Begin('LootnScoot', true)
        if not open then
            show = false
            loot.ShowUI = false
        end
        if show then
            ImGui.PushStyleColor(ImGuiCol.PopupBg, ImVec4(0.002, 0.009, 0.082, 0.991))
            if ImGui.SmallButton(string.format("%s Report", Icons.MD_INSERT_CHART)) then
                loot.guiLoot.GetSettings(loot.Settings.HideNames, loot.Settings.LookupLinks, loot.Settings.RecordData, true, loot.Settings.UseActors, 'lootnscoot', true)
            end
            if ImGui.IsItemHovered() then ImGui.SetTooltip("Show/Hide Report Window") end

            ImGui.SameLine()

            if ImGui.SmallButton(string.format("%s Console", Icons.FA_TERMINAL)) then
                loot.guiLoot.openGUI = not loot.guiLoot.openGUI
            end
            if ImGui.IsItemHovered() then ImGui.SetTooltip("Show/Hide Console Window") end

            ImGui.SameLine()

            local labelBtn = not showSettings and
                string.format("%s Settings", Icons.FA_COG) or string.format("%s   Items  ", Icons.FA_SHOPPING_BASKET)

            if ImGui.SmallButton(labelBtn) then
                showSettings = not showSettings
            end

            -- Settings Section
            if showSettings then
                if loot.TempSettings.SelectedActor == nil then
                    loot.TempSettings.SelectedActor = MyName
                end
                ImGui.Indent(2)
                ImGui.TextWrapped("You can change any setting by issuing `/lootutils set settingname value` use [on|off] for true false values.")
                ImGui.TextWrapped("You can also change settings for other characters by selecting them from the dropdown.")
                ImGui.Unindent(2)
                ImGui.Spacing()

                ImGui.Separator()
                ImGui.Spacing()
                ImGui.SetNextItemWidth(180)
                if ImGui.BeginCombo("Select Actor", loot.TempSettings.SelectedActor) then
                    for k, v in pairs(loot.Boxes) do
                        if ImGui.Selectable(k, loot.TempSettings.SelectedActor == k) then
                            loot.TempSettings.SelectedActor = k
                        end
                    end
                    ImGui.EndCombo()
                end
                loot.renderSettingsSection(loot.TempSettings.SelectedActor)
            else
                -- Items and Rules Section
                loot.drawItemsTables()
            end
            ImGui.PopStyleColor()
        end
        if colCount > 0 then
            ImGui.PopStyleColor(colCount)
        end
        if styCount > 0 then
            ImGui.PopStyleVar(styCount)
        end
        ImGui.End()
    end
end

function loot.processArgs(args)
    loot.Terminate = true
    local mercsRunnig = mq.TLO.Lua.Script('rgmercs').Status() == 'RUNNING' or false
    if args == nil then return end
    if #args == 1 then
        if args[1] == 'sellstuff' then
            if mercsRunnig then mq.cmd('/rgl pause') end
            loot.processItems('Sell')
            if mercsRunnig then mq.cmd('/rgl unpause') end
        elseif args[1] == 'tributestuff' then
            if mercsRunnig then mq.cmd('/rgl pause') end
            loot.processItems('Tribute')
            if mercsRunnig then mq.cmd('/rgl unpause') end
        elseif args[1] == 'cleanup' then
            if mercsRunnig then mq.cmd('/rgl pause') end
            loot.processItems('Cleanup')
            if mercsRunnig then mq.cmd('/rgl unpause') end
        elseif args[1] == 'once' then
            loot.lootMobs()
        elseif args[1] == 'standalone' then
            if loot.guiLoot ~= nil then
                loot.guiLoot.GetSettings(loot.Settings.HideNames, loot.Settings.LookupLinks, loot.Settings.RecordData, true, loot.Settings.UseActors, 'lootnscoot', false)
            end
            loot.Terminate = false
            loot.lootActor:send({ mailbox = 'lootnscoot', }, { action = 'Hello', Server = eqServer, who = MyName, })
        end
    end
end

function loot.init()
    local needsSave = false

    needsSave = loot.loadSettings(true)
    loot.SortItemTables()
    loot.RegisterActors()
    loot.CheckBags()
    loot.setupEvents()
    loot.setupBinds()
    loot.guiExport()
    zoneID = mq.TLO.Zone.ID()
    Logger.log_debug("Loot::init() \aoSaveRequired: \at%s", needsSave and "TRUE" or "FALSE")
    -- loot.processArgs(args)
    -- loot.sendMySettings()
    -- mq.imgui.init('LootnScoot', loot.RenderUIs)
    if needsSave then loot.writeSettings() end
    -- update module settings
    Modules:ExecModule("loot", "ModifyLootSettings")

    return needsSave
end

if loot.guiLoot ~= nil then
    loot.guiLoot.GetSettings(loot.Settings.HideNames, loot.Settings.LookupLinks, loot.Settings.RecordData, true, loot.Settings.UseActors, 'lootnscoot')
    loot.guiLoot.init(true, true, 'lootnscoot')
end
loot.RegisterActors()
loot.init()

function loot.Loop()
    if mq.TLO.MacroQuest.GameState() ~= "INGAME" then loot.Terminate = true end -- exit sctipt if at char select.
    if loot.Settings.DoLoot then loot.lootMobs() end
    if doSell then
        loot.processItems('Sell')
        doSell = false
    end
    if doBuy then
        loot.processItems('Buy')
        doBuy = false
    end
    if doTribute then
        loot.processItems('Tribute')
        doTribute = false
    end

    mq.doevents()

    if loot.TempSettings.NeedSave then
        loot.writeSettings()
        loot.TempSettings.NeedSave = false
        loot.loadSettings()
        loot.sendMySettings()
        loot.SortItemTables()
    end

    if loot.TempSettings.LookUpItem then
        if loot.TempSettings.SearchItems ~= nil and loot.TempSettings.SearchItems ~= "" then
            loot.GetItemFromDB(loot.TempSettings.SearchItems, 0)
        end
        loot.TempSettings.LookUpItem = false
    end

    loot.NewItemsCount = loot.NewItemsCount <= 0 and 0 or loot.NewItemsCount

    if loot.NewItemsCount == 0 then
        loot.showNewItem = false
    end

    if loot.TempSettings.NeedsDestroy ~= nil then
        local item = loot.TempSettings.NeedsDestroy.item
        local bag = loot.TempSettings.NeedsDestroy.bag
        local slot = loot.TempSettings.NeedsDestroy.slot
        loot.DestroyItem(item, bag, slot)
        loot.TempSettings.NeedsDestroy = nil
    end

    if loot.MyClass:lower() == 'brd' and loot.Settings.DoDestroy then
        loot.Settings.DoDestroy = false
        Logger.log_warn("\aoBard \aoDetected\ax, \arDisabling\ax [\atDoDestroy\ax].")
    end
    -- mq.delay(1)
end

-- if loot.Terminate then
--     mq.unbind("/lootutils")
--     mq.unbind("/lns")
--     mq.unbind("/looted")
-- end
return loot

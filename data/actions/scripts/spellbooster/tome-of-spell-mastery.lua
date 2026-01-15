local OPCODE_SPELL_BOOSTER_DIALOG = 200
local CACHE_DURATION = 300000

local spellCache = {}
local cacheTime = 0

local spellHideList = {
    CREATURE_ILLUSION = 'Creature Illusion',
    CURE_POISON = 'Cure Poison',
    FIND_PERSON = 'Find Person',
    GREAT_LIGHT = 'Great Light',
    LIGHT = 'Light',
    MAGIC_ROPE = 'Magic Rope',
    ULTIMATE_HEALING = 'Ultimate Healing',
    ULTIMATE_LIGHT = 'Ultimate Light',
}

local function loadSpellsFromXML()
    local now = os.time() * 1000

    if spellCache and now < cacheTime then
        return spellCache
    end

    local spells = {}
    local file = io.open("data/spells/spells.xml", "r")

    if not file then
        print("ERROR: spells.xml not found")
        return spells
    end

    local content = file:read("*a")
    file:close()

    for line in content:gmatch("[^\n]+") do
        if line:find("<instant") or line:find("<conjure") then
            local name = line:match('name="([^"]+)"')
            local words = line:match('words="([^"]+)"')
            local level = tonumber(line:match('lvl="([^"]+)"') or line:match('level="([^"]+)"')) or 0
            local mana = tonumber(line:match('mana="([^"]+)"')) or 0
            local group = line:match('group="([^"]+)"') or "attack"

            if name and words then
                table.insert(spells, {
                    name = name,
                    words = words,
                    level = level,
                    mana = mana,
                    type = group,
                    vocations = {}
                })
            end
        end

        if line:find("<vocation") then
            local vocName = line:match('name="([^"]+)"')
            if vocName and #spells > 0 then
                table.insert(spells[#spells].vocations, vocName)
            end
        end
    end

    spellCache = spells
    cacheTime = now + CACHE_DURATION

    return spells
end

function getSpellBoost(playerId, spellName)
    local result = db.storeQuery("SELECT CurrentBoostLevel FROM PlayerSpellBoosts WHERE PlayerId = " .. playerId .. " AND SpellName = '" .. spellName .. "'")
    if result then
        local level = result:getNumber("BoostLevel") or 0
        result:free()
        return level
    end
    return 0
end

function getSpellsByVocation(vocName, player)
    local allSpells = loadSpellsFromXML()
    local playerSpells = {}
    local addedSpells = {}

    for _, spell in ipairs(allSpells) do
        for _, voc in ipairs(spell.vocations) do
            if voc == vocName and not addedSpells[spell.name] then
                local boostLevel = getSpellBoost(player:getId(), spell.name) or 0

                local iconKey = spell.name:lower():gsub(" ", "")

                table.insert(playerSpells, {
                    name = spell.name,
                    type = spell.type,
                    level = spell.level,
                    mana = spell.mana,
                    boostLevel = boostLevel,
                    words = spell.words,
                    maxLevel = 4,
                    icon = iconKey
                })
                addedSpells[spell.name] = true
                break
            end
        end
    end

    return playerSpells
end

local function isInHideList(spellName, hideList)
    for _, hiddenName in pairs(hideList) do
        if spellName == hiddenName then
            return true
        end
    end
    return false
end

function onUse(player, item, fromPosition, target, toPosition, isHotkey)
    --if not player then
    --    return false
    --end
    --
    --local allSpellBoosts = Game.getSpellList()
    --if not allSpellBoosts or #allSpellBoosts == 0 then
    --    player:sendCancelMessage("No spell boost definitions found in server cache!")
    --    return false
    --end
    --
    --local playerVocation = player:getVocation():getId()
    --local filteredSpells = {}
    --
    --for _, def in ipairs(allSpellBoosts) do
    --    local canUse = false
    --
    --    for _, vocId in ipairs(def.vocations) do
    --        if vocId == playerVocation then
    --            canUse = true
    --            break
    --        end
    --    end
    --
    --    if canUse then
    --
    --        if not isInHideList(def.spellName, spellHideList) then
    --            -- Wir fügen noch das aktuelle Boost-Level des Spielers hinzu
    --            def.currentLevel = player:getSpellLevelBySpellName(def.spellName)
    --            table.insert(filteredSpells, def)
    --        end
    --    end
    --end
    --
    --if #filteredSpells == 0 then
    --    player:sendCancelMessage("No spells found for your vocation!")
    --    return false
    --end
    --
    --local jsonString = json.encode(filteredSpells)
    --player:sendExtendedOpcode(OPCODE_SPELL_BOOSTER_DIALOG, jsonString)

    return true
end
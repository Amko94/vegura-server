SpellBoostManager = {}

local spellDefinitions = {}
local tomeOfSpellMastery = 7503

function SpellBoostManager.loadSpells()
    local file = io.open("data/spells/spells.xml", "r")
    if not file then
        print("[SpellBoostManager] Error: Could not load spells.xml")
        return
    end

    local content = file:read("*a")
    file:close()

    for line in content:gmatch("[^\n]+") do
        if line:find("<instant") or line:find("<conjure") or line:find("<rune") then
            local name = line:match('name="([^"]+)"')
            local lvl = tonumber(line:match('lvl="([^"]+)"') or line:match('level="([^"]+)"')) or 0
            local mana = tonumber(line:match('mana="([^"]+)"')) or 0
            local group = line:match('group="([^"]+)"') or "attack"

            if name then
                local normalizedName = name:lower():gsub(" ", "")
                spellDefinitions[normalizedName] = {
                    spellName = name,
                    spellType = group,
                    manaCost = mana,
                    requiredLevel = lvl
                }
            end
        end
    end
end

function SpellBoostManager.calculateSpellPrice(spellName, boostLevel)
    local basePrice = 5000
    local multiplier = 2

    local requiredLevel = SpellBoostManager.getSpellRequiredLevel(spellName)
    local price = basePrice * requiredLevel * math.pow(multiplier, boostLevel)

    return math.floor(price)
end

function SpellBoostManager.getSpellRequiredLevel(spellName)

    if not spellDefinitions[spellName] then
        print("[SpellBoostManager] Spell not found: " .. spellName)
        return 0
    end
    return spellDefinitions[spellName].requiredLevel
end

function SpellBoostManager.getPlayerSpellLevel(spellName, player)
    local result = db.storeQuery(
            "SELECT CurrentBoostLevel FROM PlayerSpellBoosts WHERE PlayerId = " .. player:getGuid() .. " AND SpellName = '" .. spellName .. "'"
    )

    if not result then
        return 0
    end

    local boostLevel = result:getNumber("CurrentBoostLevel")
    result:free()
    return boostLevel
end

function SpellBoostManager.getSpellPrice(spellName, player)
    local normalizedName = spellName:lower():gsub(" ", "")

    local testSpellLevel = player:getSpellLevelBySpellName('Energy Strike')
    print('<<<<<<<<<<<----' .. testSpellLevel .. '----->>>>>>>>>>>>>>>>')

    local currentBoostLevel = SpellBoostManager.getPlayerSpellLevel(normalizedName, player)

    local nextLevel = currentBoostLevel + 1
    local price = SpellBoostManager.calculateSpellPrice(normalizedName, nextLevel)
    player:sendExtendedOpcode(SPELL_BOOSTER_MANAGER_EXTENDED_OPCODES.SEND_SPELL_PRICE, tostring(price))
    return price, nextLevel

end

function SpellBoostManager.boostSpell(spellName, player)
    local price, nextLevel = SpellBoostManager.getSpellPrice(spellName, player)

    if not player:getItemById(tomeOfSpellMastery, true) then
        player:sendCancelMessage("You need a Tomee Of Spell Master in your backpack.")
        return false
    end

    if player:getMoney() < price then
        player:sendCancelMessage("You need " .. price .. " gold coins.")
        return false
    end

    player:removeMoney(price)
    player:removeItem(tomeOfSpellMastery)

    local query = "SELECT id FROM PlayerSpellBoosts WHERE PlayerId = " .. player:getGuid() .. " AND SpellName = '" .. spellName .. "'"
    local result = db.storeQuery(query)

    if result then
        db.query("UPDATE PlayerSpellBoosts SET BoostLevel = " .. nextLevel .. " WHERE PlayerId = " .. player:getGuid() .. " AND SpellName = '" .. spellName .. "'")
        result:free()
    else
        db.query("INSERT INTO PlayerSpellBoosts (PlayerId, SpellName, BoostLevel) VALUES (" .. player:getGuid() .. ", '" .. spellName .. "', " .. nextLevel .. ")")
    end

    player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Spell boosted to level " .. nextLevel .. "!")
    player:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)
    return true
end


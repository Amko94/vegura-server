SpellBoostManager = {}

local spellDefinitions = {}
local tomeOfSpellMastery = 7503

function SpellBoostManager.loadSpells()
    print("[SpellBoost] loadSpells CALLED")

    local spellList = getSpellBoostDefinitionsList()
    print("[SpellBoost] spellList type:", type(spellList))
    print("[SpellBoost] spellList size:", #spellList)

    for i, spell in ipairs(spellList) do
        print("[SpellBoost]", i, spell.spellName)
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
            "SELECT BoostLevel FROM PlayerSpellBoosts WHERE PlayerId = " .. player:getGuid() .. " AND SpellName = '" .. spellName .. "'"
    )

    if not result then
        return 0
    end

    local boostLevel = result:getNumber("BoostLevel")
    result:free()
    return boostLevel
end

function SpellBoostManager.getSpellPrice(spellName, player)
    local normalizedName = spellName:lower():gsub(" ", "")

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


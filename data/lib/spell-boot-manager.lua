SpellBoostManager = {}

local function spellHasVocation(spell, vocationId)
    for _, vocId in ipairs(spell.vocations) do
        if vocId == vocationId then
            return true
        end
    end
    return false
end

function SpellBoostManager.getPlayerSpellLevels(player)
    local spellLevels = player:getSpellBoostLevels()

    if not spellLevels then
        print('SpellLevels table is nil')
        return
    end

    local parsedSpellLevels = json.encode(spellLevels)
    player:sendExtendedOpcode(
            SPELL_BOOSTER_MANAGER_EXTENDED_OPCODES.SEND_PAYER_SPELL_LEVELS,
            parsedSpellLevels
    )
end

function SpellBoostManager.loadSpells(player)
    local spellList = getSpellBoostDefinitionsList() or {}
    local vocationId = player:getVocation():getId()
    local filtered = {}

    for _, spell in ipairs(spellList) do
        if spellHasVocation(spell, vocationId) then
            table.insert(filtered, spell)
        end
    end

    local encodedList = json.encode(filtered)
    player:sendExtendedOpcode(
            SPELL_BOOSTER_MANAGER_EXTENDED_OPCODES.SEND_SPELL_BOOST_DEFINITIONS,
            encodedList
    )
end

function SpellBoostManager.sendSpellPrice(player, spellName)
    local price = SpellBoostManager.getSpellPrice(spellName, player)
    player:sendExtendedOpcode(
            SPELL_BOOSTER_MANAGER_EXTENDED_OPCODES.SEND_SPELL_PRICE,
            tostring(price)
    )
end

function SpellBoostManager.getSpellPrice(spellName, player)
    return player:getUpgradeSpellPrice(spellName)
end

function SpellBoostManager.boostSpell(spellName, player)

    local tile = Tile(player:getPosition())
    if not tile or not tile:hasFlag(TILESTATE_PROTECTIONZONE) then
        player:sendTextMessage(MESSAGE_STATUS_DEFAULT, "You can only use this feature in a protection zone.")
        player:sendExtendedOpcode(EXTENDED_ERROR_OPCODES.NO_PROTECT_ZONE)
        return false
    end
    local price = SpellBoostManager.getSpellPrice(spellName, player)
    if not price then
        player:sendCancelMessage("Spell cannot be upgraded.")
        return false
    end
    if player:getItemCount(TOME_OF_SPELL_MASTERY) < 1 then
        player:sendCancelMessage("You need a Tome of Spell Mastery in your backpack.")
        player:sendExtendedOpcode(EXTENDED_ERROR_OPCODES.MISSING_TOME_OF_SPELL_MASTERY)
        return false
    end
    if player:getMoney() < price then
        player:sendCancelMessage("You need " .. price .. " gold coins.")
        player:sendExtendedOpcode(EXTENDED_ERROR_OPCODES.NO_ENOUGH_MONEY)
        return false
    end
    local success = player:upgradeSpellLevel(spellName)
    if not success then
        player:sendCancelMessage("Spell cannot be upgraded further.")
        return false
    end

    player:removeMoney(price)
    player:removeItem(TOME_OF_SPELL_MASTERY, 1)

    player:sendTextMessage(
            MESSAGE_EVENT_ADVANCE,
            "Spell upgraded successfully!"
    )
    player:getPosition():sendMagicEffect(CONST_ME_SPELL_BOOST)

    player:sendExtendedOpcode(SPELL_BOOSTER_MANAGER_EXTENDED_OPCODES.UPGRADE_SUCCESSFUL)
    SpellBoostManager.getPlayerSpellLevels(player)

    return true
end

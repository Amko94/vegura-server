SpellBoostManager = {}

local TOME_OF_SPELL_MASTERY = 7503


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

local function isInHideList(spellName, hideList)
    for _, hiddenName in ipairs(hideList) do
        if spellName == hiddenName then
            return true
        end
    end
    return false
end

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
    local spellList = getSpellBoostDefinitionsList()
    local vocationId = player:getVocation():getId()

    local filteredSpells = {}
    local addedSpellIds = {}

    for _, spell in ipairs(spellList) do
        if not isInHideList(spell.spellName, spellHideList) then

            if spellHasVocation(spell, vocationId) then

                if not addedSpellIds[spell.id] then
                    table.insert(filteredSpells, spell)
                    addedSpellIds[spell.id] = true
                end

            end
        end
    end

    return json.encode(filteredSpells)
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
    player:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)

    player:sendExtendedOpcode(SPELL_BOOSTER_MANAGER_EXTENDED_OPCODES.UPGRADE_SUCCESSFUL)
    SpellBoostManager.getPlayerSpellLevels(player)

    return true
end

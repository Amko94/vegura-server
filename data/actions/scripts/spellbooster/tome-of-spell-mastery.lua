local OPCODE_SPELL_BOOSTER_DIALOG = 200

function onUse(player)
    if not player then
        return false
    end

    SpellBoostManager.getPlayerSpellLevels(player)
    local parsedSpellList = SpellBoostManager.loadSpells(player)

    player:sendExtendedOpcode(OPCODE_SPELL_BOOSTER_DIALOG, parsedSpellList)

    return true
end
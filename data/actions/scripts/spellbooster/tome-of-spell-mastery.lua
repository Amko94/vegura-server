TOME_OF_SPELL_MASTERY = 7503

function onUse(player)
    if not player then
        return true
    end

    SpellBoostManager.getPlayerSpellLevels(player)

    player:sendExtendedOpcode(SPELL_BOOSTER_MANAGER_EXTENDED_OPCODES.OPEN_SPELL_BOOST_WINDOW)
    return true
end
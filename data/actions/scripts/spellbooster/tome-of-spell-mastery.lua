TOME_OF_SPELL_MASTERY = 7503

function onUse(player)
    if not player then
        return true
    end

    if player:getItemCount(TOME_OF_SPELL_MASTERY) < 1 then
        player:sendTextMessage(
                MESSAGE_STATUS_DEFAULT,
                'To use this item, put the Tome of Spell Mastery in your backpack first.'
        )
        return true
    end

    SpellBoostManager.getPlayerSpellLevels(player)
    player:sendExtendedOpcode(SPELL_BOOSTER_MANAGER_EXTENDED_OPCODES.OPEN_SPELL_BOOST_WINDOW)

    return true
end

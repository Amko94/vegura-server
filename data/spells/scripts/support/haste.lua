function onCastSpell(creature, variant)
    local player = Player(creature)
    if not player then
        return false
    end

    local spellName = "Haste"

    local base = {
        mana = 60,
        duration = 33000,
        speedA = 0.3,
        speedB = -24
    }

    local boosts = SpellBoostManager.resolveSpellBoosts(player, spellName)

    local finalManaCost = SpellBoostManager.apply(
            base.mana,
            boosts,
            SpellBoostType.ReduceManaCost
    )
    finalManaCost = math.max(0, math.floor(finalManaCost))

    if player:getMana() < finalManaCost then
        player:sendCancelMessage("Not enough mana.")
        return false
    end

    player:addMana(-finalManaCost)

    local finalSpeedA = SpellBoostManager.apply(
            base.speedA,
            boosts,
            SpellBoostType.IncreaseSpeed
    )

    local finalDuration = SpellBoostManager.apply(
            base.duration,
            boosts,
            SpellBoostType.IncreaseDuration
    )

    player:removeCondition(CONDITION_HASTE)

    local condition = Condition(CONDITION_HASTE)
    condition:setParameter(CONDITION_PARAM_TICKS, math.floor(finalDuration))
    condition:setFormula(finalSpeedA, base.speedB, finalSpeedA, base.speedB)

    player:addCondition(condition)
    player:getPosition():sendMagicEffect(CONST_ME_MAGIC_GREEN)

    return true
end

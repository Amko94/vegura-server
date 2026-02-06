function onCastSpell(creature, variant)
    local player = Player(creature)
    if not player then
        return false
    end

    local spellName = "Haste"

    local base = {
        duration = 33000,
        speedA = 0.3,
        speedB = -24
    }

    local boosts = SpellBoostManager.resolveSpellBoosts(player, spellName)

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

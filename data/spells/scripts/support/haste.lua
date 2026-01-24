function onCastSpell(creature, variant)
    local player = Player(creature)
    if not player then return false end

    local spellName = "Haste"
    local baseDuration = 33000
    local baseSpeedA = 0.3
    local baseSpeedB = -24

    local durationBoostPct = player:getSpellBoostValue(spellName, SpellBoostType.IncreaseDuration) or 0
    local speedBoostPct    = player:getSpellBoostValue(spellName, SpellBoostType.IncreaseSpeed) or 0

    durationBoostPct = math.max(0, math.min(durationBoostPct, 100))
    speedBoostPct    = math.max(0, math.min(speedBoostPct, 100))

    local finalDuration = math.floor(baseDuration * (1 + durationBoostPct / 100))
    local finalSpeedA   = baseSpeedA * (1 + speedBoostPct / 100)

    player:removeCondition(CONDITION_HASTE)

    local condition = Condition(CONDITION_HASTE)
    condition:setParameter(CONDITION_PARAM_TICKS, finalDuration)
    condition:setFormula(finalSpeedA, baseSpeedB, finalSpeedA, baseSpeedB)

    player:addCondition(condition)
    player:getPosition():sendMagicEffect(CONST_ME_MAGIC_GREEN)
    return true
end

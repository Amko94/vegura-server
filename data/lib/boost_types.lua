SpellBoostType = {
    ReduceManaCost = 1,
    IncreaseDuration = 2,
    IncreaseDamage = 3,
    IncreaseSpeed = 4,
    IncreaseRange = 5,
    IncreaseMonsterSummon = 6,
    IncreaseHealing = 7,
    IncreaseRuneAmount = 8,
    ReduceCooldown = 9,
    IncreaseAreaOfEffect = 10,
    IncreaseConjureAmount = 11
}

SpellBoost = {}

function SpellBoost.getPct(player, spellName, boostType)
    if not player then return 0 end
    local value = player:getSpellBoostValue(spellName, boostType) or 0
    return math.max(0, math.min(value, 100))
end

function SpellBoost.scale(baseValue, boostPct)
    return baseValue * (1 + (boostPct / 100))
end

function SpellBoost.reduce(baseValue, boostPct)
    return baseValue * (1 - (boostPct / 100))
end

function SpellBoost.apply(player, spellName, boostType, baseValue)
    if not player then return baseValue end
    local value = player:getSpellBoostValue(spellName, boostType) or 0
    if value <= 0 then return baseValue end

    if boostType == SpellBoostType.IncreaseAreaOfEffect then
        return baseValue + 1
    end

    -- Alle anderen Boost-Typen sind Prozentangaben
    if boostType == SpellBoostType.ReduceManaCost or boostType == SpellBoostType.ReduceCooldown then
        return math.floor(baseValue * (1 - (value / 100)))
    else
        return baseValue * (1 + (value / 100))
    end
end

function SpellBoost.getBoostTypes(spellName)
    return getBoostTypesBySpellName(spellName)
end

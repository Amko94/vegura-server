local combat = Combat()
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_MAGIC_GREEN)
combat:setParameter(COMBAT_PARAM_AGGRESSIVE, false)

function onCastSpell(creature, variant)
    local player = Player(creature)
    if not player then
        return false
    end

    local spellName = "Strong Haste"

    local base = {
        duration = 22000,
        speedA = 0.7,
        speedB = -56
    }

    local boosts = SpellBoostManager.resolveSpellBoosts(player, spellName)

    local finalSpeedA = SpellBoostManager.apply(
            base.speedA,
            boosts,
            SpellBoostType.IncreaseSpeed
    )

    local condition = Condition(CONDITION_HASTE)
    condition:setParameter(CONDITION_PARAM_TICKS, base.duration)
    condition:setFormula(finalSpeedA, base.speedB, finalSpeedA, base.speedB)

    combat:setCondition(condition)
    return combat:execute(creature, variant)
end

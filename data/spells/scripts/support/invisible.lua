local combat = Combat()
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_MAGIC_BLUE)
combat:setParameter(COMBAT_PARAM_AGGRESSIVE, false)

function onCastSpell(creature, variant)
    local player = Player(creature)
    if not player then
        return false
    end

    local spellName = "Invisibility"

    local base = {
        duration = 200000
    }

    local boosts = SpellBoostManager.resolveSpellBoosts(player, spellName)

    local finalDuration = SpellBoostManager.apply(
            base.duration,
            boosts,
            SpellBoostType.IncreaseDuration
    )
    finalDuration = math.max(1, math.floor(finalDuration))

    local condition = Condition(CONDITION_INVISIBLE)
    condition:setParameter(CONDITION_PARAM_TICKS, finalDuration)

    combat:setCondition(condition)
    return combat:execute(creature, variant)
end

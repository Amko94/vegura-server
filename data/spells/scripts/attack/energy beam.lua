local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_ENERGYDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_ENERGYHIT)

local area = createCombatArea({
    { 0, 1, 0 },
    { 0, 1, 0 },
    { 0, 1, 0 },
    { 0, 3, 0 },
})
combat:setArea(area)

function onCastSpell(creature, variant)
    local player = Player(creature)
    if not player then
        return false
    end

    local spellName = "Energy Beam"

    local base = {
        damageMultiplier = 0.8
    }

    local boosts = SpellBoostManager.resolveSpellBoosts(player, spellName)

    local damageMultiplier = SpellBoostManager.apply(
            base.damageMultiplier,
            boosts,
            SpellBoostType.IncreaseDamage
    )

    combat:setFormula(
            COMBAT_FORMULA_LEVELMAGIC,
            -damageMultiplier, 0,
            0, 0
    )

    return combat:execute(creature, variant)
end

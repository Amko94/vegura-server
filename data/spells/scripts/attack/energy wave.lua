local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_ENERGYDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_TELEPORT)
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, CONST_ANI_ENERGY)

-- Areas
local arr = {
    { 1, 1, 1 },
    { 1, 1, 1 },
    { 1, 1, 1 },
    { 0, 1, 0 },
    { 0, 3, 0 },
}

local arrDiag = {
    { 1, 1, 1, 0, 0 },
    { 1, 1, 0, 0, 0 },
    { 1, 0, 1, 0, 0 },
    { 0, 0, 0, 1, 0 },
    { 0, 0, 0, 0, 3 },
}

combat:setArea(createCombatArea(arr, arrDiag))

function onCastSpell(creature, variant)
    local player = Player(creature)
    if not player then
        return false
    end

    local spellName = "Energy Wave"

    local base = {
        minA = 1.3,
        minB = 30,
        maxA = 1.7,
        maxB = 0
    }

    local boosts = SpellBoostManager.resolveSpellBoosts(player, spellName)

    local finalMinA = SpellBoostManager.apply(
            base.minA,
            boosts,
            SpellBoostType.IncreaseDamage
    )

    local finalMaxA = SpellBoostManager.apply(
            base.maxA,
            boosts,
            SpellBoostType.IncreaseDamage
    )

    -- Damage-Formel setzen
    combat:setFormula(
            COMBAT_FORMULA_LEVELMAGIC,
            -finalMinA, -base.minB,
            -finalMaxA, -base.maxB
    )

    return combat:execute(creature, variant)
end

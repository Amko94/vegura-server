local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_ENERGYDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_ENERGYHIT)

local area = createCombatArea({
    { 0, 1, 0 },
    { 0, 1, 0 },
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

    local spellName = "Great Energy Beam"

    local base = {
        mana = 200,
        minA = 1.3,
        minB = 30,
        maxA = 1.7,
        maxB = 0
    }

    local boosts = SpellBoostManager.resolveSpellBoosts(player, spellName)

    local finalManaCost = base.mana
    if player:getMana() < finalManaCost then
        player:sendCancelMessage("Not enough mana.")
        return false
    end

    player:addMana(-finalManaCost)

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

    combat:setFormula(
            COMBAT_FORMULA_LEVELMAGIC,
            -finalMinA, -base.minB,
            -finalMaxA, -base.maxB
    )

    return combat:execute(creature, variant)
end

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_FIREDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_FIREAREA)

local area = createCombatArea({
    { 1, 1, 1 },
    { 1, 1, 1 },
    { 1, 1, 1 },
    { 0, 1, 0 },
    { 0, 3, 0 },
})
combat:setArea(area)

function onCastSpell(creature, variant)
    local player = Player(creature)
    if not player then
        return false
    end

    local spellName = "Fire Wave"

    local base = {
        mana = 80,
        minA = 0.7,
        minB = 3,
        maxA = 1.1,
        maxB = 0
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

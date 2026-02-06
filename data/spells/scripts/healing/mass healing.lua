local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_HEALING)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_MAGIC_BLUE)
combat:setParameter(COMBAT_PARAM_AGGRESSIVE, false)
combat:setParameter(COMBAT_PARAM_TARGETCASTERORTOPMOST, true)

local area = createCombatArea({
	{0, 0, 1, 1, 1, 0, 0},
	{0, 1, 1, 1, 1, 1, 0},
	{1, 1, 1, 1, 1, 1, 1},
	{1, 1, 1, 3, 1, 1, 1},
	{1, 1, 1, 1, 1, 1, 1},
	{0, 1, 1, 1, 1, 1, 0},
	{0, 0, 1, 1, 1, 0, 0}
})
combat:setArea(area)

function onCastSpell(creature, variant)
	local player = Player(creature)
	if not player then
		return false
	end

	local spellName = "Mass Healing"

    local base = {
        minA = 0.6,
        minB = 30,
        maxA = 1.2,
        maxB = 0
    }

    local boosts = SpellBoostManager.resolveSpellBoosts(player, spellName)

    local finalMinA = SpellBoostManager.apply(
            base.minA,
            boosts,
            SpellBoostType.IncreaseHealing
    )

	local finalMaxA = SpellBoostManager.apply(
			base.maxA,
			boosts,
			SpellBoostType.IncreaseHealing
	)

	combat:setFormula(
			COMBAT_FORMULA_LEVELMAGIC,
			finalMinA, -base.minB,
			finalMaxA, base.maxB
	)

	return combat:execute(creature, variant)
end

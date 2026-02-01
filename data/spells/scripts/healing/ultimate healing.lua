local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_HEALING)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_MAGIC_BLUE)
combat:setParameter(COMBAT_PARAM_TARGETCASTERORTOPMOST, true)
combat:setParameter(COMBAT_PARAM_AGGRESSIVE, false)
combat:setParameter(COMBAT_PARAM_DISPEL, CONDITION_PARALYZE)

function onGetFormulaValues(player, level, maglevel)
	local min = (level * 2 + maglevel * 3) * 2
	local max = (level * 2 + maglevel * 3) * 2.8
	return min, max
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

function onCastSpell(creature, variant)
	local player = Player(creature)
	if not player then
		return false
	end

	local spellName = "Ultimate Healing"

	local base = {
		mana = 160
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

	return combat:execute(creature, variant)
end

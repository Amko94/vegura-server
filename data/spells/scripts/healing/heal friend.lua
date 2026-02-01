local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_HEALING)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_MAGIC_GREEN)
combat:setParameter(COMBAT_PARAM_DISPEL, CONDITION_PARALYZE)
combat:setParameter(COMBAT_PARAM_AGGRESSIVE, false)

function onGetFormulaValues(player, level, maglevel)
	local min = (level / 5) + (maglevel * 6.3) + 45
	local max = (level / 5) + (maglevel * 14.4) + 90
	return min, max
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

function onCastSpell(creature, variant)
	local player = Player(creature)
	if not player then
		return false
	end

	local spellName = "Heal Friend"

	local base = {
		mana = 70
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

	creature:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)
	return combat:execute(creature, variant)
end


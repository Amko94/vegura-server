local STORAGE_ETHEREAL_DAMAGE_BOOST = 50010

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_HITAREA)
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, CONST_ANI_ETHEREALSPEAR)
combat:setParameter(COMBAT_PARAM_BLOCKARMOR, true)

function onGetFormulaValues(player, skill, attack, factor)
    local distSkill = player:getEffectiveSkillLevel(SKILL_DISTANCE)

    local baseMin = (player:getLevel() / 5) + distSkill * 1.5
    local baseMax = (player:getLevel() / 5) + distSkill + 6

    local dmgBoostPct = player:getStorageValue(STORAGE_ETHEREAL_DAMAGE_BOOST)
    if dmgBoostPct < 0 then
        dmgBoostPct = 0
    end

    local multiplier = 1 + dmgBoostPct / 100

    return -baseMin * multiplier, -baseMax * multiplier
end

combat:setCallback(CALLBACK_PARAM_SKILLVALUE, "onGetFormulaValues")

function onCastSpell(creature, variant)
    local player = Player(creature)
    if not player then
        return false
    end

    local spellName = "Ethereal Spear"

    local base = {
        mana = 35
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

    local damageBoost = boosts[SpellBoostType.IncreaseDamage] or 0
    player:setStorageValue(STORAGE_ETHEREAL_DAMAGE_BOOST, damageBoost)

    local result = combat:execute(creature, variant)

    player:setStorageValue(STORAGE_ETHEREAL_DAMAGE_BOOST, -1)

    return result
end

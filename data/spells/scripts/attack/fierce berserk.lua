local STORAGE_FIERCE_BERSERK_DAMAGE_BOOST = 50020
local STORAGE_EXHAUSTION_FIERCE_BERSERK = 50021

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_HITAREA)
combat:setParameter(COMBAT_PARAM_BLOCKARMOR, true)
combat:setParameter(COMBAT_PARAM_USECHARGES, true)
combat:setArea(createCombatArea(AREA_SQUARE1X1))

function onGetFormulaValues(player, skill, attack, factor)
    local baseMin = (player:getLevel() / 5) + (skill * attack * 0.06) + 13
    local baseMax = (player:getLevel() / 5) + (skill * attack * 0.11) + 27

    local dmgBoostPct = player:getStorageValue(STORAGE_FIERCE_BERSERK_DAMAGE_BOOST)
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

    if player:getStorageValue(STORAGE_EXHAUSTION_FIERCE_BERSERK) > os.time() then
        player:sendCancelMessage("You are exhausted.")
        return false
    end

    local spellName = "Fierce Berserk"

    local base = {
        mana = 340,
        cooldown = 1
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
    player:setStorageValue(STORAGE_FIERCE_BERSERK_DAMAGE_BOOST, damageBoost)

    local finalCooldown = SpellBoostManager.apply(
            base.cooldown,
            boosts,
            SpellBoostType.ReduceCooldown
    )
    player:setExhaustion(STORAGE_EXHAUSTION_FIERCE_BERSERK, finalCooldown)

    local result = combat:execute(creature, variant)

    player:setStorageValue(STORAGE_FIERCE_BERSERK_DAMAGE_BOOST, -1)

    return result
end

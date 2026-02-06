local STORAGE_BERSERK_DAMAGE_BOOST = 50000

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_HITAREA)
combat:setParameter(COMBAT_PARAM_BLOCKARMOR, true)
combat:setParameter(COMBAT_PARAM_USECHARGES, true)
combat:setArea(createCombatArea(AREA_SQUARE1X1))

function onGetFormulaValues(player, skill, attack, factor)
    local baseMin = (player:getLevel() / 5) + (skill * attack * 0.03) + 7
    local baseMax = (player:getLevel() / 5) + (skill * attack * 0.05) + 11

    local dmgBoostPct = player:getStorageValue(STORAGE_BERSERK_DAMAGE_BOOST)
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

    local spellName = "Berserk"

    local boosts = SpellBoostManager.resolveSpellBoosts(player, spellName)

    local damageBoost = boosts[SpellBoostType.IncreaseDamage] or 0
    player:setStorageValue(STORAGE_BERSERK_DAMAGE_BOOST, damageBoost)

    local result = combat:execute(creature, variant)

    player:setStorageValue(STORAGE_BERSERK_DAMAGE_BOOST, -1)

    return result
end

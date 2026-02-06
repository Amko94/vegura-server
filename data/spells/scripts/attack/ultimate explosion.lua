local STORAGE_UE_DAMAGE_BOOST = 50050
local STORAGE_EXHAUSTION_UE = 50051

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_EXPLOSIONAREA)

local area = createCombatArea({
    { 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0 },
    { 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0 },
    { 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0 },
    { 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0 },
    { 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0 },
    { 1, 1, 1, 1, 1, 3, 1, 1, 1, 1, 1 },
    { 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0 },
    { 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0 },
    { 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0 },
    { 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0 },
    { 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0 },
})
combat:setArea(area)

function onGetFormulaValues(player, level, maglevel)
    local baseMin = (level * 5.1) + (maglevel * 6.95)
    local baseMax = (level * 6.0) + (maglevel * 9.2)

    local dmgBoostPct = player:getStorageValue(STORAGE_UE_DAMAGE_BOOST)
    if dmgBoostPct < 0 then
        dmgBoostPct = 0
    end

    local multiplier = 1 + dmgBoostPct / 100

    return -baseMin * multiplier, -baseMax * multiplier
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

function onCastSpell(creature, variant)
    local player = Player(creature)
    if not player then
        return false
    end

    local spellName = "Ultimate Explosion"

    local boosts = SpellBoostManager.resolveSpellBoosts(player, spellName)

    local damageBoost = boosts[SpellBoostType.IncreaseDamage] or 0
    player:setStorageValue(STORAGE_UE_DAMAGE_BOOST, damageBoost)

    local result = combat:execute(creature, variant)

    player:setStorageValue(STORAGE_UE_DAMAGE_BOOST, -1)

    return result
end

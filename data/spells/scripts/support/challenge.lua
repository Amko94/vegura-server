local area1 = createCombatArea(AREA_SQUARE1X1)
local area2 = createCombatArea(AREA_SQUARE2X2)

local combat1 = Combat()
combat1:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_MAGIC_BLUE)
combat1:setArea(area1)

local combat2 = Combat()
combat2:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_MAGIC_BLUE)
combat2:setArea(area2)

function onCastSpell(creature, variant)
    local player = Player(creature)
    if not player then
        return false
    end

    local spellName = "Challenge"
    local boosts = SpellBoostManager.resolveSpellBoosts(player, spellName)

    local hasAoEBoost = (boosts[SpellBoostType.IncreaseAreaOfEffect] or 0) > 0
    local combat = hasAoEBoost and combat2 or combat1

    return combat:execute(creature, variant)
end
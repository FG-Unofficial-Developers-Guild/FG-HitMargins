--
-- Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

--	calculate how much attacks hit/miss by
--	luacheck: globals calculateMargin
function calculateMargin(nDC, nTotal)
	if not nDC or not nTotal then
		return
	end
	local nMargin = 0
	if (nTotal - nDC) > 0 then
		nMargin = nTotal - nDC
	elseif (nTotal - nDC) < 0 then
		nMargin = nDC - nTotal
	end
	nMargin = math.floor(nMargin / 5) * 5

	if nMargin > 0 then
		return nMargin
	end
end

local onPreAttackResolve_old
local function onPreAttackResolve_new(rSource, rTarget, rRoll, rMessage, ...)
	onPreAttackResolve_old(rSource, rTarget, rRoll, rMessage, ...)
	if not rRoll.nDefenseVal then
		return
	end
	local nHitMargin = AttackMargins.calculateMargin(rRoll.nDefenseVal, rRoll.nTotal)
	if nHitMargin then
		table.insert(rRoll.aMessages, '[BY ' .. nHitMargin .. '+]')
	end
end

-- Function Overrides
function onInit()
	onPreAttackResolve_old = ActionAttack.onPreAttackResolve
	ActionAttack.onPreAttackResolve = onPreAttackResolve_new
end

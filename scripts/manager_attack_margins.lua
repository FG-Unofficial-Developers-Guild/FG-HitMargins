--
-- Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

--	calculate how much attacks hit/miss by
--	luacheck: globals calculateMargin
function calculateMargin(nDC, nTotal)
	if nDC and nTotal then
		local nMargin = 0
		if (nTotal - nDC) > 0 then
			nMargin = nTotal - nDC
		elseif (nTotal - nDC) < 0 then
			nMargin = nDC - nTotal
		end
		nMargin = math.floor(nMargin / 5) * 5

		if nMargin > 0 then return nMargin; end
	end
end

local function onAttack_pfrpg(rSource, rTarget, rRoll)
	local rMessage = ActionsManager.createActionMessage(rSource, rRoll);

	local bIsSourcePC = ActorManager.isPC(rSource);
	local bAllowCC = OptionsManager.isOption("HRCC", "on") or (not bIsSourcePC and OptionsManager.isOption("HRCC", "npc"));

	if rRoll.sDesc:match("%[CMB") then
		rRoll.sType = "grapple";
	end

	rRoll.nTotal = ActionsManager.total(rRoll);
	rRoll.aMessages = {};

	-- If we have a target, then calculate the defense we need to exceed
	local nDefenseVal, nAtkEffectsBonus, nDefEffectsBonus, nMissChance;
	if rRoll.sType == "critconfirm" then
		local sDefenseVal = rRoll.sDesc:match(" %[AC (%d+)%]");
		if sDefenseVal then
			nDefenseVal = tonumber(sDefenseVal);
		end
		nMissChance = tonumber(rRoll.sDesc:match("%[MISS CHANCE (%d+)%%%]")) or 0;
		rMessage.text = rMessage.text:gsub(" %[AC %d+%]", "");
		rMessage.text = rMessage.text:gsub(" %[MISS CHANCE %d+%%%]", "");
	else
		nDefenseVal, nAtkEffectsBonus, nDefEffectsBonus, nMissChance = ActorManager35E.getDefenseValue(rSource, rTarget, rRoll);
		if nAtkEffectsBonus ~= 0 then
			rRoll.nTotal = rRoll.nTotal + nAtkEffectsBonus;
			local sFormat = "[" .. Interface.getString("effects_tag") .. " %+d]";
			table.insert(rRoll.aMessages, string.format(sFormat, nAtkEffectsBonus));
		end
		if nDefEffectsBonus ~= 0 then
			nDefenseVal = nDefenseVal + nDefEffectsBonus;
			local sFormat = "[" .. Interface.getString("effects_def_tag") .. " %+d]";
			table.insert(rRoll.aMessages, string.format(sFormat, nDefEffectsBonus));
		end
	end
	rRoll.nMissChance = nMissChance;

	-- Get the crit threshold
	rRoll.nCrit = 20;	
	local sAltCritRange = string.match(rRoll.sDesc, "%[CRIT (%d+)%]");
	if sAltCritRange then
		rRoll.nCrit = tonumber(sAltCritRange) or 20;
		if (rRoll.nCrit <= 1) or (rRoll.nCrit > 20) then
			rRoll.nCrit = 20;
		end
	end

	rRoll.nFirstDie = 0;
	if #(rRoll.aDice) > 0 then
		rRoll.nFirstDie = rRoll.aDice[1].result or 0;
	end
	rRoll.bCritThreat = false;
	if rRoll.nFirstDie >= 20 then
		rRoll.bSpecial = true;
		if rRoll.sType == "critconfirm" then
			rRoll.sResult = "crit";
			table.insert(rRoll.aMessages, "[CRITICAL HIT]");
		elseif rRoll.sType == "attack" then
			if bAllowCC then
				rRoll.sResult = "hit";
				rRoll.bCritThreat = true;
				table.insert(rRoll.aMessages, "[AUTOMATIC HIT]");
			else
				rRoll.sResult = "crit";
				table.insert(rRoll.aMessages, "[CRITICAL HIT]");
			end
		else
			rRoll.sResult = "hit";
			table.insert(rRoll.aMessages, "[AUTOMATIC HIT]");
		end
	elseif rRoll.nFirstDie == 1 then
		if rRoll.sType == "critconfirm" then
			table.insert(rRoll.aMessages, "[CRIT NOT CONFIRMED]");
			rRoll.sResult = "miss";
		else
			table.insert(rRoll.aMessages, "[AUTOMATIC MISS]");
			rRoll.sResult = "fumble";
		end
	elseif nDefenseVal then
		if rRoll.nTotal >= nDefenseVal then
			if rRoll.sType == "critconfirm" then
				rRoll.sResult = "crit";
				table.insert(rRoll.aMessages, "[CRITICAL HIT]");
			elseif rRoll.sType == "attack" and rRoll.nFirstDie >= rRoll.nCrit then
				if bAllowCC then
					rRoll.sResult = "hit";
					rRoll.bCritThreat = true;
					table.insert(rRoll.aMessages, "[CRITICAL THREAT]");
				else
					rRoll.sResult = "crit";
					table.insert(rRoll.aMessages, "[CRITICAL HIT]");
				end
			else
				rRoll.sResult = "hit";
				table.insert(rRoll.aMessages, "[HIT]");
			end
		else
			rRoll.sResult = "miss";
			if rRoll.sType == "critconfirm" then
				table.insert(rRoll.aMessages, "[CRIT NOT CONFIRMED]");
			else
				table.insert(rRoll.aMessages, "[MISS]");
			end
		end
	elseif rRoll.sType == "critconfirm" then
		rRoll.sResult = "crit";
		table.insert(rRoll.aMessages, "[CHECK FOR CRITICAL]");
	elseif rRoll.sType == "attack" and rRoll.nFirstDie >= rRoll.nCrit then
		if bAllowCC then
			rRoll.sResult = "hit";
			rRoll.bCritThreat = true;
		else
			rRoll.sResult = "crit";
		end
		table.insert(rRoll.aMessages, "[CHECK FOR CRITICAL]");
	end

	if ((rRoll.sType == "critconfirm") or not rRoll.bCritThreat) and (rRoll.nMissChance > 0) then
		table.insert(rRoll.aMessages, "[MISS CHANCE " .. rRoll.nMissChance .. "%]");
	end

	--	bmos adding hit margin tracking
	--	for compatibility with hit margins, add this here in your onAttack function
	if AmmunitionManager then
		local nHitMargin = AmmunitionManager.calculateMargin(nDefenseVal, rRoll.nTotal)
		if nHitMargin then table.insert(rRoll.aMessages, '[BY ' .. nHitMargin .. '+]') end
	end
	--	end bmos adding hit margin tracking

	ActionAttack.onPreAttackResolve(rSource, rTarget, rRoll, rMessage);
	ActionAttack.onAttackResolve(rSource, rTarget, rRoll, rMessage);
	ActionAttack.onPostAttackResolve(rSource, rTarget, rRoll, rMessage);
end

local function onAttack_5e(rSource, rTarget, rRoll)
	ActionsManager2.decodeAdvantage(rRoll);

	local rMessage = ActionsManager.createActionMessage(rSource, rRoll);
	rMessage.text = string.gsub(rMessage.text, " %[MOD:[^]]*%]", "");

	rRoll.nTotal = ActionsManager.total(rRoll);
	rRoll.aMessages = {};

	local nDefenseVal, nAtkEffectsBonus, nDefEffectsBonus = ActorManager5E.getDefenseValue(rSource, rTarget, rRoll);
	if nAtkEffectsBonus ~= 0 then
		rRoll.nTotal = rRoll.nTotal + nAtkEffectsBonus;
		local sFormat = "[" .. Interface.getString("effects_tag") .. " %+d]"
		table.insert(rRoll.aMessages, string.format(sFormat, nAtkEffectsBonus));
	end
	if nDefEffectsBonus ~= 0 then
		nDefenseVal = nDefenseVal + nDefEffectsBonus;
		local sFormat = "[" .. Interface.getString("effects_def_tag") .. " %+d]"
		table.insert(rRoll.aMessages, string.format(sFormat, nDefEffectsBonus));
	end

	local sCritThreshold = string.match(rRoll.sDesc, "%[CRIT (%d+)%]");
	local nCritThreshold = tonumber(sCritThreshold) or 20;
	if nCritThreshold < 2 or nCritThreshold > 20 then
		nCritThreshold = 20;
	end

	rRoll.nFirstDie = 0;
	if #(rRoll.aDice) > 0 then
		rRoll.nFirstDie = rRoll.aDice[1].result or 0;
	end
	if rRoll.nFirstDie >= nCritThreshold then
		rRoll.bSpecial = true;
		rRoll.sResult = "crit";
		table.insert(rRoll.aMessages, "[CRITICAL HIT]");
	elseif rRoll.nFirstDie == 1 then
		rRoll.sResult = "fumble";
		table.insert(rRoll.aMessages, "[AUTOMATIC MISS]");
	elseif nDefenseVal then
		if rRoll.nTotal >= nDefenseVal then
			rRoll.sResult = "hit";
			table.insert(rRoll.aMessages, "[HIT]");
		else
			rRoll.sResult = "miss";
			table.insert(rRoll.aMessages, "[MISS]");
		end
	end

	--	bmos adding hit margin tracking
	--	for compatibility with hit margins, add this here in your onAttack function
	if AmmunitionManager then
		local nHitMargin = AmmunitionManager.calculateMargin(nDefenseVal, rRoll.nTotal)
		if nHitMargin then table.insert(rRoll.aMessages, '[BY ' .. nHitMargin .. '+]') end
	end
	--	end bmos adding hit margin tracking

	if not rTarget then
		rMessage.text = rMessage.text .. " " .. table.concat(rRoll.aMessages, " ");
	end

	ActionAttack.onPreAttackResolve(rSource, rTarget, rRoll, rMessage);
	ActionAttack.onAttackResolve(rSource, rTarget, rRoll, rMessage);
	ActionAttack.onPostAttackResolve(rSource, rTarget, rRoll, rMessage);
end

local function onAttack_4e(rSource, rTarget, rRoll)
	local rMessage = ActionsManager.createActionMessage(rSource, rRoll);

	rRoll.nTotal = ActionsManager.total(rRoll);
	rRoll.aMessages = {};

	-- If we have a target, then calculate the defense we need to exceed
	local nDefenseVal, nAtkEffectsBonus, nDefEffectsBonus = ActorManager4E.getDefenseValue(rSource, rTarget, rRoll);
	if nAtkEffectsBonus ~= 0 then
		rRoll.nTotal = rRoll.nTotal + nAtkEffectsBonus;
		local sFormat = "[" .. Interface.getString("effects_tag") .. " %+d]"
		table.insert(rRoll.aMessages, string.format(sFormat, nAtkEffectsBonus));
	end
	if nDefEffectsBonus ~= 0 then
		nDefenseVal = nDefenseVal + nDefEffectsBonus;
		local sFormat = "[" .. Interface.getString("effects_def_tag") .. " %+d]"
		table.insert(rRoll.aMessages, string.format(sFormat, nDefEffectsBonus));
	end

	-- Get the crit threshold
	rRoll.nCrit = 20;	
	local sAltCritRange = string.match(rRoll.sDesc, "%[CRIT (%d+)%]");
	if sAltCritRange then
		rRoll.nCrit = tonumber(sAltCritRange) or 20;
		if (rRoll.nCrit <= 1) or (rRoll.nCrit > 20) then
			rRoll.nCrit = 20;
		end
	end

	rRoll.nFirstDie = 0;
	if #(rRoll.aDice) > 0 then
		rRoll.nFirstDie = rRoll.aDice[1].result or 0;
	end
	if rRoll.nFirstDie >= 20 then
		rRoll.bSpecial = true;
		if nDefenseVal then
			if rRoll.nTotal >= nDefenseVal then
				rRoll.sResult = "crit";
				table.insert(rRoll.aMessages, "[CRITICAL HIT]");
			else
				rRoll.sResult = "hit";
				table.insert(rRoll.aMessages, "[AUTOMATIC HIT]");
			end
		else
			table.insert(rRoll.aMessages, "[AUTOMATIC HIT, CHECK FOR CRITICAL]");
		end
	elseif rRoll.nFirstDie == 1 then
		rRoll.sResult = "fumble";
		table.insert(rRoll.aMessages, "[AUTOMATIC MISS]");
	elseif nDefenseVal then
		if rRoll.nTotal >= nDefenseVal then
			if rRoll.nFirstDie >= rRoll.nCrit then
				rRoll.sResult = "crit";
				table.insert(rRoll.aMessages, "[CRITICAL HIT]");
			else
				rRoll.sResult = "hit";
				table.insert(rRoll.aMessages, "[HIT]");
			end
		else
			rRoll.sResult = "miss";
			table.insert(rRoll.aMessages, "[MISS]");
		end
	elseif rRoll.nFirstDie >= rRoll.nCrit then
		rRoll.sResult = "crit";
		table.insert(rRoll.aMessages, "[CHECK FOR CRITICAL]");
	end

	--	bmos adding hit margin tracking
	--	for compatibility with hit margins, add this here in your onAttack function
	if AmmunitionManager then
		local nHitMargin = AmmunitionManager.calculateMargin(nDefenseVal, rRoll.nTotal)
		if nHitMargin then table.insert(rRoll.aMessages, '[BY ' .. nHitMargin .. '+]') end
	end
	--	end bmos adding hit margin tracking

	ActionAttack.onPreAttackResolve(rSource, rTarget, rRoll, rMessage);
	ActionAttack.onAttackResolve(rSource, rTarget, rRoll, rMessage);
	ActionAttack.onPostAttackResolve(rSource, rTarget, rRoll, rMessage);
end

local function onAttack_sfrpg(rSource, rTarget, rRoll)
	local rMessage = ActionsManager.createActionMessage(rSource, rRoll);

	rRoll.dcbase = tonumber(rRoll.dcbase);
	rRoll.dcmod = tonumber(rRoll.dcmod);
	rRoll.oppchk = tonumber(rRoll.oppchk);

	if rRoll.sDesc:match("%[CMB") then
		rRoll.sType = "cmb";
	end

	rRoll.nTotal = ActionsManager.total(rRoll);
	rRoll.aMessages = {};

	local nDefenseVal, nAtkEffectsBonus, nDefEffectsBonus, nMissChance;
	if rTarget then
		-- If we have a target, then calculate the defense we need to exceed
		nDefenseVal, nAtkEffectsBonus, nDefEffectsBonus, nMissChance = ActorManagerSFRPG.getDefenseValue(rSource, rTarget, rRoll);

		if nAtkEffectsBonus ~= 0 then
			rRoll.nTotal = rRoll.nTotal + nAtkEffectsBonus;
			local sFormat = "[" .. Interface.getString("effects_tag") .. " %+d]"
			table.insert(rRoll.aMessages, string.format(sFormat, nAtkEffectsBonus));
		end
		if nDefEffectsBonus ~= 0 then
			nDefenseVal = nDefenseVal + nDefEffectsBonus;
			local sFormat = "[" .. Interface.getString("effects_def_tag") .. " %+d]"
			table.insert(rRoll.aMessages, string.format(sFormat, nDefEffectsBonus));
		end

		local nDCbase = rRoll.dcbase
		if nDCbase == nil then
			nDCbase = 0;
		end
		local nDCmod = rRoll.dcmod
		if nDCmod == nil then
			nDCmod = 0;
		end

		local nodeTarget = ActorManager.getCreatureNode(rTarget);
		local nType = 0;
		if rRoll.sType == "ab" then
			if nodeTarget then
				if rRoll.dctype == "cr" then
					nType = DB.getValue(nodeTarget, "cr", 0);
					if nType < 1 or nType == nil then
						nType = 0;
					end
					nDefenseVal = rRoll.dcbase + rRoll.dcmod + nType;
				elseif rRoll.dctype == "cr15" then
					nType = DB.getValue(nodeTarget, "cr", 0);
					nType = nType + (math.floor(nType / 2));
					if nType < 1 then
						nType = 0;
					end
					nDefenseVal = nDCbase + nDCmod + nType;
				elseif rRoll.dctype == "kac" then
					nType = DB.getValue(nodeTarget, "kac", 0);
					nDefenseVal = nDCbase + nDCmod + nType;
				elseif rRoll.dctype == "eac" then
					nType = DB.getValue(nodeTarget, "eac", 0);
					nDefenseVal = nDCbase + nDCmod + nType;
				else
					nDefenseVal = nDCbase + nDCmod;
				end
			end
		elseif rRoll.sType == "cmb" then
			nDefenseVal = nDefenseVal + nDCbase + nDCmod;
		elseif rRoll.sType == "attack" then
			nDefenseVal = nDefenseVal + nDCbase + nDCmod;
		end
	end
	-- Get the crit threshold
	rRoll.nCrit = 20;
	local sAltCritRange = string.match(rRoll.sDesc, "%[CRIT (%d+)%]");
	if sAltCritRange then
		rRoll.nCrit = tonumber(sAltCritRange) or 20;
		if (rRoll.nCrit <= 1) or (rRoll.nCrit > 20) then
			rRoll.nCrit = 20;
		end
	end

	rRoll.nFirstDie = 0;
	if #(rRoll.aDice) > 0 then
		rRoll.nFirstDie = rRoll.aDice[1].result or 0;
	end

	rRoll.bCritThreat = false;

	if rRoll.nFirstDie >= rRoll.nCrit then
		rRoll.bSpecial = true;
		if rRoll.sType == "attack" then
			local nTotal = rRoll.aDice[1].result + rRoll.nMod;

			if nDefenseVal == nil then
				nDefenseVal = 0;
			end
			if ActorManager.isPC(rSource) and nDefenseVal ~= 0 then
				if nTotal >= nDefenseVal then
					rRoll.sResult = "crit";
					table.insert(rRoll.aMessages, "[CRITICAL HIT]");
				else
					rRoll.sResult = "hit";
					table.insert(rRoll.aMessages, "[AUTOMATIC HIT]");
				end
			else
				rRoll.sResult = "crit";
				table.insert(rRoll.aMessages, "[CRITICAL HIT]");
			end
		end
		if rRoll.sType == "ab" then
			local nTotal = rRoll.aDice[1].result + rRoll.nMod;

			if rTarget == nil then
				nDefenseVal = 0;
			end
			rRoll.sResult = "hit";
			table.insert(rRoll.aMessages, "[AUTOMATIC SUCCESS]");
		end

	elseif rRoll.nFirstDie == 1 then
		if rRoll.sType == "ab" then
			table.insert(rRoll.aMessages, "[AUTOMATIC FAIL]");
			rRoll.sResult = "fail";
		else
			table.insert(rRoll.aMessages, "[AUTOMATIC MISS]");
			rRoll.sResult = "fumble";
		end
	elseif nDefenseVal then
		if rRoll.nTotal >= nDefenseVal then
			--if (rRoll.sType == "attack" or rRoll.sType == "ab" or rRoll.sType == "cmb") and rRoll.nFirstDie >= rRoll.nCrit then
			if (rRoll.sType == "attack" ) and rRoll.nFirstDie >= rRoll.nCrit then
				rRoll.sResult = "crit";
				table.insert(rRoll.aMessages, "[CRITICAL HIT]");
			else
				if rRoll.sType == "attack" then
					rRoll.sResult = "hit";
					table.insert(rRoll.aMessages, "[HIT]");
				elseif rRoll.sType == "cmb" then
					rRoll.sResult = "hit";
					table.insert(rRoll.aMessages, "[HIT]");
				else
					rRoll.sResult = "hit";
					if nDefenseVal == 0 then
						if rRoll.oppchk == 1 then
							table.insert(rRoll.aMessages, "[OPPOSED CHECK]");
						else
							table.insert(rRoll.aMessages, "[SUCCESS]");
						end
					else
						table.insert(rRoll.aMessages, "[SUCCESS vs. DC" .. nDefenseVal .. "]");
					end
				end
			end
		else
			if rRoll.sType == "attack" then
				rRoll.sResult = "miss";
				table.insert(rRoll.aMessages, "[MISS]");
			else
				rRoll.sResult = "miss";
				if rRoll.oppchk == 1 then
					table.insert(rRoll.aMessages, "[OPPOSED CHECK]");
				else
					table.insert(rRoll.aMessages, "[FAILED]");
				end
			end
		end
	elseif rRoll.sType == "attack" and rRoll.nFirstDie >= rRoll.nCrit then
		rRoll.sResult = "crit";
		table.insert(rRoll.aMessages, "[CHECK FOR CRITICAL]");
	end

	--	bmos adding hit margin tracking
	--	for compatibility with hit margins, add this here in your onAttack function
	if AmmunitionManager then
		local nHitMargin = AmmunitionManager.calculateMargin(nDefenseVal, rRoll.nTotal)
		if nHitMargin then table.insert(rRoll.aMessages, '[BY ' .. nHitMargin .. '+]') end
	end
	--	end bmos adding hit margin tracking

	ActionAttack.onPreAttackResolve(rSource, rTarget, rRoll, rMessage);
	ActionAttack.onAttackResolve(rSource, rTarget, rRoll, rMessage);
	ActionAttack.onPostAttackResolve(rSource, rTarget, rRoll, rMessage);
end

-- Function Overrides
function onInit()
	local sRuleset = User.getRulesetName();
	-- replace result handlers
	if sRuleset == "PFRPG" or sRuleset == "3.5E" then
		ActionsManager.unregisterResultHandler('attack');
		ActionsManager.registerResultHandler('attack', onAttack_pfrpg);
		ActionAttack.onAttack = onAttack_pfrpg;
	elseif sRuleset == "4E" then
		ActionsManager.unregisterResultHandler('attack');
		ActionsManager.registerResultHandler('attack', onAttack_4e);
		ActionAttack.onAttack = onAttack_4e;
	elseif sRuleset == "5E" then
		ActionsManager.unregisterResultHandler("attack");
		ActionsManager.registerResultHandler("attack", onAttack_5e);
		ActionAttack.onAttack = onAttack_5e;
	elseif sRuleset == "SFRPG" then
		ActionsManager.unregisterResultHandler("attack");
		ActionsManager.registerResultHandler("attack", onAttack_sfrpg);
		ActionAttack.onAttack = onAttack_sfrpg;
	end
end

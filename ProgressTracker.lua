local ADDON, Addon = ...
local Mod = Addon:NewModule('ProgressTracker')

local lastQuantity
local started = false
local lastDied
local lastDiedName
local lastDiedTime
local lastAmount
local lastAmountTime
local lastQuantity

local function ProcessLasts()
	if lastDied and lastDiedTime and lastAmount and lastAmountTime then
		if abs(lastAmountTime - lastDiedTime) < 0.1 then
			if not AngryKeystones_Data[lastDied] then AngryKeystones_Data[lastDied] = {} end
			if AngryKeystones_Data[lastDied][lastAmount] then
				AngryKeystones_Data[lastDied][lastAmount] = AngryKeystones_Data[lastDied][lastAmount] + 1
			else
				AngryKeystones_Data[lastDied][lastAmount] = 1
			end
			--print("credit", lastAmount, lastDiedName)
			lastDied, lastDiedTime, lastAmount, lastAmountTime, lastDiedName = nil, nil, nil, nil, nil
		end
	end
end

function Mod:COMBAT_LOG_EVENT_UNFILTERED(timestamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags)
	if event == "UNIT_DIED" then
		if bit.band(destFlags, COMBATLOG_OBJECT_TYPE_NPC) > 0 and bit.band(destFlags, COMBATLOG_OBJECT_CONTROL_NPC) > 0 and bit.band(destFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) > 0 then
			local type, zero, server_id, instance_id, zone_uid, npc_id, spawn_uid = strsplit("-", destGUID)
			lastDied = tonumber(npc_id)
			lastDiedTime = GetTime()
			lastDiedName = destName
			--print(lastDiedTime, "died", npc_id)
			ProcessLasts()
		end
	end
end

function Mod:SCENARIO_CRITERIA_UPDATE()
	local scenarioType = select(10, C_Scenario.GetInfo())
	if scenarioType == LE_SCENARIO_TYPE_CHALLENGE_MODE then
		local numCriteria = select(3, C_Scenario.GetStepInfo())
		for criteriaIndex = 1, numCriteria do
			local criteriaString, criteriaType, _, quantity, totalQuantity, _, _, quantityString, _, _, _, _, isWeightedProgress = C_Scenario.GetCriteriaInfo(criteriaIndex)
			if isWeightedProgress then
				local currentQuantity = quantityString and tonumber( strsub(quantityString, 1, -2) )
				if lastQuantity and currentQuantity > lastQuantity then
					lastAmount = currentQuantity - lastQuantity
					lastAmountTime = GetTime()
					--print(lastAmountTime, "update", lastAmount)
					ProcessLasts()
				end
				lastQuantity = currentQuantity
			end
		end
	end
end

local function StartTime()
	started = true
	Mod:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	local numCriteria = select(3, C_Scenario.GetStepInfo())
	for criteriaIndex = 1, numCriteria do
		local criteriaString, criteriaType, _, quantity, totalQuantity, _, _, quantityString, _, _, _, _, isWeightedProgress = C_Scenario.GetCriteriaInfo(criteriaIndex)
		if isWeightedProgress then
			local quantityString = select(8, C_Scenario.GetCriteriaInfo(criteriaIndex))
			lastQuantity = quantityString and tonumber( strsub(quantityString, 1, -2) )
		end
	end
end

local function StopTime()
	started = false
	Mod:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

local function CheckTime(...)
	for i = 1, select("#", ...) do
		local timerID = select(i, ...);
		local _, elapsedTime, type = GetWorldElapsedTime(timerID)
		if type == LE_WORLD_ELAPSED_TIMER_TYPE_CHALLENGE_MODE then
			local _, _, _, _, _, _, _, mapID = GetInstanceInfo()
			if mapID then
				StartTime()
				return
			end
		end
	end
	StopTime()
end

local function OnTooltipSetUnit(tooltip)
	if started then
		local name, unit = tooltip:GetUnit()
		local guid = unit and UnitGUID(unit)
		if guid then
			local type, zero, server_id, instance_id, zone_uid, npc_id, spawn_uid = strsplit("-", guid)
			npc_id = tonumber(npc_id)
			local info = AngryKeystones_Data[npc_id]
			if info then
				local value, valueCount
				for amount, count in pairs(info) do
					if not valueCount or count > valueCount then
						value = amount
					end
				end
				if value then
					tooltip:AddLine( format(" - Progress: %d", value), HIGHLIGHT_FONT_COLOR:GetRGB())
					tooltip:Show()
				end
			end
		end
	end
end

function Mod:PLAYER_ENTERING_WORLD(...) CheckTime(GetWorldElapsedTimers()) end
function Mod:WORLD_STATE_TIMER_START(...) local timerID = ...; CheckTime(timerID) end
function Mod:WORLD_STATE_TIMER_STOP(...) local timerID = ...; StopTime(timerID) end
function Mod:CHALLENGE_MODE_START(...) CheckTime(GetWorldElapsedTimers()) end

function Mod:Startup()
	if not AngryKeystones_Data then
		AngryKeystones_Data = {}
	end
	self:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("WORLD_STATE_TIMER_START")
	self:RegisterEvent("WORLD_STATE_TIMER_STOP")
	self:RegisterEvent("CHALLENGE_MODE_START")
	CheckTime(GetWorldElapsedTimers())
	GameTooltip:HookScript("OnTooltipSetUnit", OnTooltipSetUnit)
end
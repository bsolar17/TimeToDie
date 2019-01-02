local LubStub = LibStub

local TimeToDie = LibStub('AceAddon-3.0'):NewAddon('TimeToDie', 'AceEvent-3.0', 'AceConsole-3.0')
_G.TimeToDie = TimeToDie

local SML = LibStub("LibSharedMedia-3.0")

-------		Initialization		-------

local UnitIsFriend = UnitIsFriend
local UnitHealth = UnitHealth
local GetTime = GetTime
local UnitHealthMax = UnitHealthMax
local UnitExists = UnitExists
local format = format
local ceil = ceil

local defaults = {
	profile = {
		enemy = true,
		target = false, -- false := 'target', true := 'focus'
		tot = false,
		timeFormat = '%d:%02d',
		algorithm = 'InitialMidpoints',

		frame = true,
		locked = false,
		font = defaultFont,
		size = 24,
		outline = '',
		r = 1,
		g = .82,
		b = 0,
		strata = 'LOW',
		justify = 'CENTER',

		p1 = 'CENTER',
		p2 = 'CENTER',
		x = 0,
		y = 0,
	}
}

function TimeToDie:OnInitialize()
	local db = LibStub('AceDB-3.0'):New('TimeToDieDB', defaults, 'Default')
	self.db = db
	local RegisterCallback = db.RegisterCallback
	RegisterCallback(self, 'OnProfileChanged', 'OnEnable')
	RegisterCallback(self, 'OnProfileCopied', 'OnEnable')
	RegisterCallback(self, 'OnProfileReset', 'OnEnable')

	self:RegisterOptions()
end

function TimeToDie:OnEnable()
	local profile = self.db.profile
	self:ApplySettings(profile)

	if profile.frame then
		self:UpdateFrame(profile)
	elseif self.frame then
		self.frame:Hide()
	end
end

function TimeToDie:OnDisable()
	if self.frame then self.frame:Hide() end
	self:DisableEventFrame()
end

-------		Event Functions		--------

local profileEnemy, profileTOT, eventFrame
local profileTarget -- := profile.target and 'focus' or 'target'
local profileTargetTarget
local currentTarget -- profileTarget or profileTagert..'target'
local dataobj
local timeFormat

local ProfileAlgorithm


local health0, time0 -- initial health and time point
local mhealth, mtime -- current midpoint

function TimeToDie:InitialMidpoints(event, unit, health)  --health is not passed from blizz
	if unit ~= currentTarget then return end

	if unit == nil then return end

	health = health or UnitHealth(unit)

	if health == UnitHealthMax(unit) then
		dataobj.text, health0, time0, mhealth, mtime = nil
		return
	end

	local time = GetTime()

	if not health0 then
		health0, time0 = health, time
		mhealth, mtime = health, time
		return
	end

	mhealth = (mhealth + health) * .5
	mtime = (mtime + time) * .5

	if mhealth >= health0 then
		dataobj.text, health0, time0, mhealth, mtime = nil
	else
		time = health * (time0 - mtime) / (mhealth - health0)  -- projected time
		if time < 60 or timeFormat == 'seconds' then
			dataobj.text = ceil(time)
		else
			dataobj.text = format(timeFormat, 1/60 * time, time % 60)
		end
	end
end

local n -- number of points for averaging

-- x,y := time,health
-- health0, time0, mhealth, mtime := ysum, xsum, xysum, xxsum
function TimeToDie:LeastSquares(event, unit, health)  --health is not passed from blizz
	if unit ~= currentTarget then return end

	if unit == nil then return end

	health = health or UnitHealth(unit)

	if health == UnitHealthMax(unit) then
		dataobj.text, n = nil
		return
	end

	local time = GetTime()

	if not n then
		n = 1
		time0, health0 = time, health
		mhealth = time * health
		mtime = time * time
		return
	end

	n = n + 1
	time0 = time0 + time
	health0 = health0 + health
	mhealth = mhealth + time * health
	mtime = mtime + time * time

   time = (health0 * mtime - mhealth * time0) / (health0 * time0 - mhealth * n) - time  -- projected time

	if time < 0 then
		dataobj.text, n = nil
	elseif time < 60 or timeFormat == 'seconds' then
		dataobj.text = ceil(time)
	else
		dataobj.text = format(timeFormat, 1/60 * time, time % 60)
	end
end

-- x,y := time,health
-- health0, time0, mhealth, mtime := ybar, xbar, xybar, xxbar
function TimeToDie:WeightedLeastSquares(event, unit, health)  --health is not passed from blizz
	if unit ~= currentTarget then return end

	if unit == nil then return end

	health = health or UnitHealth(unit)

	if health == UnitHealthMax(unit) then
		dataobj.text, n = nil
		return
	end

	local time = GetTime()

	if not n then
		n = 1
		time0, health0 = time, health
		mhealth = time * health
		mtime = time * time
		return
	end

   time0 = (time0 + time) * .5
   health0 = (health0 + health) * .5
   mhealth = (mhealth + time * health) * .5
   mtime = (mtime + time * time) * .5

   time = (mtime * health0 - time0 * mhealth) / (time0 * health0 - mhealth) - time  -- projected time

	if time < 0 then
		dataobj.text, n = nil
	elseif time < 60 or timeFormat == 'seconds' then
		dataobj.text = ceil(time)
	else
		dataobj.text = format(timeFormat, 1/60 * time, time % 60)
	end
end

function TimeToDie:OnChange(event)
	dataobj.text, health0, time0, mhealth, mtime, n = nil

	currentTarget = profileTarget
	if profileEnemy and UnitIsFriend('player', currentTarget) then
		if profileTOT and UnitExists(profileTargetTarget) and not UnitIsFriend('player', profileTargetTarget) then
			currentTarget = profileTargetTarget
		else
			currentTarget = nil
			if eventFrame then eventFrame:Hide() end -- stops error in OnUpdate
		end
	end
end

local oldhealth = nil
local totalElapsed = 0
local function OnUpdate(self, elapsed)
	totalElapsed = totalElapsed + elapsed
	if totalElapsed < .1 then return end
	totalElapsed = 0

	local health = UnitHealth(currentTarget)
	if oldhealth ~= health then
		oldhealth = health
		ProfileAlgorithm(TimeToDie, 'UNIT_HEALTH', currentTarget, health)
	end
end

--unit := target, player, or nil (focus)
local function UNIT_TARGET(self, event, unit)
	if unit == 'player' then
		unit = 'target'
	elseif event == 'PLAYER_FOCUS_CHANGED' then
		unit = 'focus'
	elseif unit and not UnitIsFriend("player",unit) then
		return -- oscarucb: Ignore UNIT_TARGET events from our enemy changing targets!
	end
	if unit == profileTarget then -- unit is now either 'target' or 'focus'
		TimeToDie:OnChange()
		if currentTarget and currentTarget ~= unit then --target == unit..'target'
			self:Show()
		else
			self:Hide()
		end
	end
end

function TimeToDie:EnableEventFrame()
	if not eventFrame then
		eventFrame = CreateFrame('Frame')
		self.eventFrame = eventFrame
		eventFrame:SetScript('OnEvent', UNIT_TARGET)
		eventFrame:SetScript('OnUpdate', OnUpdate)
	end
	eventFrame:Hide() -- turn off OnUpdate when changing options
	eventFrame:RegisterEvent('UNIT_TARGET') -- covers player, targettarget, and focustarget
	eventFrame:RegisterEvent('PLAYER_FOCUS_CHANGED')  -- covers focus
	--make a call in case targets are already set when enabled
	UNIT_TARGET(eventFrame, nil, profileTarget)
end

function TimeToDie:DisableEventFrame()
	if eventFrame then
		eventFrame:Hide()
		eventFrame:UnregisterAllEvents()
	end
end

function TimeToDie:ApplySettings(profile)
	self:UnregisterAllEvents()

	local algorithm = profile.algorithm
	self:RegisterEvent('UNIT_HEALTH', algorithm)
	ProfileAlgorithm = self[algorithm]

	timeFormat = profile.timeFormat
	profileEnemy = profile.enemy
	profileTOT = profile.tot

	if profile.target then
		profileTarget = 'focus'
		self:RegisterEvent('PLAYER_FOCUS_CHANGED', 'OnChange')
	else
		profileTarget = 'target'
		self:RegisterEvent('PLAYER_TARGET_CHANGED', 'OnChange')
	end

	if profileEnemy and profileTOT then
		profileTargetTarget = profileTarget..'target'
		self:EnableEventFrame()
	else
		self:DisableEventFrame()
		self:OnChange()  -- this is called from EnableEventFrame, so need one here
	end
end

function TimeToDie:UpdateFrame(profile)
	local frame = self.frame
	if not frame then
		frame = CreateFrame('Frame', nil, UIParent, 'TimeToDieFrameTemplate')
		self.frame = frame
	end
	local text = frame.text

	frame:ClearAllPoints()
	frame:SetPoint(profile.p1, UIParent, profile.p2, profile.x, profile.y)

	if profile.frame then
		frame:Show()
	else
		frame:Hide()
		profile.locked = true
	end

	if profile.locked then
		frame.bg:Hide()
		frame:EnableMouse(false)
		dataobj.text = nil
	else
		frame.bg:Show()
		frame:EnableMouse(true)
		dataobj.text = 'TimeToDie'
	end

	text:SetFont(SML:Fetch('font', profile.font), profile.size, profile.outline)
	text:SetTextColor(profile.r, profile.g, profile.b)

	frame:SetFrameStrata(profile.strata)
	text:SetJustifyH(profile.justify)
end

dataobj = LibStub:GetLibrary('LibDataBroker-1.1'):NewDataObject('TimeToDie', {
	type = 'data source',
	text = 'TTD',
	label = 'TTD',
	icon = 'Interface\\Icons\\Spell_Holy_BorrowedTime',
})
TimeToDie.dataobj = dataobj

--[===[@debug@
function TimeToDie:Debug(...)
	if not self.debugging then return end
	if not IsAddOnLoaded('Blizzard_DebugTools') then LoadAddOn('Blizzard_DebugTools') end
	EventTraceFrame:Show()
	EventTraceFrame_OnEvent(EventTraceFrame, ...)
end
--@end-debug@]===]

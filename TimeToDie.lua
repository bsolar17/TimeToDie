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
local debug = debug
local updateFrequency = updateFrequency

local defaults = {
	profile = {
		timeFormat = '%d:%02d',
		frame = true,
		locked = false,
		updateFrequency = 0.1,
		debug = false,
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
	print('TimeToDie:OnInitialize()')
	local db = LibStub('AceDB-3.0'):New('TimeToDieDB', defaults, 'Default')
	self.db = db
	local RegisterCallback = db.RegisterCallback
	RegisterCallback(self, 'OnProfileChanged', 'OnEnable')
	RegisterCallback(self, 'OnProfileCopied', 'OnEnable')
	RegisterCallback(self, 'OnProfileReset', 'OnEnable')

	self:RegisterOptions()
end

function TimeToDie:OnEnable()
	print('TimeToDie:OnEnable()')

	local profile = self.db.profile
	self:ApplySettings(profile)

	if profile.frame then
		self:UpdateFrame(profile)
	end
end

-------		Event Functions		--------

local eventFrame
local dataobj
local timeFormat


local health0, time0 -- initial health and time point
local previousHealth, previousTime
local mhealth, mtime -- current midpoint

function TimeToDie:Midpoints(currentHealth, currentTime)
	TimeToDie:PrintDebug('TimeToDie:Midpoints()')

	if not health0 then
		TimeToDie:PrintDebug('TimeToDie:Midpoints() -> health0 not set yet: setting and returning')
		health0, time0 = currentHealth, currentTime
		mhealth, mtime = currentHealth, currentTime
		previousTime = currentTime
		return
	end

	mhealth = (mhealth + currentHealth) * .5
	mtime = (mtime + currentTime) * .5

	if mhealth >= health0 then
		TimeToDie:PrintDebug('TimeToDie:Midpoints() -> mhealth >= health0: resetting and returning')
		dataobj.text, health0, time0, mhealth, mtime = nil
		return
	end

	local projectedTime = currentHealth * (time0 - mtime) / (mhealth - health0)
		TimeToDie:PrintDebug('TimeToDie:Midpoints() -> projectedTime calculated')
	if projectedTime < 60 or timeFormat == 'seconds' then
		dataobj.text = ceil(projectedTime)
	else
		dataobj.text = format(timeFormat, 1/60 * projectedTime, projectedTime % 60)
	end

	previousTime = currentTime
	previousHealth = currentHealth
end

function TimeToDie:PLAYER_TARGET_CHANGED(self, event, unit)
	TimeToDie:PrintDebug('TimeToDie:PLAYER_TARGET_CHANGED()')
	dataobj.text, health0, time0, mhealth, mtime = nil
end

local oldhealth = nil
local totalElapsed = 0
local function OnUpdate(self, elapsed)
	totalElapsed = totalElapsed + elapsed
	if totalElapsed < updateFrequency then
		return
	end
	totalElapsed = 0
	local currentHealth = UnitHealth('target')
	local currentTime = GetTime()
	if oldhealth ~= currentHealth then
		oldhealth = currentHealth
		TimeToDie:Midpoints(currentHealth, currentTime)
	end
end


function TimeToDie:EnableEventFrame()
	if not eventFrame then
		eventFrame = CreateFrame('Frame')
		self.eventFrame = eventFrame
	end
	self:RegisterEvent('PLAYER_TARGET_CHANGED', PLAYER_TARGET_CHANGED)
	eventFrame:SetScript('OnUpdate', OnUpdate)
	eventFrame:Show()
end

function TimeToDie:DisableEventFrame()
	if eventFrame then
		eventFrame:Hide()
		eventFrame:UnregisterAllEvents()
	end
end

function TimeToDie:ApplySettings(profile)
	self:DisableEventFrame()
	timeFormat = profile.timeFormat
	self:EnableEventFrame()
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
	debug = profile.debug
	updateFrequency = profile.updateFrequency
end

function TimeToDie:PrintDebug(debugMessage)
	if debug then
		print(debugMessage)
	end
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
--@end-debug@]===]--

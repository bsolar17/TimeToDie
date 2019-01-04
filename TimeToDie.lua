local LubStub = LibStub

local TimeToDie = LibStub('AceAddon-3.0'):NewAddon('TimeToDie', 'AceEvent-3.0', 'AceConsole-3.0')
_G.TimeToDie = TimeToDie

local SML = LibStub("LibSharedMedia-3.0")

-------		Initialization		-------

local UnitHealth = UnitHealth
local GetTime = GetTime
local format = format
local ceil = ceil
local updateFrequency = updateFrequency
local interpolationMaxPoints = interpolationMaxPoints
local interpolationMinPoints = interpolationMinPoints

local defaults = {
	profile = {
		timeFormat = '%d:%02d',
		frame = true,
		locked = false,
		updateFrequency = 0.1,
		interpolationMaxPoints = 50,
		interpolationMinPoints = 3,
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


local interpolating = false
local interpolationHealthPoints = {}
local interpolationTimePoints = {}
local interpolationSavedPoints = 0
local interpolationIndex = 0
local healthSum = 0
local timeSum = 0
local healthTimeSum = 0
local timeSquaredSum = 0

function TimeToDie:ProjectTime(currentHealth, currentTime)
	interpolating = true

	interpolationIndex = (interpolationIndex % interpolationMaxPoints) + 1

	if interpolationSavedPoints < interpolationMaxPoints then
		interpolationSavedPoints = interpolationSavedPoints + 1
	else
		local oldestHealth = interpolationHealthPoints[interpolationIndex]
		local oldestTime = interpolationTimePoints[interpolationIndex]
		healthSum = healthSum - oldestHealth
		timeSum = timeSum - oldestTime
		healthTimeSum = healthTimeSum - oldestHealth * oldestTime
		timeSquaredSum = timeSquaredSum - oldestTime * oldestTime
	end

	interpolationHealthPoints[interpolationIndex] = currentHealth
	interpolationTimePoints[interpolationIndex] = currentTime

	healthSum = healthSum + currentHealth	
	timeSum = timeSum + currentTime
	healthTimeSum = healthTimeSum + currentHealth * currentTime
	timeSquaredSum = timeSquaredSum + currentTime * currentTime

	if interpolationSavedPoints < interpolationMinPoints then
		return
	end

	slope = (interpolationSavedPoints * healthTimeSum - healthSum * timeSum) / (interpolationSavedPoints * timeSquaredSum - timeSum * timeSum)

	if slope >= 0 then
		TimeToDie:ResetInterpolation()
		return
	end

	local projectedTime = currentHealth / slope * -1
	
	if projectedTime > 86400 then
		TimeToDie:ResetInterpolation()
		return
	end
	
	if projectedTime < 60 or timeFormat == 'seconds' then
		dataobj.text = ceil(projectedTime)
	else
		dataobj.text = format(timeFormat, 1/60 * projectedTime, projectedTime % 60)
	end
end

function TimeToDie:PLAYER_TARGET_CHANGED(self, event, unit)
	TimeToDie:ResetInterpolation()
end

function TimeToDie:ResetInterpolation()
	if interpolating then
		dataobj.text = nil
		interpolationIndex = 0
		interpolationSavedPoints = 0
		healthSum = 0
		timeSum = 0
		healthTimeSum = 0
		timeSquaredSum = 0
		interpolating = false
	end
end

local totalElapsed = 0
local function OnUpdate(self, elapsed)
	totalElapsed = totalElapsed + elapsed
	if totalElapsed < updateFrequency then
		return
	end
	totalElapsed = 0
	local currentHealth = UnitHealth('target')
	if currentHealth <= 0 then
		TimeToDie:ResetInterpolation()
		return
	end

	local currentTime = GetTime()
	TimeToDie:ProjectTime(currentHealth, currentTime)
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
	updateFrequency = profile.updateFrequency
	interpolationMaxPoints = profile.interpolationMaxPoints
	interpolationMinPoints = profile.interpolationMinPoints
end

dataobj = LibStub:GetLibrary('LibDataBroker-1.1'):NewDataObject('TimeToDie', {
	type = 'data source',
	text = 'TTD',
	label = 'TTD',
	icon = 'Interface\\Icons\\Spell_Holy_BorrowedTime',
})
TimeToDie.dataobj = dataobj


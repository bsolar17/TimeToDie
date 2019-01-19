local TimeToDie = TimeToDie
local LibStub = LibStub

local function GetValue(info)
	return info.handler.db.profile[info.arg]
end

local function SetValue(info, value)
	local self = info.handler
	local profile = self.db.profile
	profile[info.arg] = value
	self:ApplySettings(profile)
end

local function SetFrameValue(info, value)
	local self = info.handler
	local profile = self.db.profile
	profile[info.arg] = value
	self:UpdateFrame(profile)
end

local function GetColor(info)
	local p = info.handler.db.profile
	return p.r, p.g, p.b
end

local function SetColor(info, r,g,b)
	local self = info.handler
	local p = self.db.profile
	p.r, p.g, p.b = r,g,b
	self:UpdateFrame(p)
end

local function IsFrameDisabled(info)
	return not info.handler.db.profile.frame
end

local function GetFontList()
	return AceGUIWidgetLSMlists.font
end

local options = {
	name = 'TimeToDie',
	type = 'group',
	desc = 'Estimated time until current target will die.',
	get = GetValue,
	set = SetValue,
	handler = TimeToDie,
	args = {
		formatting = {
			name = 'formatting',
			type = 'select',
			values = {['%d:%02d'] = '12:34', ['%dm %ds'] = '12m 34s', seconds = '754'},
			order = 250,
			arg = 'timeFormat',
		},
		display = {
			name = 'display',
			type = 'group',
			order = 400,
			guiInline = true,
			set = SetFrameValue,
			disabled = IsFrameDisabled,
			args = {
				locked = {
					name = 'Locked',
					type = 'toggle',
					desc = LOCK_FOCUS_FRAME,
					order = 150,
					arg = 'locked',
				},
				font = {
					name = 'Font',
					type = 'select',
					dialogControl = 'LSM30_Font',
					values = GetFontList,  --wrap in function to keep values current
					order = 200,
					arg = 'font',
				},
				fontSize = {
					name = 'Font Size',
					type = 'range',
					min = 4, max = 27, step = 1,
					order = 250,
					arg = 'size',
				},
				outline = {
					name = 'Outline',
					type = 'select',
					desc = 'Set font outline.',
					values = {[''] = NONE, OUTLINE = VOICE_CHAT_NORMAL, THICKOUTLINE = 'Thick'},
					order = 300,
					arg = 'outline',
				},
				color = {
					name = 'Color',
					type = 'color',
					set = SetColor,
					get = GetColor,
					order = 350,
				},
				strata = {
					name = 'Strata',
					type = 'select',
					desc = 'Set frame strata.',
					values = {HIGH = HIGH, MEDIUM = AUCTION_TIME_LEFT2, LOW = LOW, BACKGROUND = BACKGROUND},
					order = 400,
					arg = 'strata',
				},
				justify = {
					name = 'Justify',
					type = 'select',
					values = {LEFT = 'Left', CENTER = 'Center', RIGHT = 'Right'},
					order = 450,
					arg = 'justify',
				},
				updateFrequency = {
					name = "Update Frequency",
					type = 'range',
					min = 0.1, max = 10, step = 0.1,
					order = 500,
					arg = 'updateFrequency',
				},
				samplingFrequency = {
					name = "Sampling Frequency",
					type = 'range',
					min = 0.1, max = 10, step = 0.1,
					order = 550,
					arg = 'samplingFrequency',
				},
				interpolationMaxPoints = {
					name = "Interpolation Max Points",
					type = 'range',
					min = 2, max = 100, step = 1,
					order = 600,
					arg = 'interpolationMaxPoints',
				},
				interpolationMinPoints = {
					name = "Interpolation Min Points",
					type = 'range',
					min = 2, max = 100, step = 1,
					order = 650,
					arg = 'interpolationMinPoints',
				},
			},
		},
	},
}

TimeToDie.optionTable = options

function TimeToDie:RegisterOptions()
	local profile = LibStub('AceDBOptions-3.0'):GetOptionsTable(self.db)

	local registry = LibStub('AceConfigRegistry-3.0')
	local dialog = LibStub('AceConfigDialog-3.0')
	LibStub('AceConfig-3.0'):RegisterOptionsTable('TimeToDie', options, {'timetodie', 'ttd'})

	registry:RegisterOptionsTable('TimeToDie Options', options)
	registry:RegisterOptionsTable('TimeToDie Profiles', profile)

	local main = dialog:AddToBlizOptions('TimeToDie Options', 'TimeToDie')
	dialog:AddToBlizOptions('TimeToDie Profiles', 'Profiles', 'TimeToDie')

	local dataobj = self.dataobj
	if dataobj then
		dataobj.OnClick = function() InterfaceOptionsFrame_OpenToCategory(main) end
		dataobj.OnTooltipShow = function(tooltip)
			tooltip:AddLine('TimeToDie')
			tooltip:AddLine('Estimated time until current target will die.')
		end
	end
end

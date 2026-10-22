--[[
	LumenUI  -  a dark glass-style Roblox UI library
	-------------------------------------------------------------------
	* Windows with tabs, two-column sections and section sub-tabs
	* Draggable sub-windows (minimize / maximize / close, :Open())
	* Label, Button (+ sub-button), Toggle (+ keybind / color pickers / tooltip),
	  Slider, Dropdown (single / multi), Textbox, Keybind, ColorPicker,
	  Viewport (+ overlay passthrough), Selectable Image List, Credits, Divider
	* Notifications (top-right), Watermark, Keybind list (hotkeys panel)
	* Dock (top-centre window launcher), Backdrop (screen dim + snow / rain / fireflies)
	* ESP preview, Key system window, flat "Starlight" default theme
	* Library.Flags[flag] -> element object   (read .Value, call :Set(...))
	* Config save / load / import / export
	* Icons through Footagesus/Icons (Main-v2.lua) with safe fallbacks

	Works as a ModuleScript (require) or through loadstring(). Returns the Library table.
	Full documentation: Documentation.md
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer

local MB1 = Enum.UserInputType.MouseButton1
local TOUCH = Enum.UserInputType.Touch
local MOVE = Enum.UserInputType.MouseMovement

--------------------------------------------------------------------------------
-- Library table
--------------------------------------------------------------------------------

local Library = {
	Version = "1.2.0",

	-- Library.Flags[flagName] -> element object (has .Value, :Set(), :Get(), .Changed, ...)
	Flags = {},

	Windows = {},
	SubWindows = {},

	-- Icons (Footagesus/Icons)
	IconsURL = "https://raw.githubusercontent.com/Footagesus/Icons/main/Main-v2.lua",
	IconSet = "lucide",
	AutoLoadIcons = true,
	IconProvider = nil,

	-- Where the ScreenGui is parented. nil -> LocalPlayer.PlayerGui.
	-- (set to gethui() / CoreGui yourself if your environment needs it)
	Parent = nil,

	-- Key that shows / hides every window (set to nil to disable)
	ToggleKey = Enum.KeyCode.RightShift,

	Unloaded = false,

	-- drag easing: higher = snappier, lower = floatier. 0 = follow the cursor exactly.
	DragSmoothing = 11,

	-- windows and sub-windows can be resized from their right / bottom edges and bottom-right corner.
	-- Set false to disable globally, or pass Resizable = false / MinSize = Vector2 per window.
	Resizable = true,

	-- false (default) = fully opaque panels. true = old see-through "glass" panels.
	Glass = false,
	-- slowly rotate the window background gradient
	AnimateGradient = false,

	-- Custom window background (image / video). Use Library:SetBackground().
	Background = { ImageId = nil, VideoId = nil, Transparency = 0.6 },

	Theme = {
		-- Starlight palette: flat near-black panels, lavender accent (Accent == Accent2 -> no gradients)
		Background = Color3.fromRGB(17, 16, 21),
		Background2 = Color3.fromRGB(17, 16, 21),
		BackgroundAngle = 90,
		Panel = Color3.fromRGB(21, 20, 26),
		Panel2 = Color3.fromRGB(21, 20, 26),
		Element = Color3.fromRGB(26, 25, 32),
		ElementHover = Color3.fromRGB(38, 37, 46),
		-- checkbox boxes + selected tab / sub-tab pills
		Checkbox = Color3.fromRGB(62, 60, 76),
		Stroke = Color3.fromRGB(40, 39, 49),
		Text = Color3.fromRGB(236, 235, 241),
		SubText = Color3.fromRGB(152, 150, 163),
		Muted = Color3.fromRGB(96, 94, 108),
		Accent = Color3.fromRGB(159, 150, 193),
		Accent2 = Color3.fromRGB(159, 150, 193),
		Success = Color3.fromRGB(92, 200, 135),
		Warning = Color3.fromRGB(232, 172, 92),
		Danger = Color3.fromRGB(226, 100, 106),
		Shadow = Color3.fromRGB(0, 0, 0),
	},

	_conns = {},
	_keybinds = {},
	_listening = false,
	_z = 10,
	_iconPending = setmetatable({}, { __mode = "k" }),
}
Library.__index = Library

local DEFAULT_THEME = table.clone(Library.Theme)
Library.Themes = {}
local function addPreset(name, over)
	local t = table.clone(DEFAULT_THEME)
	for k, v in over do
		t[k] = v
	end
	if over.Checkbox == nil then
		t.Checkbox = over.ElementHover or t.Checkbox
	end
	Library.Themes[name] = t
end
addPreset("Starlight", {})
addPreset("Midnight", {
	Background = Color3.fromRGB(20, 18, 38), Background2 = Color3.fromRGB(8, 8, 14), BackgroundAngle = 135,
	Panel = Color3.fromRGB(26, 24, 44), Panel2 = Color3.fromRGB(15, 15, 24),
	Element = Color3.fromRGB(32, 31, 50), ElementHover = Color3.fromRGB(44, 43, 68), Stroke = Color3.fromRGB(58, 56, 86),
	Accent = Color3.fromRGB(98, 110, 255), Accent2 = Color3.fromRGB(172, 98, 255),
})
addPreset("Hidden", {
	Background = Color3.fromRGB(14, 14, 20), Background2 = Color3.fromRGB(4, 4, 7), BackgroundAngle = 125,
	Panel = Color3.fromRGB(20, 20, 28), Panel2 = Color3.fromRGB(9, 9, 13),
	Element = Color3.fromRGB(27, 27, 37), ElementHover = Color3.fromRGB(38, 38, 52), Stroke = Color3.fromRGB(46, 46, 62),
	Accent = Color3.fromRGB(84, 120, 255), Accent2 = Color3.fromRGB(150, 90, 255),
})
addPreset("Illusionary", {
	Background = Color3.fromRGB(14, 14, 14), Background2 = Color3.fromRGB(6, 6, 6), BackgroundAngle = 90,
	Panel = Color3.fromRGB(18, 18, 18), Panel2 = Color3.fromRGB(11, 11, 11),
	Element = Color3.fromRGB(26, 26, 26), ElementHover = Color3.fromRGB(40, 40, 40), Stroke = Color3.fromRGB(64, 64, 64),
	Text = Color3.fromRGB(245, 245, 245), SubText = Color3.fromRGB(160, 160, 160),
	Accent = Color3.fromRGB(255, 255, 255), Accent2 = Color3.fromRGB(175, 175, 175),
})
addPreset("Crimson", {
	Background = Color3.fromRGB(34, 12, 18), Background2 = Color3.fromRGB(9, 4, 6), BackgroundAngle = 135,
	Panel = Color3.fromRGB(38, 16, 22), Panel2 = Color3.fromRGB(16, 8, 11),
	Element = Color3.fromRGB(48, 22, 30), ElementHover = Color3.fromRGB(66, 30, 40), Stroke = Color3.fromRGB(86, 40, 54),
	Accent = Color3.fromRGB(255, 70, 92), Accent2 = Color3.fromRGB(255, 140, 70),
})
addPreset("Emerald", {
	Background = Color3.fromRGB(10, 32, 26), Background2 = Color3.fromRGB(4, 10, 9), BackgroundAngle = 135,
	Panel = Color3.fromRGB(14, 36, 30), Panel2 = Color3.fromRGB(8, 16, 14),
	Element = Color3.fromRGB(20, 48, 40), ElementHover = Color3.fromRGB(28, 66, 54), Stroke = Color3.fromRGB(36, 84, 70),
	Accent = Color3.fromRGB(60, 220, 140), Accent2 = Color3.fromRGB(40, 170, 255),
})
addPreset("Ocean", {
	Background = Color3.fromRGB(10, 22, 44), Background2 = Color3.fromRGB(4, 7, 14), BackgroundAngle = 135,
	Panel = Color3.fromRGB(14, 28, 52), Panel2 = Color3.fromRGB(8, 13, 24),
	Element = Color3.fromRGB(20, 38, 68), ElementHover = Color3.fromRGB(28, 52, 92), Stroke = Color3.fromRGB(38, 70, 112),
	Accent = Color3.fromRGB(60, 170, 255), Accent2 = Color3.fromRGB(100, 110, 255),
})

local function gl(v)
	return Library.Glass and v or 0
end

-- light tint of the accent (selected tab / sub-tab text, active dock icon)
local function selText()
	return Library.Theme.Accent:Lerp(Color3.new(1, 1, 1), 0.4)
end

local FONT_REG = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
local FONT_SEMI = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold)
local FONT_BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

--------------------------------------------------------------------------------
-- Small utilities
--------------------------------------------------------------------------------

local function clamp(v, a, b)
	return math.max(a, math.min(b, v))
end

local function decimalsOf(inc)
	local s = tostring(inc)
	local frac = s:match("%.(%d+)")
	return frac and #frac or 0
end

local function snap(v, inc, min)
	if not inc or inc <= 0 then
		return v
	end
	local r = math.floor((v - min) / inc + 0.5) * inc + min
	return tonumber(string.format("%." .. decimalsOf(inc) .. "f", r)) or r
end

local function safeCall(fn, ...)
	if type(fn) == "function" then
		task.spawn(fn, ...)
	end
end

local function reducedMotion()
	local ok, r = pcall(function()
		return GuiService.ReducedMotionEnabled
	end)
	return ok and r == true
end

local function tween(inst, props, time, style, dir)
	local t = reducedMotion() and 0 or (time or 0.15)
	local tw = TweenService:Create(
		inst,
		TweenInfo.new(t, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

local function toHex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function fromHex(s)
	s = tostring(s):gsub("#", "")
	if #s == 3 then
		s = s:gsub(".", "%0%0")
	end
	if #s ~= 6 or s:find("%X") then
		return nil
	end
	return Color3.fromRGB(tonumber(s:sub(1, 2), 16), tonumber(s:sub(3, 4), 16), tonumber(s:sub(5, 6), 16))
end

-- Mouse in screen space (matches AbsolutePosition because our ScreenGui ignores the topbar inset)
local function pointerPos(input)
	if input.UserInputType == TOUCH then
		local inset = GuiService:GetGuiInset()
		return Vector2.new(input.Position.X, input.Position.Y) + inset
	end
	return UserInputService:GetMouseLocation()
end

local function isShown(gui)
	local cur = gui
	while cur and not cur:IsA("ScreenGui") do
		if cur:IsA("GuiObject") and not cur.Visible then
			return false
		end
		cur = cur.Parent
	end
	return cur ~= nil and cur.Enabled
end

--------------------------------------------------------------------------------
-- Signal
--------------------------------------------------------------------------------

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _h = {} }, Signal)
end

function Signal:Connect(fn)
	local conn = { Fn = fn, Connected = true }
	function conn:Disconnect()
		self.Connected = false
		local i = table.find(self._owner._h, self)
		if i then
			table.remove(self._owner._h, i)
		end
	end
	conn._owner = self
	table.insert(self._h, conn)
	return conn
end

function Signal:Fire(...)
	for _, c in table.clone(self._h) do
		if c.Connected then
			task.spawn(c.Fn, ...)
		end
	end
end

--------------------------------------------------------------------------------
-- Theme binding + instance factory
--------------------------------------------------------------------------------

local themed = setmetatable({}, { __mode = "k" })
local accentGradients = setmetatable({}, { __mode = "k" })

local function bind(inst, prop, key)
	inst[prop] = Library.Theme[key]
	local t = themed[inst]
	if not t then
		t = {}
		themed[inst] = t
	end
	t[prop] = key
end

local function setProp(inst, prop, v)
	if type(v) == "string" and v:byte() == 64 and (prop == "Color" or prop:sub(-6) == "Color3") then
		bind(inst, prop, v:sub(2))
	else
		local t = themed[inst]
		if t then
			t[prop] = nil
		end
		inst[prop] = v
	end
end

local function accentSequence()
	return ColorSequence.new(Library.Theme.Accent, Library.Theme.Accent2)
end

--[=[
	New(class, props, children)
	  * Props whose value is "@ThemeKey" (for Color / *Color3 props) are theme-bound
	  * GuiObjects default to transparent + no border; text objects get theme font/color
]=]
local function New(class, props, children)
	local inst = Instance.new(class)
	if inst:IsA("GuiObject") then
		inst.BorderSizePixel = 0
		inst.BackgroundTransparency = 1
		if inst:IsA("GuiButton") then
			inst.AutoButtonColor = false
		end
		if inst:IsA("TextButton") then
			inst.Text = ""
		end
		if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
			inst.FontFace = FONT_REG
			inst.TextSize = 12
			inst.TextWrapped = false
			bind(inst, "TextColor3", "Text")
		end
	end
	if props then
		local parent = props.Parent
		for k, v in props do
			if k ~= "Parent" then
				setProp(inst, k, v)
			end
		end
		if children then
			for _, c in children do
				c.Parent = inst
			end
		end
		if parent then
			inst.Parent = parent
		end
	end
	return inst
end

local function corner(parent, r)
	return New("UICorner", { CornerRadius = UDim.new(0, r or 6), Parent = parent })
end

local function stroke(parent, color, thickness, transparency)
	return New("UIStroke", {
		Color = color or "@Stroke",
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function pad(parent, l, t, r, b)
	return New("UIPadding", {
		PaddingLeft = UDim.new(0, l or 0),
		PaddingTop = UDim.new(0, t or l or 0),
		PaddingRight = UDim.new(0, r or l or 0),
		PaddingBottom = UDim.new(0, b or t or l or 0),
		Parent = parent,
	})
end

local function list(parent, padding, dir, halign, valign)
	return New("UIListLayout", {
		Padding = UDim.new(0, padding or 0),
		FillDirection = dir or Enum.FillDirection.Vertical,
		HorizontalAlignment = halign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = valign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

local function accentGradient(parent, rotation)
	setProp(parent, "BackgroundColor3", Color3.new(1, 1, 1))
	local g = New("UIGradient", { Color = accentSequence(), Rotation = rotation or 0, Parent = parent })
	accentGradients[g] = true
	return g
end

-- Gradient between two theme colors (updates live with Library:SetTheme)
local themeGradients = setmetatable({}, { __mode = "k" })
local mainGradients = setmetatable({}, { __mode = "k" })
local function themeGradient(parent, key1, key2, rotation)
	setProp(parent, "BackgroundColor3", Color3.new(1, 1, 1))
	local g = New("UIGradient", {
		Color = ColorSequence.new(Library.Theme[key1], Library.Theme[key2]),
		Rotation = rotation or 90,
		Parent = parent,
	})
	themeGradients[g] = { key1, key2 }
	return g
end

-- Colored card gradient (tint fades into a dark color). tint = Color3 or { Color3, Color3 }
local function tintGradient(parent, tint, rotation)
	setProp(parent, "BackgroundColor3", Color3.new(1, 1, 1))
	local c1, c2 = tint, Color3.fromRGB(9, 9, 13)
	if type(tint) == "table" then
		c1, c2 = tint[1], tint[2]
	else
		c1 = tint:Lerp(Color3.new(0, 0, 0), 0.3)
	end
	return New("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, c1),
			ColorSequenceKeypoint.new(0.75, c2),
			ColorSequenceKeypoint.new(1, c2),
		}),
		Rotation = rotation or -40,
		Parent = parent,
	})
end

--------------------------------------------------------------------------------
-- Icons (Footagesus/Icons)
--------------------------------------------------------------------------------

-- ASCII fallbacks so controls stay usable if the icon pack could not be loaded
local ICON_FALLBACK = {
	["x"] = "x",
	["minus"] = "-",
	["plus"] = "+",
	["square"] = "o",
	["maximize-2"] = "+",
	["chevron-down"] = "v",
	["bell"] = "!",
	["check"] = "",
	["circle-help"] = "?",
}

local function resolveIcon(name)
	if type(name) == "number" then
		return "rbxassetid://" .. name
	end
	if type(name) ~= "string" or name == "" then
		return nil
	end
	if name:find("^rbxassetid://") or name:find("^rbxasset://") then
		return name
	end
	local provider = Library.IconProvider
	if not provider then
		return nil
	end
	local ok, res = pcall(function()
		if type(provider) == "function" then
			return provider(name)
		end
		return provider.GetIcon(name)
	end)
	if not ok or res == nil then
		return nil
	end
	if type(res) == "string" then
		return res
	end
	if type(res) == "table" then
		return res.Image or res[1]
	end
	return nil
end

local function applyIcon(img, name)
	local id = resolveIcon(name)
	if id then
		img.Image = id
		local fb = img:FindFirstChild("Fallback")
		if fb then
			fb:Destroy()
		end
	else
		Library._iconPending[img] = name
	end
end

local function icon(parent, name, size, colorKey, props)
	props = props or {}
	local img = New("ImageLabel", {
		Name = "Icon",
		Size = UDim2.fromOffset(size or 14, size or 14),
		ImageColor3 = colorKey or "@SubText",
		ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex or 1,
		Parent = parent,
	})
	local fb = ICON_FALLBACK[name]
	if fb and fb ~= "" then
		local t = New("TextLabel", {
			Name = "Fallback",
			Size = UDim2.fromScale(1, 1),
			Text = fb,
			TextSize = (size or 14) - 2,
			FontFace = FONT_BOLD,
			TextColor3 = colorKey or "@SubText",
			Parent = img,
		})
		t.ZIndex = img.ZIndex
	end
	applyIcon(img, name)
	return img
end

local function httpGet(url)
	local ok, res = pcall(function()
		return game:HttpGetAsync(url)
	end)
	if ok and type(res) == "string" then
		return res
	end
	local ok2, res2 = pcall(function()
		return HttpService:GetAsync(url)
	end)
	if ok2 and type(res2) == "string" then
		return res2
	end
	return nil
end

--- Loads Footagesus/Icons (Main-v2.lua). Pass your own provider (table with .GetIcon or a function) to skip the download.
function Library:LoadIcons(provider)
	if self._iconsStarted and not provider then
		return
	end
	self._iconsStarted = true
	task.spawn(function()
		local mod = provider
		if not mod then
			local src = httpGet(self.IconsURL)
			local loader = src and loadstring
			if loader then
				local okc, fn = pcall(loader, src)
				if okc and type(fn) == "function" then
					local okr, res = pcall(fn)
					if okr then
						mod = res
					end
				end
			end
		end
		if not mod then
			warn("[LumenUI] Icon pack unavailable (HTTP/loadstring disabled?). Using text fallbacks.")
			return
		end
		if type(mod) == "table" and mod.SetIconsType then
			pcall(mod.SetIconsType, self.IconSet)
		end
		self.IconProvider = mod
		for img, name in self._iconPending do
			if img.Parent then
				self._iconPending[img] = nil
				applyIcon(img, name)
			end
		end
	end)
end

--- Returns an "rbxassetid://" string for an icon name (or nil if the pack isn't loaded yet).
function Library:GetIcon(name)
	return resolveIcon(name)
end

--------------------------------------------------------------------------------
-- Theme / accent
--------------------------------------------------------------------------------

--- Library:SetTheme({ Accent = Color3, Accent2 = Color3, Background = Color3, ... }) - live updates everything.
function Library:SetTheme(new)
	for k, v in new do
		self.Theme[k] = v
	end
	for inst, props in themed do
		for prop, key in props do
			pcall(function()
				inst[prop] = self.Theme[key]
			end)
		end
	end
	for g in accentGradients do
		g.Color = accentSequence()
	end
	for g, keys in themeGradients do
		g.Color = ColorSequence.new(self.Theme[keys[1]], self.Theme[keys[2]])
	end
	if new.BackgroundAngle then
		for g in mainGradients do
			g.Rotation = new.BackgroundAngle
		end
	end
end

--- Apply a preset by name: "Midnight", "Hidden", "Illusionary", "Crimson", "Emerald", "Ocean" (+ your own in Library.Themes)
function Library:ApplyThemePreset(name)
	local t = self.Themes[name]
	if not t then
		return false
	end
	self:SetTheme(t)
	return true
end

--------------------------------------------------------------------------------
-- Global connections / ScreenGui / layers
--------------------------------------------------------------------------------

function Library:_global(signal, fn)
	local c = signal:Connect(fn)
	table.insert(self._conns, c)
	return c
end

function Library:_nextZ()
	self._z += 1
	return self._z
end

function Library:_Gui()
	if self.Gui and self.Gui.Parent then
		return self.Gui
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "LumenUI_" .. HttpService:GenerateGUID(false):sub(1, 8)
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 1000
	gui.IgnoreGuiInset = true
	gui.Parent = self.Parent or (LocalPlayer and LocalPlayer:WaitForChild("PlayerGui"))
	self.Gui = gui

	-- Layers (ZIndex orders them): HUD < windows < toasts < tooltip
	self.BackdropLayer = New("Frame", { Name = "Backdrop", Size = UDim2.fromScale(1, 1), ZIndex = 0, Parent = gui })
	self._bdDim = New("Frame", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 0,
		Parent = self.BackdropLayer,
	})
	self._bdHolder = New("Frame", {
		Name = "Weather",
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 1,
		Parent = self.BackdropLayer,
	})
	self.HudLayer = New("Frame", { Name = "Hud", Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = gui })
	self.WindowLayer = New("Frame", { Name = "Windows", Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = gui })
	self.ToastLayer = New("Frame", { Name = "Toasts", Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = gui })
	self.TipLayer = New("Frame", { Name = "Tooltips", Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = gui })

	self:_setupInput()
	self:_global(RunService.RenderStepped, function(dt)
		self:_backdropStep(dt)
		if self.AnimateGradient then
			for g in mainGradients do
				g.Rotation = (g.Rotation + dt * 10) % 360
			end
		end
	end)
	return gui
end

--------------------------------------------------------------------------------
-- Drag helper
--------------------------------------------------------------------------------

local function bindDrag(obj, onBegin, onMove, onEnd)
	obj.InputBegan:Connect(function(input)
		if input.UserInputType ~= MB1 and input.UserInputType ~= TOUCH then
			return
		end
		if onBegin and onBegin(input) == false then
			return
		end
		local moveConn, endConn
		local function stop()
			if moveConn then
				moveConn:Disconnect()
				moveConn = nil
			end
			if endConn then
				endConn:Disconnect()
				endConn = nil
			end
			if onEnd then
				onEnd(input)
			end
		end
		moveConn = UserInputService.InputChanged:Connect(function(i)
			if i.UserInputType == MOVE or (i.UserInputType == TOUCH and i == input) then
				onMove(i)
			end
		end)
		endConn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				stop()
			end
		end)
	end)
end

--- Makes `handle` drag `target` around the screen (clamped so the header stays reachable).
--- The window chases the cursor with exponential smoothing (Library.DragSmoothing) so it glides
--- and settles instead of snapping, and its shadow lifts while it is carried.
local function makeDraggable(handle, target)
	local startPointer, startAbs, basePos
	local goal, cur = Vector2.zero, Vector2.zero
	local held = false
	local loop

	local function apply(d)
		target.Position = UDim2.new(basePos.X.Scale, basePos.X.Offset + d.X, basePos.Y.Scale, basePos.Y.Offset + d.Y)
	end
	local function lift(on)
		local sh = target:FindFirstChild("Shadow")
		if sh and sh:IsA("ImageLabel") then
			tween(sh, { ImageTransparency = on and 0.15 or 0.45 }, 0.25)
		end
	end
	local function stopLoop()
		if loop then
			loop:Disconnect()
			loop = nil
		end
	end

	bindDrag(handle, function(input)
		stopLoop()
		startPointer = Vector2.new(input.Position.X, input.Position.Y)
		startAbs = target.AbsolutePosition
		basePos = target.Position
		goal, cur = Vector2.zero, Vector2.zero
		held = true
		lift(true)
		if (Library.DragSmoothing or 0) > 0 and not reducedMotion() then
			loop = RunService.RenderStepped:Connect(function(dt)
				local k = Library.DragSmoothing
				local alpha = 1 - math.exp(-k * math.min(dt, 0.05))
				cur = cur:Lerp(goal, alpha)
				apply(cur)
				if not held and (goal - cur).Magnitude < 0.25 then
					apply(goal)
					stopLoop()
				end
			end)
		end
	end, function(input)
		local d = Vector2.new(input.Position.X, input.Position.Y) - startPointer
		local screen = Library.Gui and Library.Gui.AbsoluteSize or Vector2.new(1920, 1080)
		local size = target.AbsoluteSize
		local abs = startAbs + d
		local cx = clamp(abs.X, -size.X + 90, screen.X - 90)
		local cy = clamp(abs.Y, 0, screen.Y - 30)
		goal = Vector2.new(cx, cy) - startAbs
		if not loop then
			apply(goal)
		end
	end, function()
		held = false
		lift(false)
	end)
end

--- Adds right / bottom / corner resize handles to a floating panel. Eased like dragging.
--- Returns { Grips = Frame, SetLocked(bool) }.  Growth is compensated for the holder's AnchorPoint
--- so the top-left corner stays put.
local function makeResizable(holder, opts)
	opts = opts or {}
	local minSize = opts.MinSize or Vector2.new(320, 220)
	local grips = New("Frame", { Name = "Grips", Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = holder })
	local state = { Grips = grips, Locked = false }

	local startPointer, startSize, startPos
	local goal, cur = Vector2.zero, Vector2.zero
	local held, loop = false, nil
	local dirX, dirY = 0, 0

	local function apply(sz)
		local anchor = holder.AnchorPoint
		local dS = sz - startSize
		holder.Size = UDim2.fromOffset(sz.X, sz.Y)
		holder.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + anchor.X * dS.X,
			startPos.Y.Scale, startPos.Y.Offset + anchor.Y * dS.Y
		)
		if opts.OnResize then
			opts.OnResize(sz)
		end
	end
	local function stopLoop()
		if loop then
			loop:Disconnect()
			loop = nil
		end
	end

	local function attach(handle, dx, dy)
		bindDrag(handle, function(input)
			if state.Locked then
				return false
			end
			stopLoop()
			dirX, dirY = dx, dy
			startPointer = Vector2.new(input.Position.X, input.Position.Y)
			startSize = holder.AbsoluteSize
			startPos = holder.Position
			goal, cur = startSize, startSize
			held = true
			if (Library.DragSmoothing or 0) > 0 and not reducedMotion() then
				loop = RunService.RenderStepped:Connect(function(dt)
					local k = Library.DragSmoothing * 1.3
					cur = cur:Lerp(goal, 1 - math.exp(-k * math.min(dt, 0.05)))
					apply(cur)
					if not held and (goal - cur).Magnitude < 0.3 then
						apply(goal)
						stopLoop()
					end
				end)
			end
		end, function(input)
			local d = Vector2.new(input.Position.X, input.Position.Y) - startPointer
			local screen = Library.Gui and Library.Gui.AbsoluteSize or Vector2.new(1920, 1080)
			goal = Vector2.new(
				clamp(startSize.X + d.X * dirX, minSize.X, math.max(minSize.X, screen.X)),
				clamp(startSize.Y + d.Y * dirY, minSize.Y, math.max(minSize.Y, screen.Y))
			)
			if not loop then
				apply(goal)
			end
		end, function()
			held = false
		end)
	end

	local right = New("TextButton", {
		Name = "ResizeRight",
		Position = UDim2.new(1, -2, 0, 36),
		Size = UDim2.new(0, 6, 1, -54),
		ZIndex = 21,
		Parent = grips,
	})
	local bottom = New("TextButton", {
		Name = "ResizeBottom",
		Position = UDim2.new(0, 14, 1, -2),
		Size = UDim2.new(1, -32, 0, 6),
		ZIndex = 21,
		Parent = grips,
	})
	local cornerGrip = New("TextButton", {
		Name = "ResizeCorner",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 3, 1, 3),
		Size = UDim2.fromOffset(18, 18),
		ZIndex = 22,
		Parent = grips,
	})
	attach(right, 1, 0)
	attach(bottom, 0, 1)
	attach(cornerGrip, 1, 1)

	-- grip dots (bottom-right, drawn inside the window)
	local dots = {}
	for _, p in { { 0, 2 }, { 1, 1 }, { 2, 0 }, { 1, 2 }, { 2, 1 }, { 2, 2 } } do
		local d = New("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -3 - (2 - p[1]) * 4, 1, -3 - (2 - p[2]) * 4),
			Size = UDim2.fromOffset(2, 2),
			BackgroundColor3 = "@Muted",
			BackgroundTransparency = 0.45,
			ZIndex = 21,
			Parent = grips,
		})
		New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = d })
		table.insert(dots, d)
	end
	local function glow(on)
		for _, d in dots do
			tween(d, { BackgroundTransparency = on and 0 or 0.45 }, 0.15)
		end
	end
	for _, h in { right, bottom, cornerGrip } do
		h.MouseEnter:Connect(function()
			glow(true)
		end)
		h.MouseLeave:Connect(function()
			glow(false)
		end)
	end

	function state:SetLocked(v)
		self.Locked = v
		grips.Visible = not v
	end
	return state
end

--------------------------------------------------------------------------------
-- Keys / input dispatch
--------------------------------------------------------------------------------

local KEY_SHORT = {
	Insert = "ins", Delete = "del", LeftControl = "lctrl", RightControl = "rctrl",
	LeftShift = "lshift", RightShift = "rshift", LeftAlt = "lalt", RightAlt = "ralt",
	Return = "enter", Backspace = "bksp", Escape = "esc", Space = "space", Tab = "tab",
	CapsLock = "caps", Home = "home", End = "end", PageUp = "pgup", PageDown = "pgdn",
	Up = "up", Down = "down", Left = "left", Right = "right", Unknown = "?",
	Zero = "0", One = "1", Two = "2", Three = "3", Four = "4",
	Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9",
	Backquote = "`", Minus = "-", Equals = "=",
}

local function keyName(key)
	if not key then
		return "none"
	end
	if typeof(key) == "EnumItem" then
		if key.EnumType == Enum.UserInputType then
			if key == MB1 then
				return "m1"
			elseif key == Enum.UserInputType.MouseButton2 then
				return "m2"
			elseif key == Enum.UserInputType.MouseButton3 then
				return "m3"
			end
		end
		return KEY_SHORT[key.Name] or key.Name:lower()
	end
	return tostring(key)
end

local function keyToString(key)
	if typeof(key) == "EnumItem" then
		return tostring(key.EnumType) .. "." .. key.Name
	end
	return nil
end

local function stringToKey(s)
	if type(s) ~= "string" then
		return nil
	end
	local t, n = s:match("^(%w+)%.(%w+)$")
	if not t then
		return nil
	end
	local ok, res = pcall(function()
		return Enum[t][n]
	end)
	return ok and res or nil
end

function Library:_setupInput()
	if self._inputReady then
		return
	end
	self._inputReady = true

	self:_global(UserInputService.InputBegan, function(input, processed)
		if self._listening then
			return
		end
		if self.ToggleKey and not processed and input.KeyCode == self.ToggleKey then
			self:ToggleUI()
			return
		end
		if processed then
			return
		end
		for kb in self._keybinds do
			local key = kb.Key
			if key and (input.KeyCode == key or input.UserInputType == key) and kb.Enabled ~= false then
				kb.Down = true
				if kb.OnPress then
					task.spawn(kb.OnPress, true)
				end
			end
		end
	end)

	self:_global(UserInputService.InputEnded, function(input)
		for kb in self._keybinds do
			local key = kb.Key
			if kb.Down and key and (input.KeyCode == key or input.UserInputType == key) then
				kb.Down = false
				if kb.OnRelease then
					task.spawn(kb.OnRelease, false)
				end
			end
		end
	end)
end

function Library:_registerKeybind(kb)
	self._keybinds[kb] = true
	return function()
		self._keybinds[kb] = nil
	end
end

--- Show / hide all windows & sub-windows (HUD elements stay visible).
function Library:ToggleUI(state)
	if not self.WindowLayer then
		return
	end
	if state == nil then
		state = not self.WindowLayer.Visible
	end
	self.WindowLayer.Visible = state
	self:_backdropShow(state)
end


--------------------------------------------------------------------------------
-- Backdrop: screen dim + weather particles behind the UI (visible while the UI is)
--------------------------------------------------------------------------------

Library.Backdrop = {
	Enabled = false,
	Weather = "Snow", -- "Snow" | "Rain" | "Fireflies" | "None"
	Tint = 0.45,      -- 0..1 darkening of the game behind the windows
	Dim = true,
	Density = 1,
	Speed = 1,
}

local WEATHER_COUNT = { Snow = 70, Rain = 110, Fireflies = 26 }

function Library:_backdropBuild()
	local holder = self._bdHolder
	if not holder then
		return
	end
	for _, p in self._bdParts or {} do
		p.frame:Destroy()
	end
	self._bdParts = {}
	local bd = self.Backdrop
	local kind = bd.Weather
	local count = math.floor((WEATHER_COUNT[kind] or 0) * math.max(bd.Density, 0))
	if reducedMotion() then
		count = math.floor(count * 0.4)
	end
	local size = self.Gui.AbsoluteSize
	if size.X < 2 and workspace.CurrentCamera then
		size = workspace.CurrentCamera.ViewportSize
	end
	local W, H = math.max(size.X, 1), math.max(size.Y, 1)
	for i = 1, count do
		local p = { kind = kind, x = math.random() * W, y = math.random() * H, phase = math.random() * 6.28 }
		if kind == "Snow" then
			local s = 4 + (math.random() ^ 2) * 18
			p.size = s
			p.vy = 26 + s * 2.2
			p.vx = -6 + math.random() * 12
			p.sway = 0.6 + math.random() * 1.2
			p.frame = New("Frame", {
				Size = UDim2.fromOffset(s, s),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.4 + (s / 22) * 0.45,
				Parent = holder,
			})
			corner(p.frame, 100)
		elseif kind == "Rain" then
			local len = 12 + math.random() * 14
			p.size = len
			p.vy = 650 + math.random() * 320
			p.vx = -p.vy * 0.21
			p.frame = New("Frame", {
				Size = UDim2.fromOffset(1, len),
				Rotation = 12,
				BackgroundColor3 = Color3.fromRGB(205, 218, 238),
				BackgroundTransparency = 0.55 + math.random() * 0.2,
				Parent = holder,
			})
		elseif kind == "Fireflies" then
			local s = 4 + math.random() * 3
			p.size = s
			p.vx = (math.random() - 0.5) * 24
			p.vy = (math.random() - 0.5) * 24
			p.pulse = 0.8 + math.random() * 1.4
			p.frame = New("Frame", {
				Size = UDim2.fromOffset(s, s),
				BackgroundColor3 = Color3.fromRGB(255, 232, 150),
				BackgroundTransparency = 0.5,
				Parent = holder,
			})
			corner(p.frame, 100)
		end
		if p.frame then
			p.frame.Position = UDim2.fromOffset(p.x, p.y)
			table.insert(self._bdParts, p)
		end
	end
end

function Library:_backdropStep(dt)
	local bd = self.Backdrop
	local parts = self._bdParts
	if not (self._bdShown and parts and #parts > 0) then
		return
	end
	dt = math.min(dt, 0.1)
	local size = self.Gui.AbsoluteSize
	local W, H = math.max(size.X, 1), math.max(size.Y, 1)
	local t = os.clock()
	local sp = bd.Speed
	for _, p in parts do
		if p.kind == "Snow" then
			p.y += p.vy * sp * dt
			p.x += (p.vx + math.sin(t * p.sway + p.phase) * 14) * sp * dt
			if p.y > H + p.size then
				p.y = -p.size
				p.x = math.random() * W
			end
			if p.x > W + p.size then
				p.x = -p.size
			elseif p.x < -p.size then
				p.x = W + p.size
			end
		elseif p.kind == "Rain" then
			p.y += p.vy * sp * dt
			p.x += p.vx * sp * dt
			if p.y > H + p.size then
				p.y = -p.size
				p.x = math.random() * (W + 200)
			end
		else -- Fireflies
			p.vx = math.clamp(p.vx + (math.random() - 0.5) * 40 * dt, -22, 22)
			p.vy = math.clamp(p.vy + (math.random() - 0.5) * 40 * dt, -22, 22)
			p.x = (p.x + p.vx * sp * dt) % W
			p.y = (p.y + p.vy * sp * dt) % H
			p.frame.BackgroundTransparency = 0.2 + 0.7 * (0.5 + 0.5 * math.sin(t * p.pulse + p.phase))
		end
		p.frame.Position = UDim2.fromOffset(p.x, p.y)
	end
end

function Library:_backdropShow(on)
	local bd = self.Backdrop
	self._bdShown = on and bd.Enabled and true or false
	if self._bdDim then
		tween(self._bdDim, { BackgroundTransparency = (self._bdShown and bd.Dim) and (1 - bd.Tint) or 1 }, 0.3)
	end
	if self._bdHolder then
		self._bdHolder.Visible = self._bdShown
	end
end

--[[
	Library:SetBackdrop({ Weather = "Snow", Tint = 0.45, Dim = true, Density = 1, Speed = 1 })
	Library:SetBackdrop(false)   -- off
	The dim + weather show while the windows are shown (RightShift hides them together).
]]
function Library:SetBackdrop(opts)
	self:_Gui()
	local bd = self.Backdrop
	if opts == false then
		bd.Enabled = false
	elseif type(opts) == "table" then
		for k, v in opts do
			bd[k] = v
		end
		if opts.Enabled == nil then
			bd.Enabled = true
		end
	else
		bd.Enabled = true
	end
	self:_backdropBuild()
	self:_backdropShow(self.WindowLayer.Visible)
end

--------------------------------------------------------------------------------
-- Dock: small bar at the top-centre with one icon button per window
--------------------------------------------------------------------------------

--[[
	local dock = Library:CreateDock({
		Items = {
			{ Name = "Main", Icon = "app-window", Window = window },          -- Window or SubWindow: toggles it
			{ Name = "ESP",  Icon = "scan-face",  Window = espWindow },
			{ Name = "Keys", Icon = "keyboard",   Window = keyWindow },
			{ Name = "Hub",  Icon = "command",    Callback = function(on) end, Toggle = true, Active = false },
		},
	})
	dock:AddItem({...}), dock:SetVisible(bool), dock:Destroy()
]]
function Library:CreateDock(opts)
	opts = opts or {}
	self:_Gui()
	if self.AutoLoadIcons then
		self:LoadIcons()
	end
	if self.Dock then
		self.Dock:Destroy()
	end

	local frame = New("Frame", {
		Name = "Dock",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = opts.Position or UDim2.new(0.5, 0, 0, GuiService:GetGuiInset().Y + 12),
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = "@Background",
		BackgroundTransparency = gl(0.04),
		Parent = self.HudLayer,
	})
	corner(frame, 8)
	stroke(frame, "@Stroke", 1, 0.2)
	pad(frame, 6, 6, 6, 6)
	list(frame, 6, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center)

	local dock = { Instance = frame, Items = {} }

	local function winOpen(w)
		if w.Opened ~= nil then
			return w.Opened == true
		end
		return w.Instance ~= nil and w.Instance.Visible
	end

	function dock:AddItem(item)
		item = item or {}
		local btn = New("TextButton", {
			Name = "DockItem_" .. tostring(item.Name or #self.Items + 1),
			Size = UDim2.fromOffset(32, 32),
			BackgroundColor3 = "@Checkbox",
			BackgroundTransparency = 1,
			LayoutOrder = #self.Items + 1,
			Parent = frame,
		})
		corner(btn, 6)
		local pop = New("UIScale", { Parent = btn })
		local ic = icon(btn, item.Icon or "layout-grid", 17, Library.Theme.SubText, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
		})
		if item.Name then
			Library:_attachTooltip(btn, tostring(item.Name))
		end

		local entry = { Button = btn, Item = item, Active = item.Active == true }
		local hover = false
		local function paint()
			local on = entry.Active
			tween(btn, { BackgroundTransparency = on and 0.35 or (hover and 0.7 or 1) }, 0.12)
			local c = on and selText() or (hover and Library.Theme.Text or Library.Theme.SubText)
			tween(ic, { ImageColor3 = c }, 0.12)
			local fb = ic:FindFirstChild("Fallback")
			if fb then
				tween(fb, { TextColor3 = c }, 0.12)
			end
		end
		entry.Paint = paint
		btn.MouseEnter:Connect(function()
			hover = true
			tween(pop, { Scale = 1.14 }, 0.3, Enum.EasingStyle.Back)
			paint()
		end)
		btn.MouseLeave:Connect(function()
			hover = false
			tween(pop, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)
			paint()
		end)
		btn.MouseButton1Down:Connect(function()
			tween(pop, { Scale = 0.9 }, 0.08)
		end)
		btn.MouseButton1Up:Connect(function()
			tween(pop, { Scale = hover and 1.14 or 1 }, 0.3, Enum.EasingStyle.Back)
		end)
		btn.Activated:Connect(function()
			if item.Window then
				item.Window:Toggle()
				entry.Active = winOpen(item.Window)
			elseif item.Toggle then
				entry.Active = not entry.Active
			end
			paint()
			safeCall(item.Callback, entry.Active)
		end)
		if item.Window then
			entry.Active = winOpen(item.Window)
		end
		paint()
		table.insert(self.Items, entry)
		return entry
	end

	-- keep the active state in sync when a window is closed from its own controls
	Library:_global(RunService.Heartbeat, function()
		for _, e in dock.Items do
			local w = e.Item.Window
			if w then
				local now = winOpen(w)
				if now ~= e.Active then
					e.Active = now
					e.Paint()
				end
			end
		end
	end)

	function dock:SetVisible(v)
		frame.Visible = v
	end

	function dock:Destroy()
		frame:Destroy()
		Library.Dock = nil
	end

	for _, item in opts.Items or {} do
		dock:AddItem(item)
	end
	self.Dock = dock
	return dock
end

--------------------------------------------------------------------------------
-- Tooltips
--------------------------------------------------------------------------------

function Library:_attachTooltip(gui, text)
	if not text or text == "" then
		return
	end
	local tip = self._tip
	if not tip then
		tip = New("Frame", {
			Name = "Tooltip",
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			BackgroundColor3 = "@Background",
			BackgroundTransparency = gl(0.05),
			Visible = false,
			Parent = self.TipLayer,
		})
		corner(tip, 6)
		stroke(tip, "@Stroke")
		pad(tip, 8, 5)
		New("UISizeConstraint", { MaxSize = Vector2.new(260, 400), Parent = tip })
		New("TextLabel", {
			Name = "Text",
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			TextWrapped = true,
			RichText = true,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = tip,
		})
		self._tip = tip
	end
	local function move(p)
		local screen = self.Gui.AbsoluteSize
		local size = tip.AbsoluteSize
		local x = clamp(p.X + 14, 4, screen.X - size.X - 4)
		local y = clamp(p.Y + 18, 4, screen.Y - size.Y - 4)
		tip.Position = UDim2.fromOffset(x, y)
	end
	gui.MouseEnter:Connect(function()
		tip.Text.Text = text
		tip.Visible = true
		move(UserInputService:GetMouseLocation())
	end)
	gui.MouseMoved:Connect(function()
		move(UserInputService:GetMouseLocation())
	end)
	gui.MouseLeave:Connect(function()
		tip.Visible = false
	end)
end

--------------------------------------------------------------------------------
-- Notifications (top-right toasts)
--------------------------------------------------------------------------------

local NOTIFY_COLORS = { Info = "Text", Success = "Success", Warning = "Warning", Error = "Danger" }
local NOTIFY_ICONS = { Info = "bell", Success = "check", Warning = "triangle-alert", Error = "circle-x" }

--[[
	Library:Notify({ Title, Content, Duration = 4, Icon, Type = "Info"|"Success"|"Warning"|"Error" })
	Returns an object with :Dismiss()
]]
function Library:Notify(opts)
	if type(opts) == "string" then
		opts = { Title = opts }
	end
	opts = opts or {}
	self:_Gui()

	if not self._toastHolder then
		self._toastHolder = New("Frame", {
			Name = "ToastHolder",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, GuiService:GetGuiInset().Y + 10),
			Size = UDim2.new(0, 290, 1, -80),
			Parent = self.ToastLayer,
		})
		list(self._toastHolder, 8, nil, Enum.HorizontalAlignment.Right)
		self._toasts = {}
	end

	local kind = opts.Type or "Info"
	local colorKey = NOTIFY_COLORS[kind] or "Accent"
	local duration = opts.Duration or 4

	-- cap the stack
	while #self._toasts >= 6 do
		local old = table.remove(self._toasts, 1)
		old:Dismiss(true)
	end

	local holder = New("Frame", {
		Name = "Toast",
		Size = UDim2.fromOffset(290, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = self._toastHolder,
	})

	local toast = New("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(1, 40, 0, 0),
		GroupTransparency = 1,
		BackgroundColor3 = "@Background",
		BackgroundTransparency = gl(0.06),
		Parent = holder,
	})
	corner(toast, 8)
	stroke(toast, "@Stroke", 1, 0.2)
	pad(toast, 12, 10, 12, 12)
	list(toast, 3)

	local head = New("Frame", { Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, Parent = toast })
	local ic = icon(head, opts.Icon or NOTIFY_ICONS[kind], 15, "@" .. colorKey, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
	})
	New("TextLabel", {
		Position = UDim2.fromOffset(23, 0),
		Size = UDim2.new(1, -23, 1, 0),
		Text = tostring(opts.Title or "Notification"),
		FontFace = FONT_SEMI,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = head,
	})

	if opts.Content and opts.Content ~= "" then
		New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = tostring(opts.Content),
			TextWrapped = true,
			RichText = true,
			TextSize = 12,
			TextColor3 = "@SubText",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 2,
			Parent = toast,
		})
	end

	local barBack = New("Frame", {
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = "@Element",
		BackgroundTransparency = 0,
		LayoutOrder = 3,
		Parent = toast,
	})
	corner(barBack, 1)
	local bar = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = "@" .. colorKey,
		BackgroundTransparency = 0,
		Parent = barBack,
	})
	corner(bar, 1)

	local handle = { Dismissed = false }
	function handle:Dismiss(instant)
		if self.Dismissed then
			return
		end
		self.Dismissed = true
		local i = table.find(Library._toasts, self)
		if i then
			table.remove(Library._toasts, i)
		end
		if instant then
			holder:Destroy()
			return
		end
		tween(toast, { Position = UDim2.new(1, 40, 0, 0), GroupTransparency = 1 }, 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.24, function()
			if not holder.Parent then
				return
			end
			holder.AutomaticSize = Enum.AutomaticSize.None
			holder.Size = UDim2.fromOffset(290, holder.AbsoluteSize.Y)
			local tw = tween(holder, { Size = UDim2.fromOffset(290, 0) }, 0.15)
			tw.Completed:Wait()
			holder:Destroy()
		end)
	end
	table.insert(self._toasts, handle)

	-- clicking dismisses
	local click = New("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = holder })
	click.Activated:Connect(function()
		handle:Dismiss()
	end)

	tween(toast, { Position = UDim2.new(0, 0, 0, 0), GroupTransparency = 0 }, 0.55, Enum.EasingStyle.Back)
	if duration > 0 then
		tween(bar, { Size = UDim2.fromScale(0, 1) }, duration, Enum.EasingStyle.Linear)
		task.delay(duration, function()
			handle:Dismiss()
		end)
	end
	return handle
end

--------------------------------------------------------------------------------
-- Config (Flags <-> table / JSON / files)
--------------------------------------------------------------------------------

local function encodeValue(v)
	local t = typeof(v)
	if t == "Color3" then
		return { __t = "Color3", Hex = toHex(v) }
	elseif t == "EnumItem" then
		return { __t = "Enum", Key = keyToString(v) }
	end
	return v
end

local function decodeValue(v)
	if type(v) == "table" then
		if v.__t == "Color3" then
			return fromHex(v.Hex)
		elseif v.__t == "Enum" then
			return stringToKey(v.Key)
		end
	end
	return v
end

--- Collect every flag that supports saving into a plain table.
function Library:GetConfig()
	local out = {}
	for flag, obj in self.Flags do
		if obj._serialize then
			local ok, data = pcall(obj._serialize, obj)
			if ok and data ~= nil then
				local enc = {}
				for k, v in data do
					enc[k] = encodeValue(v)
				end
				out[flag] = enc
			end
		end
	end
	return out
end

function Library:LoadConfig(tbl)
	for flag, data in tbl do
		local obj = self.Flags[flag]
		if obj and obj._deserialize and type(data) == "table" then
			local dec = {}
			for k, v in data do
				dec[k] = decodeValue(v)
			end
			pcall(obj._deserialize, obj, dec)
		end
	end
end

function Library:GetConfigString()
	return HttpService:JSONEncode(self:GetConfig())
end

function Library:LoadConfigString(str)
	local ok, tbl = pcall(HttpService.JSONDecode, HttpService, str)
	if not ok or type(tbl) ~= "table" then
		return false, "Invalid config string"
	end
	self:LoadConfig(tbl)
	return true
end

function Library:Unload()
	if self.Unloaded then
		return
	end
	self.Unloaded = true
	for _, c in self._conns do
		pcall(function()
			c:Disconnect()
		end)
	end
	table.clear(self._conns)
	table.clear(self._keybinds)
	if self.Gui then
		self.Gui:Destroy()
	end
	table.clear(self.Flags)
end

--------------------------------------------------------------------------------
-- Element base
--------------------------------------------------------------------------------

local Base = {}
Base.__index = Base

function Base:Get()
	return self.Value
end

function Base:OnChanged(fn)
	return self.Changed:Connect(fn)
end

function Base:SetVisible(v)
	self.Instance.Visible = v
end

function Base:SetDisabled(d)
	self.Disabled = d and true or false
	if not self._blocker then
		self._blocker = New("TextButton", {
			Name = "Blocker",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = "@Panel",
			BackgroundTransparency = 0.45,
			ZIndex = 30,
			Visible = false,
			Parent = self.Instance,
		})
		corner(self._blocker, 6)
	end
	self._blocker.Visible = self.Disabled
end

function Base:Destroy()
	if self.Flag and Library.Flags[self.Flag] == self then
		Library.Flags[self.Flag] = nil
	end
	if self._cleanup then
		self._cleanup()
	end
	if self.Instance then
		self.Instance:Destroy()
	end
end

local function emit(obj, ...)
	obj.Changed:Fire(obj.Value, ...)
	safeCall(obj.Callback, obj.Value, ...)
end

local function registerFlag(obj, flag)
	if not flag then
		return
	end
	if Library.Flags[flag] and Library.Flags[flag] ~= obj then
		warn("[LumenUI] Duplicate flag '" .. flag .. "' - the previous element was replaced.")
	end
	Library.Flags[flag] = obj
end

--------------------------------------------------------------------------------
-- Keybind chip (used by Toggle and the standalone Keybind element)
--------------------------------------------------------------------------------

function Library:_makeKeybindChip(parent, kopts, hooks)
	local chip = setmetatable({
		Key = kopts.Default,
		Mode = kopts.Mode or "Toggle",
		Changed = Signal.new(),
		Enabled = true,
		Flag = kopts.Flag,
		Callback = kopts.Callback,
	}, Base)
	hooks = hooks or {}

	local btn = New("TextButton", {
		Name = "KeybindChip",
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = "@Element",
		BackgroundTransparency = 0,
		Text = keyName(chip.Key),
		TextSize = 10,
		FontFace = FONT_SEMI,
		TextColor3 = "@SubText",
		ZIndex = 2,
		Parent = parent,
	})
	corner(btn, 4)
	stroke(btn, "@Stroke")
	pad(btn, 6, 0)
	chip.Instance = btn
	chip.Value = chip.Key

	Library:_attachTooltip(btn, "Left-click: rebind  -  Right-click: switch Toggle / Hold")

	function chip:Set(key, silent)
		self.Key = key
		self.Value = key
		btn.Text = keyName(key)
		if not silent then
			self.Changed:Fire(key)
			if hooks.OnKeyChanged then
				hooks.OnKeyChanged(key)
			end
		end
	end

	function chip:SetMode(mode, silent)
		self.Mode = mode
		if not silent and hooks.OnModeChanged then
			hooks.OnModeChanged(mode)
		end
	end

	chip._serialize = function(self)
		return { Key = self.Key, Mode = self.Mode }
	end
	chip._deserialize = function(self, data)
		self:Set(data.Key, true)
		if data.Mode then
			self:SetMode(data.Mode)
		end
	end

	btn.MouseButton1Click:Connect(function()
		if Library._listening then
			return
		end
		Library._listening = true
		btn.Text = "..."
		tween(btn, { TextColor3 = Library.Theme.Accent }, 0.1)
		local conn
		conn = UserInputService.InputBegan:Connect(function(input)
			local newKey, cancel = nil, false
			if input.UserInputType == Enum.UserInputType.Keyboard then
				if input.KeyCode == Enum.KeyCode.Escape then
					cancel = true
				elseif input.KeyCode == Enum.KeyCode.Backspace then
					newKey = nil
				else
					newKey = input.KeyCode
				end
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
				newKey = input.UserInputType
			elseif input.UserInputType == MB1 then
				cancel = true
			else
				return
			end
			conn:Disconnect()
			tween(btn, { TextColor3 = Library.Theme.SubText }, 0.1)
			if cancel then
				btn.Text = keyName(chip.Key)
			else
				chip:Set(newKey)
			end
			task.delay(0.15, function()
				Library._listening = false
			end)
		end)
	end)

	btn.MouseButton2Click:Connect(function()
		if chip.NoModeSwitch then
			return
		end
		if chip.Mode == "Toggle" then
			chip:SetMode("Hold")
		else
			chip:SetMode("Toggle")
		end
		Library:Notify({ Title = (chip.Name or "Keybind") .. " mode", Content = chip.Mode, Duration = 1.5 })
	end)

	chip.OnPress = hooks.OnPress
	chip.OnRelease = hooks.OnRelease
	chip._unregister = Library:_registerKeybind(chip)
	chip._cleanup = chip._unregister
	registerFlag(chip, kopts.Flag)
	return chip
end

--------------------------------------------------------------------------------
-- Color picker (swatch + inline panel). Used by Toggle and the standalone element.
--------------------------------------------------------------------------------

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
	ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
	ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
	ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
	ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
	ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
})

local function newPickerGroup(panelsFrame)
	return { Panels = panelsFrame, Pickers = {} }
end

function Library:_makeColorPicker(opts, swatchParent, group)
	if typeof(opts) == "Color3" then
		opts = { Default = opts }
	end
	local default = opts.Default or Color3.fromRGB(255, 255, 255)
	local h, s, v = default:ToHSV()

	local picker = setmetatable({
		Value = default,
		Transparency = opts.DefaultTransparency or 0,
		Changed = Signal.new(),
		Callback = opts.Callback,
		Flag = opts.Flag,
		Opened = false,
	}, Base)

	local swatch = New("TextButton", {
		Name = "Swatch",
		Size = UDim2.fromOffset(22, 14),
		BackgroundColor3 = default,
		BackgroundTransparency = 0,
		ZIndex = 2,
		Parent = swatchParent,
	})
	corner(swatch, 4)
	stroke(swatch, "@Stroke")
	picker.Instance = swatch

	local hasAlpha = opts.Alpha == true
	local hexY = hasAlpha and 124 or 106
	local innerH = hexY + 22
	local panelH = innerH + 16

	local panel = New("Frame", {
		Name = "ColorPanel",
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = "@Element",
		BackgroundTransparency = gl(0.1),
		ClipsDescendants = true,
		Visible = false,
		LayoutOrder = #group.Pickers + 1,
		Parent = group.Panels,
	})
	corner(panel, 6)
	stroke(panel, "@Stroke", 1, 0.3)

	local inner = New("Frame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, innerH),
		Parent = panel,
	})

	-- saturation / value square
	local sv = New("Frame", {
		Size = UDim2.new(1, 0, 0, 80),
		BackgroundColor3 = Color3.fromHSV(h, 1, 1),
		BackgroundTransparency = 0,
		ClipsDescendants = true,
		Parent = inner,
	})
	corner(sv, 4)
	local white = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, Parent = sv })
	New("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = white })
	local black = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, Parent = sv })
	New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = black })
	local svKnob = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Parent = sv,
	})
	corner(svKnob, 5)
	New("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Parent = svKnob })
	local svHit = New("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = sv })

	-- hue bar
	local hue = New("Frame", {
		Position = UDim2.fromOffset(0, 88),
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		Parent = inner,
	})
	corner(hue, 5)
	New("UIGradient", { Color = RAINBOW, Parent = hue })
	local hueKnob = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(6, 14),
		Position = UDim2.fromScale(h, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		Parent = hue,
	})
	corner(hueKnob, 3)
	stroke(hueKnob, Color3.new(0, 0, 0), 1, 0.4)
	local hueHit = New("TextButton", { Size = UDim2.new(1, 0, 1, 8), Position = UDim2.fromOffset(0, -4), ZIndex = 3, Parent = hue })

	-- alpha bar (optional)
	local alphaBar, alphaKnob, alphaHit
	if hasAlpha then
		alphaBar = New("Frame", {
			Position = UDim2.fromOffset(0, 106),
			Size = UDim2.new(1, 0, 0, 10),
			BackgroundColor3 = default,
			BackgroundTransparency = 0,
			Parent = inner,
		})
		corner(alphaBar, 5)
		New("UIGradient", { Transparency = NumberSequence.new(0, 0.92), Parent = alphaBar })
		stroke(alphaBar, "@Stroke", 1, 0.4)
		alphaKnob = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(6, 14),
			Position = UDim2.fromScale(picker.Transparency, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			Parent = alphaBar,
		})
		corner(alphaKnob, 3)
		stroke(alphaKnob, Color3.new(0, 0, 0), 1, 0.4)
		alphaHit = New("TextButton", { Size = UDim2.new(1, 0, 1, 8), Position = UDim2.fromOffset(0, -4), ZIndex = 3, Parent = alphaBar })
	end

	-- hex input
	local hexBox = New("TextBox", {
		Position = UDim2.fromOffset(0, hexY),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundColor3 = "@Panel",
		BackgroundTransparency = 0,
		Text = toHex(default),
		PlaceholderText = "#RRGGBB",
		ClearTextOnFocus = false,
		TextSize = 11,
		Parent = inner,
	})
	corner(hexBox, 4)
	stroke(hexBox, "@Stroke", 1, 0.3)

	local function render()
		local c = Color3.fromHSV(h, s, v)
		picker.Value = c
		swatch.BackgroundColor3 = c
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svKnob.Position = UDim2.fromScale(s, 1 - v)
		hueKnob.Position = UDim2.fromScale(h, 0.5)
		if alphaBar then
			alphaBar.BackgroundColor3 = c
			alphaKnob.Position = UDim2.fromScale(picker.Transparency, 0.5)
		end
		if not hexBox:IsFocused() then
			hexBox.Text = toHex(c)
		end
		swatch.BackgroundTransparency = hasAlpha and picker.Transparency * 0.85 or 0
	end

	local function changed()
		render()
		emit(picker, picker.Transparency)
	end

	local function relX(gui, input)
		local p = pointerPos(input)
		return clamp((p.X - gui.AbsolutePosition.X) / math.max(gui.AbsoluteSize.X, 1), 0, 1)
	end
	local function updateSV(input)
		local p = pointerPos(input)
		s = clamp((p.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
		v = 1 - clamp((p.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
		changed()
	end
	bindDrag(svHit, updateSV, updateSV)
	local function updateHue(input)
		h = relX(hue, input)
		changed()
	end
	bindDrag(hueHit, updateHue, updateHue)
	if alphaHit then
		local function updateAlpha(input)
			picker.Transparency = snap(relX(alphaBar, input), 0.01, 0)
			changed()
		end
		bindDrag(alphaHit, updateAlpha, updateAlpha)
	end

	hexBox.FocusLost:Connect(function()
		local c = fromHex(hexBox.Text)
		if c then
			h, s, v = c:ToHSV()
			changed()
		else
			render()
		end
	end)

	function picker:Set(color, transparency, silent)
		if typeof(color) == "Color3" then
			h, s, v = color:ToHSV()
		end
		if transparency then
			self.Transparency = transparency
		end
		render()
		if not silent then
			emit(self, self.Transparency)
		end
	end

	function picker:Open()
		if self.Opened then
			return
		end
		for _, other in group.Pickers do
			if other ~= self and other.Opened then
				other:Close()
			end
		end
		self.Opened = true
		group.Panels.Visible = true
		panel.Visible = true
		tween(panel, { Size = UDim2.new(1, 0, 0, panelH) }, 0.2)
	end

	function picker:Close()
		if not self.Opened then
			return
		end
		self.Opened = false
		tween(panel, { Size = UDim2.new(1, 0, 0, 0) }, 0.16)
		task.delay(0.17, function()
			if self.Opened then
				return
			end
			panel.Visible = false
			for _, p in group.Pickers do
				if p.Opened then
					return
				end
			end
			group.Panels.Visible = false
		end)
	end

	picker._serialize = function(self)
		return { Color = self.Value, Transparency = self.Transparency }
	end
	picker._deserialize = function(self, data)
		self:Set(data.Color, data.Transparency)
	end

	swatch.Activated:Connect(function()
		if picker.Opened then
			picker:Close()
		else
			picker:Open()
		end
	end)

	table.insert(group.Pickers, picker)
	registerFlag(picker, opts.Flag)
	render()
	return picker
end

--------------------------------------------------------------------------------
-- Container (shared by Section, SubTab and SubWindow)
--------------------------------------------------------------------------------

local Container = {}
Container.__index = Container

function Container:_row(height)
	self._order = (self._order or 0) + 1
	return New("Frame", {
		Name = "Element",
		Size = UDim2.new(1, 0, 0, height or 24),
		LayoutOrder = self._order,
		Parent = self.Content,
	})
end

-- Returns the outer frame (no layout, safe for overlays) and the body that holds laid-out children.
function Container:_autoRow(padding)
	local f = self:_row(0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	if not padding then
		return f, f
	end
	local body = New("Frame", { Name = "Body", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = f })
	list(body, padding)
	return f, body
end

function Container:_finish(obj, opts, frame, skipTooltip)
	obj.Instance = frame
	obj.Changed = obj.Changed or Signal.new()
	obj.Callback = opts.Callback
	obj.Flag = opts.Flag
	obj.Container = self
	setmetatable(obj, Base)
	registerFlag(obj, opts.Flag)
	if opts.Tooltip and not skipTooltip then
		Library:_attachTooltip(frame, opts.Tooltip)
	end
	if opts.Disabled then
		obj:SetDisabled(true)
	end
	return obj
end

local function nameLabel(parent, text, props)
	props = props or {}
	return New("TextLabel", {
		Name = "Name",
		Size = props.Size or UDim2.new(1, 0, 0, 16),
		Position = props.Position,
		Text = text or "",
		FontFace = FONT_SEMI,
		TextSize = 12,
		TextXAlignment = props.Align or Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = props.LayoutOrder,
		Parent = parent,
	})
end

---------------------------------------------------------------------- Label --

function Container:AddLabel(opts)
	if type(opts) == "string" then
		opts = { Text = opts }
	end
	local frame = self:_autoRow()
	local lbl = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = tostring(opts.Text or ""),
		TextWrapped = true,
		RichText = true,
		TextSize = opts.Size or 12,
		FontFace = opts.Bold and FONT_SEMI or FONT_REG,
		TextColor3 = opts.Color or (opts.Dim and "@SubText" or "@Text"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = frame,
	})
	local obj = { Value = lbl.Text, Label = lbl }
	function obj:Set(text, silent)
		self.Value = tostring(text)
		lbl.Text = self.Value
		if not silent then
			self.Changed:Fire(self.Value)
		end
	end
	obj.SetText = obj.Set
	return self:_finish(obj, opts, frame)
end

--------------------------------------------------------------------- Divider --

function Container:AddDivider()
	local frame = self:_row(9)
	New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = "@Stroke",
		BackgroundTransparency = 0.4,
		Parent = frame,
	})
	return self:_finish({}, {}, frame)
end

function Container:AddSpacer(height)
	return self:_finish({}, {}, self:_row(height or 6))
end

-------------------------------------------------------------------- Button --

function Container:AddButton(opts)
	if type(opts) == "string" then
		opts = { Name = opts }
	end
	local frame = self:_row(opts.Height or 28)
	list(frame, 6, Enum.FillDirection.Horizontal)

	local hasSub = opts.SubButton ~= nil
	local obj = {}

	local function make(o, order)
		local btn = New("TextButton", {
			Name = "Button",
			Size = hasSub and UDim2.new(0.5, -3, 1, 0) or UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 0,
			Text = o.Name or "Button",
			FontFace = FONT_SEMI,
			TextSize = 12,
			LayoutOrder = order,
			Parent = frame,
		})
		corner(btn, 6)
		local st = stroke(btn, "@Stroke", 1, 0.2)
		local scale = New("UIScale", { Parent = btn })
		local baseKey = "Element"
		if o.Accent then
			accentGradient(btn, 20)
			st.Transparency = 1
			btn.TextColor3 = Color3.new(1, 1, 1)
		else
			bind(btn, "BackgroundColor3", baseKey)
		end
		if o.Icon then
			icon(btn, o.Icon, 14, "@SubText", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0) })
		end
		btn.MouseEnter:Connect(function()
			if not o.Accent then
				tween(btn, { BackgroundColor3 = Library.Theme.ElementHover }, 0.12)
			else
				tween(btn, { BackgroundTransparency = 0.12 }, 0.12)
			end
		end)
		btn.MouseLeave:Connect(function()
			if not o.Accent then
				tween(btn, { BackgroundColor3 = Library.Theme[baseKey] }, 0.12)
			else
				tween(btn, { BackgroundTransparency = 0 }, 0.12)
			end
			tween(scale, { Scale = 1 }, 0.1)
		end)
		btn.MouseButton1Down:Connect(function()
			tween(scale, { Scale = 0.95 }, 0.1)
			if not o.Accent then
				tween(btn, { BackgroundColor3 = Library.Theme.Stroke }, 0.08)
			end
		end)
		btn.MouseButton1Up:Connect(function()
			tween(scale, { Scale = 1 }, 0.35, Enum.EasingStyle.Back)
			if not o.Accent then
				tween(btn, { BackgroundColor3 = Library.Theme.ElementHover }, 0.1)
			end
		end)
		btn.Activated:Connect(function()
			if obj.Disabled then
				return
			end
			safeCall(o.Callback)
			obj.Changed:Fire()
		end)
		return btn
	end

	obj.Button = make(opts, 1)
	if hasSub then
		obj.Sub = make(opts.SubButton, 2)
	end
	function obj:SetText(t)
		self.Button.Text = t
	end
	function obj:SetSubText(t)
		if self.Sub then
			self.Sub.Text = t
		end
	end
	return self:_finish(obj, opts, frame)
end

-------------------------------------------------------------------- Toggle --

function Container:AddToggle(opts)
	if type(opts) == "string" then
		opts = { Name = opts }
	end
	local frame, body = self:_autoRow(4)
	local row = New("Frame", { Name = "Row", Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 1, Parent = body })
	local panels = New("Frame", {
		Name = "Panels",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Visible = false,
		Parent = body,
	})
	list(panels, 4)
	local group = newPickerGroup(panels)

	local hit = New("TextButton", { Name = "Hit", Size = UDim2.fromScale(1, 1), Parent = row })

	local box = New("Frame", {
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.new(0, 0, 0.5, -8),
		BackgroundColor3 = "@Checkbox",
		BackgroundTransparency = 0,
		Parent = row,
	})
	corner(box, 4)
	local boxStroke = stroke(box, "@Stroke")
	local fill = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		Parent = box,
	})
	accentGradient(fill, 45)
	corner(fill, 4)
	local check = icon(box, "check", 12, Color3.new(1, 1, 1), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 2,
	})
	check.ImageTransparency = 1

	local label = New("TextLabel", {
		Position = UDim2.fromOffset(26, 0),
		Size = UDim2.new(1, -26, 1, 0),
		Text = opts.Name or "Toggle",
		FontFace = FONT_SEMI,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})

	local extras = New("Frame", {
		Name = "Extras",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 2,
		Parent = row,
	})
	list(extras, 5, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	extras:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		label.Size = UDim2.new(1, -(30 + extras.AbsoluteSize.X), 1, 0)
	end)

	local obj = { Value = false }
	local listId = opts.Flag or (tostring(opts.Name) .. "_" .. HttpService:GenerateGUID(false):sub(1, 4))

	local function render()
		local on = obj.Value
		tween(fill, {
			Size = on and UDim2.fromScale(1, 1) or UDim2.fromScale(0, 0),
			BackgroundTransparency = on and 0 or 1,
		}, 0.3, Enum.EasingStyle.Back)
		tween(check, { ImageTransparency = on and 0 or 1 }, 0.12)
		tween(boxStroke, { Transparency = on and 1 or 0 }, 0.12)
	end

	function obj:Set(v, silent)
		v = v and true or false
		local changed = v ~= self.Value
		self.Value = v
		render()
		if changed then
			Library:_listSet(listId, { Active = v })
			if not silent then
				emit(self)
			end
		end
	end

	hit.Activated:Connect(function()
		if not obj.Disabled then
			obj:Set(not obj.Value)
		end
	end)
	hit.MouseEnter:Connect(function()
		tween(boxStroke, { Color = Library.Theme.Accent }, 0.1)
	end)
	hit.MouseLeave:Connect(function()
		tween(boxStroke, { Color = Library.Theme.Stroke }, 0.1)
	end)

	-- Keybind chip
	if opts.Keybind then
		local k = opts.Keybind
		if typeof(k) == "EnumItem" then
			k = { Default = k }
		end
		local showInList = k.ShowInList ~= false
		local chip
		chip = Library:_makeKeybindChip(extras, k, {
			OnPress = function()
				if chip.Mode == "Toggle" then
					obj:Set(not obj.Value)
				elseif chip.Mode == "Hold" then
					obj:Set(true)
				end
			end,
			OnRelease = function()
				if chip.Mode == "Hold" then
					obj:Set(false)
				end
			end,
			OnKeyChanged = function(key)
				Library:_listSet(listId, { Key = key })
			end,
		})
		chip.Name = opts.Name
		obj.Keybind = chip
		if showInList then
			Library:_listSet(listId, { Name = k.ListName or opts.Name or "Toggle", Key = chip.Key, Active = false, Show = true })
		end
	end

	-- Color pickers (1 or more)
	local colors = opts.Colors or (opts.Color and { opts.Color }) or nil
	if colors then
		obj.Colors = {}
		for i, c in colors do
			local picker = Library:_makeColorPicker(c, extras, group)
			picker.Instance.LayoutOrder = 10 + i
			table.insert(obj.Colors, picker)
		end
		obj.Color = obj.Colors[1]
	end

	-- Tooltip chip
	if opts.Tooltip then
		local q = New("TextButton", {
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = "@Element",
			BackgroundTransparency = 0,
			Text = "?",
			TextSize = 10,
			FontFace = FONT_BOLD,
			TextColor3 = "@SubText",
			LayoutOrder = 99,
			ZIndex = 2,
			Parent = extras,
		})
		corner(q, 8)
		stroke(q, "@Stroke")
		Library:_attachTooltip(q, opts.Tooltip)
	end

	obj._serialize = function(self)
		return { Value = self.Value }
	end
	obj._deserialize = function(self, data)
		self:Set(data.Value)
	end
	obj._cleanup = function()
		Library:_listRemove(listId)
		if obj.Keybind then
			obj.Keybind:Destroy()
		end
	end

	self:_finish(obj, opts, frame, true)
	obj:Set(opts.Default == true, true)
	return obj
end

-------------------------------------------------------------------- Keybind --

function Container:AddKeybind(opts)
	if type(opts) == "string" then
		opts = { Name = opts }
	end
	local frame = self:_row(24)
	local label = New("TextLabel", {
		Size = UDim2.new(1, -70, 1, 0),
		Text = opts.Name or "Keybind",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})
	local holder = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = frame,
	})
	list(holder, 4, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center)

	local obj = { State = false }
	local mode = opts.Mode or "Press"
	local chip
	chip = Library:_makeKeybindChip(holder, { Default = opts.Default, Mode = "Toggle" }, {
		OnPress = function()
			if mode == "Press" then
				safeCall(obj.Callback, chip.Key)
			elseif mode == "Toggle" then
				obj.State = not obj.State
				safeCall(obj.Callback, obj.State)
			elseif mode == "Hold" then
				obj.State = true
				safeCall(obj.Callback, true)
			end
		end,
		OnRelease = function()
			if mode == "Hold" then
				obj.State = false
				safeCall(obj.Callback, false)
			end
		end,
		OnKeyChanged = function(key)
			obj.Value = key
			obj.Changed:Fire(key)
		end,
	})
	chip.NoModeSwitch = true
	obj.Chip = chip
	obj.Value = chip.Key
	function obj:Set(key, silent)
		chip:Set(key, true)
		self.Value = key
		if not silent then
			self.Changed:Fire(key)
		end
	end
	obj._serialize = function(self)
		return { Key = self.Value }
	end
	obj._deserialize = function(self, data)
		self:Set(data.Key)
	end
	obj._cleanup = function()
		chip:Destroy()
	end
	return self:_finish(obj, opts, frame)
end

-------------------------------------------------------------- Color picker --

function Container:AddColorPicker(opts)
	if type(opts) == "string" then
		opts = { Name = opts }
	end
	local frame, body = self:_autoRow(4)
	local row = New("Frame", { Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 1, Parent = body })
	New("TextLabel", {
		Size = UDim2.new(1, -40, 1, 0),
		Text = opts.Name or "Color",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})
	local holder = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = row,
	})
	list(holder, 4, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center)
	local panels = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Visible = false,
		Parent = body,
	})
	list(panels, 4)
	local group = newPickerGroup(panels)
	local picker = Library:_makeColorPicker(opts, holder, group)
	picker.Instance = frame -- the element frame is the visible root (swatch lives inside)
	picker.Callback = opts.Callback
	if opts.Tooltip then
		Library:_attachTooltip(row, opts.Tooltip)
	end
	if opts.Disabled then
		picker:SetDisabled(true)
	end
	picker.Container = self
	return picker
end

-------------------------------------------------------------------- Slider --

function Container:AddSlider(opts)
	opts = opts or {}
	local min, max = opts.Min or 0, opts.Max or 100
	local inc = opts.Increment or opts.Rounding or 1
	local decimals = decimalsOf(inc)
	local frame = self:_row(38)

	nameLabel(frame, opts.Name or "Slider", { Size = UDim2.new(0.6, 0, 0, 16) })
	local valueLabel = New("TextLabel", {
		Position = UDim2.fromScale(0.6, 0),
		Size = UDim2.new(0.4, 0, 0, 16),
		TextSize = 11,
		TextColor3 = "@SubText",
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = frame,
	})

	local track = New("Frame", {
		Position = UDim2.fromOffset(0, 25),
		Size = UDim2.new(1, 0, 0, 5),
		BackgroundColor3 = "@Element",
		BackgroundTransparency = 0,
		Parent = frame,
	})
	corner(track, 3)
	stroke(track, "@Stroke", 1, 0.5)
	local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundTransparency = 0, Parent = track })
	accentGradient(fill, 0)
	corner(fill, 3)
	local knob = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(11, 11),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		ZIndex = 2,
		Parent = track,
	})
	corner(knob, 6)
	local knobScale = New("UIScale", { Parent = knob })
	local hit = New("TextButton", { Position = UDim2.fromOffset(0, 17), Size = UDim2.new(1, 0, 0, 22), ZIndex = 3, Parent = frame })

	local obj = { Value = min }

	local function format(val)
		if opts.Format then
			return tostring(opts.Format(val, min, max))
		end
		local s = string.format("%." .. decimals .. "f", val)
		if opts.Display then
			s = (opts.Display:gsub("{value}", s):gsub("{min}", tostring(min)):gsub("{max}", tostring(max)))
		end
		return s .. (opts.Suffix or "")
	end

	local function render(animate)
		local frac = max == min and 0 or (obj.Value - min) / (max - min)
		valueLabel.Text = format(obj.Value)
		if animate then
			tween(fill, { Size = UDim2.fromScale(frac, 1) }, 0.22, Enum.EasingStyle.Quint)
			tween(knob, { Position = UDim2.fromScale(frac, 0.5) }, 0.22, Enum.EasingStyle.Quint)
		else
			fill.Size = UDim2.fromScale(frac, 1)
			knob.Position = UDim2.fromScale(frac, 0.5)
		end
	end

	function obj:Set(val, silent, animate)
		val = clamp(snap(tonumber(val) or min, inc, min), min, max)
		local changed = val ~= self.Value
		self.Value = val
		render(animate ~= false and not self._dragging)
		if changed and not silent then
			emit(self)
		end
	end

	local function fromInput(input)
		local p = pointerPos(input)
		local frac = clamp((p.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		obj:Set(min + (max - min) * frac, false, false)
	end
	bindDrag(hit, function(input)
		if obj.Disabled then
			return false
		end
		obj._dragging = true
		tween(knobScale, { Scale = 1.5 }, 0.22, Enum.EasingStyle.Back)
		fromInput(input)
	end, fromInput, function()
		obj._dragging = false
		tween(knobScale, { Scale = 1 }, 0.3, Enum.EasingStyle.Back)
	end)

	obj._serialize = function(self)
		return { Value = self.Value }
	end
	obj._deserialize = function(self, data)
		self:Set(data.Value)
	end

	self:_finish(obj, opts, frame)
	obj.Value = clamp(snap(opts.Default or min, inc, min), min, max)
	render(false)
	return obj
end

------------------------------------------------------------------- Dropdown --

function Container:AddDropdown(opts)
	opts = opts or {}
	local multi = opts.Multi == true
	local options = table.clone(opts.Options or {})
	local maxVisible = opts.MaxVisible or 6
	local ITEM_H = 22

	local frame, body = self:_autoRow(4)
	if opts.Name then
		nameLabel(body, opts.Name, { LayoutOrder = 1 })
	end
	local btn = New("TextButton", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = "@Element",
		BackgroundTransparency = 0,
		LayoutOrder = 2,
		Parent = body,
	})
	corner(btn, 6)
	local btnStroke = stroke(btn, "@Stroke", 1, 0.2)
	local current = New("TextLabel", {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -34, 1, 0),
		Text = "--",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = "@SubText",
		Parent = btn,
	})
	local arrow = icon(btn, "chevron-down", 14, "@SubText", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
	})

	local listWrap = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = "@Element",
		BackgroundTransparency = gl(0.05),
		ClipsDescendants = true,
		Visible = false,
		LayoutOrder = 3,
		Parent = body,
	})
	corner(listWrap, 6)
	stroke(listWrap, "@Stroke", 1, 0.3)
	local scroll = New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = "@Muted",
		ScrollingDirection = Enum.ScrollingDirection.Y,
		BorderSizePixel = 0,
		Parent = listWrap,
	})
	pad(scroll, 4, 4, 4, 4)
	list(scroll, 0)

	local obj = { Value = multi and {} or nil, Options = options, Opened = false }
	local items = {}

	local function isSelected(name)
		if multi then
			return table.find(obj.Value, name) ~= nil
		end
		return obj.Value == name
	end

	local function paintItem(name)
		local it = items[name]
		if not it then
			return
		end
		local sel = isSelected(name)
		tween(it.Label, { TextColor3 = sel and Library.Theme.Accent or Library.Theme.Text }, 0.12)
		tween(it.Bar, { BackgroundTransparency = sel and 0 or 1 }, 0.12)
	end

	local function renderCurrent()
		local txt
		if multi then
			txt = #obj.Value > 0 and table.concat(obj.Value, ", ") or "--"
		else
			txt = obj.Value ~= nil and tostring(obj.Value) or "--"
		end
		current.Text = txt
		local has = (multi and #obj.Value > 0) or (not multi and obj.Value ~= nil)
		current.TextColor3 = has and Library.Theme.Text or Library.Theme.SubText
	end

	local function listHeight()
		return math.min(#options, maxVisible) * ITEM_H + 8
	end

	local function setOpen(open)
		if open == obj.Opened then
			return
		end
		obj.Opened = open
		if open then
			listWrap.Visible = true
			tween(listWrap, { Size = UDim2.new(1, 0, 0, listHeight()) }, 0.38, Enum.EasingStyle.Back)
			tween(arrow, { Rotation = 180 }, 0.38, Enum.EasingStyle.Back)
			tween(btnStroke, { Color = Library.Theme.Accent }, 0.15)
		else
			tween(listWrap, { Size = UDim2.new(1, 0, 0, 0) }, 0.22, Enum.EasingStyle.Quint)
			tween(arrow, { Rotation = 0 }, 0.3, Enum.EasingStyle.Back)
			tween(btnStroke, { Color = Library.Theme.Stroke }, 0.15)
			task.delay(0.17, function()
				if not obj.Opened then
					listWrap.Visible = false
				end
			end)
		end
	end
	obj.SetOpen = function(_, o)
		setOpen(o)
	end

	local function choose(name)
		if obj.Disabled then
			return
		end
		if multi then
			local i = table.find(obj.Value, name)
			if i then
				table.remove(obj.Value, i)
			else
				table.insert(obj.Value, name)
			end
			paintItem(name)
		else
			if obj.Value == name and opts.AllowNone then
				obj.Value = nil
			else
				local prev = obj.Value
				obj.Value = name
				if prev then
					paintItem(prev)
				end
			end
			paintItem(name)
			setOpen(false)
		end
		renderCurrent()
		emit(obj)
	end

	local function build()
		for _, it in items do
			it.Button:Destroy()
		end
		table.clear(items)
		for i, name in options do
			local b = New("TextButton", {
				Size = UDim2.new(1, 0, 0, ITEM_H),
				BackgroundColor3 = "@ElementHover",
				BackgroundTransparency = 1,
				LayoutOrder = i,
				Parent = scroll,
			})
			corner(b, 4)
			local bar = New("Frame", {
				Position = UDim2.fromOffset(0, 5),
				Size = UDim2.new(0, 2, 1, -10),
				BackgroundTransparency = 1,
				Parent = b,
			})
			accentGradient(bar, 90)
			local lbl = New("TextLabel", {
				Position = UDim2.fromOffset(9, 0),
				Size = UDim2.new(1, -14, 1, 0),
				Text = tostring(name),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = b,
			})
			items[name] = { Button = b, Label = lbl, Bar = bar }
			b.MouseEnter:Connect(function()
				tween(b, { BackgroundTransparency = 0.45 }, 0.1)
				tween(lbl, { Position = UDim2.fromOffset(14, 0) }, 0.2, Enum.EasingStyle.Back)
			end)
			b.MouseLeave:Connect(function()
				tween(b, { BackgroundTransparency = 1 }, 0.1)
				tween(lbl, { Position = UDim2.fromOffset(9, 0) }, 0.2, Enum.EasingStyle.Quint)
			end)
			b.Activated:Connect(function()
				choose(name)
			end)
			paintItem(name)
		end
		if obj.Opened then
			listWrap.Size = UDim2.new(1, 0, 0, listHeight())
		end
	end

	function obj:Set(value, silent)
		if multi then
			local new = {}
			for _, n in (type(value) == "table" and value or { value }) do
				if table.find(options, n) then
					table.insert(new, n)
				end
			end
			local old = self.Value
			self.Value = new
			for _, n in options do
				paintItem(n)
			end
			renderCurrent()
			if not silent then
				emit(self)
			end
			return old
		end
		if value ~= nil and not table.find(options, value) then
			return
		end
		local prev = self.Value
		self.Value = value
		if prev then
			paintItem(prev)
		end
		if value then
			paintItem(value)
		end
		renderCurrent()
		if prev ~= value and not silent then
			emit(self)
		end
	end

	function obj:SetOptions(newOptions, keepValue)
		options = table.clone(newOptions)
		self.Options = options
		if not keepValue then
			self.Value = multi and {} or nil
		else
			self:Set(self.Value, true)
		end
		build()
		renderCurrent()
	end

	btn.Activated:Connect(function()
		if not obj.Disabled then
			setOpen(not obj.Opened)
		end
	end)
	btn.MouseEnter:Connect(function()
		if not obj.Opened then
			tween(btn, { BackgroundColor3 = Library.Theme.ElementHover }, 0.1)
		end
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, { BackgroundColor3 = Library.Theme.Element }, 0.1)
	end)

	obj._serialize = function(self)
		return { Value = self.Value }
	end
	obj._deserialize = function(self, data)
		self:Set(data.Value)
	end

	self:_finish(obj, opts, frame)
	build()
	if opts.Default ~= nil then
		obj:Set(opts.Default, true)
	end
	renderCurrent()
	return obj
end

------------------------------------------------------------------- Textbox --

function Container:AddTextbox(opts)
	if type(opts) == "string" then
		opts = { Name = opts }
	end
	local multiline = opts.Multiline == true
	local height = opts.Height or (multiline and 70 or 26)
	local frame, body = self:_autoRow(4)
	if opts.Name then
		nameLabel(body, opts.Name, { LayoutOrder = 1 })
	end
	local wrap = New("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = "@Element",
		BackgroundTransparency = 0,
		LayoutOrder = 2,
		Parent = body,
	})
	corner(wrap, 6)
	local st = stroke(wrap, "@Stroke", 1, 0.2)
	local tb = New("TextBox", {
		Position = UDim2.fromOffset(10, multiline and 6 or 0),
		Size = UDim2.new(1, -20, 1, multiline and -12 or 0),
		Text = tostring(opts.Default or ""),
		PlaceholderText = opts.Placeholder or "",
		PlaceholderColor3 = Library.Theme.Muted,
		ClearTextOnFocus = false,
		MultiLine = multiline,
		TextWrapped = multiline,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
		Parent = wrap,
	})

	local obj = { Value = opts.Default or "" }
	local function read()
		local text = tb.Text
		if opts.Numeric then
			text = text:gsub("[^%d%.%-]", "")
			return tonumber(text)
		end
		return text
	end

	function obj:Set(value, silent)
		tb.Text = tostring(value or "")
		self.Value = read() or self.Value
		if not silent then
			emit(self)
		end
	end

	tb.Focused:Connect(function()
		tween(st, { Color = Library.Theme.Accent }, 0.12)
	end)
	tb.FocusLost:Connect(function(enter)
		tween(st, { Color = Library.Theme.Stroke }, 0.12)
		if opts.Numeric then
			local n = read()
			tb.Text = n ~= nil and tostring(n) or ""
		end
		if enter or opts.FireOnBlur ~= false then
			local val = read()
			if val ~= nil and val ~= obj.Value or (not opts.Numeric and val ~= obj.Value) then
				obj.Value = val
				emit(obj, enter)
			end
		end
	end)
	if opts.LiveUpdate then
		tb:GetPropertyChangedSignal("Text"):Connect(function()
			local val = read()
			if val ~= nil and val ~= obj.Value then
				obj.Value = val
				emit(obj, false)
			end
		end)
	end

	obj.TextBox = tb
	obj._serialize = function(self)
		return { Value = self.Value }
	end
	obj._deserialize = function(self, data)
		self:Set(data.Value)
	end
	return self:_finish(obj, opts, frame)
end

------------------------------------------------------------------ Viewport --

local function boundsOf(obj)
	if obj:IsA("Model") then
		return obj:GetBoundingBox()
	elseif obj:IsA("BasePart") then
		return obj.CFrame, obj.Size
	end
	local cf, size = CFrame.new(), Vector3.new(4, 4, 4)
	local parts = obj:GetDescendants()
	for _, p in parts do
		if p:IsA("BasePart") then
			return boundsOf(p)
		end
	end
	return cf, size
end

--[[
	AddViewport({
		Height = 160,
		Object = Instance | nil,     -- cloned into the viewport
		Avatar = userId | nil,       -- loads that player's avatar model
		Rotate = true | speed,       -- auto-rotate (degrees / second, default 30)
		Interactive = true,          -- drag to rotate
	})
	obj.Overlay      -> Frame on top of the viewport; empty areas let input through
	obj:SetObject(inst), obj:SetAvatar(userId), obj:SetRotate(speed|false)
	obj:AddOverlayButton({ Name, Position, Size, Callback })
]]
function Container:AddViewport(opts)
	opts = opts or {}
	local frame = self:_row(opts.Height or 160)
	local holder = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = "@Element",
		BackgroundTransparency = gl(0.2),
		ClipsDescendants = true,
		Parent = frame,
	})
	corner(holder, 8)
	stroke(holder, "@Stroke", 1, 0.2)

	local vp = New("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(160, 160, 175),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1.5, -1),
		Active = true,
		Parent = holder,
	})
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = vp
	vp.CurrentCamera = cam

	-- Overlay: Active = false so it never blocks the viewport; children (buttons, boxes...) still work.
	local overlay = New("Frame", { Name = "Overlay", Size = UDim2.fromScale(1, 1), ZIndex = 5, Active = false, Parent = holder })

	local obj = {
		Viewport = vp,
		Camera = cam,
		Overlay = overlay,
		Model = nil,
		Value = nil,
		_angle = 0,
		_pitch = 0.15,
		_speed = (opts.Rotate == nil or opts.Rotate == true) and 30 or (tonumber(opts.Rotate) or 0),
		_dist = 10,
		_center = Vector3.zero,
	}

	local function placeCamera()
		local c, d, p = obj._center, obj._dist, obj._pitch
		local offset = Vector3.new(math.sin(obj._angle) * math.cos(p), math.sin(p), math.cos(obj._angle) * math.cos(p)) * d
		cam.CFrame = CFrame.lookAt(c + offset, c)
	end

	function obj:SetObject(inst, noClone)
		if self.Model then
			self.Model:Destroy()
			self.Model = nil
		end
		if not inst then
			return
		end
		local clone = noClone and inst or inst:Clone()
		if not clone then
			warn("[LumenUI] Viewport object is not archivable")
			return
		end
		clone.Parent = vp
		self.Model = clone
		self.Value = inst
		local cf, size = boundsOf(clone)
		self._center = cf.Position
		local radius = size.Magnitude / 2
		self._dist = math.max(radius / math.tan(math.rad(cam.FieldOfView) / 2) * 1.05, 2)
		placeCamera()
	end

	function obj:SetAvatar(userId)
		task.spawn(function()
			local ok, model = pcall(function()
				return Players:CreateHumanoidModelFromUserId(userId)
			end)
			if ok and model then
				for _, d in model:GetDescendants() do
					if d:IsA("Script") or d:IsA("LocalScript") then
						d:Destroy()
					end
				end
				model:PivotTo(CFrame.new(0, 0, 0))
				self:SetObject(model, true)
			else
				warn("[LumenUI] Could not load avatar " .. tostring(userId))
			end
		end)
	end

	function obj:SetRotate(speed)
		self._speed = speed == true and 30 or (tonumber(speed) or 0)
	end

	function obj:AddOverlayButton(o)
		local b = New("TextButton", {
			Position = o.Position or UDim2.new(1, -8, 1, -8),
			AnchorPoint = o.AnchorPoint or Vector2.new(1, 1),
			Size = o.Size or UDim2.fromOffset(0, 22),
			AutomaticSize = o.Size and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
			BackgroundColor3 = "@Background",
			BackgroundTransparency = gl(0.25),
			Text = o.Name or "Button",
			TextSize = 11,
			FontFace = FONT_SEMI,
			Parent = overlay,
		})
		corner(b, 5)
		stroke(b, "@Stroke", 1, 0.3)
		pad(b, 8, 0)
		b.Activated:Connect(function()
			safeCall(o.Callback)
		end)
		return b
	end

	-- drag to rotate
	if opts.Interactive ~= false then
		local last
		bindDrag(vp, function(input)
			last = Vector2.new(input.Position.X, input.Position.Y)
			obj._dragging = true
		end, function(input)
			local cur = Vector2.new(input.Position.X, input.Position.Y)
			local d = cur - last
			last = cur
			obj._angle -= d.X * 0.012
			obj._pitch = clamp(obj._pitch + d.Y * 0.008, -1.2, 1.2)
			placeCamera()
		end, function()
			obj._dragging = false
		end)
	end

	Library:_global(RunService.RenderStepped, function(dt)
		if obj._speed ~= 0 and not obj._dragging and obj.Model and isShown(vp) then
			obj._angle += math.rad(obj._speed) * dt
			placeCamera()
		end
	end)

	if opts.Object then
		obj:SetObject(opts.Object)
	elseif opts.Avatar then
		obj:SetAvatar(opts.Avatar)
	elseif opts.Placeholder ~= false then
		local part = Instance.new("Part")
		part.Size = Vector3.new(4, 1.2, 2)
		part.Color = Color3.fromRGB(150, 150, 160)
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CFrame = CFrame.Angles(0, math.rad(25), 0)
		obj:SetObject(part, true)
	end

	obj._cleanup = function()
		if obj.Model then
			obj.Model:Destroy()
		end
	end
	return self:_finish(obj, opts, frame)
end

----------------------------------------------------------------- Image list --

--[[
	AddImageList({
		Name = "Skins",
		Items = { { Name = "Neon", Image = 123456, Description = "Rare", Value = "neon" }, ... },
		ItemSize = Vector2.new(100, 100),   -- offset size of each cell
		Height = 230,                       -- visible height (scrolls)
		Multi = false,
		Collapsible = false,                -- header toggles the grid like a dropdown
		Default = value | { values },
	})
]]
function Container:AddImageList(opts)
	opts = opts or {}
	local multi = opts.Multi == true
	local itemSize = opts.ItemSize or Vector2.new(100, 100)
	local height = opts.Height or 230
	local items = table.clone(opts.Items or {})

	local frame, body = self:_autoRow(5)
	local header = New("TextButton", { Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, Parent = body })
	New("TextLabel", {
		Size = UDim2.new(1, -20, 1, 0),
		Text = opts.Name or "Image List",
		FontFace = FONT_SEMI,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	local arrow
	if opts.Collapsible then
		arrow = icon(header, "chevron-down", 14, "@SubText", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5) })
	end

	local wrap = New("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = "@Panel",
		BackgroundTransparency = gl(0.35),
		ClipsDescendants = true,
		LayoutOrder = 2,
		Parent = body,
	})
	corner(wrap, 8)
	stroke(wrap, "@Stroke", 1, 0.4)
	local scroll = New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = "@Muted",
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = wrap,
	})
	pad(scroll, 6, 6, 6, 6)
	New("UIGridLayout", {
		CellSize = UDim2.fromOffset(itemSize.X, itemSize.Y),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = scroll,
	})

	local obj = { Value = multi and {} or nil, Items = items, Opened = true }
	local cells = {}

	local function valueOf(item)
		if item.Value ~= nil then
			return item.Value
		end
		return item.Name
	end
	local function isSel(val)
		if multi then
			return table.find(obj.Value, val) ~= nil
		end
		return obj.Value == val
	end
	local function paint(val)
		local c = cells[val]
		if not c then
			return
		end
		local sel = isSel(val)
		tween(c.Stroke, { Color = sel and Library.Theme.Accent or Library.Theme.Stroke, Thickness = sel and 2 or 1 }, 0.12)
		tween(c.Badge, { BackgroundTransparency = sel and 0 or 1 }, 0.12)
		tween(c.BadgeIcon, { ImageTransparency = sel and 0 or 1 }, 0.12)
	end

	local function choose(val)
		if obj.Disabled then
			return
		end
		if multi then
			local i = table.find(obj.Value, val)
			if i then
				table.remove(obj.Value, i)
			else
				table.insert(obj.Value, val)
			end
			paint(val)
		else
			local prev = obj.Value
			obj.Value = (prev == val and opts.AllowNone) and nil or val
			if prev ~= nil then
				paint(prev)
			end
			paint(val)
		end
		emit(obj)
	end

	local function build()
		for _, c in cells do
			c.Button:Destroy()
		end
		table.clear(cells)
		for i, item in items do
			local val = valueOf(item)
			local cell = New("TextButton", {
				BackgroundColor3 = "@Element",
				BackgroundTransparency = 0,
				LayoutOrder = i,
				Parent = scroll,
			})
			corner(cell, 8)
			local st = stroke(cell, "@Stroke")
			local hasDesc = item.Description ~= nil and item.Description ~= ""
			local textH = hasDesc and 30 or 18
			local img = New("ImageLabel", {
				Position = UDim2.fromOffset(6, 6),
				Size = UDim2.new(1, -12, 1, -(textH + 10)),
				ScaleType = Enum.ScaleType.Fit,
				Parent = cell,
			})
			local id = item.Image
			if type(id) == "number" then
				id = "rbxassetid://" .. id
			end
			if id then
				img.Image = id
			else
				New("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					Text = tostring(item.Name):sub(1, 1):upper(),
					TextSize = 24,
					FontFace = FONT_BOLD,
					TextColor3 = "@Muted",
					Parent = img,
				})
			end
			New("TextLabel", {
				Position = UDim2.new(0, 4, 1, -textH),
				Size = UDim2.new(1, -8, 0, 14),
				Text = tostring(item.Name),
				TextSize = 10,
				FontFace = FONT_SEMI,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = cell,
			})
			if hasDesc then
				New("TextLabel", {
					Position = UDim2.new(0, 4, 1, -16),
					Size = UDim2.new(1, -8, 0, 12),
					Text = tostring(item.Description),
					TextSize = 9,
					TextColor3 = "@SubText",
					TextTruncate = Enum.TextTruncate.AtEnd,
					Parent = cell,
				})
			end
			local badge = New("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -5, 0, 5),
				Size = UDim2.fromOffset(16, 16),
				BackgroundTransparency = 1,
				Parent = cell,
			})
			accentGradient(badge, 45)
			badge.BackgroundTransparency = 1
			corner(badge, 8)
			local badgeIcon = icon(badge, "check", 11, Color3.new(1, 1, 1), {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
			})
			badgeIcon.ImageTransparency = 1

			cell.MouseEnter:Connect(function()
				tween(cell, { BackgroundColor3 = Library.Theme.ElementHover }, 0.1)
			end)
			cell.MouseLeave:Connect(function()
				tween(cell, { BackgroundColor3 = Library.Theme.Element }, 0.1)
			end)
			cell.Activated:Connect(function()
				choose(val)
			end)
			if hasDesc then
				Library:_attachTooltip(cell, tostring(item.Description))
			end
			cells[val] = { Button = cell, Stroke = st, Badge = badge, BadgeIcon = badgeIcon }
			paint(val)
		end
	end

	function obj:Set(value, silent)
		local old = self.Value
		if multi then
			self.Value = type(value) == "table" and table.clone(value) or { value }
		else
			self.Value = value
		end
		for val in cells do
			paint(val)
		end
		if not silent then
			emit(self)
		end
		return old
	end

	function obj:SetItems(newItems)
		items = table.clone(newItems)
		self.Items = items
		self.Value = multi and {} or nil
		build()
	end

	function obj:SetOpen(open)
		if not opts.Collapsible or open == self.Opened then
			return
		end
		self.Opened = open
		if open then
			wrap.Visible = true
			tween(wrap, { Size = UDim2.new(1, 0, 0, height) }, 0.22)
		else
			tween(wrap, { Size = UDim2.new(1, 0, 0, 0) }, 0.18)
			task.delay(0.19, function()
				if not self.Opened then
					wrap.Visible = false
				end
			end)
		end
		if arrow then
			tween(arrow, { Rotation = open and 180 or 0 }, 0.2)
		end
	end
	if opts.Collapsible then
		header.Activated:Connect(function()
			obj:SetOpen(not obj.Opened)
		end)
		if opts.StartClosed then
			obj.Opened = false
			wrap.Visible = false
			wrap.Size = UDim2.new(1, 0, 0, 0)
		end
	end

	obj._serialize = function(self)
		return { Value = self.Value }
	end
	obj._deserialize = function(self, data)
		self:Set(data.Value)
	end

	self:_finish(obj, opts, frame)
	build()
	if opts.Default ~= nil then
		obj:Set(opts.Default, true)
	end
	return obj
end

-------------------------------------------------------------------- Credit --

function Container:AddCredit(opts)
	opts = opts or {}
	local frame, body = self:_autoRow(4)
	local card = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = "@Element",
		BackgroundTransparency = gl(0.35),
		Parent = body,
	})
	corner(card, 6)
	stroke(card, "@Stroke", 1, 0.4)
	pad(card, 10, 8, 10, 9)
	list(card, 5)

	local top = New("Frame", { Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, Parent = card })
	list(top, 8, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center)
	New("TextLabel", {
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = tostring(opts.Name or "@name"),
		FontFace = FONT_SEMI,
		TextSize = 13,
		LayoutOrder = 1,
		Parent = top,
	})
	if opts.Tag then
		local tagColor = opts.TagColor or Library.Theme.Accent
		local pill = New("Frame", {
			Size = UDim2.fromOffset(0, 16),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = tagColor,
			BackgroundTransparency = 0.85,
			LayoutOrder = 2,
			Parent = top,
		})
		corner(pill, 8)
		stroke(pill, tagColor, 1, 0.45)
		pad(pill, 8, 0)
		New("TextLabel", {
			Size = UDim2.fromOffset(0, 16),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = tostring(opts.Tag),
			TextSize = 9,
			FontFace = FONT_SEMI,
			TextColor3 = tagColor,
			Parent = pill,
		})
	end
	if opts.Description then
		New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = tostring(opts.Description),
			TextSize = 10,
			TextColor3 = "@SubText",
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
			Parent = card,
		})
	end
	return self:_finish({}, opts, frame)
end

------------------------------------------------------------- ESP preview --

--[[
	local esp = container:AddESPPreview({
		Height = 380, Avatar = userId | nil (default: you), Object = Instance | nil,
		Style = "Corner" | "Box", Color = Color3, Name = true, Health = true, Distance = true,
		Text = "PlayerName", Rotate = false,
	})
	esp:Set({ Style = "Box", Color = Color3, Name = false, ... })  -- live preview of your ESP settings
	esp.Viewport, esp.Box
]]
function Container:AddESPPreview(opts)
	opts = opts or {}
	local vp = self:AddViewport({
		Height = opts.Height or 380,
		Avatar = opts.Object == nil and (opts.Avatar or (LocalPlayer and LocalPlayer.UserId)) or nil,
		Object = opts.Object,
		Rotate = opts.Rotate or false,
		Interactive = opts.Interactive ~= false,
	})
	local state = {
		Style = opts.Style or "Corner",
		Color = opts.Color or Color3.new(1, 1, 1),
		Name = opts.Name ~= false,
		Health = opts.Health ~= false,
		Distance = opts.Distance ~= false,
		Text = opts.Text or (LocalPlayer and LocalPlayer.DisplayName) or "Player",
		Dist = opts.DistanceText or "42m",
		HealthValue = opts.HealthValue or 0.75,
	}

	local box = New("Frame", {
		Name = "ESPBox",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 6,
		Parent = vp.Overlay,
	})
	local outline = New("UIStroke", { Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = box })
	local corners = {}
	for ax = 0, 1 do
		for ay = 0, 1 do
			local h = New("Frame", {
				AnchorPoint = Vector2.new(ax, ay),
				Position = UDim2.fromScale(ax, ay),
				Size = UDim2.new(0.3, 0, 0, 2),
				BackgroundTransparency = 0,
				ZIndex = 7,
				Parent = box,
			})
			local v = New("Frame", {
				AnchorPoint = Vector2.new(ax, ay),
				Position = UDim2.fromScale(ax, ay),
				Size = UDim2.new(0, 2, 0.14, 0),
				BackgroundTransparency = 0,
				ZIndex = 7,
				Parent = box,
			})
			table.insert(corners, h)
			table.insert(corners, v)
		end
	end
	local nameLbl = New("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -4),
		Size = UDim2.new(1, 0, 0, 14),
		FontFace = FONT_SEMI,
		TextSize = 12,
		ZIndex = 7,
		Parent = box,
	})
	local distLbl = New("TextLabel", {
		Position = UDim2.new(0, 0, 1, 4),
		Size = UDim2.new(1, 0, 0, 14),
		TextSize = 11,
		ZIndex = 7,
		Parent = box,
	})
	local hpBack = New("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0, -5, 0, 0),
		Size = UDim2.new(0, 3, 1, 0),
		BackgroundColor3 = Color3.fromRGB(10, 10, 12),
		BackgroundTransparency = 0.2,
		ZIndex = 7,
		Parent = box,
	})
	local hpFill = New("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		BackgroundTransparency = 0,
		ZIndex = 8,
		Parent = hpBack,
	})

	local obj = { Viewport = vp, Box = box, Value = state }
	local function render()
		outline.Color = state.Color
		outline.Enabled = state.Style == "Box"
		for _, c in corners do
			c.BackgroundColor3 = state.Color
			c.Visible = state.Style == "Corner"
		end
		nameLbl.Visible = state.Name
		nameLbl.Text = state.Text
		nameLbl.TextColor3 = state.Color
		distLbl.Visible = state.Distance
		distLbl.Text = state.Dist
		distLbl.TextColor3 = state.Color
		hpBack.Visible = state.Health
		hpFill.Size = UDim2.fromScale(1, math.clamp(state.HealthValue, 0, 1))
		hpFill.BackgroundColor3 = Color3.fromRGB(226, 100, 106):Lerp(Color3.fromRGB(92, 200, 135), math.clamp(state.HealthValue, 0, 1))
	end
	function obj:Set(patch)
		for k, v in patch or {} do
			state[k] = v
		end
		render()
	end
	render()
	return obj
end


--------------------------------------------------------------------------------
-- Dashboard-style elements: profile card + gradient info cards
--------------------------------------------------------------------------------

--[[
	AddProfile({ UserId = number?, Title = "Hello, Name", Subtitle = "Name - Game", Height = 72 })
	obj:SetTitle(s)  obj:SetSubtitle(s)
]]
function Container:AddProfile(opts)
	opts = opts or {}
	local h = opts.Height or 72
	local frame = self:_row(h)
	local av = New("ImageLabel", {
		Size = UDim2.fromOffset(h, h),
		BackgroundColor3 = "@Element",
		BackgroundTransparency = 0,
		ScaleType = Enum.ScaleType.Crop,
		Parent = frame,
	})
	corner(av, 10)
	stroke(av, "@Stroke", 1, 0.2)
	local userId = opts.UserId or (LocalPlayer and LocalPlayer.UserId)
	if userId then
		task.spawn(function()
			local ok, img = pcall(function()
				return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			end)
			if ok and av.Parent then
				av.Image = img
			end
		end)
	end

	local card = New("Frame", {
		Position = UDim2.fromOffset(h + 8, 0),
		Size = UDim2.new(1, -(h + 8), 1, 0),
		BackgroundColor3 = "@Element",
		BackgroundTransparency = 0,
		Parent = frame,
	})
	corner(card, 10)
	stroke(card, "@Stroke", 1, 0.2)
	local inner = New("Frame", { Size = UDim2.fromScale(1, 1), Parent = card })
	pad(inner, 16, 0, 16, 0)
	list(inner, 2, nil, nil, Enum.VerticalAlignment.Center)
	local title = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		Text = tostring(opts.Title or ("Hello, " .. (LocalPlayer and LocalPlayer.DisplayName or "Player"))),
		FontFace = FONT_BOLD,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 1,
		Parent = inner,
	})
	local sub = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		Text = tostring(opts.Subtitle or ""),
		TextSize = 12,
		TextColor3 = "@SubText",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 2,
		Parent = inner,
	})
	local obj = { Value = title.Text }
	function obj:SetTitle(t)
		title.Text = t
		self.Value = t
	end
	function obj:SetSubtitle(t)
		sub.Text = t
	end
	return self:_finish(obj, opts, frame)
end

--[[
	AddInfoCard({
		Title = "Server", Description = "Information on the session...",
		Gradient = Color3 | { Color3, Color3 },     -- tint (bottom-left) -> dark (top-right)
		GradientRotation = -40,
		Columns = 2, TileHeight = 44,
		Tiles = { { Id = "players", Title = "Players", Text = "9 playing", Callback = function() end }, ... },
		Callback = function() end,                  -- makes the whole card clickable (only when there are no tiles)
	})
	card:SetTile("players", "12 playing")   -- by Id or index; optional 3rd arg changes the tile title
]]
function Container:AddInfoCard(opts)
	opts = opts or {}
	local frame = self:_autoRow()
	local card = New("Frame", {
		Name = "InfoCard",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0,
		Parent = frame,
	})
	corner(card, 10)
	stroke(card, "@Stroke", 1, 0.35)
	tintGradient(card, opts.Gradient or Library.Theme.Accent, opts.GradientRotation)
	pad(card, 12, 11, 12, 12)
	list(card, 6)

	New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		Text = tostring(opts.Title or "Card"),
		FontFace = FONT_BOLD,
		TextSize = opts.TitleSize or 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		Parent = card,
	})
	if opts.Description then
		New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = tostring(opts.Description),
			TextSize = 11,
			TextColor3 = "@SubText",
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
			Parent = card,
		})
	end

	local obj = { Tiles = {} }
	if opts.Tiles and #opts.Tiles > 0 then
		local cols = opts.Columns or 2
		local grid = New("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 3,
			Parent = card,
		})
		New("UIGridLayout", {
			CellSize = UDim2.new(1 / cols, -((cols - 1) * 6) / cols, 0, opts.TileHeight or 44),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = grid,
		})
		for i, t in opts.Tiles do
			local tile = New(t.Callback and "TextButton" or "Frame", {
				BackgroundColor3 = Color3.fromRGB(11, 11, 16),
				BackgroundTransparency = 0,
				LayoutOrder = i,
				Parent = grid,
			})
			corner(tile, 7)
			stroke(tile, "@Stroke", 1, 0.45)
			local tl = New("TextLabel", {
				Position = UDim2.fromOffset(9, 6),
				Size = UDim2.new(1, -18, 0, 16),
				Text = tostring(t.Title or ""),
				FontFace = FONT_BOLD,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = tile,
			})
			local tx = New("TextLabel", {
				Position = UDim2.fromOffset(9, 23),
				Size = UDim2.new(1, -18, 0, 14),
				Text = tostring(t.Text or ""),
				TextSize = 10,
				TextColor3 = "@SubText",
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = tile,
			})
			if t.Callback then
				tile.MouseEnter:Connect(function()
					tween(tile, { BackgroundColor3 = Color3.fromRGB(24, 24, 34) }, 0.1)
				end)
				tile.MouseLeave:Connect(function()
					tween(tile, { BackgroundColor3 = Color3.fromRGB(11, 11, 16) }, 0.1)
				end)
				tile.Activated:Connect(function()
					safeCall(t.Callback)
				end)
			end
			local entry = { Frame = tile, Title = tl, Text = tx }
			obj.Tiles[t.Id or i] = entry
			if t.Id then
				obj.Tiles[i] = entry
			end
		end
	elseif opts.Callback then
		local hit = New("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = frame })
		hit.Activated:Connect(function()
			safeCall(opts.Callback)
		end)
	end

	function obj:SetTile(id, text, title)
		local e = self.Tiles[id]
		if e then
			if text ~= nil then
				e.Text.Text = tostring(text)
			end
			if title ~= nil then
				e.Title.Text = tostring(title)
			end
		end
	end
	return self:_finish(obj, opts, frame)
end

--------------------------------------------------------------------------------
-- Keybind list (active hotkeys panel) + watermark
--------------------------------------------------------------------------------

Library._listed = {}

function Library:_listSet(id, patch)
	local e = self._listed[id]
	if not e then
		e = { Order = (self._listCount or 0) + 1 }
		self._listCount = e.Order
		self._listed[id] = e
	end
	for k, v in patch do
		e[k] = v
	end
	if self.KeybindList then
		self.KeybindList:_refresh(id)
	end
end

function Library:_listRemove(id)
	self._listed[id] = nil
	if self.KeybindList then
		self.KeybindList:_refresh(id)
	end
end

local function hex(c)
	return toHex(c)
end

--[[
	Library:CreateKeybindList({ Title = "Hotkeys", Position = UDim2 })
	Toggles created with `Keybind = { ... }` show up here automatically.
	list:Add(id, { Name, Key, Active })   list:SetActive(id, bool)   list:Remove(id)   list:SetVisible(bool)
]]
function Library:CreateKeybindList(opts)
	opts = opts or {}
	self:_Gui()
	if self.KeybindList then
		return self.KeybindList
	end

	local frame = New("Frame", {
		Name = "KeybindList",
		Position = opts.Position or UDim2.new(0, 16, 0.5, -60),
		Size = UDim2.fromOffset(190, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = "@Background",
		BackgroundTransparency = gl(0.1),
		Parent = self.HudLayer,
	})
	corner(frame, 8)
	stroke(frame, "@Stroke", 1, 0.25)
	pad(frame, 10, 8, 10, 10)
	list(frame, 6)

	local header = New("Frame", { Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 0, Parent = frame })
	icon(header, "keyboard", 14, "@SubText", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5) })
	New("TextLabel", {
		Position = UDim2.fromOffset(22, 0),
		Size = UDim2.new(1, -22, 1, 0),
		Text = opts.Title or "Hotkeys",
		FontFace = FONT_SEMI,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	makeDraggable(header, frame)

	local rows = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = frame,
	})
	list(rows, 2)

	local obj = { Instance = frame, _rows = {} }

	function obj:_refresh(id)
		local e = Library._listed[id]
		local lbl = self._rows[id]
		if not e or not e.Show then
			if lbl then
				lbl:Destroy()
				self._rows[id] = nil
			end
		else
			if not lbl then
				lbl = New("TextLabel", {
					Size = UDim2.new(1, 0, 0, 16),
					RichText = true,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					LayoutOrder = e.Order,
					Parent = rows,
				})
				self._rows[id] = lbl
			end
			local active = e.Active == true
			local status = active and "Active" or "Inactive"
			local col = active and hex(Library.Theme.Success) or hex(Library.Theme.Muted)
			lbl.Text = string.format(
				'<font color="%s">[%s]</font> %s - <font color="%s">%s</font>',
				hex(Library.Theme.SubText),
				keyName(e.Key):upper(),
				tostring(e.Name),
				col,
				status
			)
		end
		frame.Visible = obj._forceVisible ~= false
	end

	function obj:Add(id, info)
		info = info or {}
		Library:_listSet(id, { Name = info.Name or id, Key = info.Key, Active = info.Active == true, Show = true })
	end
	function obj:SetActive(id, active)
		Library:_listSet(id, { Active = active == true })
	end
	function obj:SetKey(id, key)
		Library:_listSet(id, { Key = key })
	end
	function obj:Remove(id)
		Library:_listRemove(id)
	end
	function obj:SetVisible(v)
		self._forceVisible = v
		frame.Visible = v
	end

	self.KeybindList = obj
	for id in self._listed do
		obj:_refresh(id)
	end
	return obj
end

--[[
	Library:CreateWatermark({ Title = "My Script", Text = "extra", Position, ShowUser, ShowFPS, ShowPing })
	watermark:SetTitle(t)  :SetText(t)  :SetVisible(b)
]]
function Library:CreateWatermark(opts)
	opts = opts or {}
	self:_Gui()
	local frame = New("Frame", {
		Name = "Watermark",
		Position = opts.Position or UDim2.fromOffset(16, GuiService:GetGuiInset().Y + 10),
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = "@Background",
		BackgroundTransparency = gl(0.08),
		Parent = self.HudLayer,
	})
	corner(frame, 8)
	stroke(frame, "@Stroke", 1, 0.2)
	pad(frame, 10, 0, 12, 0)
	list(frame, 8, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center)

	local ic = icon(frame, opts.Icon or "sparkles", 15, "@Accent", { LayoutOrder = 1 })
	local lbl = New("TextLabel", {
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		RichText = true,
		TextSize = 12,
		LayoutOrder = 2,
		Parent = frame,
	})

	local obj = { Instance = frame, Title = opts.Title or "LumenUI", Text = opts.Text or "" }
	local fps, ping = 60, 0

	local function sep()
		return string.format('  <font color="%s">|</font>  ', hex(Library.Theme.Muted))
	end
	local function render()
		local parts = { string.format("<b>%s</b>", obj.Title) }
		if opts.ShowUser ~= false and LocalPlayer then
			table.insert(parts, LocalPlayer.Name)
		end
		if opts.ShowFPS ~= false then
			local c = fps >= 50 and Library.Theme.Success or (fps >= 30 and Library.Theme.Warning or Library.Theme.Danger)
			table.insert(parts, string.format('<font color="%s">%d FPS</font>', hex(c), fps))
		end
		if opts.ShowPing ~= false then
			local c = ping <= 80 and Library.Theme.Success or (ping <= 160 and Library.Theme.Warning or Library.Theme.Danger)
			table.insert(parts, string.format('<font color="%s">%dms</font>', hex(c), ping))
		end
		if obj.Text ~= "" then
			table.insert(parts, obj.Text)
		end
		lbl.Text = table.concat(parts, sep())
	end

	local acc, frames = 0, 0
	Library:_global(RunService.RenderStepped, function(dt)
		acc += dt
		frames += 1
		if acc >= 0.5 then
			fps = math.floor(frames / acc + 0.5)
			acc, frames = 0, 0
			local ok, p = pcall(function()
				return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
			end)
			ping = ok and math.floor(p + 0.5) or 0
			if frame.Visible then
				render()
			end
		end
	end)

	function obj:SetTitle(t)
		self.Title = t
		render()
	end
	function obj:SetText(t)
		self.Text = t
		render()
	end
	function obj:SetVisible(v)
		frame.Visible = v
	end
	makeDraggable(frame, frame)
	render()
	return obj
end

--------------------------------------------------------------------------------
-- Sections & sub-tabs
--------------------------------------------------------------------------------

local Section = setmetatable({}, { __index = Container })
Section.__index = Section

local SubTab = setmetatable({}, { __index = Container })
SubTab.__index = SubTab

function SubTab:Select()
	local sec = self.Section
	for _, s in sec._subs do
		local on = s == self
		s.Content.Visible = on
		tween(s.Button, { BackgroundTransparency = on and 0.35 or 1, TextColor3 = on and selText() or Library.Theme.Text }, 0.14)
	end
	sec.ActiveSubTab = self
end

--- Adds a mini tab bar inside the section. Returns a container (same :AddX methods).
function Section:CreateSubTab(opts)
	if type(opts) == "string" then
		opts = { Name = opts }
	end
	if not self._bar then
		self._bar = New("Frame", { Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 1, Parent = self.Card })
		list(self._bar, 4, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center)
		self._pages = New("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = self.Card,
		})
		list(self._pages, 0)
		self._subs = {}
	end

	local btn = New("TextButton", {
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = "@Checkbox",
		BackgroundTransparency = 1,
		Text = opts.Name or "Tab",
		TextSize = 11,
		FontFace = FONT_SEMI,
		TextColor3 = "@SubText",
		LayoutOrder = #self._subs + 1,
		Parent = self._bar,
	})
	corner(btn, 5)
	pad(btn, 9, 0)

	local page = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = self._pages,
	})
	list(page, 7)

	local sub = setmetatable({ Content = page, Button = btn, Section = self, Name = opts.Name }, SubTab)
	table.insert(self._subs, sub)
	btn.Activated:Connect(function()
		sub:Select()
	end)
	if #self._subs == 1 then
		sub:Select()
	end
	return sub
end

--------------------------------------------------------------------------------
-- Tabs
--------------------------------------------------------------------------------

local Tab = {}
Tab.__index = Tab

--- Tab:CreateSection({ Name = "Aimbot", Side = "Left" | "Right" | "Full", Gradient = Color3?, Plain = false })
function Tab:CreateSection(opts)
	if type(opts) == "string" then
		opts = { Name = opts }
	end
	local col = (opts.Side == "Right" and self.Right) or (opts.Side == "Full" and self.Full) or self.Left
	self._colOrder[col] = (self._colOrder[col] or 0) + 1

	local card = New("Frame", {
		Name = "Section",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = gl(0.3),
		LayoutOrder = self._colOrder[col],
		Parent = col,
	})
	if opts.Plain then
		-- no card chrome: elements sit directly on the window background
		card.BackgroundTransparency = 1
		list(card, 8)
	else
		corner(card, 8)
		stroke(card, "@Stroke", 1, 0.4)
		pad(card, 10, 10, 10, 10)
		list(card, 8)
		if opts.Gradient then
			tintGradient(card, opts.Gradient, opts.GradientRotation)
		else
			themeGradient(card, "Panel", "Panel2", 90)
		end
	end

	if opts.Name then
		New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 14),
			Text = opts.Name,
			FontFace = FONT_BOLD,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 0,
			Parent = card,
		})
	end
	local content = New("Frame", {
		Name = "Content",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = card,
	})
	list(content, 7)
	return setmetatable({ Content = content, Card = card, Tab = self }, Section)
end

--- Tab:SetWarning({ Title, Text, Color }) / Tab:SetWarning(nil) to hide
function Tab:SetWarning(w)
	if self._banner then
		self._banner:Destroy()
		self._banner = nil
	end
	if not w then
		return
	end
	local color = w.Color or Library.Theme.Warning
	local b = New("Frame", {
		Name = "Warning",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = "@Panel",
		BackgroundTransparency = gl(0.3),
		LayoutOrder = 0,
		Parent = self.Scroll,
	})
	corner(b, 8)
	stroke(b, "@Stroke", 1, 0.4)
	if w.Color then
		local bar = New("Frame", { Size = UDim2.new(0, 3, 1, -16), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = color, BackgroundTransparency = 0, Parent = b })
		corner(bar, 2)
	end
	local inner = New("Frame", { Position = UDim2.fromOffset(w.Color and 20 or 14, 0), Size = UDim2.new(1, w.Color and -28 or -22, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = b })
	pad(inner, 0, 9, 0, 9)
	list(inner, 2)
	New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		Text = tostring(w.Title or "Notice"),
		FontFace = FONT_BOLD,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		Parent = inner,
	})
	if w.Text then
		New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = tostring(w.Text),
			TextWrapped = true,
			RichText = true,
			TextSize = 11,
			TextColor3 = "@SubText",
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
			Parent = inner,
		})
	end
	self._banner = b
end

function Tab:Select()
	self.Window:SelectTab(self)
end

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------

local Window = {}
Window.__index = Window

local function controlButton(parent, iconName, callback, hoverKey, order)
	local b = New("TextButton", {
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = "@ElementHover",
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
	corner(b, 5)
	icon(b, iconName, 13, "@SubText", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	b.MouseEnter:Connect(function()
		tween(b, { BackgroundTransparency = 0.3 }, 0.1)
		if hoverKey then
			b.BackgroundColor3 = Library.Theme[hoverKey]
		end
	end)
	b.MouseLeave:Connect(function()
		tween(b, { BackgroundTransparency = 1 }, 0.1)
	end)
	b.Activated:Connect(callback)
	return b
end

--------------------------------------------------------------------------------
-- Custom background (image / video) + gradient window frame
--------------------------------------------------------------------------------

local bgTargets = setmetatable({}, { __mode = "k" })

local function strHash(s)
	local h = 5381
	for k = 1, #s do
		h = (h * 33 + s:byte(k)) % 4294967296
	end
	return string.format("%08x", h)
end

-- returns assetUrl, kind ("image" | "video"), errorMessage
local function resolveAsset(src)
	if type(src) == "number" then
		return "rbxassetid://" .. src, "image"
	end
	src = tostring(src)
	src = (src:gsub("^%s+", ""))
	src = (src:gsub("%s+$", ""))
	if src == "" then
		return nil, nil, "empty source"
	end
	if src:match("^%d+$") then
		return "rbxassetid://" .. src, "image"
	end
	if src:find("^rbxassetid://") or src:find("^rbxasset://") then
		return src, "image"
	end
	if src:find("^https?://") then
		local gca = getcustomasset or getsynasset
		if not (gca and writefile and isfile) then
			return nil, nil, "Link backgrounds need getcustomasset/writefile (executor). Use an asset id instead."
		end
		local clean = (src:gsub("%?.*$", ""))
		local ext = (clean:match("%.(%w+)$") or "png"):lower()
		local kind = (ext == "webm" or ext == "mp4" or ext == "mov") and "video" or "image"
		if isfolder and makefolder and not isfolder("LumenUI") then
			makefolder("LumenUI")
		end
		local path = "LumenUI/bg_" .. strHash(src) .. "." .. ext
		if not isfile(path) then
			local data = httpGet(src)
			if not data then
				return nil, nil, "Download failed"
			end
			writefile(path, data)
		end
		return gca(path), kind
	end
	return nil, nil, "Unrecognised source"
end

function Library:_applyBackground(main)
	local t = bgTargets[main]
	if not t then
		return
	end
	local bg = self.Background
	local hasImg, hasVid = bg.ImageId ~= nil, bg.VideoId ~= nil
	t.Image.Visible = hasImg
	if hasImg then
		t.Image.Image = bg.ImageId
	end
	t.Video.Visible = hasVid
	if hasVid then
		t.Video.Video = bg.VideoId
		t.Video.Playing = true
	else
		t.Video.Playing = false
	end
	t.Dim.Visible = hasImg or hasVid
	t.Dim.BackgroundTransparency = bg.Transparency
end

function Library:_attachBackground(main, radius)
	local img = New("ImageLabel", {
		Name = "BgImage",
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 0,
		Visible = false,
		Parent = main,
	})
	corner(img, radius or 10)
	local vid = New("VideoFrame", {
		Name = "BgVideo",
		Size = UDim2.fromScale(1, 1),
		Looped = true,
		Volume = 0,
		ZIndex = 0,
		Visible = false,
		Parent = main,
	})
	local dim = New("Frame", {
		Name = "BgDim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = "@Background",
		BackgroundTransparency = 0.6,
		ZIndex = 0,
		Visible = false,
		Parent = main,
	})
	bgTargets[main] = { Image = img, Video = vid, Dim = dim }
	self:_applyBackground(main)
end

function Library:_applyAllBackgrounds()
	for main in bgTargets do
		self:_applyBackground(main)
	end
end

--[[
	Library:SetBackground({
		Image = "rbxassetid://123" | 123 | "https://.../pic.png",   -- image (links need getcustomasset)
		Video = "rbxassetid://456" | "https://.../clip.webm",        -- looping muted video
		Transparency = 0.6,   -- visibility of the background: 0 = hidden under the window color, 1 = fully visible
		Clear = true,         -- remove the custom background
	})
	Applies to every window and sub-window.
]]
function Library:SetBackground(opts)
	opts = opts or {}
	local bg = self.Background
	if opts.Transparency ~= nil then
		bg.Transparency = clamp(opts.Transparency, 0, 1)
	end
	if opts.Clear then
		bg.ImageId, bg.VideoId = nil, nil
	end
	local source = opts.Video or opts.Image or opts.Source
	if source then
		task.spawn(function()
			local id, kind, err = resolveAsset(source)
			if not id then
				self:Notify({ Title = "Background", Content = tostring(err), Type = "Error" })
				return
			end
			if opts.Video then
				kind = "video"
			end
			bg.ImageId, bg.VideoId = nil, nil
			if kind == "video" then
				bg.VideoId = id
			else
				bg.ImageId = id
			end
			self:_applyAllBackgrounds()
		end)
	else
		self:_applyAllBackgrounds()
	end
end

local function glassFrame(holder, size)
	local shadow = New("ImageLabel", {
		Name = "Shadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 48, 1, 48),
		Image = "rbxassetid://6014261993",
		ImageColor3 = "@Shadow",
		ImageTransparency = 0.45,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(49, 49, 450, 450),
		ZIndex = 0,
		Parent = holder,
	})
	local main = New("Frame", {
		Name = "Main",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = gl(0.06),
		ClipsDescendants = true,
		Active = true,
		ZIndex = 1,
		Parent = holder,
	})
	corner(main, 8)
	stroke(main, "@Stroke", 1, 0.2)
	-- gradient window background (Theme.Background -> Theme.Background2)
	local g = themeGradient(main, "Background", "Background2", Library.Theme.BackgroundAngle)
	mainGradients[g] = true
	Library:_attachBackground(main, 8)
	return main, shadow
end

--[[
	Library:CreateWindow({
		Title = "My Hub", Subtitle = "Game name", Footer = "discord.gg/...",
		Badges = { { Text = "Pro", Color = Color3 }, { Text = "v2.0", Color = Color3 } },
		Size = UDim2.fromOffset(560, 520), Position = UDim2,
		Icon = "sparkles", OnClose = function() end,
	})
]]
function Library:CreateWindow(opts)
	opts = opts or {}
	self:_Gui()
	if self.AutoLoadIcons then
		self:LoadIcons()
	end

	local layout = opts.Layout == "Sidebar" and "Sidebar" or "Top"
	local sidebar = layout == "Sidebar"
	local size = opts.Size or (sidebar and UDim2.fromOffset(640, 420) or UDim2.fromOffset(560, 520))
	local holder = New("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = opts.Position or UDim2.fromScale(0.5, 0.5),
		Size = size,
		ZIndex = self:_nextZ(),
		Parent = self.WindowLayer,
	})
	local main = glassFrame(holder, size)
	local uiScale = New("UIScale", { Scale = 0.88, Parent = holder })
	tween(uiScale, { Scale = 1 }, 0.5, Enum.EasingStyle.Back)

	main.InputBegan:Connect(function(input)
		if input.UserInputType == MB1 or input.UserInputType == TOUCH then
			holder.ZIndex = self:_nextZ()
		end
	end)

	local window = setmetatable({
		Instance = holder,
		Main = main,
		Tabs = {},
		Active = nil,
		Layout = layout,
		_size = size,
		_minimized = false,
		OnClose = opts.OnClose,
	}, Window)

	-- header
	local headerH = sidebar and 54 or 42
	local header = New("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, headerH), Parent = main })
	pad(header, 14, 0, 10, 0)
	local left = New("Frame", { Size = UDim2.new(0.75, 0, 1, 0), Parent = header })
	list(left, 8, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center)
	if opts.Icon then
		icon(left, opts.Icon, sidebar and 28 or 16, "@Accent", { LayoutOrder = 0 })
	end
	local titleLabel = New("TextLabel", {
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = opts.Title or "Window",
		FontFace = FONT_BOLD,
		TextSize = sidebar and 15 or 13,
		LayoutOrder = 1,
		Parent = left,
	})
	window._badges = left
	window._titleLabel = titleLabel

	local right = New("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(sidebar and 0.25 or 0.35, 0, 1, 0),
		Parent = header,
	})
	list(right, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	local subtitle = New("TextLabel", {
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = opts.Subtitle or "",
		TextSize = 11,
		TextColor3 = "@SubText",
		LayoutOrder = 1,
		Parent = sidebar and left or right,
	})
	if sidebar then
		subtitle.LayoutOrder = 2
	end
	window._subtitle = subtitle
	controlButton(right, "minus", function()
		window:Minimize()
	end, nil, 2)
	controlButton(right, "x", function()
		window:SetVisible(false)
		safeCall(window.OnClose)
	end, "Danger", 3)
	makeDraggable(header, holder)
	if opts.Resizable ~= false and Library.Resizable then
		window._resize = makeResizable(holder, {
			MinSize = opts.MinSize or Vector2.new(sidebar and 440 or 380, 260),
			OnResize = function(sz)
				window._size = UDim2.fromOffset(sz.X, sz.Y)
			end,
		})
	end

	local footerH = opts.Footer and 22 or 6
	local body

	if sidebar then
		-- vertical icon sidebar (like a hub dashboard)
		local showAvatar = opts.SidebarAvatar ~= false
		local side = New("ScrollingFrame", {
			Name = "Sidebar",
			Position = UDim2.fromOffset(8, headerH),
			Size = UDim2.new(0, 48, 1, -(headerH + (showAvatar and 58 or 8))),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 0,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Parent = main,
		})
		list(side, 6, nil, Enum.HorizontalAlignment.Center)
		pad(side, 0, 2, 0, 2)
		window._bar = side

		if showAvatar then
			local av = New("ImageLabel", {
				Name = "Avatar",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 14, 1, -12),
				Size = UDim2.fromOffset(36, 36),
				BackgroundColor3 = "@Element",
				BackgroundTransparency = 0,
				Parent = main,
			})
			corner(av, 18)
			stroke(av, "@Stroke")
			local userId = type(opts.SidebarAvatar) == "number" and opts.SidebarAvatar or (LocalPlayer and LocalPlayer.UserId)
			if userId then
				task.spawn(function()
					local ok, img = pcall(function()
						return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
					end)
					if ok and av.Parent then
						av.Image = img
					end
				end)
			end
		end

		body = New("Frame", {
			Name = "Body",
			Position = UDim2.fromOffset(66, headerH),
			Size = UDim2.new(1, -76, 1, -(headerH + footerH + 4)),
			ClipsDescendants = true,
			Parent = main,
		})
	else
		-- top tab bar
		local barWrap = New("Frame", { Name = "TabBar", Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 32), Parent = main })
		local bar = New("ScrollingFrame", {
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -20, 1, 0),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			ScrollBarThickness = 0,
			ScrollingDirection = Enum.ScrollingDirection.X,
			Parent = barWrap,
		})
		list(bar, 4, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center)
		window._bar = bar
		body = New("Frame", {
			Name = "Body",
			Position = UDim2.fromOffset(10, 80),
			Size = UDim2.new(1, -20, 1, -(80 + footerH)),
			ClipsDescendants = true,
			Parent = main,
		})
	end
	window._body = body

	if opts.Footer then
		New("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -3),
			Size = UDim2.new(1, 0, 0, 16),
			Text = opts.Footer,
			TextSize = 10,
			TextColor3 = "@Muted",
			Parent = main,
		})
	end

	for _, b in opts.Badges or {} do
		window:AddBadge(b)
	end

	table.insert(self.Windows, window)
	return window
end

function Window:AddBadge(b)
	if type(b) == "string" then
		b = { Text = b }
	end
	local color = b.Color or Library.Theme.Accent
	local pill = New("Frame", {
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = color,
		BackgroundTransparency = 0.85,
		LayoutOrder = 2 + #self._badges:GetChildren(),
		Parent = self._badges,
	})
	corner(pill, 8)
	stroke(pill, color, 1, 0.35)
	pad(pill, 8, 0)
	New("TextLabel", {
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = b.Text or "",
		TextSize = 10,
		FontFace = FONT_SEMI,
		TextColor3 = color,
		Parent = pill,
	})
	return pill
end

function Window:SetTitle(t)
	self._titleLabel.Text = t
end

function Window:SetSubtitle(t)
	self._subtitle.Text = t
end

--- Window:CreateTab({ Name = "Combat", Icon = "swords", Warning = { Title, Text } })
function Window:CreateTab(opts)
	if type(opts) == "string" then
		opts = { Name = opts }
	end
	local tab = setmetatable({ Window = self, Name = opts.Name, _colOrder = {} }, Tab)

	local btn
	if self.Layout == "Sidebar" then
		btn = New("TextButton", {
			Name = "Tab_" .. tostring(opts.Name),
			Size = UDim2.fromOffset(40, 40),
			BackgroundColor3 = "@Element",
			BackgroundTransparency = 1,
			LayoutOrder = #self.Tabs + 1,
			Parent = self._bar,
		})
		corner(btn, 10)
		local st = stroke(btn, "@Accent", 1, 1)
		local ic
		if opts.Icon then
			ic = icon(btn, opts.Icon, 18, "@SubText", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		end
		local letter = New("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Text = tostring(opts.Name or "?"):sub(1, 1):upper(),
			FontFace = FONT_BOLD,
			TextSize = 15,
			TextColor3 = "@SubText",
			Visible = ic == nil or ic.Image == "",
			Parent = btn,
		})
		if ic then
			ic:GetPropertyChangedSignal("Image"):Connect(function()
				letter.Visible = ic.Image == ""
			end)
		end
		Library:_attachTooltip(btn, tostring(opts.Name))
		local function paint(color)
			if ic then
				tween(ic, { ImageColor3 = color }, 0.12)
				local fb = ic:FindFirstChild("Fallback")
				if fb then
					tween(fb, { TextColor3 = color }, 0.12)
				end
			end
			tween(letter, { TextColor3 = color }, 0.12)
		end
		btn.MouseEnter:Connect(function()
			if self.Active ~= tab then
				paint(Library.Theme.Text)
			end
		end)
		btn.MouseLeave:Connect(function()
			if self.Active ~= tab then
				paint(Library.Theme.SubText)
			end
		end)
		function tab:_setSelected(on)
			tween(btn, { BackgroundTransparency = on and 0 or 1 }, 0.15)
			tween(st, { Transparency = on and 0.1 or 1 }, 0.15)
			paint(on and Library.Theme.Text or Library.Theme.SubText)
		end
		tab.Button = btn
	else
	-- button
	btn = New("TextButton", {
		Name = "Tab_" .. tostring(opts.Name),
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = "@Checkbox",
		BackgroundTransparency = 1,
		LayoutOrder = #self.Tabs + 1,
		Parent = self._bar,
	})
	corner(btn, 6)
	local inner = New("Frame", { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = btn })
	pad(inner, 10, 0, 10, 0)
	list(inner, 6, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center)
	if opts.Icon then
		icon(inner, opts.Icon, 13, "@SubText", { LayoutOrder = 1 })
	end
	local lbl = New("TextLabel", {
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = opts.Name or "Tab",
		FontFace = FONT_SEMI,
		TextColor3 = "@SubText",
		LayoutOrder = 2,
		Parent = inner,
	})
	local underline = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(0, 0, 0, 2),
		BackgroundTransparency = 1,
		Parent = btn,
	})
	accentGradient(underline, 0)
	underline.BackgroundTransparency = 1
	corner(underline, 1)
	tab.Button = btn

	btn.MouseEnter:Connect(function()
		if self.Active ~= tab then
			tween(lbl, { TextColor3 = Library.Theme.Text }, 0.1)
		end
	end)
	btn.MouseLeave:Connect(function()
		if self.Active ~= tab then
			tween(lbl, { TextColor3 = Library.Theme.SubText }, 0.1)
		end
	end)

	function tab:_setSelected(on)
		tween(btn, { BackgroundTransparency = on and 0.35 or 1 }, 0.15)
		tween(lbl, { TextColor3 = on and selText() or Library.Theme.SubText }, 0.15)
	end
	end
	btn.Activated:Connect(function()
		self:SelectTab(tab)
	end)

	-- page (CanvasGroup so we can fade the whole page)
	local page = New("CanvasGroup", {
		Name = "Page_" .. tostring(opts.Name),
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		GroupTransparency = 1,
		Parent = self._body,
	})
	local scroll = New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = "@Muted",
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = page,
	})
	pad(scroll, 0, 0, 6, 8)
	list(scroll, 8)

	local full = New("Frame", {
		Name = "Full",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = scroll,
	})
	list(full, 8)
	local columns = New("Frame", {
		Name = "Columns",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = scroll,
	})
	list(columns, 8, Enum.FillDirection.Horizontal)
	local function column(order)
		local c = New("Frame", {
			Size = UDim2.new(0.5, -4, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order,
			Parent = columns,
		})
		list(c, 8)
		return c
	end
	tab.Page = page
	tab.Scroll = scroll
	tab.Full = full
	tab.Left = column(1)
	tab.Right = column(2)

	table.insert(self.Tabs, tab)
	if opts.Warning then
		tab:SetWarning(opts.Warning)
	end
	if #self.Tabs == 1 then
		self:SelectTab(tab)
	end
	return tab
end

function Window:SelectTab(tab)
	if type(tab) == "string" then
		for _, t in self.Tabs do
			if t.Name == tab then
				tab = t
				break
			end
		end
	end
	if type(tab) ~= "table" or self.Active == tab then
		return
	end
	local prev = self.Active
	if prev then
		prev.Page.Visible = false
		prev:_setSelected(false)
	end
	self.Active = tab
	tab.Page.Position = UDim2.fromOffset(0, 24)
	tab.Page.GroupTransparency = 1
	tab.Page.Visible = true
	tween(tab.Page, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, 0.42, Enum.EasingStyle.Quint)
	tab:_setSelected(true)
end

function Window:SetVisible(v)
	self.Instance.Visible = v
end

function Window:Toggle()
	self.Instance.Visible = not self.Instance.Visible
end

function Window:Minimize()
	self._minimized = not self._minimized
	if self._resize then
		self._resize:SetLocked(self._minimized)
	end
	local target = self._minimized and UDim2.new(self._size.X.Scale, self._size.X.Offset, 0, 42) or self._size
	tween(self.Instance, { Size = target }, 0.24, Enum.EasingStyle.Quint)
end

function Window:Destroy()
	local i = table.find(Library.Windows, self)
	if i then
		table.remove(Library.Windows, i)
	end
	self.Instance:Destroy()
end

--------------------------------------------------------------------------------
-- Sub-windows (floating draggable panels)
--------------------------------------------------------------------------------

local SubWindow = setmetatable({}, { __index = Container })
SubWindow.__index = SubWindow

--[[
	local win = Library:CreateSubWindow({
		Name = "Key System", Size = UDim2.fromOffset(340, 220), Position = UDim2,
		Minimizable = true, Maximizable = true, Closable = true, Visible = false,
	})
	win:AddTextbox({...}) -- it's a container
	win:Open() / :Close() / :Toggle() / :Minimize() / :Maximize()
]]
function Library:CreateSubWindow(opts)
	opts = opts or {}
	self:_Gui()
	if self.AutoLoadIcons then
		self:LoadIcons()
	end
	local size = opts.Size or UDim2.fromOffset(340, 260)
	local HEADER = 34

	local holder = New("Frame", {
		Name = "SubWindow_" .. tostring(opts.Name),
		Position = opts.Position or UDim2.new(0.5, -170, 0.5, -130),
		Size = size,
		ZIndex = self:_nextZ(),
		Visible = false,
		Parent = self.WindowLayer,
	})
	local main = glassFrame(holder, size)
	local uiScale = New("UIScale", { Scale = 0.94, Parent = holder })

	main.InputBegan:Connect(function(input)
		if input.UserInputType == MB1 or input.UserInputType == TOUCH then
			holder.ZIndex = self:_nextZ()
		end
	end)

	local header = New("Frame", { Size = UDim2.new(1, 0, 0, HEADER), Parent = main })
	pad(header, 14, 0, 8, 0)
	local title = New("TextLabel", {
		Size = UDim2.new(1, -90, 1, 0),
		Text = opts.Name or "Window",
		FontFace = FONT_BOLD,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = header,
	})
	local controls = New("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 80, 1, 0),
		Parent = header,
	})
	list(controls, 4, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

	New("Frame", {
		Position = UDim2.fromOffset(0, HEADER),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = "@Stroke",
		BackgroundTransparency = 0.5,
		Parent = main,
	})

	local body = New("ScrollingFrame", {
		Position = UDim2.fromOffset(0, HEADER + 1),
		Size = UDim2.new(1, 0, 1, -(HEADER + 1)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = "@Muted",
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = main,
	})
	pad(body, 12, 12, 14, 12)
	list(body, 8)

	local sw = setmetatable({
		Instance = holder,
		Main = main,
		Content = body,
		Title = title,
		_size = size,
		_normalPos = holder.Position,
		_minimized = false,
		_maximized = false,
		Opened = false,
		OnClose = opts.OnClose,
	}, SubWindow)

	local function present()
		return holder.Parent ~= nil
	end

	function sw:Open()
		if self.Opened or not present() then
			return
		end
		self.Opened = true
		holder.ZIndex = Library:_nextZ()
		holder.Visible = true
		uiScale.Scale = 0.88
		tween(uiScale, { Scale = 1 }, 0.42, Enum.EasingStyle.Back)
	end

	function sw:Close()
		if not self.Opened or not present() then
			return
		end
		self.Opened = false
		tween(uiScale, { Scale = 0.9 }, 0.16)
		task.delay(0.14, function()
			if not self.Opened and present() then
				holder.Visible = false
			end
		end)
		safeCall(self.OnClose)
	end

	function sw:Toggle()
		if self.Opened then
			self:Close()
		else
			self:Open()
		end
	end

	function sw:Minimize()
		if self._maximized then
			self:Maximize()
		end
		self._minimized = not self._minimized
		if self._resize then
			self._resize:SetLocked(self._minimized or self._maximized)
		end
		local target = self._minimized and UDim2.new(self._size.X.Scale, self._size.X.Offset, 0, HEADER) or self._size
		tween(holder, { Size = target }, 0.22, Enum.EasingStyle.Quint)
	end

	function sw:Maximize()
		if self._minimized then
			self._minimized = false
		end
		self._maximized = not self._maximized
		if self._resize then
			self._resize:SetLocked(self._maximized)
		end
		if self._maximized then
			self._normalPos = holder.Position
			tween(holder, { Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1) }, 0.26, Enum.EasingStyle.Quint)
		else
			tween(holder, { Size = self._size, Position = self._normalPos }, 0.26, Enum.EasingStyle.Quint)
		end
	end

	function sw:SetTitle(t)
		title.Text = t
	end

	function sw:Destroy()
		local i = table.find(Library.SubWindows, self)
		if i then
			table.remove(Library.SubWindows, i)
		end
		holder:Destroy()
	end

	if opts.Minimizable ~= false then
		controlButton(controls, "minus", function()
			sw:Minimize()
		end, nil, 1)
	end
	if opts.Maximizable ~= false then
		controlButton(controls, "square", function()
			sw:Maximize()
		end, nil, 2)
	end
	if opts.Closable ~= false then
		controlButton(controls, "x", function()
			sw:Close()
		end, "Danger", 3)
	end
	makeDraggable(header, holder)
	if opts.Resizable ~= false and Library.Resizable then
		sw._resize = makeResizable(holder, {
			MinSize = opts.MinSize or Vector2.new(220, 120),
			OnResize = function(sz)
				sw._size = UDim2.fromOffset(sz.X, sz.Y)
			end,
		})
	end

	table.insert(self.SubWindows, sw)
	if opts.Visible then
		sw:Open()
	end
	return sw
end


--[[
	Library:CreateKeySystem({
		Name = "Key System", Placeholder = "Enter key...", Position = UDim2, Visible = true,
		GetKeyText = "Get Key", SubmitText = "Submit",
		OnGetKey = function() end,          -- e.g. setclipboard(link)
		OnSubmit = function(key, window) end,
	}) -> SubWindow  (win.Textbox is the key box)
]]
function Library:CreateKeySystem(opts)
	opts = opts or {}
	local win = self:CreateSubWindow({
		Name = opts.Name or "Key System",
		Size = opts.Size or UDim2.fromOffset(360, 150),
		Position = opts.Position,
		Minimizable = opts.Minimizable == true,
		Maximizable = opts.Maximizable == true,
		Closable = opts.Closable == true,
		Visible = opts.Visible ~= false,
	})
	local box = win:AddTextbox({ Placeholder = opts.Placeholder or "Enter key...", Flag = opts.Flag })
	win.Textbox = box
	win:AddButton({
		Name = opts.GetKeyText or "Get Key",
		Callback = opts.OnGetKey,
		SubButton = {
			Name = opts.SubmitText or "Submit",
			Callback = function()
				local text = box.TextBox and box.TextBox.Text or box.Value
				if opts.OnSubmit then
					task.spawn(opts.OnSubmit, text, win)
				end
			end,
		},
	})
	return win
end

--------------------------------------------------------------------------------
-- Config UI helper (files when available, clipboard / string otherwise)
--------------------------------------------------------------------------------

--- Library:BuildConfigSection(section, { Folder = "MyHub" })
function Library:BuildConfigSection(container, opts)
	opts = opts or {}
	local folder = opts.Folder or "LumenUI"
	local hasFiles = writefile and readfile and isfolder and makefolder and listfiles and true or false

	local function configs()
		local out = {}
		if hasFiles and isfolder(folder) then
			for _, path in listfiles(folder) do
				local name = tostring(path):match("([^/\\]+)%.json$")
				if name then
					table.insert(out, name)
				end
			end
		end
		table.sort(out)
		return out
	end

	local nameBox = container:AddTextbox({ Name = "Config name", Placeholder = "default" })
	local dropdown = container:AddDropdown({ Name = "Saved configs", Options = configs() })

	local function refresh()
		dropdown:SetOptions(configs())
	end
	local function chosen()
		local n = dropdown.Value
		if n == nil or n == "" then
			n = nameBox.Value
		end
		return (n ~= nil and n ~= "") and n or nil
	end

	if hasFiles then
		container:AddButton({
			Name = "Save",
			Callback = function()
				local n = nameBox.Value ~= "" and nameBox.Value or chosen()
				if not n then
					return Library:Notify({ Title = "Config", Content = "Enter a config name first.", Type = "Warning" })
				end
				if not isfolder(folder) then
					makefolder(folder)
				end
				writefile(folder .. "/" .. n .. ".json", Library:GetConfigString())
				refresh()
				Library:Notify({ Title = "Config saved", Content = n, Type = "Success" })
			end,
			SubButton = {
				Name = "Load",
				Callback = function()
					local n = chosen()
					if not n then
						return Library:Notify({ Title = "Config", Content = "Pick a config.", Type = "Warning" })
					end
					local ok, data = pcall(readfile, folder .. "/" .. n .. ".json")
					if ok and Library:LoadConfigString(data) then
						Library:Notify({ Title = "Config loaded", Content = n, Type = "Success" })
					else
						Library:Notify({ Title = "Config", Content = "Could not load " .. n, Type = "Error" })
					end
				end,
			},
		})
		container:AddButton({
			Name = "Refresh list",
			Callback = refresh,
			SubButton = {
				Name = "Delete",
				Callback = function()
					local n = chosen()
					if n and delfile and isfile(folder .. "/" .. n .. ".json") then
						delfile(folder .. "/" .. n .. ".json")
						refresh()
						Library:Notify({ Title = "Config deleted", Content = n, Type = "Info" })
					end
				end,
			},
		})
	else
		container:AddLabel({ Text = "File access unavailable here - use Export / Import below.", Dim = true })
	end

	local importBox = container:AddTextbox({ Name = "Config string", Placeholder = "paste exported config...", FireOnBlur = false })
	container:AddButton({
		Name = "Export",
		Callback = function()
			local str = Library:GetConfigString()
			importBox:Set(str, true)
			if setclipboard then
				setclipboard(str)
				Library:Notify({ Title = "Config exported", Content = "Copied to clipboard.", Type = "Success" })
			else
				Library:Notify({ Title = "Config exported", Content = "Copy it from the text box.", Type = "Info" })
			end
		end,
		SubButton = {
			Name = "Import",
			Callback = function()
				local ok, err = Library:LoadConfigString(importBox.TextBox.Text)
				Library:Notify({
					Title = ok and "Config imported" or "Import failed",
					Content = ok and "Settings applied." or tostring(err),
					Type = ok and "Success" or "Error",
				})
			end,
		},
	})
end


--------------------------------------------------------------------------------
-- Theme + background settings UI (colors, presets, custom themes, custom background)
--------------------------------------------------------------------------------

--- Library:BuildThemeSection(container, { Folder = "MyHub" })
function Library:BuildThemeSection(container, opts)
	opts = opts or {}
	local folder = opts.Folder or "LumenUI"
	local hasFiles = (writefile and readfile and isfolder and makefolder and listfiles and isfile) and true or false

	local function encodeTheme(t)
		local out = {}
		for k, v in t do
			out[k] = typeof(v) == "Color3" and toHex(v) or v
		end
		return out
	end
	local function decodeTheme(tb)
		local t = table.clone(DEFAULT_THEME)
		for k, v in tb do
			if type(v) == "string" and v:sub(1, 1) == "#" then
				t[k] = fromHex(v) or t[k]
			elseif type(v) == "number" then
				t[k] = v
			end
		end
		return t
	end

	-- saved custom themes + default theme
	if hasFiles and isfolder(folder .. "/themes") then
		for _, path in listfiles(folder .. "/themes") do
			local name = tostring(path):match("([^/\\]+)%.json$")
			if name then
				pcall(function()
					self.Themes[name] = decodeTheme(HttpService:JSONDecode(readfile(path)))
				end)
			end
		end
	end
	if hasFiles and isfile(folder .. "/default_theme.txt") then
		local ok, n = pcall(readfile, folder .. "/default_theme.txt")
		if ok and self.Themes[n] then
			self:ApplyThemePreset(n)
		end
	end

	local pickers, angle = {}, nil
	local function color(label, key, flag)
		pickers[key] = container:AddColorPicker({
			Name = label,
			Flag = flag,
			Default = self.Theme[key],
			Callback = function(c)
				self:SetTheme({ [key] = c })
			end,
		})
	end
	color("Background color (start)", "Background", "theme_background")
	color("Background color (end)", "Background2", "theme_background2")
	color("Main color", "Panel", "theme_panel")
	color("Main color (end)", "Panel2", "theme_panel2")
	color("Accent color", "Accent", "theme_accent")
	color("Accent color 2", "Accent2", "theme_accent2")
	color("Outline color", "Stroke", "theme_stroke")
	color("Font color", "Text", "theme_text")

	angle = container:AddSlider({
		Name = "Background gradient angle",
		Flag = "theme_angle",
		Min = 0,
		Max = 360,
		Default = self.Theme.BackgroundAngle,
		Suffix = " deg",
		Callback = function(v)
			self:SetTheme({ BackgroundAngle = v })
		end,
	})
	container:AddToggle({
		Name = "Animated gradient",
		Flag = "theme_animated",
		Default = self.AnimateGradient,
		Callback = function(on)
			self.AnimateGradient = on
		end,
	})
	container:AddToggle({
		Name = "Glass (see-through panels)",
		Flag = "theme_glass",
		Default = self.Glass,
		Tooltip = "Applies to windows created after changing it.",
		Callback = function(on)
			self.Glass = on
		end,
	})

	local function names()
		local n = {}
		for k in self.Themes do
			table.insert(n, k)
		end
		table.sort(n)
		return n
	end
	local dd
	dd = container:AddDropdown({
		Name = "Theme list",
		Flag = "theme_preset",
		Options = names(),
		Callback = function(name)
			if self:ApplyThemePreset(name) then
				for key, p in pickers do
					p:Set(self.Theme[key], nil, true)
				end
				angle:Set(self.Theme.BackgroundAngle, true)
			end
		end,
	})

	container:AddButton({
		Name = "Set as default",
		Callback = function()
			local n = dd.Value
			if not n then
				return self:Notify({ Title = "Theme", Content = "Pick a theme first.", Type = "Warning" })
			end
			if not hasFiles then
				return self:Notify({ Title = "Theme", Content = "File access unavailable here.", Type = "Warning" })
			end
			if not isfolder(folder) then
				makefolder(folder)
			end
			writefile(folder .. "/default_theme.txt", n)
			self:Notify({ Title = "Default theme", Content = n, Type = "Success" })
		end,
	})

	local nameBox = container:AddTextbox({ Name = "Custom theme name", Placeholder = "my theme" })
	container:AddButton({
		Name = "Create theme",
		Callback = function()
			local n = nameBox.TextBox.Text
			if n == "" then
				return self:Notify({ Title = "Theme", Content = "Enter a theme name.", Type = "Warning" })
			end
			self.Themes[n] = table.clone(self.Theme)
			dd:SetOptions(names(), true)
			dd:Set(n, true)
			if hasFiles then
				if not isfolder(folder) then
					makefolder(folder)
				end
				if not isfolder(folder .. "/themes") then
					makefolder(folder .. "/themes")
				end
				writefile(folder .. "/themes/" .. n .. ".json", HttpService:JSONEncode(encodeTheme(self.Theme)))
			end
			self:Notify({ Title = "Theme created", Content = n, Type = "Success" })
		end,
	})
end

--- Library:BuildBackgroundSection(container): custom image / video background controls
function Library:BuildBackgroundSection(container)
	local box = container:AddTextbox({
		Name = "Background (asset id or link: png / jpg / webm / mp4)",
		Flag = "bg_source",
		Placeholder = "rbxassetid://... or https://...",
		FireOnBlur = false,
	})
	local isVideo = container:AddToggle({ Name = "Source is a video", Flag = "bg_is_video", Tooltip = "Links ending in .webm / .mp4 are detected automatically. Tick this for video asset ids." })
	container:AddSlider({
		Name = "Background visibility",
		Flag = "bg_visibility",
		Min = 0,
		Max = 100,
		Default = math.floor(self.Background.Transparency * 100),
		Suffix = "%",
		Callback = function(v)
			self:SetBackground({ Transparency = v / 100 })
		end,
	})
	container:AddButton({
		Name = "Apply background",
		Accent = true,
		Callback = function()
			local text = box.TextBox.Text
			if text == "" then
				return self:Notify({ Title = "Background", Content = "Enter an asset id or link.", Type = "Warning" })
			end
			local lower = text:lower()
			local video = isVideo.Value or lower:find("%.webm") ~= nil or lower:find("%.mp4") ~= nil
			if video then
				self:SetBackground({ Video = text })
			else
				self:SetBackground({ Image = text })
			end
		end,
		SubButton = {
			Name = "Clear",
			Callback = function()
				self:SetBackground({ Clear = true })
			end,
		},
	})
end

return Library

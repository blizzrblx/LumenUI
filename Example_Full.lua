--[[
	LumenUI - FULL FEATURE EXAMPLE
	Every feature of the library, populated with placeholder text / values.
	Replace anything marked PLACEHOLDER with your own data.
]]

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/LumenUI.lua"))() -- PLACEHOLDER url
-- local Library = require(path.to.LumenUI)            -- ModuleScript alternative

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Theme = Library.Theme

--------------------------------------------------------------------------------
-- 0. GLOBAL SETTINGS
--------------------------------------------------------------------------------
Library.ToggleKey = Enum.KeyCode.RightShift   -- show / hide every window (nil disables)
Library.IconSet = "lucide"                    -- icon pack (Footagesus/Icons)
Library.Glass = false                         -- true = see-through panels
Library.Resizable = true                      -- windows + sub-windows resize from right / bottom edges and the corner
Library.DragSmoothing = 11                    -- eased dragging: 6 = floaty, 20 = snappy, 0 = exact cursor follow
Library.AnimateGradient = false               -- slowly rotate window gradient (non-flat themes)
-- Library.Parent = gethui()                  -- where the ScreenGui lives (default PlayerGui)

Library:ApplyThemePreset("Starlight")         -- Starlight | Midnight | Hidden | Illusionary | Crimson | Emerald | Ocean
-- Library:SetTheme({ Accent = Color3.fromRGB(159,150,193), Accent2 = Color3.fromRGB(159,150,193) })

--------------------------------------------------------------------------------
-- 1. BACKDROP (dim + weather) -- "Snow" | "Rain" | "Fireflies" | "None"
--------------------------------------------------------------------------------
Library:SetBackdrop({ Weather = "Snow", Tint = 0.45, Dim = true, Density = 1, Speed = 1 })

--------------------------------------------------------------------------------
-- 2. HUD: WATERMARK + HOTKEYS PANEL
--------------------------------------------------------------------------------
local Watermark = Library:CreateWatermark({
	Title = "Placeholder Hub",       -- PLACEHOLDER
	Text = "v1.0.0",
	ShowUser = true, ShowFPS = true, ShowPing = true,
	Icon = "sparkles",
})
-- Watermark:SetTitle("..."), :SetText("..."), :SetVisible(bool)

local Hotkeys = Library:CreateKeybindList({ Title = "Hotkeys", Position = UDim2.new(0, 16, 0.5, -40) })
Hotkeys:Add("manual1", { Name = "Placeholder Feature A", Key = "X", Active = false })
Hotkeys:Add("manual2", { Name = "Placeholder Feature B", Key = "?", Active = true })
-- Hotkeys:SetActive("manual1", true) / :Remove("manual2") / :SetVisible(false)
-- (toggles created with Keybind = {...} register themselves here automatically)

--------------------------------------------------------------------------------
-- 3. MAIN WINDOW
--------------------------------------------------------------------------------
local Window = Library:CreateWindow({
	Title = "Placeholder Interface Suite",       -- PLACEHOLDER
	Subtitle = "Placeholder Game : Name",
	Footer = "discord.gg/placeholder",
	Icon = "sparkles",
	Layout = "Top",                              -- "Top" (tab bar) or "Sidebar" (icon rail + avatar)
	Size = UDim2.fromOffset(460, 540),
	Resizable = true, MinSize = Vector2.new(380, 260),   -- per-window overrides (Resizable = false locks it)
	Position = UDim2.new(0.5, -480, 0.5, 0),
	Badges = {
		{ Text = "Pro", Color = Theme.Success },
		{ Text = "v2.0", Color = Theme.Danger },
	},
	OnClose = function() print("main window closed") end,
})
-- Window:AddBadge({ Text = "Beta", Color = Theme.Warning }) / :SetTitle / :SetSubtitle
-- Window:SelectTab(tab) / :SetVisible(b) / :Toggle() / :Minimize() / :Destroy()

--==============================================================================
-- TAB 1: ELEMENTS (every element type)
--==============================================================================
local Elements = Window:CreateTab({
	Name = "Elements",
	Icon = "swords",
	Warning = { Title = "PLACEHOLDER WARNING", Text = "Example warning banner for a tab." },
	-- Warning = { ..., Color = Theme.Danger }  -> adds a coloured side bar
})

----- Left column: basic controls ------------------------------------------------
local Basic = Elements:CreateSection({ Name = "Basic Controls", Side = "Left" })

Basic:AddLabel({ Text = "Basic label" })
Basic:AddLabel({ Text = "Bold label", Bold = true })
Basic:AddLabel({ Text = "Dim label (sub text colour)", Dim = true })
Basic:AddLabel({ Text = "<font color='#9f96c1'>Rich</font> <b>text</b> label with wrapping so it grows over several lines when needed.", Size = 12 })
Basic:AddDivider()
Basic:AddSpacer(6)

Basic:AddToggle({ Name = "Toggle", Flag = "Toggle1", Default = false, Callback = function(v) print("Toggle1", v) end })
Basic:AddToggle({ Name = "Toggle (default on)", Flag = "Toggle2", Default = true })
Basic:AddToggle({ Name = "Toggle with tooltip", Tooltip = "Placeholder tooltip text" })
Basic:AddToggle({
	Name = "Toggle with keybind",
	Flag = "ToggleKey",
	Keybind = { Default = Enum.KeyCode.Insert, Mode = "Toggle", ListName = "Placeholder Hotkey", ShowInList = true },
	-- Mode = "Toggle" | "Hold" | "Always"
})
Basic:AddToggle({
	Name = "Toggle with colour pickers",
	Colors = { Color3.fromRGB(150, 235, 160), Color3.fromRGB(255, 120, 120) },
	-- Color = Color3 for a single swatch
})
local DisabledToggle = Basic:AddToggle({ Name = "Disabled toggle" })
DisabledToggle:SetDisabled(true)

Basic:AddButton({ Name = "Button", Icon = "mouse-pointer-click", Callback = function() Library:Notify({ Title = "Button pressed" }) end })
Basic:AddButton({
	Name = "Button",
	Callback = function() print("main") end,
	SubButton = { Name = "Sub-button", Callback = function() print("sub") end },
})
Basic:AddButton({ Name = "Accent button", Accent = true, Callback = function() end })

Basic:AddKeybind({ Name = "Standalone keybind (Press)", Default = Enum.KeyCode.F, Mode = "Press", Flag = "KeyPress" })
Basic:AddKeybind({ Name = "Standalone keybind (Toggle)", Default = Enum.KeyCode.G, Mode = "Toggle", Flag = "KeyToggle" })
Basic:AddKeybind({ Name = "Standalone keybind (Hold)", Default = Enum.KeyCode.H, Mode = "Hold", Flag = "KeyHold" })

Basic:AddColorPicker({ Name = "Colour picker", Default = Color3.fromRGB(248, 165, 255), Flag = "Color1" })
Basic:AddColorPicker({ Name = "Colour picker + alpha", Default = Color3.fromRGB(120, 180, 255), Alpha = true, Flag = "Color2" })

----- Right column: value controls -----------------------------------------------
local Values = Elements:CreateSection({ Name = "Value Controls", Side = "Right" })

Values:AddSlider({ Name = "Slider", Min = 0, Max = 100, Default = 50, Increment = 1, Flag = "Slider1" })
Values:AddSlider({ Name = "Slider with suffix", Min = 0, Max = 10000, Default = 8000, Display = "{value} km/100", Flag = "Slider2" })
Values:AddSlider({ Name = "Decimal slider", Min = 0, Max = 1, Default = 0.25, Increment = 0.05, Flag = "Slider3" })
Values:AddSlider({
	Name = "Custom formatted slider", Min = 0, Max = 360, Default = 90,
	Format = function(v, min, max) return v .. "°" end, Flag = "Slider4",
})

Values:AddDropdown({ Name = "Dropdown", Options = { "Placeholder 1", "Placeholder 2", "Placeholder 3" }, Default = "Placeholder 1", Flag = "Drop1" })
Values:AddDropdown({ Name = "Multi dropdown", Options = { "Option A", "Option B", "Option C", "Option D" }, Multi = true, Default = { "Option A" }, Flag = "Drop2" })
Values:AddDropdown({ Name = "Dropdown (allow none)", Options = { "Alpha", "Beta", "Gamma" }, AllowNone = true, MaxVisible = 4, Flag = "Drop3" })

Values:AddTextbox({ Name = "Textbox", Placeholder = "Dynamic input (textbox)", Flag = "Text1" })
Values:AddTextbox({ Name = "Numeric textbox", Placeholder = "123", Numeric = true, Flag = "Text2" })
Values:AddTextbox({ Name = "Multiline textbox", Placeholder = "Placeholder notes...", Multiline = true, Height = 70, Flag = "Text3" })
Values:AddTextbox({ Name = "Live-update textbox", Placeholder = "Fires while typing", LiveUpdate = true, Callback = function(t) print(t) end })

--==============================================================================
-- TAB 2: LAYOUT (sub-tabs, full-width sections, previews, image list)
--==============================================================================
local Layout = Window:CreateTab({ Name = "Layout", Icon = "layout-grid" })

local Tabbed = Layout:CreateSection({ Side = "Left" })           -- no title: sub-tab bar only
local SubA = Tabbed:CreateSubTab("Aimbot")
local SubB = Tabbed:CreateSubTab("FOV")
local SubC = Tabbed:CreateSubTab("Prediction")
SubA:AddToggle({ Name = "Sub-tab toggle A" })
SubA:AddSlider({ Name = "Sub-tab slider A", Min = 0, Max = 100, Default = 20 })
SubB:AddToggle({ Name = "Sub-tab toggle B" })
SubC:AddLabel({ Text = "Anything works inside a sub-tab.", Dim = true })

local Previews = Layout:CreateSection({ Name = "Viewports", Side = "Right" })
Previews:AddViewport({ Height = 170, Avatar = LocalPlayer.UserId, Rotate = 25, Interactive = true })     -- your avatar
local placeholderPart = Instance.new("Part")                                                           -- PLACEHOLDER object
placeholderPart.Size = Vector3.new(4, 1.6, 2)
placeholderPart.Color = Color3.fromRGB(160, 160, 160)
local vp = Previews:AddViewport({ Height = 170, Object = placeholderPart, Rotate = 30 })
vp:AddOverlayButton({ Name = "Overlay", Position = UDim2.new(1, -62, 1, -26), Size = UDim2.fromOffset(56, 20), Callback = function() print("overlay") end })
-- vp:SetObject(inst) / vp:SetAvatar(userId) / vp:SetRotate(speed | false) / vp.Overlay

Previews:AddESPPreview({ Height = 220, Style = "Corner", Color = Color3.new(1, 1, 1), Text = "PlaceholderName", DistanceText = "42m", HealthValue = 0.75 })

local Images = Layout:CreateSection({ Name = "Image List", Side = "Full" })
local imgItems = {}
for i = 1, 8 do
	imgItems[i] = { Name = "Item " .. i, Image = 0, Description = "Placeholder", Value = "item" .. i } -- PLACEHOLDER asset ids
end
Images:AddImageList({ Name = "Selectable images", Items = imgItems, ItemSize = Vector2.new(96, 96), Height = 220, Multi = false, Collapsible = true, Default = "item1", Flag = "Skin" })
Images:AddImageList({ Name = "Multi-select images", Items = imgItems, ItemSize = Vector2.new(80, 80), Height = 180, Multi = true, Default = { "item2", "item3" }, Flag = "SkinMulti" })

--==============================================================================
-- TAB 3: DASHBOARD (profile, info cards, credits)
--==============================================================================
local Dash = Window:CreateTab({ Name = "Dashboard", Icon = "layout-dashboard" })

local Cards = Dash:CreateSection({ Name = "Cards", Side = "Left", Plain = false })
local profile = Cards:AddProfile({ UserId = LocalPlayer.UserId, Title = "Hello, Placeholder", Subtitle = "Placeholder - Game Name", Height = 72 })
-- profile:SetTitle("...") / :SetSubtitle("...")
local server = Cards:AddInfoCard({
	Title = "Server", Description = "Placeholder session information...",
	Gradient = Color3.fromRGB(90, 120, 255), GradientRotation = -40, Columns = 2, TileHeight = 44,
	Tiles = {
		{ Id = "players", Title = "Players", Text = "9 playing", Callback = function() print("players") end },
		{ Id = "ping", Title = "Ping", Text = "42 ms" },
		{ Id = "region", Title = "Region", Text = "PLACEHOLDER" },
		{ Id = "uptime", Title = "Uptime", Text = "00:12:34" },
	},
})
server:SetTile("players", "12 playing")
Cards:AddInfoCard({ Title = "Clickable card", Description = "Whole card is a button.", Gradient = { Color3.fromRGB(120, 60, 160), Color3.fromRGB(9, 9, 13) }, Callback = function() Library:Notify({ Title = "Card clicked" }) end })

local Credits = Dash:CreateSection({ Name = "Credits", Side = "Right" })
Credits:AddCredit({ Name = "@placeholder_owner", Tag = "OWNER/DEVELOPER", TagColor = Theme.Success, Description = "Placeholder description text." })
Credits:AddCredit({ Name = "@placeholder_tester", Tag = "OWNER/TESTER", TagColor = Theme.Warning, Description = "Placeholder description text." })
Credits:AddCredit({ Name = "@placeholder_bugs", Tag = "CONTRIBUTOR » BUG FIXING", TagColor = Theme.Danger, Description = "Lorem Ipsum Dolor Sit Amet." })
Credits:AddCredit({ Name = "@placeholder_ui", Tag = "CONTRIBUTOR » UI", TagColor = Color3.fromRGB(90, 150, 255), Description = "Lorem Ipsum Dolor Sit Amet." })

--==============================================================================
-- TAB 4: SETTINGS (config, theme, background, notifications, flags)
--==============================================================================
local Settings = Window:CreateTab({ Name = "Settings", Icon = "settings" })

local Cfg = Settings:CreateSection({ Name = "Configs", Side = "Left" })
Library:BuildConfigSection(Cfg, { Folder = "PlaceholderHub" })      -- save / load / delete / import / export

local Thm = Settings:CreateSection({ Name = "Theme", Side = "Right" })
Library:BuildThemeSection(Thm, { Folder = "PlaceholderHub" })       -- colours, presets, custom themes

local Bg = Settings:CreateSection({ Name = "Background", Side = "Full" })
Library:BuildBackgroundSection(Bg)                                  -- image / video background picker
-- Library:SetBackground({ Image = "rbxassetid://0", Transparency = 0.6 })   -- PLACEHOLDER
-- Library:SetBackground({ Clear = true })

local Misc = Settings:CreateSection({ Name = "Notifications & Misc", Side = "Full" })
Misc:AddButton({ Name = "Info toast", Callback = function() Library:Notify({ Title = "Info", Content = "Placeholder content", Type = "Info" }) end,
	SubButton = { Name = "Success toast", Callback = function() Library:Notify({ Title = "Success", Content = "Placeholder content", Type = "Success" }) end } })
Misc:AddButton({ Name = "Warning toast", Callback = function() Library:Notify({ Title = "Warning", Content = "Placeholder content", Type = "Warning" }) end,
	SubButton = { Name = "Error toast", Callback = function() Library:Notify({ Title = "Error", Content = "Placeholder content", Type = "Error" }) end } })
Misc:AddButton({ Name = "Custom icon / 10s toast", Callback = function() Library:Notify({ Title = "Custom", Content = "Stays 10 seconds", Icon = "rocket", Duration = 10 }) end })
Misc:AddButton({ Name = "Read flags", Callback = function()
	-- Library.Flags[flag] -> element object (.Value, :Set(), :Get(), .Changed)
	print(Library.Flags.Toggle1.Value, Library.Flags.Slider1.Value, Library.Flags.Drop1.Value)
	Library.Flags.Slider1:Set(75)
end })
Misc:AddButton({ Name = "Config -> JSON string", Callback = function()
	local json = Library:GetConfigString()           -- Library:LoadConfigString(json) restores it
	print(json)
end })
Misc:AddButton({ Name = "Toggle backdrop weather", Callback = function()
	local order = { "Snow", "Rain", "Fireflies", "None" }
	local cur = table.find(order, Library.Backdrop.Weather) or 1
	Library:SetBackdrop({ Weather = order[cur % #order + 1] })
end })
Misc:AddButton({ Name = "Unload UI", Callback = function() Library:Unload() end })

--------------------------------------------------------------------------------
-- 4. SIDEBAR-LAYOUT WINDOW (optional second window style)
--------------------------------------------------------------------------------
local Side = Library:CreateWindow({
	Title = "Sidebar Window", Subtitle = "Placeholder", Layout = "Sidebar",
	Size = UDim2.fromOffset(520, 380), Position = UDim2.new(0.5, 40, 0.5, 120),
	SidebarAvatar = true,  -- or a userId number, or false to hide
	Badges = { { Text = "Beta", Color = Theme.Warning } },
})
local SideTab = Side:CreateTab({ Name = "Home", Icon = "house" })
SideTab:CreateSection({ Name = "Placeholder", Side = "Left" }):AddLabel({ Text = "Sidebar layout window.", Dim = true })
Side:CreateTab({ Name = "Stats", Icon = "chart-bar" })
Side:SetVisible(false) -- opened from the dock

--------------------------------------------------------------------------------
-- 5. SUB-WINDOWS (floating, draggable panels; they are full containers)
--------------------------------------------------------------------------------
local Generic = Library:CreateSubWindow({
	Name = "Generic Sub-window", Size = UDim2.fromOffset(300, 260), Position = UDim2.new(0.5, 80, 0.5, -300),
	Minimizable = true, Maximizable = true, Closable = true, Visible = true,
	OnClose = function() print("sub-window closed") end,
})
Generic:AddLabel({ Text = "Any element can live in a sub-window.", Dim = true })
Generic:AddToggle({ Name = "Placeholder toggle" })
Generic:AddSlider({ Name = "Placeholder slider", Min = 0, Max = 100, Default = 40 })
Generic:AddButton({ Name = "Placeholder button" })
-- Generic:Open() / :Close() / :Toggle() / :Minimize() / :Maximize() / :SetTitle() / :Destroy()

local Skins = Library:CreateSubWindow({
	Name = "Skin Changer", Size = UDim2.fromOffset(520, 330), Position = UDim2.new(0.5, 330, 0.5, -330),
	Minimizable = false, Maximizable = false, Closable = false, Visible = true,
})
Skins:AddImageList({ Name = "", Items = imgItems, ItemSize = Vector2.new(104, 104), Height = 280 })

local ESPWin = Library:CreateSubWindow({
	Name = "ESP Preview", Size = UDim2.fromOffset(250, 450), Position = UDim2.new(0.5, 20, 0.5, -90),
	Minimizable = false, Maximizable = false, Closable = false, Visible = true,
})
local esp = ESPWin:AddESPPreview({ Height = 380, Style = "Corner", Color = Color3.new(1, 1, 1), Name = false, Health = false, Distance = false })
ESPWin:AddToggle({ Name = "Box style", Default = false, Callback = function(v) esp:Set({ Style = v and "Box" or "Corner" }) end })
ESPWin:AddToggle({ Name = "Name", Default = false, Callback = function(v) esp:Set({ Name = v }) end })
ESPWin:AddToggle({ Name = "Health", Default = false, Callback = function(v) esp:Set({ Health = v }) end })
ESPWin:AddToggle({ Name = "Distance", Default = false, Callback = function(v) esp:Set({ Distance = v }) end })
ESPWin:AddColorPicker({ Name = "ESP colour", Default = Color3.new(1, 1, 1), Callback = function(c) esp:Set({ Color = c }) end })

local KeyWin = Library:CreateKeySystem({
	Name = "Key System", Placeholder = "Placeholder key provider support", Position = UDim2.new(0.5, 40, 0.5, 170),
	GetKeyText = "Get Key", SubmitText = "Submit",
	OnGetKey = function() Library:Notify({ Title = "Key link copied", Type = "Success" }) end,   -- PLACEHOLDER: setclipboard(link)
	OnSubmit = function(key, win) Library:Notify({ Title = "Checking key...", Content = key }) end, -- PLACEHOLDER: validate
})

local CreditsWin = Library:CreateSubWindow({
	Name = "Credits", Size = UDim2.fromOffset(320, 330), Position = UDim2.new(0.5, 300, 0.5, 40),
	MinSize = Vector2.new(260, 200), -- sub-windows take Resizable / MinSize too
	Minimizable = false, Maximizable = false, Closable = false, Visible = true,
})
CreditsWin:AddLabel({ Text = "Cool people behind *your* script", Dim = true })
CreditsWin:AddCredit({ Name = "@placeholder_owner", Tag = "OWNER/DEVELOPER", TagColor = Theme.Success, Description = "Placeholder." })
CreditsWin:AddCredit({ Name = "@placeholder_tester", Tag = "OWNER/TESTER", TagColor = Theme.Warning, Description = "Placeholder." })
CreditsWin:AddCredit({ Name = "@placeholder_bugs", Tag = "CONTRIBUTOR » BUG FIXING", TagColor = Theme.Danger, Description = "Lorem Ipsum Dolor Sit Amet." })

--------------------------------------------------------------------------------
-- 6. DOCK (top-centre launcher: one icon per window)
--------------------------------------------------------------------------------
local Dock = Library:CreateDock({
	Items = {
		{ Name = "Main window", Icon = "app-window", Window = Window },
		{ Name = "Sidebar window", Icon = "panel-left", Window = Side },
		{ Name = "Generic sub-window", Icon = "square", Window = Generic },
		{ Name = "Skin changer", Icon = "command", Window = Skins },
		{ Name = "ESP preview", Icon = "scan-face", Window = ESPWin },
		{ Name = "Key system", Icon = "keyboard", Window = KeyWin },
		{ Name = "Credits", Icon = "user-round", Window = CreditsWin },
		{ Name = "Custom toggle", Icon = "bell", Toggle = true, Active = false, Callback = function(on) Library:Notify({ Title = "Dock toggle: " .. tostring(on) }) end },
	},
})
-- Dock:AddItem({...}) / Dock:SetVisible(bool) / Dock:Destroy()

--------------------------------------------------------------------------------
-- 7. TOASTS ON START
--------------------------------------------------------------------------------
Library:Notify({ Title = "Placeholder Hub loaded", Content = "Press RightShift to hide the UI.", Type = "Success", Duration = 6 })
Library:Notify({ Title = "test notif", Duration = 6 })

return Library

-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------
local MAX_DISTANCE = 2500
local HP_THRESHOLD = 200
local HIGHLIGHT_LIMIT = 30 

-- Stamina Config
local STAMINA_DRAIN_RATE = 10     -- Drains 10 per second
local STAMINA_REGEN_RATE = 20     -- Regens 20 per second
local DELAY_NORMAL = 1            -- Delay before regen normally
local DELAY_EXHAUSTED = 2         -- Delay if stamina hits 0

-- Speed Thresholds (Must be STRICTLY greater than these to drain)
local DEFAULT_SPEED_LOW_HP = 12.1 
local DEFAULT_SPEED_HIGH_HP = 12.000001

-- Specific HP Lookups (MaxHealth -> Drain Speed)
local HP_SPEED_MAP = {
	[2500] = 9.1,
	[1700] = 7.1,
	[1500] = 9.1,
	[1250] = 9.1,
	[1100] = 8.1,
	[1111] = 7.1,
	[800]  = 7.9
}

-- Colors
local REAL_NORMAL_FILL = Color3.fromRGB(0, 255, 0)
local REAL_HIGH_HP_FILL = Color3.fromRGB(255, 0, 0)
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)

-- State
local espEnabled = false
local staminaEnabled = true
local currentMethod = "Position" -- "Position" or "WalkSpeed"
local trackedModels = {}

--------------------------------------------------------------------------------
-- 1. UI SYSTEM (Forsaken ESP v4)
--------------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ForsakenESP_v4"
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Tween Helper
local function tween(obj, props, time, style, dir)
	TweenService:Create(obj, TweenInfo.new(time or 0.3, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props):Play()
end

-- Main Panel
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainPanel"
MainFrame.Size = UDim2.new(0, 220, 0, 240) -- Increased height for new buttons
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Position = UDim2.new(0.5, 0, 0.4, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

local Glow = Instance.new("UIStroke")
Glow.Color = Color3.fromRGB(0, 0, 0)
Glow.Thickness = 2
Glow.Transparency = 0.5
Glow.Parent = MainFrame

-- Draggable
local function MakeDraggable(frame)
	local dragging, dragInput, dragStart, startPos
	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
			input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
		end
	end)
	frame.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end
MakeDraggable(MainFrame)

-- Title
local Title = Instance.new("TextLabel")
Title.Text = "Forsaken ESP"
Title.Size = UDim2.new(1, -40, 0, 30)
Title.Position = UDim2.new(0, 15, 0, 5)
Title.BackgroundTransparency = 1
Title.TextColor3 = Color3.fromRGB(230, 230, 230)
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 18
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

local Desc = Instance.new("TextLabel")
Desc.Text = "v4"
Desc.Size = UDim2.new(0, 30, 0, 20)
Desc.Position = UDim2.new(0, 130, 0, 12)
Desc.BackgroundTransparency = 1
Desc.TextColor3 = Color3.fromRGB(150, 150, 150)
Desc.Font = Enum.Font.GothamBold
Desc.TextSize = 12
Desc.Parent = MainFrame

-- Minimize
local MinButton = Instance.new("TextButton")
MinButton.Text = "-"
MinButton.Size = UDim2.new(0, 30, 0, 30)
MinButton.Position = UDim2.new(1, -35, 0, 2)
MinButton.BackgroundTransparency = 1
MinButton.TextColor3 = Color3.fromRGB(200, 200, 200)
MinButton.Font = Enum.Font.GothamBold
MinButton.TextSize = 24
MinButton.Parent = MainFrame

-- == ESP TOGGLE ==
local ESPToggleBtn = Instance.new("TextButton")
ESPToggleBtn.Size = UDim2.new(0.9, 0, 0, 40)
ESPToggleBtn.Position = UDim2.new(0.5, 0, 0.18, 0)
ESPToggleBtn.AnchorPoint = Vector2.new(0.5, 0)
ESPToggleBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
ESPToggleBtn.Text = "ESP: OFF"
ESPToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ESPToggleBtn.Font = Enum.Font.GothamBold
ESPToggleBtn.TextSize = 16
ESPToggleBtn.AutoButtonColor = false -- DISABLE DEFAULT ROBLOX COLOR BEHAVIOR
ESPToggleBtn.Parent = MainFrame

local BtnCorner1 = Instance.new("UICorner")
BtnCorner1.CornerRadius = UDim.new(0, 6)
BtnCorner1.Parent = ESPToggleBtn

-- == STAMINA TOGGLE ==
local StaminaToggleBtn = Instance.new("TextButton")
StaminaToggleBtn.Size = UDim2.new(0.9, 0, 0, 40)
StaminaToggleBtn.Position = UDim2.new(0.5, 0, 0.38, 0)
StaminaToggleBtn.AnchorPoint = Vector2.new(0.5, 0)
StaminaToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 80) -- Default ON
StaminaToggleBtn.Text = "Stamina: ON"
StaminaToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
StaminaToggleBtn.Font = Enum.Font.GothamBold
StaminaToggleBtn.TextSize = 16
StaminaToggleBtn.AutoButtonColor = false
StaminaToggleBtn.Parent = MainFrame

local BtnCorner2 = Instance.new("UICorner")
BtnCorner2.CornerRadius = UDim.new(0, 6)
BtnCorner2.Parent = StaminaToggleBtn

-- == METHOD SELECTOR ==
local MethodLabel = Instance.new("TextLabel")
MethodLabel.Text = "Calc Method"
MethodLabel.Size = UDim2.new(1, 0, 0, 20)
MethodLabel.Position = UDim2.new(0, 0, 0.58, 0)
MethodLabel.BackgroundTransparency = 1
MethodLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
MethodLabel.Font = Enum.Font.Gotham
MethodLabel.TextSize = 12
MethodLabel.Parent = MainFrame

local MethodBtn = Instance.new("TextButton")
MethodBtn.Size = UDim2.new(0.9, 0, 0, 35)
MethodBtn.Position = UDim2.new(0.5, 0, 0.68, 0)
MethodBtn.AnchorPoint = Vector2.new(0.5, 0)
MethodBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
MethodBtn.Text = "Position"
MethodBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MethodBtn.Font = Enum.Font.GothamBold
MethodBtn.TextSize = 14
MethodBtn.AutoButtonColor = false
MethodBtn.Parent = MainFrame

local BtnCorner3 = Instance.new("UICorner")
BtnCorner3.CornerRadius = UDim.new(0, 6)
BtnCorner3.Parent = MethodBtn

-- Selection Dropdown (Hidden by default)
local MethodDropdown = Instance.new("Frame")
MethodDropdown.Size = UDim2.new(0.9, 0, 0, 70)
MethodDropdown.Position = UDim2.new(0.5, 0, 0.85, 0) -- Pops out below
MethodDropdown.AnchorPoint = Vector2.new(0.5, 0)
MethodDropdown.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
MethodDropdown.Visible = false
MethodDropdown.ZIndex = 5
MethodDropdown.Parent = MainFrame

local DropCorner = Instance.new("UICorner")
DropCorner.Parent = MethodDropdown

local PosBtn = Instance.new("TextButton")
PosBtn.Size = UDim2.new(1, 0, 0.5, 0)
PosBtn.BackgroundTransparency = 1
PosBtn.Text = "Position"
PosBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
PosBtn.Font = Enum.Font.Gotham
PosBtn.ZIndex = 6
PosBtn.Parent = MethodDropdown

local WalkBtn = Instance.new("TextButton")
WalkBtn.Size = UDim2.new(1, 0, 0.5, 0)
WalkBtn.Position = UDim2.new(0, 0, 0.5, 0)
WalkBtn.BackgroundTransparency = 1
WalkBtn.Text = "WalkSpeed"
WalkBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
WalkBtn.Font = Enum.Font.Gotham
WalkBtn.ZIndex = 6
WalkBtn.Parent = MethodDropdown

-- Icon (Minimized)
local IconFrame = Instance.new("ImageButton")
IconFrame.Name = "FloatingIcon"
IconFrame.Size = UDim2.new(0, 0, 0, 0)
IconFrame.AnchorPoint = Vector2.new(0.5, 0.5)
IconFrame.Position = UDim2.new(0.9, 0, 0.8, 0)
IconFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
IconFrame.Image = "rbxthumb://type=Asset&id=41862651&w=420&h=420"
IconFrame.Visible = false 
IconFrame.Parent = ScreenGui
MakeDraggable(IconFrame)

local IconCorner = Instance.new("UICorner")
IconCorner.CornerRadius = UDim.new(1, 0)
IconCorner.Parent = IconFrame

local IconStroke = Instance.new("UIStroke")
IconStroke.Thickness = 3
IconStroke.Color = Color3.fromRGB(255, 255, 255)
IconStroke.Parent = IconFrame
TweenService:Create(IconStroke, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Color = Color3.fromRGB(0, 0, 0)}):Play()

-- ================= INTERACTIONS =================

-- Hover Logic that respects Toggle State
local function applyStateHover(btn, isEnabled)
	local baseColor = isEnabled and Color3.fromRGB(50, 200, 80) or Color3.fromRGB(255, 60, 60)
	btn.BackgroundColor3 = baseColor -- Reset to base state immediately

	btn.MouseEnter:Connect(function() 
		-- Check current state to know which color to brighten
		local currentColor = (btn.Text:find("ON") or btn.Text:find("Position") or btn.Text:find("WalkSpeed")) and btn.BackgroundColor3 or baseColor
		tween(btn, {BackgroundColor3 = currentColor:Lerp(Color3.new(1,1,1), 0.2)}, 0.2) 
	end)
	
	btn.MouseLeave:Connect(function() 
		-- Revert to correct state color
		local stateColor
		if btn == ESPToggleBtn then stateColor = espEnabled and Color3.fromRGB(50, 200, 80) or Color3.fromRGB(255, 60, 60)
		elseif btn == StaminaToggleBtn then stateColor = staminaEnabled and Color3.fromRGB(50, 200, 80) or Color3.fromRGB(255, 60, 60) 
		else stateColor = Color3.fromRGB(60, 60, 60) end
		
		tween(btn, {BackgroundColor3 = stateColor}, 0.2) 
	end)
	
	btn.MouseButton1Down:Connect(function() tween(btn, {Size = UDim2.new(0.85, 0, 0, 35)}, 0.1) end)
	btn.MouseButton1Up:Connect(function() tween(btn, {Size = UDim2.new(0.9, 0, 0, 40)}, 0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out) end)
end

-- Initialize Buttons
applyStateHover(ESPToggleBtn, false)
applyStateHover(StaminaToggleBtn, true)

-- Menu Logic
local function OpenMenu()
	IconFrame.Visible = true
	tween(IconFrame, {Size = UDim2.new(0,0,0,0)}, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.wait(0.2)
	IconFrame.Visible = false
	MainFrame.Visible = true
	MainFrame.Size = UDim2.new(0, 0, 0, 0)
	tween(MainFrame, {Size = UDim2.new(0, 220, 0, 240)}, 0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
end

local function CloseMenu()
	tween(MainFrame, {Size = UDim2.new(0, 0, 0, 0)}, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.wait(0.2)
	MainFrame.Visible = false
	IconFrame.Visible = true
	IconFrame.Size = UDim2.new(0,0,0,0)
	tween(IconFrame, {Size = UDim2.new(0, 60, 0, 60)}, 0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
end

MinButton.MouseButton1Click:Connect(CloseMenu)
IconFrame.MouseButton1Click:Connect(OpenMenu)

-- ESP Toggle Action
ESPToggleBtn.MouseButton1Click:Connect(function()
	espEnabled = not espEnabled
	if espEnabled then
		ESPToggleBtn.Text = "ESP: ON"
		ESPToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
	else
		ESPToggleBtn.Text = "ESP: OFF"
		ESPToggleBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	end
end)

-- Stamina Toggle Action
StaminaToggleBtn.MouseButton1Click:Connect(function()
	staminaEnabled = not staminaEnabled
	if staminaEnabled then
		StaminaToggleBtn.Text = "Stamina: ON"
		StaminaToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
	else
		StaminaToggleBtn.Text = "Stamina: OFF"
		StaminaToggleBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	end
end)

-- Method Selector Action
MethodBtn.MouseButton1Click:Connect(function()
	MethodDropdown.Visible = not MethodDropdown.Visible
end)

PosBtn.MouseButton1Click:Connect(function()
	currentMethod = "Position"
	MethodBtn.Text = "Position"
	MethodDropdown.Visible = false
end)

WalkBtn.MouseButton1Click:Connect(function()
	currentMethod = "WalkSpeed"
	MethodBtn.Text = "WalkSpeed"
	MethodDropdown.Visible = false
end)


--------------------------------------------------------------------------------
-- 2. CORE LOGIC
--------------------------------------------------------------------------------

local function ResolvePlayer(model)
	local p = Players:GetPlayerFromCharacter(model)
	if p then return p end
	if model:GetAttribute("Player") then
		local found = Players:FindFirstChild(model:GetAttribute("Player"))
		if found then return found end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character == model then return player end
	end
	return nil
end

local function GetPlayerItems(player, model)
	local items = {}
	if player and player:FindFirstChild("Backpack") then
		for _, obj in ipairs(player.Backpack:GetChildren()) do
			if obj:IsA("Tool") then table.insert(items, obj.Name) end
		end
	end
	if model then
		for _, obj in ipairs(model:GetChildren()) do
			if obj:IsA("Tool") then table.insert(items, obj.Name) end
		end
	end
	if #items == 0 then return "" end
	return table.concat(items, ", ")
end

local function GetStaminaParameters(maxHealth)
	local maxStamina = 100
	if maxHealth >= 200 then maxStamina = 110 end

	local speedThreshold = DEFAULT_SPEED_LOW_HP
	if maxHealth >= 200 then
		if HP_SPEED_MAP[maxHealth] then
			speedThreshold = HP_SPEED_MAP[maxHealth]
		else
			speedThreshold = DEFAULT_SPEED_HIGH_HP
		end
	end
	
	return maxStamina, speedThreshold
end

local function AddESP(model)
	task.spawn(function()
		if trackedModels[model] then return end
		if model == LocalPlayer.Character then return end

		local humanoid = model:WaitForChild("Humanoid", 15)
		local head = model:WaitForChild("Head", 15)
		local root = model:WaitForChild("HumanoidRootPart", 15)
		
		if not humanoid or not head or not root then return end
		if trackedModels[model] then return end

		local player = ResolvePlayer(model)
		local displayName = player and player.DisplayName or model.Name 

		-- Clean old highlights
		for _, c in ipairs(model:GetChildren()) do if c:IsA("Highlight") then c:Destroy() end end

		local highlight = Instance.new("Highlight")
		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 0
		highlight.Enabled = false
		highlight.Parent = model

		local bbg = Instance.new("BillboardGui")
		bbg.Adornee = head
		bbg.Size = UDim2.new(0, 250, 0, 100)
		bbg.StudsOffset = Vector3.new(0, 3.5, 0)
		bbg.AlwaysOnTop = true
		bbg.Enabled = false
		bbg.Parent = model

		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.new(1, 0, 1, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.TextSize = 13
		textLabel.Font = Enum.Font.GothamBold
		textLabel.TextColor3 = TEXT_COLOR
		textLabel.RichText = true
		textLabel.TextStrokeTransparency = 0
		textLabel.Parent = bbg

		trackedModels[model] = {
			Model = model,
			Player = player,
			Name = displayName,
			Highlight = highlight,
			Billboard = bbg,
			Text = textLabel,
			Humanoid = humanoid,
			Root = root,
			LastPosition = root.Position, 
			AvgSpeed = 0,
			Stamina = 100,
			RegenTimer = 0,
			IsExhausted = false
		}
		
		humanoid.Died:Connect(function()
			task.wait(3)
			if trackedModels[model] then trackedModels[model] = nil end
		end)
	end)
end

local function RemoveESP(model)
	if trackedModels[model] then
		if trackedModels[model].Highlight then trackedModels[model].Highlight:Destroy() end
		if trackedModels[model].Billboard then trackedModels[model].Billboard:Destroy() end
		trackedModels[model] = nil
	end
end

-- SCANNER
local function ScanFolder(folder)
	if not folder then return end
	for _, child in ipairs(folder:GetChildren()) do if child:IsA("Model") then AddESP(child) end end
	folder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then 
			task.wait(0.5)
			AddESP(child) 
		end
	end)
end

if Workspace:FindFirstChild("Players") then
	ScanFolder(Workspace.Players:FindFirstChild("Survivors"))
	ScanFolder(Workspace.Players:FindFirstChild("Killers"))
end

Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(AddESP) end)
for _, p in ipairs(Players:GetPlayers()) do
	if p.Character then AddESP(p.Character) end
	p.CharacterAdded:Connect(AddESP)
end


--------------------------------------------------------------------------------
-- 3. MAIN LOOP
--------------------------------------------------------------------------------
RunService.RenderStepped:Connect(function(dt)
	-- If ESP is OFF, hide everything and return
	if not espEnabled then
		for _, d in pairs(trackedModels) do d.Highlight.Enabled = false d.Billboard.Enabled = false end
		return
	end

	local myPos = Camera.CFrame.Position
	local validTargets = {}

	for model, data in pairs(trackedModels) do
		if not model.Parent or not data.Humanoid.Parent then 
			RemoveESP(model) 
			continue 
		end

		for _, c in ipairs(model:GetChildren()) do
			if c:IsA("Highlight") and c ~= data.Highlight then c:Destroy() end
		end

		local dist = (data.Root.Position - myPos).Magnitude
		if dist <= MAX_DISTANCE then
			table.insert(validTargets, {Data = data, Model = model, Dist = dist})
		else
			data.Highlight.Enabled = false
			data.Billboard.Enabled = false
		end
	end

	table.sort(validTargets, function(a, b) return a.Dist < b.Dist end)

	for i, item in ipairs(validTargets) do
		local data = item.Data
		local model = item.Model
		
		if i <= HIGHLIGHT_LIMIT then
			data.Highlight.Enabled = true
			data.Billboard.Enabled = true
			
			local itemsList = GetPlayerItems(data.Player, model)
			local toolDisplay = itemsList ~= "" and string.format("\n<font color='rgb(255,240,100)' size='11'>[ %s ]</font>", itemsList) or ""
			local hp = math.floor(data.Humanoid.Health)
			local maxHp = math.floor(data.Humanoid.MaxHealth)

			local MAX_STAMINA, RUN_THRESHOLD = GetStaminaParameters(maxHp)

			-- ==========================================================
			-- SPEED CALCULATION SWITCH
			-- ==========================================================
			local calculatedSpeed = 0
			
			if currentMethod == "Position" then
				-- METHOD 1: POSITION DELTA
				local currentPos = data.Root.Position
				local horizontalPos = Vector3.new(currentPos.X, 0, currentPos.Z)
				local lastHorizontalPos = Vector3.new(data.LastPosition.X, 0, data.LastPosition.Z)
				
				local distanceMoved = (horizontalPos - lastHorizontalPos).Magnitude
				local instantSpeed = distanceMoved / dt 
				
				-- Generator Fix: If Input is 0, force speed 0
				if data.Humanoid.MoveDirection.Magnitude == 0 then
					instantSpeed = 0
				end
	
				-- Smoothing
				data.AvgSpeed = (data.AvgSpeed * 0.8) + (instantSpeed * 0.2)
				data.LastPosition = currentPos
				calculatedSpeed = data.AvgSpeed

			elseif currentMethod == "WalkSpeed" then
				-- METHOD 2: DIRECT WALKSPEED PROPERTY
				-- If MoveDirection is 0, they aren't moving, so effective speed is 0
				if data.Humanoid.MoveDirection.Magnitude > 0 then
					calculatedSpeed = data.Humanoid.WalkSpeed
				else
					calculatedSpeed = 0
				end
			end

			-- ==========================================================
			-- STAMINA LOGIC
			-- ==========================================================
			if staminaEnabled then
				-- STRICT CHECK: Must be GREATER than threshold
				if calculatedSpeed > RUN_THRESHOLD then
					-- Running
					data.Stamina = data.Stamina - (STAMINA_DRAIN_RATE * dt)
					if data.Stamina <= 0 then
						data.Stamina = 0
						data.IsExhausted = true
						data.RegenTimer = DELAY_EXHAUSTED
					else
						data.RegenTimer = DELAY_NORMAL
					end
				else
					-- Resting
					if data.RegenTimer > 0 then
						data.RegenTimer = data.RegenTimer - dt
					else
						data.Stamina = data.Stamina + (STAMINA_REGEN_RATE * dt)
						data.IsExhausted = false
					end
				end
				data.Stamina = math.clamp(data.Stamina, 0, MAX_STAMINA)
			else
				-- If Stamina is toggled OFF, just keep it max
				data.Stamina = MAX_STAMINA 
			end

			-- ==========================================================
			-- DISPLAY LOGIC
			-- ==========================================================
			local staminaString = ""
			
			if staminaEnabled then
				local r, g, b
				if data.IsExhausted then
					r, g, b = 255, 50, 50
				else
					r, g, b = 0, 200, 255
				end
				staminaString = string.format(" <font color='rgb(%d,%d,%d)'>%d/%d</font>", r, g, b, math.floor(data.Stamina), MAX_STAMINA)
			end
			
			data.Text.Text = string.format("%s\n<font color='rgb(200,255,200)'>%d/%d</font>%s%s", data.Name, hp, maxHp, staminaString, toolDisplay)

			if hp > HP_THRESHOLD then
				data.Highlight.FillColor = REAL_HIGH_HP_FILL
				data.Highlight.OutlineColor = Color3.fromRGB(130, 0, 0)
				data.Text.TextColor3 = Color3.fromRGB(255, 100, 100)
			else
				data.Highlight.FillColor = REAL_NORMAL_FILL
				data.Highlight.OutlineColor = Color3.fromRGB(170, 255, 170)
				data.Text.TextColor3 = TEXT_COLOR
			end
		else
			data.Highlight.Enabled = false
			data.Billboard.Enabled = false
		end
	end
end)

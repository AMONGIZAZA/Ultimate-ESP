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
local MAX_DISTANCE = 2000
local HP_THRESHOLD = 200
local HIGHLIGHT_LIMIT = 30 

-- Stamina Constants
local STAMINA_DRAIN_RATE = 10
local STAMINA_REGEN_RATE = 20
local DELAY_NORMAL = 1
local DELAY_EXHAUSTED = 2

-- Speed Thresholds (The speed required to start draining stamina)
local DEFAULT_SPEED_LOW_HP = 13
local DEFAULT_SPEED_HIGH_HP = 12.000001 -- Fallback for high HP if not in specific list

-- Specific HP Lookups (MaxHealth -> Drain Speed)
local HP_SPEED_MAP = {
	[2500] = 10,
	[1700] = 8,
	[1500] = 10,
	[1250] = 10,
	[1100] = 9,
	[1111] = 8,
	[800]  = 8.25
}

-- Colors
local REAL_NORMAL_FILL = Color3.fromRGB(0, 255, 0)
local REAL_HIGH_HP_FILL = Color3.fromRGB(255, 0, 0)
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)

-- State
local espEnabled = false
local trackedModels = {}
local uiOpen = true

--------------------------------------------------------------------------------
-- 1. UI SYSTEM (ANIMATED)
--------------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ForsakenESP_v2"
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Helper: Tween Wrapper
local function tween(obj, props, time, style, dir)
	TweenService:Create(obj, TweenInfo.new(time or 0.3, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props):Play()
end

-- Main Panel
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainPanel"
MainFrame.Size = UDim2.new(0, 220, 0, 130)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5) -- Center pivot for bounce scaling
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

-- Draggable Logic
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
Desc.Text = "v2"
Desc.Size = UDim2.new(0, 30, 0, 20)
Desc.Position = UDim2.new(0, 130, 0, 12)
Desc.BackgroundTransparency = 1
Desc.TextColor3 = Color3.fromRGB(150, 150, 150)
Desc.Font = Enum.Font.GothamBold
Desc.TextSize = 12
Desc.Parent = MainFrame

-- Minimize Button
local MinButton = Instance.new("TextButton")
MinButton.Text = "-"
MinButton.Size = UDim2.new(0, 30, 0, 30)
MinButton.Position = UDim2.new(1, -35, 0, 2)
MinButton.BackgroundTransparency = 1
MinButton.TextColor3 = Color3.fromRGB(200, 200, 200)
MinButton.Font = Enum.Font.GothamBold
MinButton.TextSize = 24
MinButton.Parent = MainFrame

-- Toggle Button
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0.9, 0, 0, 45)
ToggleBtn.Position = UDim2.new(0.5, 0, 0.45, 0)
ToggleBtn.AnchorPoint = Vector2.new(0.5, 0.5)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
ToggleBtn.Text = "STATUS: OFF"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 18
ToggleBtn.Parent = MainFrame

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 6)
BtnCorner.Parent = ToggleBtn

-- Credits
local Creds = Instance.new("TextLabel")
Creds.Text = "Forsaken Stamina tracker update [BETA]"
Creds.Size = UDim2.new(1, 0, 0, 20)
Creds.Position = UDim2.new(0, 0, 0.85, 0)
Creds.BackgroundTransparency = 1
Creds.TextColor3 = Color3.fromRGB(100, 100, 100)
Creds.TextSize = 11
Creds.Font = Enum.Font.Gotham
Creds.Parent = MainFrame

-- Floating Icon
local IconFrame = Instance.new("ImageButton")
IconFrame.Name = "FloatingIcon"
IconFrame.Size = UDim2.new(0, 0, 0, 0) -- Start hidden/small
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

-- Stroke Animation
local strokeTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
TweenService:Create(IconStroke, strokeTweenInfo, {Color = Color3.fromRGB(0, 0, 0)}):Play()

-- ================= ANIMATIONS & INTERACTION =================

-- Hover Effects
local function applyHover(btn)
	local originalColor = btn.BackgroundColor3
	btn.MouseEnter:Connect(function()
		tween(btn, {BackgroundColor3 = originalColor:Lerp(Color3.new(1,1,1), 0.2)}, 0.2)
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, {BackgroundColor3 = originalColor}, 0.2)
	end)
	btn.MouseButton1Down:Connect(function()
		tween(btn, {Size = UDim2.new(0.85, 0, 0, 40)}, 0.1) -- Shrink
	end)
	btn.MouseButton1Up:Connect(function()
		tween(btn, {Size = UDim2.new(0.9, 0, 0, 45)}, 0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out) -- Bounce back
	end)
end
applyHover(ToggleBtn)

-- Toggle Menu Logic
local function OpenMenu()
	IconFrame.Visible = true
	tween(IconFrame, {Size = UDim2.new(0,0,0,0)}, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.wait(0.2)
	IconFrame.Visible = false
	
	MainFrame.Visible = true
	MainFrame.Size = UDim2.new(0, 0, 0, 0) -- Reset scale
	tween(MainFrame, {Size = UDim2.new(0, 220, 0, 130)}, 0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
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

-- ESP Toggle
ToggleBtn.MouseButton1Click:Connect(function()
	espEnabled = not espEnabled
	if espEnabled then
		ToggleBtn.Text = "STATUS: ON"
		ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
	else
		ToggleBtn.Text = "STATUS: OFF"
		ToggleBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	end
	applyHover(ToggleBtn) -- Re-apply hover to update base color reference
end)

--------------------------------------------------------------------------------
-- 2. CORE LOGIC
--------------------------------------------------------------------------------

local function GetPlayerItems(player, model)
	local items = {}
	if not player then return "" end
	if model then
		for _, obj in ipairs(model:GetChildren()) do
			if obj:IsA("Tool") then table.insert(items, obj.Name) end
		end
	end
	if player:FindFirstChild("Backpack") then
		for _, obj in ipairs(player.Backpack:GetChildren()) do
			if obj:IsA("Tool") then table.insert(items, obj.Name) end
		end
	end
	if #items == 0 then return "" end
	return table.concat(items, ", ")
end

local function IsNameDuplicate(player)
	for _, data in pairs(trackedModels) do
		if data.Player and data.Player ~= player and data.Player.DisplayName == player.DisplayName then
			return true
		end
	end
	return false
end

local function GetStaminaParameters(maxHealth)
	-- Determine Max Stamina
	local maxStamina = 100
	if maxHealth >= 200 then
		maxStamina = 110
	end

	-- Determine Speed Threshold
	local speedThreshold = DEFAULT_SPEED_LOW_HP
	
	if maxHealth >= 200 then
		-- Check specific map
		if HP_SPEED_MAP[maxHealth] then
			speedThreshold = HP_SPEED_MAP[maxHealth]
		else
			-- Fallback for other high HP entities (if any)
			speedThreshold = DEFAULT_SPEED_HIGH_HP
		end
	end

	return maxStamina, speedThreshold
end

local function AddESP(character, player)
	task.spawn(function()
		if not character or not player then return end
		if trackedModels[character] or character == LocalPlayer.Character then return end
		
		if IsNameDuplicate(player) then return end

		local humanoid = character:WaitForChild("Humanoid", 15)
		local head = character:WaitForChild("Head", 15)
		local root = character:WaitForChild("HumanoidRootPart", 15)
		
		if not humanoid or not head or not root then return end
		if trackedModels[character] then return end

		for _, c in ipairs(character:GetChildren()) do if c:IsA("Highlight") then c:Destroy() end end

		local highlight = Instance.new("Highlight")
		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 0
		highlight.Enabled = false
		highlight.Parent = character

		local bbg = Instance.new("BillboardGui")
		bbg.Adornee = head
		bbg.Size = UDim2.new(0, 250, 0, 100)
		bbg.StudsOffset = Vector3.new(0, 3.5, 0)
		bbg.AlwaysOnTop = true
		bbg.Enabled = false
		bbg.Parent = character

		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.new(1, 0, 1, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.TextSize = 13
		textLabel.Font = Enum.Font.GothamBold
		textLabel.TextColor3 = TEXT_COLOR
		textLabel.RichText = true
		textLabel.TextStrokeTransparency = 0
		textLabel.Parent = bbg

		trackedModels[character] = {
			Model = character,
			Player = player, 
			Highlight = highlight,
			Billboard = bbg,
			Text = textLabel,
			Humanoid = humanoid,
			Root = root,
			LastPosition = root.Position, 
			-- Stamina Data (Initialized to 100, updated in loop based on MaxHP)
			Stamina = 100,
			RegenTimer = 0,
			IsExhausted = false
		}
		
		humanoid.Died:Connect(function()
			task.wait(3)
			if trackedModels[character] then trackedModels[character] = nil end
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

local function SetupPlayer(player)
	if player.Character then AddESP(player.Character, player) end
	player.CharacterAdded:Connect(function(char) AddESP(char, player) end)
end

for _, p in ipairs(Players:GetPlayers()) do SetupPlayer(p) end
Players.PlayerAdded:Connect(SetupPlayer)

--------------------------------------------------------------------------------
-- 3. MAIN LOOP (POSITION DELTA & LOGIC)
--------------------------------------------------------------------------------
RunService.RenderStepped:Connect(function(dt)
	if not espEnabled then
		for _, d in pairs(trackedModels) do d.Highlight.Enabled = false d.Billboard.Enabled = false end
		return
	end

	local myPos = Camera.CFrame.Position
	local validTargets = {}

	for model, data in pairs(trackedModels) do
		if not model.Parent or not data.Humanoid.Parent or not data.Player.Parent then 
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

			-- ==========================================================
			-- GET DYNAMIC PARAMETERS
			-- ==========================================================
			local MAX_STAMINA, RUN_THRESHOLD = GetStaminaParameters(maxHp)

			-- ==========================================================
			-- TRUE SPEED CALCULATION
			-- ==========================================================
			local currentPos = data.Root.Position
			local horizontalPos = Vector3.new(currentPos.X, 0, currentPos.Z)
			local lastHorizontalPos = Vector3.new(data.LastPosition.X, 0, data.LastPosition.Z)
			local distanceMoved = (horizontalPos - lastHorizontalPos).Magnitude
			local trueSpeed = distanceMoved / dt 
			
			data.LastPosition = currentPos

			-- Stamina Logic
			if trueSpeed > RUN_THRESHOLD then
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
			-- Clamp stamina to dynamic max
			data.Stamina = math.clamp(data.Stamina, 0, MAX_STAMINA)

			-- Display Logic
			local staminaString = ""
			local r, g, b
			if data.IsExhausted then
				r, g, b = 255, 50, 50
			else
				r, g, b = 0, 200, 255
			end
			
			-- Show Current/Max Stamina based on entity type
			staminaString = string.format(" <font color='rgb(%d,%d,%d)'>%d/%d</font>", r, g, b, math.floor(data.Stamina), MAX_STAMINA)
			
			data.Text.Text = string.format("%s\n<font color='rgb(200,255,200)'>%d/%d</font>%s%s", data.Player.DisplayName, hp, maxHp, staminaString, toolDisplay)

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

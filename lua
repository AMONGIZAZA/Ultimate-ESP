-- LocalScript: Ultimate ESP + Killstreak + Cutscenes (Optimized v14)
-- Execute in Command Bar or Executor

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera
local defaultFOV = camera.FieldOfView

-------------------------------------------------------------------------
-- CONFIGURATION & ASSETS
-------------------------------------------------------------------------

-- Performance Settings
local MAX_RENDER_DISTANCE = 1500 -- Won't update ESP bars beyond this distance
local BASE_CHECK_INTERVAL = 1 -- Only check base health once per second, not every frame

-- Admin/Dev IDs
local adminIDs = {
    [953755554] = true, [164319242] = true, [3869419288] = true,
    [3432620479] = true, [3205175627] = true, [1268816379] = true,
    [2432812472] = true, [354943218] = true, [584213169] = true,
    [59567837] = true, [1384434668] = true, [1092756069] = true,
    [1306931272] = true, [97418702] = true, [34435267] = true,
    [142732332] = true, [476855757] = true, [191817078] = true,
    [130064766] = true, [860337027] = true
}

-- Audio IDs
local SOUNDS = {
    CutsceneText  = "rbxassetid://2048662066",
    RareDeath     = "rbxassetid://129710406245892",
    AdminAlarm    = "rbxassetid://243702801",
    BossSpawn     = {"rbxassetid://8910610321", "rbxassetid://5773338685", "rbxassetid://101569203360944"},
    BossDeath     = {
        {id = "rbxassetid://98741471903049", vol = 1, speed = 1},
        {id = "rbxassetid://8227660256", vol = 1, speed = 1.65},
        {id = "rbxassetid://75730845492004", vol = 2, speed = 1},
        {id = "rbxassetid://133014492553616", vol = 3, speed = 1}
    },
    NormalKill    = {
        "rbxassetid://97113622160405", "rbxassetid://125986071668075", "rbxassetid://103600892072827",
        "rbxassetid://103999634941081", "rbxassetid://80301239006039", "rbxassetid://79299693318576"
    },
    BaseBlue      = {"rbxassetid://131169447699141", "rbxassetid://137811389321922"},
    BaseRed       = "rbxassetid://8304443672"
}

-- Boss Intro Sounds
local BOSS_INTRO_SOUNDS = {
    ["Doombringer"] = "rbxassetid://131057316",
    ["Deathbringer"] = "rbxassetid://82507792119454",
    ["Turking"] = "rbxassetid://97538785569799",
    ["EXEC"] = "rbxassetid://75810075829808",
    ["Infernus"] = "rbxassetid://14384858049",
    ["X-TREME"] = "rbxassetid://16806957815",
    ["DEFAULT"] = "rbxassetid://131057316"
}

-- Image IDs
local IMAGES = {
    Rare = "8508980536",
    Icon = "60411471", 
    Doombringer = "16952823463", 
    Turking = "14384855375", 
    EXEC = "16806958739",
    Deathbringer = "17824322901",
    Infernus = "17824323726", 
    ["X-TREME"] = "17824323726", 
    BlueBase = "84091694732791",
    RedBase = "72257572315634"
}

-- Blacklist (For ESP)
local ignoredNames = { 
    ["Red Base"] = true, 
    ["Blue Base"] = true,
    ["Red's Base"] = true,
    ["Blue's Base"] = true,
    ["Tarnished Wall"] = true
}

-- Bosses with Cutscenes
local cutsceneBosses = {
    ["Doombringer"] = true, ["Deathbringer"] = true, ["Turking"] = true,
    ["Infernus"] = true, ["EXEC"] = true, ["X-TREME"] = true
}

-- State
local espObjects = {}
local existingBosses = {}
local processedBases = {}
-- Optimization: Store base references so we don't search workspace every frame
local baseCache = {Blue = nil, Red = nil} 

local isEspToggled = false
local isKillstreakToggled = false
local totalKills = 0
local currentStreak = 0
local streakSpeed = 1.0
local lastKillTime = 0
local lastBaseCheckTime = 0
local activeRainbowTweens = {} 

-------------------------------------------------------------------------
-- UTILITIES
-------------------------------------------------------------------------
local function toImage(id)
    local cleanId = string.match(tostring(id), "%d+")
    return "rbxthumb://type=Asset&id=" .. cleanId .. "&w=420&h=420"
end

local function playSound(id, vol, speed, parent, looped)
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = vol or 1
    s.PlaybackSpeed = speed or 1
    s.Looped = looped or false
    s.Parent = parent or workspace
    s:Play()
    if not looped then 
        Debris:AddItem(s, 10) 
    end
    return s
end

local function makeDraggable(guiObject)
    local dragging, dragInput, dragStart, startPos
    local function update(input)
        local delta = input.Position - dragStart
        guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    guiObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = guiObject.Position
            input.Changed:Connect(function() 
                if input.UserInputState == Enum.UserInputState.End then dragging = false end 
            end)
        end
    end)
    guiObject.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then 
            dragInput = input 
        end
    end)
    UserInputService.InputChanged:Connect(function(input) 
        if input == dragInput and dragging then update(input) end 
    end)
end

local function tweenFade(container, goalTransparency)
    local info = TweenInfo.new(0.5)
    if container:IsA("Frame") or container:IsA("ImageLabel") then
        local bgGoal = (goalTransparency == 1) and 1 or (container.Name == "KillstreakHUD" and 0.65 or 0)
        if container.Name == "BossBarContainer" then bgGoal = 1 end
        TweenService:Create(container, info, {BackgroundTransparency = bgGoal}):Play()
    elseif container:IsA("CanvasGroup") then
        TweenService:Create(container, info, {GroupTransparency = goalTransparency}):Play()
        return
    end
    for _, child in pairs(container:GetDescendants()) do
        if child:IsA("TextLabel") or child:IsA("TextButton") then
            TweenService:Create(child, info, {TextTransparency = goalTransparency}):Play()
            if child:FindFirstChild("UIStroke") then 
                TweenService:Create(child.UIStroke, info, {Transparency = goalTransparency}):Play() 
            end
        elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
            TweenService:Create(child, info, {ImageTransparency = goalTransparency}):Play()
        elseif child:IsA("Frame") and child.Name ~= "FlashOverlay" then
             if goalTransparency == 1 then 
                TweenService:Create(child, info, {BackgroundTransparency = 1}):Play()
             else 
                TweenService:Create(child, info, {BackgroundTransparency = 0}):Play() 
             end
        end
    end
end

-------------------------------------------------------------------------
-- UI SETUP
-------------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UltimateSystem_v14_Opt"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- 1. CUTSCENE UI
local cutsceneFrame = Instance.new("Frame")
cutsceneFrame.Name = "CutsceneOverlay"
cutsceneFrame.Size = UDim2.new(1,0,1,0)
cutsceneFrame.BackgroundTransparency = 1
cutsceneFrame.Visible = false
cutsceneFrame.ZIndex = 200
cutsceneFrame.Parent = screenGui

local textContainer = Instance.new("Frame")
textContainer.Size = UDim2.new(1,0,0.2,0)
textContainer.Position = UDim2.new(0,0,0.2,0)
textContainer.BackgroundTransparency = 1
textContainer.Parent = cutsceneFrame

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Horizontal
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
listLayout.Padding = UDim.new(0,20)
listLayout.Parent = textContainer

local cutsceneImage = Instance.new("ImageLabel")
cutsceneImage.Name = "CutsceneDecal"
cutsceneImage.Size = UDim2.new(0.4,0,0.6,0)
cutsceneImage.Position = UDim2.new(1.2,0,0.4,0)
cutsceneImage.BackgroundTransparency = 1
cutsceneImage.Visible = false
cutsceneImage.Parent = cutsceneFrame

-- 2. MAIN PANEL
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0,160,0,100)
mainFrame.Position = UDim2.new(0,100,0,100)
mainFrame.BackgroundColor3 = Color3.fromRGB(30,30,30)
mainFrame.Active = true
mainFrame.Parent = screenGui
Instance.new("UICorner",mainFrame).CornerRadius = UDim.new(0,8)
makeDraggable(mainFrame)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1,0,0,25)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "CONTROL PANEL"
titleLabel.TextColor3 = Color3.new(1,1,1)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Parent = mainFrame

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0,25,0,25)
minBtn.Position = UDim2.new(1,-25,0,0)
minBtn.BackgroundTransparency = 1
minBtn.Text = "-"
minBtn.TextColor3 = Color3.fromRGB(255,200,200)
minBtn.Font = Enum.Font.GothamBlack
minBtn.TextSize = 20
minBtn.Parent = mainFrame

local espBtn = Instance.new("TextButton")
espBtn.Size = UDim2.new(0.9,0,0.3,0)
espBtn.Position = UDim2.new(0.05,0,0.3,0)
espBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
espBtn.Text = "ESP: OFF"
espBtn.TextColor3 = Color3.new(1,1,1)
espBtn.Font = Enum.Font.Gotham
espBtn.Parent = mainFrame
Instance.new("UICorner",espBtn).CornerRadius = UDim.new(0,6)

local ksBtn = Instance.new("TextButton")
ksBtn.Size = UDim2.new(0.9,0,0.3,0)
ksBtn.Position = UDim2.new(0.05,0,0.65,0)
ksBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
ksBtn.Text = "Killstreak UI: OFF"
ksBtn.TextColor3 = Color3.new(1,1,1)
ksBtn.Font = Enum.Font.Gotham
ksBtn.Parent = mainFrame
Instance.new("UICorner",ksBtn).CornerRadius = UDim.new(0,6)

-- 3. RESTORE ICON
local openBtn = Instance.new("ImageButton")
openBtn.Size = UDim2.new(0,50,0,50)
openBtn.Position = UDim2.new(0.5,-25,0,10)
openBtn.BackgroundColor3 = Color3.fromRGB(255,255,255)
openBtn.BackgroundTransparency = 1
openBtn.Image = toImage(IMAGES.Icon)
openBtn.ImageTransparency = 0
openBtn.Visible = false
openBtn.Active = true
openBtn.ZIndex = 50
openBtn.Parent = screenGui
makeDraggable(openBtn)
Instance.new("UICorner",openBtn).CornerRadius = UDim.new(1,0)
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(50,255,50)
stroke.Thickness = 3
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = openBtn

-- 4. KILLSTREAK HUD
local ksFrame = Instance.new("Frame")
ksFrame.Name = "KillstreakHUD"
ksFrame.Size = UDim2.new(0,250,0,140)
ksFrame.Position = UDim2.new(0,20,0.5,-70)
ksFrame.BackgroundColor3 = Color3.fromRGB(20,20,20)
ksFrame.BackgroundTransparency = 0.65
ksFrame.Visible = false
ksFrame.Active = true
ksFrame.Parent = screenGui
Instance.new("UICorner",ksFrame).CornerRadius = UDim.new(0,10)
makeDraggable(ksFrame)

local lblTotal = Instance.new("TextLabel")
lblTotal.Size = UDim2.new(1,-20,0,25)
lblTotal.Position = UDim2.new(0,10,0,10)
lblTotal.BackgroundTransparency = 1
lblTotal.TextColor3 = Color3.fromRGB(200,200,200)
lblTotal.Font = Enum.Font.Gotham
lblTotal.TextXAlignment = Enum.TextXAlignment.Left
lblTotal.Text = "Total Kills: 0"
lblTotal.Parent = ksFrame

local lblStreakTitle = Instance.new("TextLabel")
lblStreakTitle.Size = UDim2.new(1,0,0,20)
lblStreakTitle.Position = UDim2.new(0,0,0.3,0)
lblStreakTitle.BackgroundTransparency = 1
lblStreakTitle.TextColor3 = Color3.new(1,1,1)
lblStreakTitle.Font = Enum.Font.GothamBlack
lblStreakTitle.Text = "KILLSTREAK"
lblStreakTitle.Parent = ksFrame

local lblStreakNum = Instance.new("TextLabel")
lblStreakNum.Size = UDim2.new(1,0,0,50)
lblStreakNum.Position = UDim2.new(0,0,0.45,0)
lblStreakNum.BackgroundTransparency = 1
lblStreakNum.TextColor3 = Color3.fromRGB(255,50,50)
lblStreakNum.Font = Enum.Font.GothamBlack
lblStreakNum.TextSize = 45
lblStreakNum.Text = "0"
lblStreakNum.Parent = ksFrame

local lblHighHP = Instance.new("TextLabel")
lblHighHP.Size = UDim2.new(1,-20,0,25)
lblHighHP.Position = UDim2.new(0,10,0.85,-10)
lblHighHP.BackgroundTransparency = 1
lblHighHP.TextColor3 = Color3.fromRGB(150,150,255)
lblHighHP.Font = Enum.Font.GothamBold
lblHighHP.TextScaled = true
lblHighHP.Text = "Highest HP: None"
lblHighHP.Parent = ksFrame

-- 5. BOSS BAR
local bossContainer = Instance.new("Frame")
bossContainer.Name = "BossBarContainer"
bossContainer.Size = UDim2.new(0.4,0,0,80)
bossContainer.Position = UDim2.new(0.3,0,0,20)
bossContainer.BackgroundTransparency = 1
bossContainer.Visible = false
bossContainer.Parent = screenGui

local bossName = Instance.new("TextLabel")
bossName.Size = UDim2.new(1,0,0.3,0)
bossName.Position = UDim2.new(0,0,0.1,0)
bossName.BackgroundTransparency = 1
bossName.TextColor3 = Color3.new(1,1,1)
bossName.Font = Enum.Font.GothamBlack
bossName.TextStrokeTransparency = 0
bossName.TextSize = 20
bossName.Text = "BOSS"
bossName.Parent = bossContainer

local bossBg = Instance.new("Frame")
bossBg.Size = UDim2.new(1,0,0.4,0)
bossBg.Position = UDim2.new(0,0,0.5,0)
bossBg.BackgroundColor3 = Color3.fromRGB(20,20,20)
bossBg.Parent = bossContainer
Instance.new("UICorner",bossBg).CornerRadius = UDim.new(0,6)

local bossFill = Instance.new("Frame")
bossFill.Size = UDim2.new(1,0,1,0)
bossFill.BorderSizePixel = 0
bossFill.Parent = bossBg
Instance.new("UICorner",bossFill).CornerRadius = UDim.new(0,6)

local bossHealthText = Instance.new("TextLabel")
bossHealthText.Size = UDim2.new(1,0,1,0)
bossHealthText.BackgroundTransparency = 1
bossHealthText.TextColor3 = Color3.new(1,1,1)
bossHealthText.Font = Enum.Font.GothamBold
bossHealthText.TextStrokeTransparency = 0.5
bossHealthText.Parent = bossBg

-- 6. RARE DEATH IMAGE
local rareImage = Instance.new("ImageLabel")
rareImage.Size = UDim2.new(1,0,1,0)
rareImage.BackgroundTransparency = 1
rareImage.Image = toImage(IMAGES.Rare)
rareImage.ImageTransparency = 0
rareImage.Visible = false
rareImage.ZIndex = 200
rareImage.Parent = screenGui

-------------------------------------------------------------------------
-- CUTSCENE LOGIC
-------------------------------------------------------------------------
local function createWord(text, color, scale)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color
    l.Font = Enum.Font.GothamBlack
    l.TextScaled = true
    l.Size = UDim2.new(0, 0, 1, 0)
    l.AutomaticSize = Enum.AutomaticSize.X
    l.TextTransparency = 1
    l.Parent = textContainer
    
    if scale then 
        l.Size = UDim2.new(0, 0, 1.5, 0) 
    end
    
    TweenService:Create(l, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
    return l
end

local function animateBounce(label)
    TweenService:Create(label, TweenInfo.new(0.1), {Rotation = 10}):Play()
    task.delay(0.1, function() 
        TweenService:Create(label, TweenInfo.new(0.1), {Rotation = 0}):Play() 
    end)
end

local function animateShake(label)
    task.spawn(function()
        for i = 1, 20 do 
            if not label.Parent then break end
            label.Rotation = math.random(-5, 5)
            task.wait(0.05) 
        end
        if label.Parent then label.Rotation = 0 end
    end)
end

local function animateColorShift(label)
    local running = true
    table.insert(activeRainbowTweens, function() running = false end)
    
    task.spawn(function()
        local colors = {Color3.fromRGB(255,0,0), Color3.fromRGB(255,165,0), Color3.fromRGB(0,0,0)}
        local i = 1
        while running and label.Parent do
            local nextColor = colors[(i % #colors) + 1]
            TweenService:Create(label, TweenInfo.new(0.5), {TextColor3 = nextColor}):Play()
            task.wait(0.5)
            i = i + 1
        end
    end)
end

local function cleanupCutscene()
    for _, stopFunc in pairs(activeRainbowTweens) do stopFunc() end
    activeRainbowTweens = {}
    local slide = TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.In)
    TweenService:Create(textContainer, slide, {Position = UDim2.new(-1, 0, 0.2, 0)}):Play()
    TweenService:Create(cutsceneImage, slide, {Position = UDim2.new(-1, 0, 0.4, 0)}):Play()
    task.wait(1)
    cutsceneFrame.Visible = false
    textContainer.Position = UDim2.new(0, 0, 0.2, 0)
    for _, c in pairs(textContainer:GetChildren()) do 
        if c:IsA("TextLabel") then c:Destroy() end 
    end
end

local function playCutscene(bossNameVal)
    cutsceneFrame.Visible = true
    cutsceneImage.Visible = false
    for _, c in pairs(textContainer:GetChildren()) do 
        if c:IsA("TextLabel") then c:Destroy() end 
    end

    local introId = BOSS_INTRO_SOUNDS[bossNameVal] or BOSS_INTRO_SOUNDS["DEFAULT"]
    local vol = 2
    if bossNameVal == "Infernus" then vol = 4 end
    local speed = 1
    if bossNameVal == "Deathbringer" then speed = 0.85 end
    playSound(introId, vol, speed)

    if bossNameVal == "X-TREME" then
        local imgId = IMAGES["X-TREME"] or IMAGES.Icon
        cutsceneImage.Image = toImage(imgId)
        cutsceneImage.Visible = true
        cutsceneImage.Position = UDim2.new(1.2, 0, 0.4, 0)
        TweenService:Create(cutsceneImage, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0.3, 0, 0.4, 0)}):Play()
        task.wait(2)
        local w1 = createWord("OFFENSE", Color3.fromRGB(255, 255, 0))
        local s1 = Instance.new("UIStroke"); s1.Thickness = 3; s1.Color = Color3.new(0,0,0); s1.Parent = w1
        playSound(SOUNDS.CutsceneText, 1, 1)
        task.wait(1.5)
        local w2 = createWord("MODE", Color3.fromRGB(180, 180, 0))
        local s2 = Instance.new("UIStroke"); s2.Thickness = 3; s2.Color = Color3.new(0,0,0); s2.Parent = w2
        playSound(SOUNDS.CutsceneText, 1, 1); animateBounce(w2)
        task.wait(1.5)
        local w3 = createWord("ON.", Color3.new(0,0,0))
        local s3 = Instance.new("UIStroke"); s3.Thickness = 3; s3.Color = Color3.fromRGB(255, 255, 0); s3.Parent = w3
        playSound(SOUNDS.CutsceneText, 1, 1); animateBounce(w3)
        task.wait(2)
        cleanupCutscene()

    elseif bossNameVal == "Infernus" then
        cutsceneImage.Image = toImage(IMAGES.Infernus)
        cutsceneImage.Visible = true
        cutsceneImage.Position = UDim2.new(1.2, 0, 0.4, 0)
        TweenService:Create(cutsceneImage, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0.3, 0, 0.4, 0)}):Play()
        task.wait(2)
        local w1 = createWord("NO", Color3.fromRGB(255, 0, 0)); animateColorShift(w1); playSound(SOUNDS.CutsceneText, 1, 1)
        task.wait(1.5)
        local w2 = createWord("MORE", Color3.fromRGB(128, 0, 0)); animateColorShift(w2); playSound(SOUNDS.CutsceneText, 1, 1)
        task.wait(1.5)
        local w3 = createWord("GAMES.", Color3.fromRGB(100, 50, 50)); animateColorShift(w3); playSound(SOUNDS.CutsceneText, 1, 1)
        task.wait(2); cleanupCutscene()

    elseif bossNameVal == "Doombringer" then
        cutsceneImage.Image = toImage(IMAGES.Doombringer); cutsceneImage.Visible=true; cutsceneImage.Position=UDim2.new(1.2,0,0.4,0)
        TweenService:Create(cutsceneImage, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position=UDim2.new(0.3,0,0.4,0)}):Play()
        task.wait(2); createWord("Doom", Color3.fromRGB(150,100,100)); playSound(SOUNDS.CutsceneText,1,1)
        task.wait(1.5); local w2 = createWord("and", Color3.fromRGB(255,0,0)); playSound(SOUNDS.CutsceneText,1,1); animateBounce(w2)
        task.wait(1.5); local w3 = createWord("DESPAIR.", Color3.fromRGB(200,0,0)); playSound(SOUNDS.CutsceneText,1,1); animateBounce(w3)
        TweenService:Create(cutsceneImage, TweenInfo.new(0.3), {Position=UDim2.new(0.25,0,0.4,0)}):Play(); task.wait(0.3)
        TweenService:Create(cutsceneImage, TweenInfo.new(0.3), {Position=UDim2.new(0.3,0,0.4,0)}):Play(); task.wait(2); cleanupCutscene()

    elseif bossNameVal == "Turking" then
        cutsceneImage.Image = toImage(IMAGES.Turking); cutsceneImage.Visible=true; cutsceneImage.Position=UDim2.new(1.2,0,0.4,0)
        TweenService:Create(cutsceneImage, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position=UDim2.new(0.3,0,0.4,0)}):Play()
        task.wait(2); createWord("It's...", Color3.fromRGB(255,0,0)); playSound(SOUNDS.CutsceneText,1,1)
        task.wait(1.5); local w2 = createWord("TURKING", Color3.fromRGB(139,69,19)); playSound(SOUNDS.CutsceneText,1,1); animateBounce(w2)
        task.wait(1.5); local w3 = createWord("TIME!", Color3.fromRGB(128,0,0)); playSound(SOUNDS.CutsceneText,1,1); animateBounce(w3)
        task.wait(2); cleanupCutscene()

    elseif bossNameVal == "EXEC" then
        cutsceneImage.Image = toImage(IMAGES.EXEC); cutsceneImage.Visible=true; cutsceneImage.Position=UDim2.new(1.2,0,0.4,0)
        TweenService:Create(cutsceneImage, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position=UDim2.new(0.3,0,0.4,0)}):Play()
        task.wait(2); createWord("Time", Color3.fromRGB(255,255,0)); playSound(SOUNDS.CutsceneText,1,1)
        task.wait(1.5); local w2 = createWord("to", Color3.fromRGB(255,165,0)); playSound(SOUNDS.CutsceneText,1,1); animateBounce(w2)
        task.wait(1.5); local w3 = createWord("HACK!", Color3.fromRGB(0,255,0)); playSound(SOUNDS.CutsceneText,1,1); animateBounce(w3)
        task.wait(2); cleanupCutscene()

    elseif bossNameVal == "Deathbringer" then
        cutsceneImage.Image = toImage(IMAGES.Deathbringer); cutsceneImage.Visible=true; cutsceneImage.Position=UDim2.new(1.2,0,0.4,0)
        TweenService:Create(cutsceneImage, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position=UDim2.new(0.3,0,0.4,0)}):Play()
        task.wait(2); createWord("YOU..", Color3.fromRGB(128,0,0)); playSound(SOUNDS.CutsceneText,1,1)
        task.wait(1.5); createWord("WILL..", Color3.fromRGB(60,0,0)); playSound(SOUNDS.CutsceneText,1,1)
        task.wait(1.5); local w3 = createWord("BURN!", Color3.fromRGB(255,69,0), true); playSound(SOUNDS.CutsceneText,1,1); animateShake(w3)
        task.wait(2); cleanupCutscene()

    else
        createWord(bossNameVal, Color3.new(1,1,1))
        createWord("HAS SPAWNED", Color3.new(1,0,0))
        playSound(SOUNDS.CutsceneText, 1, 1)
        task.wait(3); cleanupCutscene()
    end
end

-------------------------------------------------------------------------
-- OPTIMIZED BASE EVENT LOGIC
-------------------------------------------------------------------------
-- New: Find bases once, only retry if they are nil.
local function locateBases()
    if baseCache.Blue and baseCache.Red then return end
    
    -- Heavy scan only if we haven't found them yet
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "Blue's Base" then baseCache.Blue = obj end
        if obj.Name == "Red's Base" then baseCache.Red = obj end
    end
end

local function triggerBaseEvent(baseName)
    if processedBases[baseName] then return end
    processedBases[baseName] = true
    
    rareImage.Visible = true
    rareImage.ImageTransparency = 0
    rareImage.ZIndex = 200
    
    if baseName == "Blue's Base" then
        rareImage.Image = toImage(IMAGES.BlueBase)
        local snd = SOUNDS.BaseBlue[math.random(1, #SOUNDS.BaseBlue)]
        playSound(snd, 3, 1)
        task.wait(5)
    elseif baseName == "Red's Base" then
        rareImage.Image = toImage(IMAGES.RedBase)
        playSound(SOUNDS.BaseRed, 3, 1)
        task.wait(4)
    end
    
    local t = TweenService:Create(rareImage, TweenInfo.new(2), {ImageTransparency = 1})
    t:Play()
    t.Completed:Connect(function() rareImage.Visible = false end)
end

local function scanBases()
    if not isKillstreakToggled then return end
    
    -- Throttle checking (only check health once per second)
    if tick() - lastBaseCheckTime < BASE_CHECK_INTERVAL then return end
    lastBaseCheckTime = tick()

    -- Ensure we have references
    locateBases()

    local function checkBase(baseObj)
        if baseObj and baseObj:FindFirstChild("Humanoid") then
            local hum = baseObj.Humanoid
            if hum.Health <= 1 and hum.Health >= 0 and not processedBases[baseObj.Name] then
                task.spawn(function() triggerBaseEvent(baseObj.Name) end)
            elseif hum.Health > 1 then
                processedBases[baseObj.Name] = false
            end
        end
    end

    checkBase(baseCache.Blue)
    checkBase(baseCache.Red)
end

-------------------------------------------------------------------------
-- KILL & ESP LOGIC
-------------------------------------------------------------------------
local function flashHealthBar(barFillFrame)
    if not barFillFrame then return end
    local ov = barFillFrame:FindFirstChild("FlashOverlay")
    if not ov then
        ov = Instance.new("Frame")
        ov.Name = "FlashOverlay"
        ov.Size = UDim2.new(1,0,1,0)
        ov.BackgroundColor3 = Color3.new(1,1,1)
        ov.Transparency = 1
        ov.BorderSizePixel = 0
        ov.Parent = barFillFrame
        Instance.new("UICorner",ov).CornerRadius = UDim.new(0,6)
    end
    TweenService:Create(ov, TweenInfo.new(0.1), {Transparency = 0}):Play()
    task.delay(0.1, function() 
        TweenService:Create(ov, TweenInfo.new(0.1), {Transparency = 1}):Play() 
    end)
end

local function getTorsoColor(char)
    local t = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")
    return t and t.Color or Color3.fromRGB(170,0,255)
end

local function handleKill(humanoid)
    totalKills = totalKills + 1
    local now = tick()
    if now - lastKillTime <= 2 then 
        currentStreak = currentStreak + 1 
    else 
        currentStreak = 1
        streakSpeed = 1.0 
    end
    
    if currentStreak > 6 then 
        streakSpeed = streakSpeed + 0.05 
    end
    
    local isBoss = humanoid.MaxHealth >= 5000
    if isKillstreakToggled then
        if isBoss then 
            local d = SOUNDS.BossDeath[math.random(1,#SOUNDS.BossDeath)]
            playSound(d.id, d.vol, d.speed)
        else 
            local id = SOUNDS.NormalKill[((currentStreak-1)%6)+1]
            playSound(id, 1.5, streakSpeed) 
        end
        TweenService:Create(camera, TweenInfo.new(0.25), {FieldOfView = math.clamp(defaultFOV*1.5,70,120)}):Play()
        task.delay(0.25, function() 
            TweenService:Create(camera, TweenInfo.new(0.25), {FieldOfView = defaultFOV}):Play() 
        end)
    end
    if isBoss and math.random() <= 0.10 then
        task.spawn(function()
            rareImage.Image = toImage(IMAGES.Rare)
            rareImage.Visible = true
            rareImage.ImageTransparency = 0
            playSound(SOUNDS.RareDeath,5,1)
            task.wait(3)
            TweenService:Create(rareImage, TweenInfo.new(2), {ImageTransparency = 1}):Play()
        end)
    end
    lastKillTime = now
end

local function createESP(humanoid)
    if espObjects[humanoid] then return end
    local char = humanoid.Parent
    if not char or ignoredNames[char.Name] or humanoid.Health<=0 or Players:GetPlayerFromCharacter(char) then return end
    if humanoid.Health ~= humanoid.Health then return end -- NaN check
    
    if humanoid.MaxHealth >= 5000 and isKillstreakToggled then 
        local id = SOUNDS.BossSpawn[math.random(1,#SOUNDS.BossSpawn)]
        playSound(id,1,1) 
    end
    
    local bb = Instance.new("BillboardGui")
    bb.Adornee = char:FindFirstChild("Head") or char:FindFirstChild("Torso")
    bb.Size = UDim2.new(0,120,0,50)
    bb.StudsOffset = Vector3.new(0,3.5,0)
    bb.AlwaysOnTop = true
    bb.Parent = screenGui
    bb.Enabled = false -- Start disabled for optimization

    local nm = Instance.new("TextLabel")
    nm.Size = UDim2.new(1,0,0.3,0)
    nm.BackgroundTransparency = 1
    nm.TextColor3 = Color3.new(1,1,1)
    nm.TextStrokeTransparency = 0.5
    nm.Font = Enum.Font.GothamBold
    nm.TextScaled = true
    nm.Text = char.Name
    nm.Parent = bb

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0.9,0,0.25,0)
    bg.Position = UDim2.new(0.05,0,0.35,0)
    bg.BackgroundColor3 = Color3.new(0,0,0)
    bg.Parent = bb
    Instance.new("UICorner",bg).CornerRadius = UDim.new(0,4)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(1,0,1,0)
    fill.BackgroundColor3 = getTorsoColor(char)
    fill.Parent = bg
    Instance.new("UICorner",fill).CornerRadius = UDim.new(0,4)

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1,0,1,0)
    txt.BackgroundTransparency = 1
    txt.TextColor3 = Color3.new(1,1,1)
    txt.Font = Enum.Font.SourceSansBold
    txt.TextSize = 12
    txt.Text = "..."
    txt.Parent = bg

    espObjects[humanoid] = {billboard = bb, hpFill = fill, hpText = txt, lastHealth = -1, isDead = false}
end

local function removeESP(humanoid) 
    if espObjects[humanoid] then 
        if espObjects[humanoid].billboard then 
            espObjects[humanoid].billboard:Destroy() 
        end
        espObjects[humanoid] = nil 
    end 
end

-- INITIAL SCAN (Run once at start)
task.spawn(function()
    for _, v in ipairs(workspace:GetDescendants()) do 
        if v:IsA("Humanoid") and v.Parent ~= player.Character then createESP(v) end 
        if v:IsA("Model") and cutsceneBosses[v.Name] and v:FindFirstChild("Humanoid") then existingBosses[v] = true end
    end 
end)

-- EFFICIENT EVENT-BASED DETECTION (Replaces the lagging loop)
workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("Humanoid") and isEspToggled and obj.Parent ~= player.Character then
        createESP(obj)
    elseif obj:IsA("Model") and cutsceneBosses[obj.Name] then
        local h = obj:WaitForChild("Humanoid", 5)
        if h and not existingBosses[obj] then 
            existingBosses[obj] = true
            task.spawn(function() playCutscene(obj.Name) end) 
        end 
    end
end)

-- Cleanup routine (runs rarely just to catch errors, instead of every second)
task.spawn(function()
    while true do
        task.wait(10) -- Only check every 10 seconds
        if isEspToggled then
            for hum, data in pairs(espObjects) do
                if not hum.Parent then removeESP(hum) end
            end
        end
    end
end)


-------------------------------------------------------------------------
-- MAIN LOOP
-------------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
    -- Killstreak Logic
    if tick() - lastKillTime > 2 then 
        currentStreak = 0
        streakSpeed = 1.0 
    end
    
    -- Optimized Base Scan
    scanBases()

    -- HUD Logic
    if isKillstreakToggled then
        ksFrame.Visible = true
        tweenFade(ksFrame, 0)
        lblTotal.Text = "Total Kills: " .. totalKills
        if currentStreak > 0 then
            lblStreakNum.Text = tostring(currentStreak)
            lblStreakTitle.Visible = true
            lblStreakNum.Visible = true
            local amp = math.min(currentStreak, 20) * 0.5
            lblStreakNum.Position = UDim2.new(0, math.sin(tick()*5)*amp, 0.45, math.cos(tick()*6)*amp)
            ksFrame.BackgroundColor3 = Color3.fromRGB(20,20,20):Lerp(Color3.fromRGB(100,0,0), math.clamp(currentStreak/20,0,1))
        else
            lblStreakNum.Text = ""
            lblStreakTitle.Visible = false
            ksFrame.BackgroundColor3 = Color3.fromRGB(20,20,20)
        end
    else
        tweenFade(ksFrame, 1)
        if ksFrame.BackgroundTransparency >= 0.95 then ksFrame.Visible = false end
    end

    if not isEspToggled then 
        bossContainer.Visible = false
        for _, obj in pairs(espObjects) do obj.billboard.Enabled = false end
        return 
    end

    local hHP = 0
    local hName = "None"
    local highestHum = nil 
    local camPos = camera.CFrame.Position

    -- ESP Loop (Optimized with Distance Check)
    for hum, obj in pairs(espObjects) do
        if not hum or not hum.Parent then 
            removeESP(hum)
            continue 
        end
        if hum.Health <= 0 then 
            if not obj.isDead then 
                obj.isDead = true
                handleKill(hum) 
            end
            removeESP(hum)
            continue 
        end

        local char = hum.Parent
        local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        
        -- DISTANCE CHECK: If enemy is too far, hide UI and skip math
        if head then
            local dist = (head.Position - camPos).Magnitude
            if dist > MAX_RENDER_DISTANCE then
                obj.billboard.Enabled = false
                continue
            else
                obj.billboard.Enabled = true
            end
        end

        local hp = math.floor(hum.Health)
        local max = math.floor(hum.MaxHealth)
        
        -- Track Boss
        if max > hHP then 
            hHP = max
            hName = char.Name
            highestHum = hum 
        end

        -- Update UI only if changed
        if obj.lastHealth ~= hp then
            obj.hpText.Text = hp .. " / " .. max
            TweenService:Create(obj.hpFill, TweenInfo.new(0.3), {Size = UDim2.new(hp/max,0,1,0)}):Play()
            if obj.lastHealth ~= -1 and hp < obj.lastHealth then 
                flashHealthBar(obj.hpFill) 
            end
            obj.lastHealth = hp
        end
    end

    if isKillstreakToggled then
        local displayCur = 0
        if highestHum then displayCur = math.floor(highestHum.Health) end
        if hName == "None" then hHP = 0; displayCur = 0 end
        lblHighHP.Text = "Highest HP: " .. hName .. " (" .. displayCur .. " / " .. hHP .. ")"
    end

    local isBoss = highestHum and (highestHum.MaxHealth >= 5000)
    if isBoss then
        bossContainer.Visible = true
        tweenFade(bossContainer, 0)
        bossName.Text = highestHum.Parent.Name
        local cur, max = math.floor(highestHum.Health), math.floor(highestHum.MaxHealth)
        bossHealthText.Text = cur .. " / " .. max
        TweenService:Create(bossFill, TweenInfo.new(0.3), {Size = UDim2.new(cur/max,0,1,0), BackgroundColor3 = getTorsoColor(highestHum.Parent)}):Play()
        local bossObj = espObjects[highestHum]
        if bossObj and bossObj.lastHealth ~= -1 and cur < bossObj.lastHealth then 
            flashHealthBar(bossFill) 
        end
    else
        tweenFade(bossContainer, 1)
        if bossBg.BackgroundTransparency >= 0.95 then bossContainer.Visible = false end
    end
end)

minBtn.MouseButton1Click:Connect(function() 
    mainFrame.Visible = false
    openBtn.Visible = true 
end)

openBtn.MouseButton1Click:Connect(function() 
    mainFrame.Visible = true
    openBtn.Visible = false 
end)

espBtn.MouseButton1Click:Connect(function() 
    isEspToggled = not isEspToggled
    espBtn.Text = isEspToggled and "ESP: ON" or "ESP: OFF"
    espBtn.BackgroundColor3 = isEspToggled and Color3.fromRGB(50,200,50) or Color3.fromRGB(200,50,50)
    if not isEspToggled then 
        for h,_ in pairs(espObjects) do removeESP(h) end
        espObjects = {} 
        -- Trigger a fresh scan when turned back on
        for _, v in ipairs(workspace:GetDescendants()) do 
            if v:IsA("Humanoid") and v.Parent ~= player.Character then createESP(v) end 
        end
    end 
end)

ksBtn.MouseButton1Click:Connect(function() 
    isKillstreakToggled = not isKillstreakToggled
    ksBtn.Text = isKillstreakToggled and "Killstreak UI: ON" or "Killstreak UI: OFF"
    ksBtn.BackgroundColor3 = isKillstreakToggled and Color3.fromRGB(50,200,50) or Color3.fromRGB(200,50,50) 
end)

local function checkAdmin(plr) 
    if adminIDs[plr.UserId] then 
        local wf = Instance.new("Frame")
        wf.Size = UDim2.new(0,400,0,300)
        wf.Position = UDim2.new(0.5,-200,0.5,-150)
        wf.BackgroundColor3 = Color3.new(0.2,0.2,0.2)
        wf.BackgroundTransparency = 0.85
        wf.Parent = screenGui
        Instance.new("UICorner",wf).CornerRadius = UDim.new(0,10)

        local wt = Instance.new("TextLabel")
        wt.Size = UDim2.new(0.9,0,0.6,0)
        wt.Position = UDim2.new(0.05,0,0.05,0)
        wt.BackgroundTransparency = 1
        wt.Text = "WARNING ADMIN DETECTED"
        wt.TextColor3 = Color3.new(1,0,0)
        wt.TextScaled = true
        wt.Font = Enum.Font.GothamBlack
        wt.Parent = wf

        local b1 = Instance.new("TextButton")
        b1.Size = UDim2.new(0.4,0,0.2,0)
        b1.Position = UDim2.new(0.05,0,0.75,0)
        b1.Text = "Ok"
        b1.BackgroundColor3 = Color3.new(0,1,0)
        b1.Parent = wf

        local b2 = Instance.new("TextButton")
        b2.Size = UDim2.new(0.4,0,0.2,0)
        b2.Position = UDim2.new(0.55,0,0.75,0)
        b2.Text = "Kick Me"
        b2.BackgroundColor3 = Color3.new(1,0,0)
        b2.Parent = wf

        local alarm = playSound(SOUNDS.AdminAlarm, 2, 1, workspace, true)
        local f = true
        
        task.spawn(function() 
            while f and wf.Parent do 
                wt.TextColor3 = Color3.new(1,0,0)
                task.wait(2)
                wt.TextColor3 = Color3.new(1,1,0)
                task.wait(0.5) 
            end 
        end)
        
        b1.MouseButton1Click:Connect(function() 
            f = false
            if alarm then alarm:Destroy() end
            wf:Destroy() 
        end)
        
        b2.MouseButton1Click:Connect(function() 
            player:Kick("Agreed") 
        end)
    end 
end

for _,p in ipairs(Players:GetPlayers()) do 
    if p ~= player then checkAdmin(p) end 
end
Players.PlayerAdded:Connect(checkAdmin)

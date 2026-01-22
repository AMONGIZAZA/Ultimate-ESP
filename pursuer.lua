local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

local IsSpecialUser = (LocalPlayer.Name == "AmoGODUS_Minion" or LocalPlayer.DisplayName == "amongi")

local ASSETS = {
    TypingSound = "rbxassetid://9116156872",
    LoopMusic = "rbxassetid://77553637552266",
    Phase2Music = "rbxassetid://131177086142186", 
    MusicSpeed = 1, 
    
    AbilitySound = IsSpecialUser and "rbxassetid://76901928660559" or "rbxassetid://103698387056353",
    KillSoundMedium = "rbxassetid://8164951181",
    DecalImage = "rbxthumb://type=Asset&id=12599215426&w=420&h=420",
    BloodImage = "rbxassetid://1699933189",
    ShopItems = {{"Shotgun", 0}, {"Machete", 0}},
    SpawnSound = "rbxassetid://118419378021190",
    DeathSound1 = "rbxassetid://108241835492023",
    DeathSound2 = "rbxassetid://112303393444108",
    StealActivate = "rbxassetid://129215648504150", 
    StealSuccess2 = "rbxassetid://130287027440962", 
    StealFail = "rbxassetid://112756265911052",
    BtnImage = "rbxthumb://type=Asset&id=108404693479953&w=420&h=420"
}

local NPC_WHITELIST = {
    "Baby Avoider", "Baby Bling", "Pursuer", "Baby ClawsGuy", "Baby FriendBro", 
    "Baby HardestGame", "Baby IWantToHelp", "Baby MazeGuy", "Baby Meatwad", 
    "Baby Mequot", "Baby Miso", "Baby Phantasm", "Baby Pursuer", "Baby Purpuer", 
    "Baby Pursuer Female", "Baby SeeSaws", "Baby Stalker", "Baby Zombie", 
    "Baby Zombie_1", "Baby Zombie_2", "DREAM"
}

-- Global State
local killCount = 0
local totalKills = 0
local isAbilityActive = false 
local isStealing = false 
local forceStopSteal = false 
local deadCache = {} 
local targetBaseSpeed = 16 
local deathCounter = 0
local hasSpawnedOnce = false

-- Cooldown Timestamps
local visionCooldownEnd = 0 
local stealCooldownEnd = 0

-- Noclip State
local noclipConnection = nil

-- // UTILITIES //

local function PlaySound(id, looped, speed)
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Looped = looped or false
    s.PlaybackSpeed = speed or 1
    s.Parent = workspace 
    s.Volume = 2
    s.Name = "SFX"
    s:Play()
    if not looped then
        Debris:AddItem(s, 10)
    end
    return s
end

local function EnableNoclip(enable)
    if enable then
        if noclipConnection then noclipConnection:Disconnect() end
        noclipConnection = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if noclipConnection then 
            noclipConnection:Disconnect() 
            noclipConnection = nil
        end
        local char = LocalPlayer.Character
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end
end

-- // PHASE 2 TRANSITION HELPER //
local function ActivatePhase2Effects(char)
    if not char then return end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    if root and not root:FindFirstChild("Phase2Trail") then
        local att1 = Instance.new("Attachment", root)
        att1.Position = Vector3.new(0, 0.5, 0)
        local att2 = Instance.new("Attachment", root)
        att2.Position = Vector3.new(0, -0.5, 0)
        local trail = Instance.new("Trail", root)
        trail.Name = "Phase2Trail"
        trail.Attachment0 = att1
        trail.Attachment1 = att2
        trail.Color = ColorSequence.new(Color3.fromRGB(0, 100, 255))
        trail.Lifetime = 0.4
        trail.WidthScale = NumberSequence.new(1, 0) 
        trail.LightEmission = 0.5
        trail.FaceCamera = true
    end

    local h = char:FindFirstChild("Highlight") 
    if not h then 
        h = Instance.new("Highlight", char) 
    end
    h.OutlineColor = Color3.new(0, 0, 1)
    h.OutlineTransparency = 0
    h.FillTransparency = 0.5
    h.FillColor = Color3.fromRGB(0, 0, 255) 
    
    task.spawn(function()
        local pulse = true
        while h.Parent do
            local targetColor = pulse and Color3.fromRGB(0, 255, 255) or Color3.fromRGB(0, 0, 255)
            TweenService:Create(h, TweenInfo.new(0.5), {FillColor = targetColor}):Play()
            pulse = not pulse
            task.wait(0.5)
        end
    end)

    targetBaseSpeed = 24
    local hum = char:FindFirstChild("Humanoid")
    if hum then hum.WalkSpeed = 24 end
end

-- // GUI SETUP //

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "JusticeOverlay_V20"
ScreenGui.ResetOnSpawn = false 
ScreenGui.Parent = PlayerGui

local MusicSound = Instance.new("Sound")
MusicSound.Name = "LoopAudio"
MusicSound.SoundId = ASSETS.LoopMusic
MusicSound.Looped = true
MusicSound.PlaybackSpeed = ASSETS.MusicSpeed
MusicSound.Volume = 1
MusicSound.Parent = ScreenGui 

local IntroFrame = Instance.new("Frame")
IntroFrame.Size = UDim2.new(1, 0, 1, 0)
IntroFrame.BackgroundColor3 = Color3.new(0, 0, 0)
IntroFrame.BackgroundTransparency = 1
IntroFrame.ZIndex = 100
IntroFrame.Parent = ScreenGui

local IntroText = Instance.new("TextLabel")
IntroText.Size = UDim2.new(0.8, 0, 0.2, 0)
IntroText.Position = UDim2.new(0.1, 0, 0.4, 0)
IntroText.BackgroundTransparency = 1
IntroText.Font = Enum.Font.GothamBold
IntroText.TextScaled = true
IntroText.RichText = true
IntroText.ZIndex = 101
IntroText.TextTransparency = 1
IntroText.Parent = IntroFrame

local StatsFrame = Instance.new("Frame")
StatsFrame.Size = UDim2.new(0, 200, 0, 100)
StatsFrame.Position = UDim2.new(0.8, 0, 0.05, 0)
StatsFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
StatsFrame.Visible = false
StatsFrame.Active = true
StatsFrame.Draggable = true
StatsFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = StatsFrame

local KillstreakLabel = Instance.new("TextLabel")
KillstreakLabel.Text = "Killstreak"
KillstreakLabel.Size = UDim2.new(1, 0, 0.3, 0)
KillstreakLabel.BackgroundTransparency = 1
KillstreakLabel.Font = Enum.Font.GothamBlack
KillstreakLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
KillstreakLabel.TextSize = 20
KillstreakLabel.Parent = StatsFrame

local CurrentKillLabel = Instance.new("TextLabel")
CurrentKillLabel.Text = "0"
CurrentKillLabel.Size = UDim2.new(1, 0, 0.4, 0)
CurrentKillLabel.Position = UDim2.new(0, 0, 0.3, 0)
CurrentKillLabel.BackgroundTransparency = 1
CurrentKillLabel.Font = Enum.Font.GothamBold
CurrentKillLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
CurrentKillLabel.TextScaled = true
CurrentKillLabel.Parent = StatsFrame

local TotalKillLabel = Instance.new("TextLabel")
TotalKillLabel.Text = "Total kills: 0"
TotalKillLabel.Size = UDim2.new(1, 0, 0.2, 0)
TotalKillLabel.Position = UDim2.new(0, 0, 0.75, 0)
TotalKillLabel.BackgroundTransparency = 1
TotalKillLabel.Font = Enum.Font.Gotham
TotalKillLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
TotalKillLabel.TextSize = 14
TotalKillLabel.Parent = StatsFrame

-- // NEW UI //
local NewUIContainer = Instance.new("Frame")
NewUIContainer.Size = UDim2.new(1, 0, 1, 0)
NewUIContainer.BackgroundTransparency = 1
NewUIContainer.Visible = true 
NewUIContainer.Parent = ScreenGui

local NewVisionFrame = Instance.new("ImageButton")
NewVisionFrame.Size = UDim2.new(0, 220, 0, 70)
NewVisionFrame.Position = UDim2.new(0.5, -230, 0.78, 0)
NewVisionFrame.BackgroundColor3 = Color3.new(1,1,1)
NewVisionFrame.ImageTransparency = 1
NewVisionFrame.AutoButtonColor = false
NewVisionFrame.Parent = NewUIContainer

local VisionStroke = Instance.new("UIStroke")
VisionStroke.Thickness = 4
VisionStroke.Color = Color3.fromRGB(255, 100, 0) 
VisionStroke.Parent = NewVisionFrame

local VisionImage = Instance.new("ImageLabel")
VisionImage.Size = UDim2.new(1, -4, 1, -4)
VisionImage.Position = UDim2.new(0, 2, 0, 2)
VisionImage.BackgroundTransparency = 1
VisionImage.Image = ASSETS.BtnImage
VisionImage.ScaleType = Enum.ScaleType.Crop
VisionImage.Parent = NewVisionFrame

local VisionKey = Instance.new("TextLabel")
VisionKey.Text = "Q / TAP"
VisionKey.Size = UDim2.new(1, -10, 0, 20)
VisionKey.Position = UDim2.new(0, 5, 0, 2)
VisionKey.BackgroundTransparency = 1
VisionKey.Font = Enum.Font.GothamBlack
VisionKey.TextColor3 = Color3.new(1,1,1)
VisionKey.TextStrokeTransparency = 0
VisionKey.TextXAlignment = Enum.TextXAlignment.Left
VisionKey.TextSize = 14
VisionKey.Parent = NewVisionFrame

local VisionTitle = Instance.new("TextLabel")
VisionTitle.Text = "THE VISION"
VisionTitle.Size = UDim2.new(1, -10, 0, 25)
VisionTitle.Position = UDim2.new(0, 5, 1, -27)
VisionTitle.BackgroundTransparency = 1
VisionTitle.Font = Enum.Font.GothamBlack
VisionTitle.TextColor3 = Color3.new(1,1,1)
VisionTitle.TextStrokeTransparency = 0
VisionTitle.TextXAlignment = Enum.TextXAlignment.Left
VisionTitle.TextSize = 20
VisionTitle.Parent = NewVisionFrame

local VisionCD = Instance.new("TextLabel")
VisionCD.Text = "5"
VisionCD.Size = UDim2.new(1,0,1,0)
VisionCD.BackgroundTransparency = 1
VisionCD.Font = Enum.Font.GothamBlack
VisionCD.TextColor3 = Color3.new(1,1,1)
VisionCD.TextStrokeTransparency = 0
VisionCD.TextSize = 30
VisionCD.Visible = false
VisionCD.ZIndex = 10
VisionCD.Parent = NewVisionFrame

local NewStealFrame = Instance.new("ImageButton")
NewStealFrame.Size = UDim2.new(0, 220, 0, 70)
NewStealFrame.Position = UDim2.new(0.5, 10, 0.78, 0) 
NewStealFrame.BackgroundColor3 = Color3.new(1,1,1)
NewStealFrame.ImageTransparency = 1
NewStealFrame.Visible = false
NewStealFrame.AutoButtonColor = false
NewStealFrame.Parent = NewUIContainer

local StealStroke = Instance.new("UIStroke")
StealStroke.Thickness = 4
StealStroke.Color = Color3.fromRGB(0, 255, 255)
StealStroke.Parent = NewStealFrame

local StealImage = Instance.new("ImageLabel")
StealImage.Size = UDim2.new(1, -4, 1, -4)
StealImage.Position = UDim2.new(0, 2, 0, 2)
StealImage.BackgroundTransparency = 1
StealImage.Image = ASSETS.BtnImage
StealImage.ScaleType = Enum.ScaleType.Crop
StealImage.Parent = NewStealFrame

local StealKey = Instance.new("TextLabel")
StealKey.Text = "R / TAP"
StealKey.Size = UDim2.new(1, -10, 0, 20)
StealKey.Position = UDim2.new(0, 5, 0, 2)
StealKey.BackgroundTransparency = 1
StealKey.Font = Enum.Font.GothamBlack
StealKey.TextColor3 = Color3.new(1,1,1)
StealKey.TextStrokeTransparency = 0
StealKey.TextXAlignment = Enum.TextXAlignment.Left
StealKey.TextSize = 14
StealKey.Parent = NewStealFrame

local StealTitle = Instance.new("TextLabel")
StealTitle.Text = "STEAL"
StealTitle.Size = UDim2.new(1, -10, 0, 25)
StealTitle.Position = UDim2.new(0, 5, 1, -27)
StealTitle.BackgroundTransparency = 1
StealTitle.Font = Enum.Font.GothamBlack
StealTitle.TextColor3 = Color3.new(1,1,1)
StealTitle.TextStrokeTransparency = 0
StealTitle.TextXAlignment = Enum.TextXAlignment.Left
StealTitle.TextSize = 20
StealTitle.Parent = NewStealFrame

local StealCD = Instance.new("TextLabel")
StealCD.Text = "20"
StealCD.Size = UDim2.new(1,0,1,0)
StealCD.BackgroundTransparency = 1
StealCD.Font = Enum.Font.GothamBlack
StealCD.TextColor3 = Color3.new(1,1,1)
StealCD.TextStrokeTransparency = 0
StealCD.TextSize = 30
StealCD.Visible = false
StealCD.ZIndex = 10
StealCD.Parent = NewStealFrame

local EffectFrame = Instance.new("Frame")
EffectFrame.Size = UDim2.new(1, 0, 1, 0)
EffectFrame.BackgroundTransparency = 1
EffectFrame.Parent = ScreenGui
EffectFrame.ZIndex = 50

local RedOverlay = Instance.new("Frame")
RedOverlay.Size = UDim2.new(1,0,1,0)
RedOverlay.BackgroundColor3 = Color3.new(1,0,0)
RedOverlay.BackgroundTransparency = 1
RedOverlay.Parent = EffectFrame

local BlueOverlay = Instance.new("Frame")
BlueOverlay.Size = UDim2.new(1,0,1,0)
BlueOverlay.BackgroundColor3 = Color3.new(0, 0.5, 1)
BlueOverlay.BackgroundTransparency = 1
BlueOverlay.Parent = EffectFrame

local DecalOverlay = Instance.new("ImageLabel")
DecalOverlay.Size = UDim2.new(1,0,1,0)
DecalOverlay.BackgroundTransparency = 1
DecalOverlay.ImageTransparency = 1
DecalOverlay.Image = ASSETS.DecalImage
DecalOverlay.ScaleType = Enum.ScaleType.Crop
DecalOverlay.Parent = EffectFrame

local function ShakeScreen(intensity, duration)
    local startTime = tick()
    local conn
    conn = RunService.RenderStepped:Connect(function()
        if tick() - startTime > duration then
            conn:Disconnect()
            return
        end
        local x = (math.random() - 0.5) * intensity
        local y = (math.random() - 0.5) * intensity
        Camera.CFrame = Camera.CFrame * CFrame.new(x, y, 0)
    end)
end

local function ShowBlood()
    local BloodFrame = Instance.new("ImageLabel")
    BloodFrame.Size = UDim2.new(1,0,1,0)
    BloodFrame.BackgroundTransparency = 1
    BloodFrame.Image = ASSETS.BloodImage
    BloodFrame.ImageTransparency = 0.2
    BloodFrame.Parent = EffectFrame
    Debris:AddItem(BloodFrame, 2)
end

local function IsInWhitelist(npcName)
    if not npcName then return false end
    for _, validName in pairs(NPC_WHITELIST) do
        if string.find(npcName, validName) then return true end
    end
    return false
end

local function UpdateUI_Cooldown(isVision, timeLeft, isActive)
    if isVision then
        if isActive then
            NewVisionFrame.BackgroundColor3 = Color3.fromRGB(100,100,100)
            VisionStroke.Color = Color3.fromRGB(100,100,100)
            VisionImage.ImageColor3 = Color3.fromRGB(100,100,100)
            VisionTitle.TextColor3 = Color3.fromRGB(150,150,150)
            VisionKey.TextColor3 = Color3.fromRGB(150,150,150)
            VisionCD.Visible = true
            VisionCD.Text = tostring(math.ceil(timeLeft))
        else
            NewVisionFrame.BackgroundColor3 = Color3.new(1,1,1)
            VisionStroke.Color = Color3.fromRGB(255, 100, 0)
            VisionImage.ImageColor3 = Color3.new(1,1,1)
            VisionTitle.TextColor3 = Color3.new(1,1,1)
            VisionKey.TextColor3 = Color3.new(1,1,1)
            VisionCD.Visible = false
        end
    else
        if isActive then
            if StealTitle.Text == "STOP" then
                NewStealFrame.BackgroundColor3 = Color3.new(1,0,0)
                StealStroke.Color = Color3.new(1,0,0)
                StealCD.Visible = false
            else
                NewStealFrame.BackgroundColor3 = Color3.fromRGB(100,100,100)
                StealStroke.Color = Color3.fromRGB(100,100,100)
                StealImage.ImageColor3 = Color3.fromRGB(100,100,100)
                StealTitle.TextColor3 = Color3.fromRGB(150,150,150)
                StealKey.TextColor3 = Color3.fromRGB(150,150,150)
                StealCD.Visible = true
                StealCD.Text = tostring(math.ceil(timeLeft))
            end
        else
            NewStealFrame.BackgroundColor3 = Color3.new(1,1,1)
            StealStroke.Color = Color3.fromRGB(0, 255, 255)
            StealImage.ImageColor3 = Color3.new(1,1,1)
            StealTitle.TextColor3 = Color3.new(1,1,1)
            StealKey.TextColor3 = Color3.new(1,1,1)
            StealCD.Visible = false
            StealTitle.Text = "STEAL"
        end
    end
end

RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            if not isAbilityActive and not isStealing and hum.Health > 0 then
                if math.abs(hum.WalkSpeed - targetBaseSpeed) > 0.5 then
                    hum.WalkSpeed = targetBaseSpeed
                end
            end
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    -- RESET STATES
    isStealing = false 
    isAbilityActive = false
    forceStopSteal = false
    EnableNoclip(false)
    
    -- RESET COOLDOWNS & UI
    visionCooldownEnd = 0
    stealCooldownEnd = 0
    UpdateUI_Cooldown(true, 0, false)
    UpdateUI_Cooldown(false, 0, false)

    if not IsSpecialUser then return end
    
    local hum = char:WaitForChild("Humanoid")
    
    if not hasSpawnedOnce then
        PlaySound(ASSETS.SpawnSound, false, 1)
        hasSpawnedOnce = true
        return
    end
    
    deathCounter = deathCounter + 1
    
    if deathCounter == 3 then
        LocalPlayer:Kick("IM DONE")
        return
    end

    if deathCounter >= 1 then
        NewStealFrame.Visible = true
    end

    -- AUDIO LOGIC
    if deathCounter == 1 then
        PlaySound(ASSETS.DeathSound1, false, 1)
        -- CHANGE LOOP MUSIC TO PHASE 2 MUSIC
        MusicSound:Stop()
        MusicSound.SoundId = ASSETS.Phase2Music
        MusicSound.PlaybackSpeed = 1 
        MusicSound:Play()
        
        local h = Instance.new("Highlight", char)
        h.OutlineColor = Color3.new(0, 0, 1)
        h.FillTransparency = 1
        targetBaseSpeed = 16 + 6.5
        
    elseif deathCounter == 2 then
        PlaySound(ASSETS.DeathSound2, false, 1)
        ActivatePhase2Effects(char)
        -- SPEED UP MUSIC BY 1.1x
        MusicSound.PlaybackSpeed = MusicSound.PlaybackSpeed * 1.1
    end
    
    local t1 = TweenService:Create(BlueOverlay, TweenInfo.new(0.5), {BackgroundTransparency = 0.45})
    t1:Play()
    t1.Completed:Connect(function()
        task.wait(1)
        TweenService:Create(BlueOverlay, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
    end)
    
    local originalFOV = Camera.FieldOfView
    TweenService:Create(Camera, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {FieldOfView = 120}):Play()
    task.delay(2, function()
        TweenService:Create(Camera, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {FieldOfView = originalFOV}):Play()
    end)
    
    hum.WalkSpeed = targetBaseSpeed
end)

local function UpdateUI_Kill()
    CurrentKillLabel.Text = tostring(killCount)
    TotalKillLabel.Text = "Total kills: " .. tostring(totalKills)
    local percent = math.clamp(killCount / 50, 0, 1)
    local newColor = Color3.new(1, 1, 1):Lerp(Color3.new(1, 0, 0), percent)
    KillstreakLabel.TextColor3 = newColor
    if killCount >= 50 then KillstreakLabel.Font = Enum.Font.Creepster else KillstreakLabel.Font = Enum.Font.GothamBlack end
    if killCount >= 100 then
        KillstreakLabel.TextColor3 = Color3.new(0,0,0)
        local x = (math.random() - 0.5) * 5
        local y = (math.random() - 0.5) * 5
        StatsFrame.Position = UDim2.new(0.8, x, 0.05, y)
    end
end

local function HandleKill(victimPosition)
    killCount = killCount + 1
    totalKills = totalKills + 1
    UpdateUI_Kill()
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return end
    local distance = (myChar.HumanoidRootPart.Position - victimPosition).Magnitude
    if distance >= 60 then
        ShakeScreen(0.5, 0.3)
        local t1 = TweenService:Create(RedOverlay, TweenInfo.new(0.15), {BackgroundTransparency = 0.5})
        t1:Play()
        t1.Completed:Connect(function() TweenService:Create(RedOverlay, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play() end)
    elseif distance >= 20 then
        PlaySound(ASSETS.KillSoundMedium, false, 1)
        ShakeScreen(1.0, 0.3)
        local t1 = TweenService:Create(RedOverlay, TweenInfo.new(0.1), {BackgroundTransparency = 0.3})
        t1:Play()
        t1.Completed:Connect(function() TweenService:Create(RedOverlay, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play() end)
    else
        PlaySound(ASSETS.KillSoundMedium, false, 1)
        ShowBlood()
        TweenService:Create(RedOverlay, TweenInfo.new(0.1), {BackgroundTransparency = 0.2}):Play()
        task.delay(0.1, function() TweenService:Create(RedOverlay, TweenInfo.new(1), {BackgroundTransparency = 1}):Play() end)
        TweenService:Create(DecalOverlay, TweenInfo.new(0.25), {ImageTransparency = 0}):Play()
        task.delay(3, function() TweenService:Create(DecalOverlay, TweenInfo.new(2), {ImageTransparency = 1}):Play() end)
    end
end

local function ScanForDeadHumanoids()
    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("Humanoid") and v.Parent ~= myChar then
            if v.Health <= 0 then
                if not deadCache[v] then
                    deadCache[v] = true
                    if v.RootPart then
                        local dist = (v.RootPart.Position - myRoot.Position).Magnitude
                        if dist <= 100 then HandleKill(v.RootPart.Position) end
                    end
                end
            end
        end
    end
end

local function ActivateVision()
    if tick() < visionCooldownEnd then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if not hum then return end
    
    isAbilityActive = true
    local slowSpeed = 6.5
    local cooldownDuration = 25
    if IsSpecialUser and deathCounter > 0 then
        slowSpeed = 10
        cooldownDuration = 5 
    end
    visionCooldownEnd = tick() + cooldownDuration
    
    local success, err = pcall(function()
        TweenService:Create(hum, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {WalkSpeed = slowSpeed}):Play()
        ShowBlood()
        task.delay(0.6, function() PlaySound(ASSETS.AbilitySound, false, 1) end)
        
        local highlights = {}
        
        for _, model in pairs(workspace:GetDescendants()) do
            if model:IsA("Model") and model:FindFirstChild("Humanoid") and model ~= char then
                if model.Humanoid.Health > 0 then
                    local h = Instance.new("Highlight")
                    h.FillColor = Color3.fromRGB(255, 100, 0)
                    h.OutlineColor = Color3.fromRGB(255, 255, 0)
                    h.FillTransparency = 1
                    h.OutlineTransparency = 1
                    
                    -- FIX: Changed AlwaysOn to AlwaysOnTop
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop 
                    
                    h.Parent = model
                    table.insert(highlights, h)
                    TweenService:Create(h, TweenInfo.new(0.5), {FillTransparency = 0.5, OutlineTransparency = 0}):Play()
                end
            end
        end
        
        task.wait(2)
        if hum then 
            TweenService:Create(hum, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {WalkSpeed = targetBaseSpeed}):Play() 
        end
        task.wait(3) 
        
        for _, h in pairs(highlights) do
            if h.Parent then
                local t = TweenService:Create(h, TweenInfo.new(0.5), {FillTransparency = 1, OutlineTransparency = 1})
                t:Play()
                t.Completed:Connect(function() h:Destroy() end)
            end
        end
    end)
    
    if not success then
        warn("Vision Ability Error:", err)
        if hum then hum.WalkSpeed = targetBaseSpeed end
    end

    isAbilityActive = false
    
    task.spawn(function()
        while tick() < visionCooldownEnd do
            local remaining = visionCooldownEnd - tick()
            UpdateUI_Cooldown(true, remaining, true)
            task.wait(0.1)
        end
        UpdateUI_Cooldown(true, 0, false)
    end)
end

local function ActivateSteal()
    if isStealing then
        if StealTitle.Text == "STOP" then
            forceStopSteal = true 
        end
        return 
    end

    if tick() < stealCooldownEnd then return end
    
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    local head = char and char:FindFirstChild("Head")
    if not root or not hum or not head then return end
    
    local startOrigin = root.CFrame 

    PlaySound(ASSETS.StealActivate, false, 1)

    stealCooldownEnd = tick() + 20
    isStealing = true 
    isAbilityActive = true
    forceStopSteal = false
    
    local nearestNPC = nil
    local nearestDist = math.huge
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj ~= char and not Players:GetPlayerFromCharacter(obj) then
            local npcRoot = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
            if npcRoot then
                local dist = (root.Position - npcRoot.Position).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearestNPC = obj
                end
            end
        end
    end
    
    if not nearestNPC then
        isStealing = false
        isAbilityActive = false
        return
    end
    
    local npcRoot = nearestNPC:FindFirstChild("HumanoidRootPart") or nearestNPC:FindFirstChild("Torso")
    
    EnableNoclip(true)
    root.Anchored = false 
    
    -- 1. TRACKING PHASE
    local stealStartTime = tick()
    local tracking = true
    
    while tracking and isStealing and hum.Health > 0 do
        if (tick() - stealStartTime) > 10 then
            StealTitle.Text = "STOP"
            UpdateUI_Cooldown(false, 0, true) 
        else
            local remaining = stealCooldownEnd - tick()
            UpdateUI_Cooldown(false, remaining, true)
        end

        if forceStopSteal then break end

        local currentPos = root.Position
        local targetPos = npcRoot.Position + Vector3.new(0, 1.5, 2)
        local dist = (targetPos - currentPos).Magnitude
        
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero

        if dist < 3 then
            tracking = false
        else
            local direction = (targetPos - currentPos).Unit
            local newCFrame = CFrame.new(currentPos, targetPos) + (direction * 6)
            root.CFrame = root.CFrame:Lerp(newCFrame, 0.2)
        end
        RunService.Heartbeat:Wait()
    end
    
    if forceStopSteal or hum.Health <= 0 then
        isStealing = false
        isAbilityActive = false
        EnableNoclip(false)
        StealTitle.Text = "STEAL"
        UpdateUI_Cooldown(false, 0, false)
        return
    end
    
    local isValidTarget = IsInWhitelist(nearestNPC.Name)
    local grabLocation = npcRoot.Position 

    if isValidTarget then
        local grabEvent = ReplicatedStorage:WaitForChild("GrabEvent", 2)
        local hitBox = nearestNPC:FindFirstChild("Hitbox")
        
        -- 2. LOCK & WAIT PHASE
        local lockStart = tick()
        local hasFired = false
        
        while (tick() - lockStart) < 1 do
            if forceStopSteal or hum.Health <= 0 then break end
            
            for _, p in pairs(nearestNPC:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
            
            root.CFrame = npcRoot.CFrame * CFrame.new(0, 1.5, 2)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            
            if (tick() - lockStart) >= 0.6 and not hasFired then
                hasFired = true
                if grabEvent and hitBox then
                    grabEvent:FireServer("Grab", hitBox)
                    grabEvent:FireServer("Grab", hitBox)
                end
            end
            RunService.Heartbeat:Wait()
        end
        
        if forceStopSteal then
             isStealing = false
             isAbilityActive = false
             EnableNoclip(false)
             StealTitle.Text = "STEAL"
             UpdateUI_Cooldown(false, 0, false)
             return
        end
        
        PlaySound(ASSETS.StealSuccess2, false, 1)
        
        -- 3. RISING PHASE (Fly High with NPC) - UPDATED TO "TRACKING TYPE" FLIGHT
        local riseStart = tick()
        local riseDuration = 6 
        local hasDropped = false

        local rising = true
        local speedRising = 4 
        
        while rising and isStealing and hum.Health > 0 do
             if forceStopSteal then break end
             
             local elapsed = tick() - riseStart
             if elapsed >= riseDuration then rising = false end
             
             for _, p in pairs(nearestNPC:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
             end
             
             -- DROP LOGIC: 1.5 seconds BEFORE rise ends
             if elapsed >= (riseDuration - 1.5) and not hasDropped then
                 hasDropped = true
                 if grabEvent then
                    grabEvent:FireServer("Drop")
                    grabEvent:FireServer("Drop")
                 end
             end

             -- MOVEMENT: Uses "Tracking" style Lerp logic but going UP
             local currentPos = root.Position
             -- Move 3 studs Up relative to current pos
             local targetPos = currentPos + Vector3.new(0, speedRising, 0)
             
             -- Lerp for smoothness (Tracking feel)
             root.CFrame = root.CFrame:Lerp(CFrame.new(targetPos) * root.CFrame.Rotation, 0.2)
             
             root.AssemblyLinearVelocity = Vector3.zero
             root.AssemblyAngularVelocity = Vector3.zero
             
             RunService.Heartbeat:Wait()
        end

        if not hasDropped and grabEvent then
            grabEvent:FireServer("Drop")
            grabEvent:FireServer("Drop")
        end
        
        -- 5. RETURN PHASE (Fly Back to Original Spot) - UPDATED TO "TRACKING TYPE" FLIGHT
        local returnStart = tick()
        local returning = true
        local speedReturn = 8
        
        while returning and isStealing and hum.Health > 0 do
            if forceStopSteal then break end
            
            local currentPos = root.Position
            local dist = (startOrigin.Position - currentPos).Magnitude
            
            if dist < 5 then
                returning = false
            end
            
            -- Direction towards start
            local direction = (startOrigin.Position - currentPos).Unit
            
            -- Look at grabLocation, but keep current Y for head rotation? 
            -- User wants to "look at where you grabbed the NPC"
            local lookAtPos = Vector3.new(grabLocation.X, currentPos.Y, grabLocation.Z)
            
            -- Calculate target CFrame: Move towards start, Face the grab location
            local targetPos = currentPos + (direction * speedReturn)
            local targetCFrame = CFrame.lookAt(targetPos, lookAtPos)
            
            -- Apply Lerp
            root.CFrame = root.CFrame:Lerp(targetCFrame, 0.2)
            
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            
            RunService.Heartbeat:Wait()
        end

        task.wait(0.1)
        EnableNoclip(false)
        root.AssemblyLinearVelocity = Vector3.zero
        
    else
        -- SAFETY CHECK FOR NIL PLAY SOUND
        if ASSETS and ASSETS.StealFail then
             PlaySound(ASSETS.StealFail, false, 1)
        end
        
        if deathCounter < 2 then
            -- FAIL STUN: SIT FOR 2 SECONDS
            local oldSpeed = hum.WalkSpeed
            hum.WalkSpeed = 0 
            hum.Sit = true 
            task.wait(2) 
            hum.Sit = false
            hum.WalkSpeed = oldSpeed
            
            deathCounter = 2
            ActivatePhase2Effects(char)
            MusicSound.PlaybackSpeed = MusicSound.PlaybackSpeed * 1.1
        end
    end
    
    EnableNoclip(false)
    isStealing = false
    isAbilityActive = false
    StealTitle.Text = "STEAL"
    UpdateUI_Cooldown(false, 0, false)
    
    task.spawn(function()
        while tick() < stealCooldownEnd do
            local remaining = stealCooldownEnd - tick()
            UpdateUI_Cooldown(false, remaining, true)
            task.wait(0.1)
        end
        UpdateUI_Cooldown(false, 0, false)
    end)
end

NewVisionFrame.MouseButton1Click:Connect(ActivateVision)
NewStealFrame.MouseButton1Click:Connect(ActivateSteal)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Q then ActivateVision() end
    if input.KeyCode == Enum.KeyCode.R and IsSpecialUser and deathCounter >= 1 then ActivateSteal() end
end)

task.spawn(function()
    if IsSpecialUser then 
        PlaySound(ASSETS.SpawnSound, false, 1)
        hasSpawnedOnce = true 
    end
    TweenService:Create(IntroFrame, TweenInfo.new(1), {BackgroundTransparency = 0}):Play()
    task.wait(1.1)
    local textContent = '<font color="rgb(170,0,0)" strokeColor="rgb(80,0,0)" strokeTransparency="0">Bring <font color="rgb(255,255,0)" strokeColor="rgb(255,100,0)">JUSTICE</font> to life. Trust nothing, observe everything.</font>'
    if IsSpecialUser then
        textContent = '<font color="rgb(0,255,255)" strokeColor="rgb(0,0,255)" strokeTransparency="0">Kill all intruders.</font>'
    end
    IntroText.Text = textContent
    IntroText.MaxVisibleGraphemes = 0
    IntroText.TextTransparency = 0
    local totalChars = #IntroText.ContentText
    for i = 1, totalChars do
        IntroText.MaxVisibleGraphemes = i
        PlaySound(ASSETS.TypingSound, false, 1)
        task.wait(0.05)
    end
    task.wait(5)
    TweenService:Create(IntroText, TweenInfo.new(1), {TextTransparency = 1}):Play()
    task.wait(2)
    TweenService:Create(IntroFrame, TweenInfo.new(2), {BackgroundTransparency = 1}):Play()
    for _, item in pairs(ASSETS.ShopItems) do
        local args = {item[1], item[2]}
        local event = ReplicatedStorage:WaitForChild("BuyShopItem", 2)
        if event then event:FireServer(unpack(args)) end
    end
    task.wait(2)
    IntroFrame:Destroy()
    StatsFrame.Visible = true
    MusicSound:Play() 
    RunService.Heartbeat:Connect(function()
        ScanForDeadHumanoids()
    end)
end)

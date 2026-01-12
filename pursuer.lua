local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

local IsSpecialUser = (LocalPlayer.Name == "AmoGODUS_Minion" or LocalPlayer.DisplayName == "amongi")

local ASSETS = {
    TypingSound = "rbxassetid://9116156872",
    LoopMusic = IsSpecialUser and "rbxassetid://111399160714629" or "rbxassetid://131533591074605",
    MusicSpeed = IsSpecialUser and 0.1 or 1.3,
    AbilitySound = IsSpecialUser and "rbxassetid://76901928660559" or "rbxassetid://103698387056353",
    KillSoundMedium = "rbxassetid://8164951181",
    DecalImage = "rbxthumb://type=Asset&id=12599215426&w=420&h=420",
    BloodImage = "rbxassetid://1699933189",
    ShopItems = {{"Shotgun", 0}, {"Machete", 0}},
    SpawnSound = "rbxassetid://118419378021190",
    DeathSound1 = "rbxassetid://108241835492023",
    DeathSound2 = "rbxassetid://112303393444108",
    StealSuccess1 = "rbxassetid://129215648504150",
    StealSuccess2 = "rbxassetid://130287027440962",
    StealFail = "rbxassetid://112756265911052"
}

local NPC_WHITELIST = {
    "Baby Avoider", "Baby Bling", "Pursuer", "Baby Clawsguy", "Baby FriendBro", 
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

-- GUI Setup
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "JusticeOverlay_FixedV8"
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

local AbilityBtn = Instance.new("TextButton")
AbilityBtn.Size = UDim2.new(0, 140, 0, 50)
AbilityBtn.Position = UDim2.new(0.5, -145, 0.85, 0)
AbilityBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
AbilityBtn.Text = "The Vision"
AbilityBtn.Font = Enum.Font.GothamBlack
AbilityBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AbilityBtn.TextSize = 18
AbilityBtn.Visible = false
AbilityBtn.AutoButtonColor = true
AbilityBtn.Parent = ScreenGui

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 8)
BtnCorner.Parent = AbilityBtn

local BtnStroke = Instance.new("UIStroke")
BtnStroke.Color = Color3.fromRGB(255, 100, 0)
BtnStroke.Thickness = 2
BtnStroke.Parent = AbilityBtn

local StealBtn = Instance.new("TextButton")
StealBtn.Size = UDim2.new(0, 140, 0, 50)
StealBtn.Position = UDim2.new(0.5, 5, 0.85, 0) 
StealBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
StealBtn.Text = "STEAL"
StealBtn.Font = Enum.Font.GothamBlack
StealBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
StealBtn.TextSize = 18
StealBtn.Visible = false 
StealBtn.AutoButtonColor = true
StealBtn.Parent = ScreenGui

local StealCorner = Instance.new("UICorner")
StealCorner.CornerRadius = UDim.new(0, 8)
StealCorner.Parent = StealBtn

local StealStroke = Instance.new("UIStroke")
StealStroke.Color = Color3.fromRGB(255, 0, 0)
StealStroke.Thickness = 2
StealStroke.Parent = StealBtn

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

local function PlaySound(id, looped, speed)
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Looped = looped or false
    s.PlaybackSpeed = speed or 1
    s.Parent = ScreenGui
    s.Volume = 2
    s.Name = "SFX"
    s:Play()
    if not looped then
        Debris:AddItem(s, 10)
    end
    return s
end

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
    for _, validName in pairs(NPC_WHITELIST) do
        if string.find(npcName, validName) then
            return true
        end
    end
    return false
end

local function CreateBlueTrail(char)
    local root = char:WaitForChild("HumanoidRootPart")
    local att1 = Instance.new("Attachment")
    att1.Position = Vector3.new(0, 0.5, 0)
    att1.Parent = root
    local att2 = Instance.new("Attachment")
    att2.Position = Vector3.new(0, -0.5, 0)
    att2.Parent = root
    local trail = Instance.new("Trail")
    trail.Parent = root
    trail.Attachment0 = att1
    trail.Attachment1 = att2
    trail.Color = ColorSequence.new(Color3.fromRGB(0, 100, 255))
    trail.Lifetime = 0.4
    trail.WidthScale = NumberSequence.new(1, 0) 
    trail.LightEmission = 0.5
    trail.FaceCamera = true
end

-- Fallback Speed Check
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
    isStealing = false 
    isAbilityActive = false
    forceStopSteal = false

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
        StealBtn.Visible = true
        StealBtn.Text = "STEAL"
        StealBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    end

    if deathCounter == 1 then
        PlaySound(ASSETS.DeathSound1, false, 1)
    elseif deathCounter == 2 then
        PlaySound(ASSETS.DeathSound2, false, 1)
        CreateBlueTrail(char) 
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
    
    local h = Instance.new("Highlight")
    h.Parent = char
    h.OutlineColor = Color3.new(0, 0, 1)
    h.OutlineTransparency = 0
    
    if deathCounter == 1 then
        h.FillTransparency = 1
        targetBaseSpeed = 16 + 6.5
    elseif deathCounter == 2 then
        h.FillTransparency = 0.5
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
    end
    
    hum.WalkSpeed = targetBaseSpeed
end)

local function UpdateUI()
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
    UpdateUI()
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
                    task.delay(10, function() deadCache[v] = nil end)
                end
            end
        end
    end
end

local visionCooldownEnd = 0 
AbilityBtn.MouseButton1Click:Connect(function()
    if tick() < visionCooldownEnd then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if not hum then return end
    isAbilityActive = true
    local slowSpeed = 6.5
    local cooldownDuration = 25
    if IsSpecialUser and deathCounter > 0 then
        slowSpeed = 10
        cooldownDuration = 2.5
    end
    visionCooldownEnd = tick() + cooldownDuration
    local savedSpeed = targetBaseSpeed 
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
                h.Parent = model
                table.insert(highlights, h)
                TweenService:Create(h, TweenInfo.new(0.5), {FillTransparency = 0.5, OutlineTransparency = 0}):Play()
            end
        end
    end
    task.wait(2)
    if hum then TweenService:Create(hum, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {WalkSpeed = savedSpeed}):Play() end
    task.wait(3) 
    for _, h in pairs(highlights) do
        if h.Parent then
            local t = TweenService:Create(h, TweenInfo.new(0.5), {FillTransparency = 1, OutlineTransparency = 1})
            t:Play()
            t.Completed:Connect(function() h:Destroy() end)
        end
    end
    isAbilityActive = false
    task.spawn(function()
        while tick() < visionCooldownEnd do
            local remaining = math.ceil(visionCooldownEnd - tick())
            AbilityBtn.Text = tostring(remaining)
            AbilityBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            task.wait(0.1)
        end
        AbilityBtn.Text = "The Vision"
        AbilityBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    end)
end)

-- // STEAL ABILITY LOGIC (FIXED) //

local stealCooldownEnd = 0

StealBtn.MouseButton1Click:Connect(function()
    -- STRICT DEBOUNCE
    if isStealing then
        if StealBtn.Text == "STOP" then
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
    root.Anchored = true
    
    -- 1. TRACKING PHASE
    local stealStartTime = tick()
    local tracking = true
    
    while tracking and isStealing and hum.Health > 0 do
        if (tick() - stealStartTime) > 10 then
            StealBtn.Text = "STOP"
            StealBtn.BackgroundColor3 = Color3.new(1, 0, 0) 
        end
        if forceStopSteal then break end

        local currentPos = root.Position
        local targetPos = npcRoot.Position - Vector3.new(0, 2, 0)
        local dist = (targetPos - currentPos).Magnitude
        
        if dist < 3 then
            tracking = false
        else
            local direction = (targetPos - currentPos).Unit
            local newCFrame = CFrame.new(currentPos, targetPos) + (direction * 3)
            root.CFrame = root.CFrame:Lerp(newCFrame, 0.2)
        end
        RunService.Heartbeat:Wait()
    end
    
    if forceStopSteal or hum.Health <= 0 then
        root.Anchored = false
        isStealing = false
        isAbilityActive = false
        StealBtn.Text = "STEAL"
        StealBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        return
    end
    
    local isValidTarget = IsInWhitelist(nearestNPC.Name)
    
    if isValidTarget then
        local grabEvent = ReplicatedStorage:WaitForChild("GrabEvent", 2)
        local hitBox = nearestNPC:FindFirstChild("Hitbox")
        
        -- 2. LOCK & SPAM PHASE (1 Second)
        local lockStart = tick()
        while (tick() - lockStart) < 1 do
            if forceStopSteal or hum.Health <= 0 then break end
            
            -- Teleport Under
            root.CFrame = npcRoot.CFrame * CFrame.new(0, -2, 0)
            
            -- Spam Remote
            if grabEvent and hitBox then
                grabEvent:FireServer("Grab", hitBox)
            end
            RunService.Heartbeat:Wait()
        end
        
        if forceStopSteal then
             root.Anchored = false
             isStealing = false
             isAbilityActive = false
             StealBtn.Text = "STEAL"
             StealBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
             return
        end
        
        PlaySound(ASSETS.StealSuccess1, false, 1)
        PlaySound(ASSETS.StealSuccess2, false, 1)
        
        -- 3. RISING PHASE
        local targetRiseHeight = 50
        local riseDuration = 4
        local riseStartTime = tick()
        local startY = root.Position.Y
        
        local headConn
        headConn = head.Touched:Connect(function()
            targetRiseHeight = targetRiseHeight + 15
            riseDuration = riseDuration + 2
        end)
        
        local rising = true
        while rising and isStealing and hum.Health > 0 do
            if (tick() - stealStartTime) > 10 then
                StealBtn.Text = "STOP"
                StealBtn.BackgroundColor3 = Color3.new(1, 0, 0)
            end
            if forceStopSteal then break end

            local elapsed = tick() - riseStartTime
            if elapsed >= riseDuration then rising = false end
            
            local currentHeight = root.Position.Y - startY
            
            if currentHeight < targetRiseHeight then
                root.CFrame = root.CFrame:Lerp(root.CFrame * CFrame.new(0, 1, 0), 0.2)
            end
            
            RunService.Heartbeat:Wait()
        end
        
        if headConn then headConn:Disconnect() end
        
        if forceStopSteal or hum.Health <= 0 then
            root.Anchored = false
            isStealing = false
            isAbilityActive = false
            StealBtn.Text = "STEAL"
            StealBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            -- Only fly down if we are high up? No, user said stop breaks things. Just drop.
            return
        end
        
        task.wait(0.5)
        
        if grabEvent then
            grabEvent:FireServer("Drop")
            grabEvent:FireServer("Drop")
        end
        
        task.wait(2)
        
        local fallTween = TweenService:Create(root, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {CFrame = root.CFrame * CFrame.new(0, -50, 0)})
        fallTween:Play()
        fallTween.Completed:Wait()
        
        root.Anchored = false
    else
        PlaySound(ASSETS.StealFail, false, 1)
        root.Anchored = false
        hum.Sit = true
        task.wait(3)
        hum.Sit = false
    end
    
    isStealing = false
    isAbilityActive = false
    StealBtn.Text = "STEAL"
    StealBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    
    task.spawn(function()
        while tick() < stealCooldownEnd do
            local remaining = math.ceil(stealCooldownEnd - tick())
            StealBtn.Text = tostring(remaining)
            StealBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            task.wait(0.1)
        end
        StealBtn.Text = "STEAL"
        StealBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    end)
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
    AbilityBtn.Visible = true
    MusicSound:Play() 
    RunService.Heartbeat:Connect(function()
        ScanForDeadHumanoids()
    end)
end)

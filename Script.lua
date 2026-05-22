-- ================================================
-- MM2 TARZI BOMB JUMP + DOUBLE JUMP
-- Mobil/Tablet Sürüklenebilir Buton
-- StarterCharacterScripts içine LocalScript olarak koy
-- ================================================

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local Debris           = game:GetService("Debris")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local hrp       = character:WaitForChild("HumanoidRootPart")

-- ================================================
-- AYARLAR
-- ================================================
local CONFIG = {
    -- Bomba
    BombCooldown   = 4,      -- Buton bekleme süresi (saniye)
    FuseTime       = 1.2,    -- Bomba kaç saniyede patlar
    BombOffset     = Vector3.new(0, -2.5, 0), -- Karakterin neresine düşer

    -- Zıplama
    FirstJumpForce  = 130,   -- 1. zıplama gücü (bomba patlaması)
    SecondJumpForce = 90,    -- 2. zıplama gücü (havadayken tekrar)
    SecondJumpTime  = 1.8,   -- 2. zıplama için süre penceresi (saniye)

    -- Görsel
    BombColor  = Color3.fromRGB(20, 20, 20),
    FuseColor  = Color3.fromRGB(255, 150, 0),

    -- Buton UI
    ButtonSize     = UDim2.new(0, 85, 0, 85),
    ButtonPosition = UDim2.new(1, -120, 1, -140), -- Sağ alt köşe
}

-- ================================================
-- DURUM
-- ================================================
local onCooldown   = false
local canSecondJump = false
local secondJumpUsed = false
local bombActive   = false

-- ================================================
-- GUI OLUŞTUR
-- ================================================
local gui = Instance.new("ScreenGui")
gui.Name           = "BombJumpGui"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = player.PlayerGui

-- Sürüklenebilir frame
local frame = Instance.new("Frame")
frame.Name                 = "BombFrame"
frame.Size                 = CONFIG.ButtonSize
frame.Position             = CONFIG.ButtonPosition
frame.AnchorPoint          = Vector2.new(0.5, 0.5)
frame.BackgroundTransparency = 1
frame.Parent               = gui

-- Dış parlama halkası (cooldown)
local glowRing = Instance.new("Frame")
glowRing.Size            = UDim2.new(1, 14, 1, 14)
glowRing.Position        = UDim2.new(0, -7, 0, -7)
glowRing.BackgroundColor3 = Color3.fromRGB(255, 80, 0)
glowRing.BorderSizePixel  = 0
glowRing.ZIndex           = 1
glowRing.Parent           = frame
Instance.new("UICorner", glowRing).CornerRadius = UDim.new(1, 0)

-- Ana buton
local btn = Instance.new("TextButton")
btn.Name               = "BombBtn"
btn.Size               = UDim2.new(1, 0, 1, 0)
btn.BackgroundColor3   = Color3.fromRGB(22, 22, 22)
btn.BorderSizePixel    = 0
btn.Text               = "💣"
btn.TextSize           = 38
btn.AutoButtonColor    = false
btn.ZIndex             = 2
btn.Parent             = frame
Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

-- "BOMB" alt yazı
local subLabel = Instance.new("TextLabel")
subLabel.Size               = UDim2.new(1, 0, 0, 14)
subLabel.Position           = UDim2.new(0, 0, 1, -16)
subLabel.BackgroundTransparency = 1
subLabel.Text               = "BOMB"
subLabel.TextColor3         = Color3.fromRGB(180, 180, 180)
subLabel.TextSize           = 9
subLabel.Font               = Enum.Font.GothamBold
subLabel.ZIndex             = 3
subLabel.Parent             = btn

-- Cooldown sayacı
local cdLabel = Instance.new("TextLabel")
cdLabel.Size               = UDim2.new(1, 0, 1, 0)
cdLabel.BackgroundTransparency = 1
cdLabel.Text               = ""
cdLabel.TextColor3         = Color3.fromRGB(255, 120, 0)
cdLabel.TextSize           = 30
cdLabel.Font               = Enum.Font.GothamBold
cdLabel.ZIndex             = 4
cdLabel.Visible            = false
cdLabel.Parent             = btn

-- "2. ZIP" göstergesi (havadayken yanar)
local doubleLabel = Instance.new("TextLabel")
doubleLabel.Size               = UDim2.new(0, 70, 0, 22)
doubleLabel.Position           = UDim2.new(0.5, -35, 0, -30)
doubleLabel.BackgroundColor3   = Color3.fromRGB(0, 200, 255)
doubleLabel.BackgroundTransparency = 0.2
doubleLabel.Text               = "⬆ 2. ZIP!"
doubleLabel.TextColor3         = Color3.fromRGB(255, 255, 255)
doubleLabel.TextSize           = 11
doubleLabel.Font               = Enum.Font.GothamBold
doubleLabel.ZIndex             = 5
doubleLabel.Visible            = false
doubleLabel.Parent             = frame
Instance.new("UICorner", doubleLabel).CornerRadius = UDim.new(0, 6)

-- ================================================
-- BOMBA OLUŞTURMA
-- ================================================
local function spawnBomb()
    local bomb = Instance.new("Part")
    bomb.Name     = "MM2Bomb"
    bomb.Shape    = Enum.PartType.Ball
    bomb.Size     = Vector3.new(1.4, 1.4, 1.4)
    bomb.Color    = CONFIG.BombColor
    bomb.Material = Enum.Material.SmoothPlastic
    bomb.CFrame   = CFrame.new(hrp.Position + CONFIG.BombOffset)
    bomb.CanCollide = true
    bomb.Parent   = workspace

    -- Fitil ışığı
    local light = Instance.new("PointLight")
    light.Brightness = 4
    light.Range      = 8
    light.Color      = CONFIG.FuseColor
    light.Parent     = bomb

    -- Fitil titreşimi
    local tweenIn  = TweenService:Create(bomb, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Size = Vector3.new(1.7, 1.7, 1.7)})
    local tweenOut = TweenService:Create(bomb, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Size = Vector3.new(1.4, 1.4, 1.4)})

    local shaking = true
    local function shake()
        if not shaking then return end
        tweenIn:Play()
        tweenIn.Completed:Wait()
        tweenOut:Play()
        tweenOut.Completed:Wait()
        shake()
    end
    task.spawn(shake)

    -- Fitil sesi
    local fuseSound = Instance.new("Sound")
    fuseSound.SoundId = "rbxassetid://3240499779"
    fuseSound.Volume  = 0.6
    fuseSound.Parent  = bomb
    fuseSound:Play()

    -- Patlama
    task.delay(CONFIG.FuseTime, function()
        shaking = false
        if not bomb or not bomb.Parent then return end

        local explodePos = bomb.Position

        -- Patlama efekti
        local explosion = Instance.new("Explosion")
        explosion.Position             = explodePos
        explosion.BlastRadius          = 12
        explosion.BlastPressure        = 0
        explosion.DestroyJointRadiusPercent = 0
        explosion.Parent               = workspace

        -- Patlama sesi
        local boom = Instance.new("Sound")
        boom.SoundId = "rbxassetid://3264793735"
        boom.Volume  = 0.9
        boom.Parent  = workspace
        boom:Play()
        Debris:AddItem(boom, 3)

        bomb:Destroy()

        -- Karaktere mesafeye göre itme kuvveti uygula
        local dist = (hrp.Position - explodePos).Magnitude
        if dist <= 14 then
            -- 1. Zıplama (bomba patlaması)
            local dir = (hrp.Position - explodePos).Unit
            local velocity = Vector3.new(
                dir.X * CONFIG.FirstJumpForce * 0.4,
                CONFIG.FirstJumpForce,
                dir.Z * CONFIG.FirstJumpForce * 0.4
            )

            local bv = Instance.new("BodyVelocity")
            bv.Velocity    = velocity
            bv.MaxForce    = Vector3.new(1e5, 1e5, 1e5)
            bv.P           = 1e4
            bv.Parent      = hrp

            -- Kısa süre sonra BodyVelocity kaldır (doğal fizik devam etsin)
            task.delay(0.12, function()
                bv:Destroy()
            end)

            -- Çift zıplama penceresini aç
            canSecondJump  = true
            secondJumpUsed = false
            doubleLabel.Visible = true

            -- Parlama efekti butona
            TweenService:Create(glowRing, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(0, 220, 255)
            }):Play()

            -- Süre penceresi bitince kapat
            task.delay(CONFIG.SecondJumpTime, function()
                canSecondJump = false
                doubleLabel.Visible = false
                TweenService:Create(glowRing, TweenInfo.new(0.3), {
                    BackgroundColor3 = Color3.fromRGB(255, 80, 0)
                }):Play()
            end)
        end
    end)
end

-- ================================================
-- 2. ZIPLAMA (HAVADAYKEN BUTONA BAS)
-- ================================================
local function doSecondJump()
    if not canSecondJump or secondJumpUsed then return end
    secondJumpUsed = true
    canSecondJump  = false
    doubleLabel.Visible = false

    -- 2. zıplama kuvveti
    local bv = Instance.new("BodyVelocity")
    bv.Velocity  = Vector3.new(hrp.Velocity.X * 0.6, CONFIG.SecondJumpForce, hrp.Velocity.Z * 0.6)
    bv.MaxForce  = Vector3.new(1e5, 1e5, 1e5)
    bv.P         = 1e4
    bv.Parent    = hrp

    task.delay(0.1, function()
        bv:Destroy()
    end)

    -- Görsel geri bildirim
    TweenService:Create(btn, TweenInfo.new(0.07), {BackgroundColor3 = Color3.fromRGB(0, 180, 255)}):Play()
    task.delay(0.2, function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(22, 22, 22)}):Play()
    end)

    -- Halka rengi sıfırla
    TweenService:Create(glowRing, TweenInfo.new(0.3), {
        BackgroundColor3 = Color3.fromRGB(255, 80, 0)
    }):Play()
end

-- ================================================
-- COOLDOWN FONKSİYONU
-- ================================================
local function startCooldown()
    onCooldown = true
    btn.TextTransparency = 0.5
    cdLabel.Visible = true

    local startTime = tick()
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local elapsed  = tick() - startTime
        local remaining = CONFIG.BombCooldown - elapsed
        if remaining <= 0 then
            conn:Disconnect()
            onCooldown = false
            cdLabel.Visible = false
            cdLabel.Text    = ""
            btn.TextTransparency = 0
            -- Buton hazır rengi
            TweenService:Create(glowRing, TweenInfo.new(0.3), {
                BackgroundColor3 = Color3.fromRGB(0, 255, 100)
            }):Play()
            task.delay(0.5, function()
                TweenService:Create(glowRing, TweenInfo.new(0.4), {
                    BackgroundColor3 = Color3.fromRGB(255, 80, 0)
                }):Play()
            end)
        else
            cdLabel.Text = math.ceil(remaining) .. "s"
        end
    end)
end

-- ================================================
-- BUTON MANTAĞI
-- Kısa dokun = bomba at (veya 2. zıplama)
-- Uzun bas + sürükle = butonu taşı
-- ================================================
local dragging      = false
local dragStartPos  = Vector2.new()
local frameStart    = UDim2.new()
local touchMoved    = false
local DRAG_THRESHOLD = 8

btn.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Touch
    and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

    dragging     = true
    touchMoved   = false
    dragStartPos = Vector2.new(input.Position.X, input.Position.Y)
    frameStart   = frame.Position
end)

btn.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.Touch
    and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

    local delta = Vector2.new(
        input.Position.X - dragStartPos.X,
        input.Position.Y - dragStartPos.Y
    )

    if delta.Magnitude > DRAG_THRESHOLD then
        touchMoved = true
        local vp = gui.AbsoluteSize
        local newX = math.clamp(
            frameStart.X.Offset + delta.X,
            45, vp.X - 45
        )
        local newY = math.clamp(
            frameStart.Y.Offset + delta.Y,
            45, vp.Y - 45
        )
        frame.Position = UDim2.new(0, newX, 0, newY)
    end
end)

btn.InputEnded:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.Touch
    and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

    dragging = false

    -- Sürüklenmediyse = tıklama
    if not touchMoved then
        if canSecondJump then
            -- Havadayken: 2. zıplama
            doSecondJump()
        elseif not onCooldown then
            -- Yerde: bomba at
            bombActive = true
            spawnBomb()
            startCooldown()

            -- Buton bastı efekti
            TweenService:Create(btn, TweenInfo.new(0.06), {BackgroundColor3 = Color3.fromRGB(50, 50, 50)}):Play()
            task.delay(0.15, function()
                TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(22, 22, 22)}):Play()
            end)
        end
    end
end)

-- ================================================
-- KARAKTERİ YENİDEN BAĞLA (ölünce)
-- ================================================
player.CharacterAdded:Connect(function(newChar)
    character  = newChar
    humanoid   = newChar:WaitForChild("Humanoid")
    hrp        = newChar:WaitForChild("HumanoidRootPart")
    onCooldown = false
    canSecondJump = false
    cdLabel.Visible = false
    btn.TextTransparency = 0
    doubleLabel.Visible = false
end)

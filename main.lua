-- Ashly Survive Zombie Arena - KILL ZOMBIE ONLY
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local CoreGui
pcall(function() CoreGui = game:GetService("CoreGui") end)

local VirtualInputManager
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

local LocalPlayer = Players.LocalPlayer

local KEY_FILE = "AshlySZA_Key.txt"
local SETTINGS_FILE = "AshlySZA_Settings.json"

local SavedKey = ""
if isfile and isfile(KEY_FILE) then
    pcall(function() SavedKey = readfile(KEY_FILE) end)
end

local Settings = { KillAura = false, Noclip = false, AntiAFK = false }

if isfile and isfile(SETTINGS_FILE) then
    pcall(function()
        local data = HttpService:JSONDecode(readfile(SETTINGS_FILE))
        if data then for k,v in pairs(data) do Settings[k] = v end end
    end)
end

local function Save()
    if writefile then pcall(function() writefile(SETTINGS_FILE, HttpService:JSONEncode(Settings)) end) end
end

local GUI_Toggles = {}

local function Announce(text, duration)
    duration = duration or 3
    local p = CoreGui
    pcall(function() if gethui then p = gethui() end end)
    
    local ann = Instance.new("TextLabel")
    ann.Size = UDim2.new(0, 300, 0, 36)
    ann.Position = UDim2.new(0.5, -150, 0.5, -18)
    ann.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
    ann.BackgroundTransparency = 0.2
    ann.Text = text
    ann.TextColor3 = Color3.fromRGB(255, 255, 255)
    ann.TextSize = 16
    ann.Font = Enum.Font.GothamBold
    ann.BorderSizePixel = 0
    ann.ZIndex = 9999
    ann.Parent = p
    Instance.new("UICorner", ann).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", ann)
    stroke.Color = Color3.fromRGB(255, 50, 50)
    stroke.Thickness = 2
    
    task.spawn(function()
        task.wait(duration)
        TweenService:Create(ann, TweenInfo.new(0.5), {TextTransparency = 1, BackgroundTransparency = 1}):Play()
        task.wait(0.5)
        ann:Destroy()
    end)
end

-- Find a target zombie and lock on until dead
local currentTarget = nil

local function GetTargetZombie()
    if currentTarget and currentTarget.Model and currentTarget.Model.Parent then
        local h = currentTarget.Hum
        if (not h) or (h and h.Health > 0) then
            if currentTarget.Head or currentTarget.Root then
                return currentTarget
            end
        end
    end
    
    currentTarget = nil
    local char = LocalPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    
    local nearest = nil
    local nearestDist = math.huge
    
    -- Check Zombies_Local folder
    local zf = workspace:FindFirstChild("Zombies_Local") or workspace:FindFirstChild("Zombies") or workspace:FindFirstChild("Enemies")
    if zf then
        for _, c in ipairs(zf:GetChildren()) do
            if c:IsA("Model") then
                local h = c:FindFirstChildOfClass("Humanoid")
                local rp = c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Head") or c.PrimaryPart
                if rp and ((not h) or (h and h.Health > 0)) then
                    local dist = (rp.Position - root.Position).Magnitude
                    if dist < nearestDist then
                        nearestDist = dist
                        nearest = {Model = c, Root = rp, Head = c:FindFirstChild("Head") or rp, Hum = h}
                    end
                end
            end
        end
    end
    
    -- Also check workspace for loose NPCs
    for _, c in ipairs(workspace:GetChildren()) do
        if c:IsA("Model") and not Players:GetPlayerFromCharacter(c) and c ~= char then
            local h = c:FindFirstChildOfClass("Humanoid")
            local rp = c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Head") or c.PrimaryPart
            if (h or c.Name:lower():find("zombie")) and rp then
                if (not h) or (h and h.Health > 0) then
                    local dist = (rp.Position - root.Position).Magnitude
                    if dist < nearestDist then
                        nearestDist = dist
                        nearest = {Model = c, Hum = h, Root = rp, Head = c:FindFirstChild("Head") or rp}
                    end
                end
            end
        end
    end
    
    currentTarget = nearest
    return currentTarget
end

-- Equip a weapon tool
local function EquipWeapon()
    local char = LocalPlayer.Character
    if not char then return nil end
    
    -- Already have a weapon equipped?
    local equipped = char:FindFirstChildOfClass("Tool")
    if equipped then return equipped end
    
    -- Find weapon in backpack
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then
                -- Equip it
                pcall(function() tool.Parent = char end)
                task.wait(0.05)
                return tool
            end
        end
    end
    
    return nil
end

-- ===== KILL ZOMBIE - WEAPON BASED AUTO FIRE =====
local KillAuraCon = nil
local lastFireTime = 0

local function StartKillAura()
    if KillAuraCon then KillAuraCon:Disconnect() KillAuraCon = nil end
    Announce("[K] Kill Zombie ENABLED", 2)
    
    KillAuraCon = RunService.Heartbeat:Connect(function()
        if not Settings.KillAura then return end
        
        local now = tick()
        -- Faster fire rate since it targets one at a time
        if now - lastFireTime < 0.05 then return end
        
        local zombie = GetTargetZombie()
        local char = LocalPlayer.Character
        
        if not zombie then
            if char then pcall(function() char:FindFirstChildOfClass("Humanoid").AutoRotate = true end) end
            return
        end
        
        lastFireTime = now
        
        if not char then return end
        
        local weapon = EquipWeapon()
        local tp = zombie.Head or zombie.Root
        
        -- CAMERA LOCK (Aims gun precisely)
        pcall(function()
            local cam = workspace.CurrentCamera
            cam.CFrame = CFrame.lookAt(cam.CFrame.Position, tp.Position)
        end)
        
        -- SHIFT LOCK (Force camera-relative rotation)
        pcall(function()
            UserSettings():GetService("UserGameSettings").RotationType = Enum.RotationType.CameraRelative
        end)
        
        -- SHOOT WEAPON
        if weapon then
            pcall(function() weapon:Activate() end)
        end
        
        -- MOUSE CLICK (Center of screen)
        pcall(function()
            if VirtualInputManager then
                local vp = workspace.CurrentCamera.ViewportSize
                VirtualInputManager:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, true, game, 1)
                task.wait(0.01)
                VirtualInputManager:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, false, game, 1)
            end
        end)
    end)
end

local function StopKillAura()
    if KillAuraCon then KillAuraCon:Disconnect() KillAuraCon = nil end
    pcall(function() UserSettings():GetService("UserGameSettings").RotationType = Enum.RotationType.MovementRelative end)
    Announce("[K] Kill Zombie DISABLED", 2)
end

-- ===== TOGGLE =====
local function ToggleSetting(key, silent)
    Settings[key] = not Settings[key]
    Save()
    
    if GUI_Toggles[key] then
        local t = GUI_Toggles[key]
        if Settings[key] then
            t.Frame.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
            TweenService:Create(t.Circle, TweenInfo.new(0.15), {Position = UDim2.new(1, -11, 0.5, -4.5)}):Play()
        else
            t.Frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            TweenService:Create(t.Circle, TweenInfo.new(0.15), {Position = UDim2.new(0, 2, 0.5, -4.5)}):Play()
        end
    end
    
    if key == "KillAura" then
        if Settings.KillAura then StartKillAura() else StopKillAura() end
    elseif key == "Noclip" then
        if not Settings.Noclip and type(RestoreNoclip) == "function" then RestoreNoclip() end
    end
    
    if not silent then
        local names = {KillAura="Kill Zombie", Noclip="Noclip", AntiAFK="Anti AFK"}
        local keys = {KillAura="K", Noclip="N", AntiAFK="L"}
        Announce("[" .. (keys[key] or "?") .. "] " .. (names[key] or key) .. ": " .. (Settings[key] and "ON" or "OFF"), 2)
    end
end

-- NOCLIP
local NoclipOriginalCollisions = {}
RunService.Stepped:Connect(function()
    if Settings.Noclip and LocalPlayer.Character then
        for _, p in ipairs(LocalPlayer.Character:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                NoclipOriginalCollisions[p] = true
                p.CanCollide = false
            end
        end
    end
end)

RestoreNoclip = function()
    for p, _ in pairs(NoclipOriginalCollisions) do
        if p and p.Parent then p.CanCollide = true end
    end
    NoclipOriginalCollisions = {}
end

-- AUTO LOOPS
local lastAntiAFK = 0

RunService.Heartbeat:Connect(function()
    local now = tick()
    
    if Settings.AntiAFK and now - lastAntiAFK >= 25 then
        lastAntiAFK = now
        if VirtualInputManager then
            task.spawn(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.RightShift, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.RightShift, false, game)
            end)
        end
    end
end)

-- KEYBINDS
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    
    if input.KeyCode == Enum.KeyCode.F2 then
        local sg = CoreGui and CoreGui:FindFirstChild("AshlySZA")
        if not sg then
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if pg then sg = pg:FindFirstChild("AshlySZA") end
        end
        if sg and sg:FindFirstChild("MainFrame") then
            sg.MainFrame.Visible = not sg.MainFrame.Visible
        end
    elseif input.KeyCode == Enum.KeyCode.K then
        ToggleSetting("KillAura")
    elseif input.KeyCode == Enum.KeyCode.N then
        ToggleSetting("Noclip")
    elseif input.KeyCode == Enum.KeyCode.L then
        ToggleSetting("AntiAFK")
    end
end)

-- VERIFY
local function VerifyKey(key)
    local s, r = pcall(function() return game:HttpGet("https://aged-wood-309e.gamaoashly6.workers.dev/?key=" .. key) end)
    if not s then return "ERROR" end
    return r:gsub("%s+", "")
end

-- MAIN GUI
local function MakeGUI()
    local p = nil
    pcall(function() if gethui then p = gethui() end end)
    if not p then p = CoreGui or LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui") end
    
    local sg = Instance.new("ScreenGui")
    sg.Name = "AshlySZA"
    sg.Parent = p
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local mf = Instance.new("Frame")
    mf.Name = "MainFrame"
    mf.Size = UDim2.new(0, 300, 0, 310)
    mf.Position = UDim2.new(0.5, -150, 0.1, 0)
    mf.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
    mf.Parent = sg
    Instance.new("UICorner", mf).CornerRadius = UDim.new(0, 10)
    local ms = Instance.new("UIStroke", mf)
    ms.Color = Color3.fromRGB(255, 50, 50)
    ms.Thickness = 2
    
    local ashlyBtn = Instance.new("TextButton", sg)
    ashlyBtn.Name = "AshlyToggle"
    ashlyBtn.Size = UDim2.new(0, 60, 0, 30)
    ashlyBtn.Position = UDim2.new(0.5, -30, 0, 10)
    ashlyBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    ashlyBtn.Text = "ASHLY"
    ashlyBtn.TextColor3 = Color3.fromRGB(255, 50, 50)
    ashlyBtn.TextSize = 12
    ashlyBtn.Font = Enum.Font.GothamBold
    ashlyBtn.BorderSizePixel = 0
    ashlyBtn.ZIndex = 10
    Instance.new("UICorner", ashlyBtn).CornerRadius = UDim.new(0, 8)
    local abStroke = Instance.new("UIStroke", ashlyBtn)
    abStroke.Thickness = 1.5
    abStroke.Color = Color3.fromRGB(255, 50, 50)
    
    ashlyBtn.MouseButton1Click:Connect(function()
        if mf then mf.Visible = not mf.Visible end
    end)
    
    local adrg, adri, ads, asp
    ashlyBtn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            adrg = true ads = i.Position asp = ashlyBtn.Position
            i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then adrg = false end end)
        end
    end)
    ashlyBtn.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then adri = i end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if i == adri and adrg then
            local d = i.Position - ads
            ashlyBtn.Position = UDim2.new(asp.X.Scale, asp.X.Offset + d.X, asp.Y.Scale, asp.Y.Offset + d.Y)
        end
    end)
    
    local tb = Instance.new("Frame", mf)
    tb.Size = UDim2.new(1, 0, 0, 38)
    tb.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 10)
    
    local title = Instance.new("TextLabel", tb)
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "ASHLY HUB"
    title.TextColor3 = Color3.fromRGB(255, 50, 50)
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    local cb = Instance.new("TextButton", tb)
    cb.Size = UDim2.new(0, 26, 0, 26)
    cb.Position = UDim2.new(1, -32, 0.5, -13)
    cb.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    cb.Text = "-"
    cb.TextColor3 = Color3.fromRGB(180, 180, 180)
    cb.TextSize = 18
    cb.Font = Enum.Font.GothamBold
    cb.BorderSizePixel = 0
    Instance.new("UICorner", cb).CornerRadius = UDim.new(0, 5)
    cb.MouseButton1Click:Connect(function()
        mf.Visible = false
        Announce("Press [F2] to open", 5)
    end)
    
    local drg, dri, ds, sp
    tb.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drg = true ds = i.Position sp = mf.Position
            i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then drg = false end end)
        end
    end)
    tb.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then dri = i end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if i == dri and drg then
            local d = i.Position - ds
            mf.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)
    
    local c = Instance.new("Frame", mf)
    c.Size = UDim2.new(1, -20, 1, -50)
    c.Position = UDim2.new(0, 10, 0, 44)
    c.BackgroundTransparency = 1
    
    local y = 5
    
    local function AddLabel(text)
        local l = Instance.new("TextLabel", c)
        l.Size = UDim2.new(1, 0, 0, 22)
        l.Position = UDim2.new(0, 0, 0, y)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = Color3.fromRGB(255, 80, 80)
        l.TextSize = 12
        l.Font = Enum.Font.GothamBold
        l.TextXAlignment = Enum.TextXAlignment.Left
        y = y + 24
    end
    
    local function AddToggle(name, key, setting)
        local f = Instance.new("Frame", c)
        f.Size = UDim2.new(1, 0, 0, 30)
        f.Position = UDim2.new(0, 0, 0, y)
        f.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4)
        
        local l = Instance.new("TextLabel", f)
        l.Size = UDim2.new(1, -45, 1, 0)
        l.Position = UDim2.new(0, 8, 0, 0)
        l.BackgroundTransparency = 1
        l.Text = name .. " [" .. key .. "]"
        l.TextColor3 = Color3.fromRGB(180, 180, 180)
        l.TextSize = 13
        l.Font = Enum.Font.Gotham
        l.TextXAlignment = Enum.TextXAlignment.Left
        
        local tog = Instance.new("Frame", f)
        tog.Size = UDim2.new(0, 24, 0, 13)
        tog.Position = UDim2.new(1, -32, 0.5, -6.5)
        tog.BackgroundColor3 = Settings[setting] and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(40, 40, 40)
        Instance.new("UICorner", tog).CornerRadius = UDim.new(0, 6.5)
        
        local cir = Instance.new("Frame", tog)
        cir.Size = UDim2.new(0, 9, 0, 9)
        cir.Position = Settings[setting] and UDim2.new(1, -11, 0.5, -4.5) or UDim2.new(0, 2, 0.5, -4.5)
        cir.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Instance.new("UICorner", cir).CornerRadius = UDim.new(0, 4.5)
        
        GUI_Toggles[setting] = {Frame = tog, Circle = cir}
        
        f.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                ToggleSetting(setting, true)
            end
        end)
        
        y = y + 34
    end
    
    AddLabel("-- COMBAT --")
    AddToggle("Kill Zombie", "K", "KillAura")
    
    AddLabel("-- UTILITY --")
    AddToggle("Noclip", "N", "Noclip")
    AddToggle("Anti AFK", "L", "AntiAFK")
    
    local ft = Instance.new("TextLabel", c)
    ft.Size = UDim2.new(1, 0, 0, 20)
    ft.Position = UDim2.new(0, 0, 0, y + 5)
    ft.BackgroundTransparency = 1
    ft.Text = "🔸discord.gg/uevZf2qtM"
    ft.TextColor3 = Color3.fromRGB(255, 200, 50)
    ft.TextSize = 10
    ft.Font = Enum.Font.Gotham
    
    if Settings.KillAura then StartKillAura() end
end

-- AUTH GUI
local function AuthGUI()
    local p = nil
    pcall(function() if gethui then p = gethui() end end)
    if not p then p = CoreGui or LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui") end
    
    local sg = Instance.new("ScreenGui")
    sg.Name = "AshlyAuth"
    sg.Parent = p
    
    local mf = Instance.new("Frame")
    mf.Size = UDim2.new(0, 340, 0, 240)
    mf.Position = UDim2.new(0.5, -170, 0.5, -120)
    mf.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
    mf.Parent = sg
    Instance.new("UICorner", mf).CornerRadius = UDim.new(0, 10)
    local st = Instance.new("UIStroke", mf)
    st.Color = Color3.fromRGB(255, 50, 50)
    st.Thickness = 2
    
    local t = Instance.new("TextLabel", mf)
    t.Size = UDim2.new(1, 0, 0, 28)
    t.Position = UDim2.new(0, 0, 0, 12)
    t.BackgroundTransparency = 1
    t.Text = "ASHLY HUB"
    t.TextColor3 = Color3.fromRGB(255, 255, 255)
    t.TextSize = 20
    t.Font = Enum.Font.GothamBold
    
    local s = Instance.new("TextLabel", mf)
    s.Size = UDim2.new(1, 0, 0, 18)
    s.Position = UDim2.new(0, 0, 0, 42)
    s.BackgroundTransparency = 1
    s.Text = "Kill Zombie | Noclip | Anti AFK"
    s.TextColor3 = Color3.fromRGB(160, 160, 160)
    s.TextSize = 13
    s.Font = Enum.Font.Gotham
    
    local savedL = Instance.new("TextLabel", mf)
    savedL.Size = UDim2.new(1, 0, 0, 16)
    savedL.Position = UDim2.new(0, 0, 0, 65)
    savedL.BackgroundTransparency = 1
    savedL.TextColor3 = Color3.fromRGB(100, 200, 100)
    savedL.TextSize = 11
    savedL.Font = Enum.Font.Gotham
    if SavedKey ~= "" then savedL.Text = "Saved key: " .. string.sub(SavedKey, 1, 12) .. "..." end
    
    local inp = Instance.new("TextBox", mf)
    inp.Size = UDim2.new(0, 280, 0, 36)
    inp.Position = UDim2.new(0.5, -140, 0, 90)
    inp.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    inp.PlaceholderText = "ASHLY-XXXXXXXX"
    inp.Text = SavedKey
    inp.TextColor3 = Color3.fromRGB(255, 255, 255)
    inp.TextSize = 14
    inp.Font = Enum.Font.GothamSemibold
    Instance.new("UICorner", inp).CornerRadius = UDim.new(0, 6)
    
    local statusL = Instance.new("TextLabel", mf)
    statusL.Size = UDim2.new(1, 0, 0, 18)
    statusL.Position = UDim2.new(0, 0, 0, 132)
    statusL.BackgroundTransparency = 1
    statusL.Text = ""
    statusL.TextColor3 = Color3.fromRGB(255, 50, 50)
    statusL.TextSize = 12
    statusL.Font = Enum.Font.GothamBold
    
    local btn = Instance.new("TextButton", mf)
    btn.Size = UDim2.new(0, 280, 0, 34)
    btn.Position = UDim2.new(0.5, -140, 0, 153)
    btn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    btn.Text = SavedKey ~= "" and "AUTO LOAD" or "VERIFY"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamBold
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
    local dc = Instance.new("TextButton", mf)
    dc.Size = UDim2.new(0, 280, 0, 28)
    dc.Position = UDim2.new(0.5, -140, 0, 196)
    dc.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
    dc.Text = "GET KEY (Discord)"
    dc.TextColor3 = Color3.fromRGB(255, 255, 255)
    dc.TextSize = 13
    dc.Font = Enum.Font.GothamBold
    Instance.new("UICorner", dc).CornerRadius = UDim.new(0, 6)
    dc.MouseButton1Click:Connect(function()
        pcall(function() setclipboard("https://discord.gg/uevZf2qtM") end)
        dc.Text = "COPIED!"
        task.wait(1)
        dc.Text = "GET KEY (Discord)"
    end)
    
    btn.MouseButton1Click:Connect(function()
        local key = inp.Text
        if key == "" then statusL.Text = "Enter a key" statusL.TextColor3 = Color3.fromRGB(255, 50, 50) return end
        btn.Text = "CHECKING..."
        local r = VerifyKey(key)
        if r == "VALID" then
            statusL.Text = "ACCESS GRANTED!"
            statusL.TextColor3 = Color3.fromRGB(50, 255, 50)
            if writefile then pcall(function() writefile(KEY_FILE, key) end) SavedKey = key end
            task.wait(0.8)
            sg:Destroy()
            MakeGUI()
        elseif r == "ERROR" then
            statusL.Text = "Server error"
            statusL.TextColor3 = Color3.fromRGB(255, 50, 50)
        else
            statusL.Text = "Invalid key"
            statusL.TextColor3 = Color3.fromRGB(255, 50, 50)
        end
        btn.Text = "VERIFY"
    end)
    
    if SavedKey ~= "" then
        task.spawn(function()
            task.wait(0.3)
            statusL.Text = "Auto-verifying..."
            statusL.TextColor3 = Color3.fromRGB(255, 200, 50)
            local r = VerifyKey(SavedKey)
            if r == "VALID" then
                statusL.Text = "ACCESS GRANTED!"
                statusL.TextColor3 = Color3.fromRGB(50, 255, 50)
                task.wait(0.8)
                sg:Destroy()
                MakeGUI()
            else
                savedL.Text = "Saved key expired"
                savedL.TextColor3 = Color3.fromRGB(255, 200, 50)
            end
        end)
    end
end

AuthGUI()
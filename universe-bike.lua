-- =====================================================================
-- UNIVERSE BIKE // LIGHTWEIGHT STABLE EDITION
-- Target Position: Vector3.new(5344.32, 3.5, 493.93)
-- Author: NostraTeam
-- =====================================================================

local TARGET_POSITION = Vector3.new(5344.32, 3.5, 493.93)
local TARGET_CFRAME = CFrame.new(TARGET_POSITION) * CFrame.Angles(0, math.rad(-90), 0)

-- Services
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local SystemActive = true
local HasTeleported = false
local Connection = nil
local RespawnConnection = nil

-- Performance & Cache Variables
local CachedVehicle = nil
local CachedSeat = nil
local LastSearchTick = 0

-- Customization Variables
local ToggleKey = Enum.KeyCode.K
local IsListeningForKey = false
local StartTime = tick()

-- Safe GUI Initialization (No gethui dependency to prevent crashes)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "UB_CoreSystemLight"
ScreenGui.ResetOnSpawn = false

if syn and syn.protect_gui then
    syn.protect_gui(ScreenGui)
    ScreenGui.Parent = CoreGui
elseif protectgui then
    protectgui(ScreenGui)
    ScreenGui.Parent = CoreGui
else
    ScreenGui.Parent = CoreGui
end

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 23)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Position = UDim2.new(0.5, 0, 0.35, 0)
MainFrame.Size = UDim2.new(0, 320, 0, 145)
MainFrame.Active = true
MainFrame.Draggable = true

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Parent = MainFrame
MainStroke.Color = Color3.fromRGB(45, 48, 66)
MainStroke.Thickness = 1.2

-- Header
local Header = Instance.new("Frame")
Header.Parent = MainFrame
Header.BackgroundTransparency = 1
Header.Position = UDim2.new(0, 12, 0, 8)
Header.Size = UDim2.new(1, -24, 0, 26)

local AppTitle = Instance.new("TextLabel")
AppTitle.Parent = Header
AppTitle.BackgroundTransparency = 1
AppTitle.Size = UDim2.new(1, -30, 1, 0)
AppTitle.Font = Enum.Font.GothamBold
AppTitle.Text = "❖ UNIVERSE BIKE | By: NostraTeam"
AppTitle.TextColor3 = Color3.fromRGB(225, 228, 240)
AppTitle.TextSize = 12
AppTitle.TextXAlignment = Enum.TextXAlignment.Left

local CloseBtn = Instance.new("TextButton")
CloseBtn.Parent = Header
CloseBtn.BackgroundTransparency = 1
CloseBtn.Position = UDim2.new(1, -22, 0, 2)
CloseBtn.Size = UDim2.new(0, 22, 0, 22)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(130, 135, 155)
CloseBtn.TextSize = 12

-- Divider
local Divider = Instance.new("Frame")
Divider.Parent = MainFrame
Divider.BackgroundColor3 = Color3.fromRGB(30, 33, 48)
Divider.BorderSizePixel = 0
Divider.Position = UDim2.new(0, 12, 0, 38)
Divider.Size = UDim2.new(1, -24, 0, 1)

-- Status Box
local StatusBox = Instance.new("Frame")
StatusBox.Parent = MainFrame
StatusBox.BackgroundColor3 = Color3.fromRGB(20, 23, 33)
StatusBox.Position = UDim2.new(0, 12, 0, 46)
StatusBox.Size = UDim2.new(1, -24, 0, 52)

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 8)
StatusCorner.Parent = StatusBox

local StatusStroke = Instance.new("UIStroke")
StatusStroke.Parent = StatusBox
StatusStroke.Color = Color3.fromRGB(138, 43, 226)
StatusStroke.Thickness = 1.2

local StateBadge = Instance.new("Frame")
StateBadge.Parent = StatusBox
StateBadge.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
StateBadge.Position = UDim2.new(0, 12, 0.5, -5)
StateBadge.Size = UDim2.new(0, 10, 0, 10)

local BadgeCorner = Instance.new("UICorner")
BadgeCorner.CornerRadius = UDim.new(1, 0)
BadgeCorner.Parent = StateBadge

local MainText = Instance.new("TextLabel")
MainText.Parent = StatusBox
MainText.BackgroundTransparency = 1
MainText.Position = UDim2.new(0, 32, 0, 9)
MainText.Size = UDim2.new(1, -40, 0, 16)
MainText.Font = Enum.Font.GothamBold
MainText.Text = "SAFE & LIGHTWEIGHT"
MainText.TextColor3 = Color3.fromRGB(240, 242, 250)
MainText.TextSize = 11
MainText.TextXAlignment = Enum.TextXAlignment.Left

local SubText = Instance.new("TextLabel")
SubText.Parent = StatusBox
SubText.BackgroundTransparency = 1
SubText.Position = UDim2.new(0, 32, 0, 26)
SubText.Size = UDim2.new(1, -40, 0, 16)
SubText.Font = Enum.Font.Gotham
SubText.Text = "Anti-Crash Mode Active"
SubText.TextColor3 = Color3.fromRGB(120, 125, 145)
SubText.TextSize = 10
SubText.TextXAlignment = Enum.TextXAlignment.Left

-- Footer Info Bar
local InfoBar = Instance.new("Frame")
InfoBar.Parent = MainFrame
InfoBar.BackgroundTransparency = 1
InfoBar.Position = UDim2.new(0, 12, 0, 106)
InfoBar.Size = UDim2.new(1, -24, 0, 26)

local RuntimeText = Instance.new("TextLabel")
RuntimeText.Parent = InfoBar
RuntimeText.BackgroundTransparency = 1
RuntimeText.Size = UDim2.new(0, 140, 1, 0)
RuntimeText.Font = Enum.Font.GothamMedium
RuntimeText.Text = "Runtime: 00:00"
RuntimeText.TextColor3 = Color3.fromRGB(140, 145, 165)
RuntimeText.TextSize = 10
RuntimeText.TextXAlignment = Enum.TextXAlignment.Left

local KeybindBtn = Instance.new("TextButton")
KeybindBtn.Parent = InfoBar
KeybindBtn.BackgroundColor3 = Color3.fromRGB(25, 28, 40)
KeybindBtn.Position = UDim2.new(1, -110, 0, 0)
KeybindBtn.Size = UDim2.new(0, 110, 0, 22)
KeybindBtn.Font = Enum.Font.GothamBold
KeybindBtn.Text = "Key: [ K ]"
KeybindBtn.TextColor3 = Color3.fromRGB(200, 205, 220)
KeybindBtn.TextSize = 10

local KeybindCorner = Instance.new("UICorner")
KeybindCorner.CornerRadius = UDim.new(0, 6)
KeybindCorner.Parent = KeybindBtn

-- Vehicle Caching Logic
local function getVehicleModel()
    local char = LocalPlayer.Character
    if not char then return nil end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.SeatPart then
        CachedVehicle = humanoid.SeatPart.Parent
        return CachedVehicle
    end
    
    if CachedVehicle and CachedVehicle.Parent then
        return CachedVehicle
    end

    if tick() - LastSearchTick > 1 then
        LastSearchTick = tick()
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Model") and (obj:FindFirstChildOfClass("VehicleSeat") or obj:FindFirstChildOfClass("Seat")) then
                    local primary = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
                    if primary and (primary.Position - hrp.Position).Magnitude < 35 then
                        CachedVehicle = obj
                        return obj
                    end
                end
            end
        end
    end
    return nil
end

local function getVehicleSeat()
    local char = LocalPlayer.Character
    if not char then return nil end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.SeatPart and humanoid.SeatPart:IsA("VehicleSeat") then
        CachedSeat = humanoid.SeatPart
        return CachedSeat
    end
    if CachedSeat and CachedSeat.Parent then
        return CachedSeat
    end
    return nil
end

local function Shutdown()
    SystemActive = false
    if Connection then
        Connection:Disconnect()
        Connection = nil
    end
    if RespawnConnection then
        RespawnConnection:Disconnect()
        RespawnConnection = nil
    end
    pcall(function()
        local seat = getVehicleSeat()
        if seat then seat.Throttle = 0 end
    end)
    ScreenGui:Destroy()
end

CloseBtn.MouseButton1Click:Connect(Shutdown)

-- Safe Teleport Handler (No VirtualInputManager to prevent crashes)
local function TryTeleport()
    if HasTeleported then return end
    local vehicle = getVehicleModel()
    if vehicle then
        pcall(function()
            if vehicle:IsA("Model") then
                vehicle:PivotTo(TARGET_CFRAME)
                for _, part in ipairs(vehicle:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    end
                end
            elseif vehicle:IsA("BasePart") then
                vehicle.CFrame = TARGET_CFRAME
                vehicle.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                vehicle.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end
        end)
        HasTeleported = true
        SubText.Text = "Teleported Safely"
    end
end

-- Runtime Timer Updater
task.spawn(function()
    while task.wait(1) do
        if SystemActive then
            local diff = math.floor(tick() - StartTime)
            local mins = math.floor(diff / 60)
            local secs = diff % 60
            RuntimeText.Text = string.format("Runtime: %02d:%02d", mins, secs)
        end
    end
end)

-- Lightweight Throttle Loop (Direct Vehicle Seat Control - Undetected)
local ThrottleCounter = 0
Connection = RunService.Heartbeat:Connect(function()
    if SystemActive then
        if not HasTeleported then
            TryTeleport()
        end
        
        ThrottleCounter = ThrottleCounter + 1
        if ThrottleCounter % 2 == 0 then
            pcall(function()
                local seat = getVehicleSeat()
                if seat then 
                    seat.Throttle = 1 
                end
            end)
        end
    end
end)

RespawnConnection = LocalPlayer.CharacterAdded:Connect(function()
    HasTeleported = false
    CachedVehicle = nil
    CachedSeat = nil
    SubText.Text = "Re-syncing vehicle..."
end)

local function ToggleState()
    SystemActive = not SystemActive

    if SystemActive then
        HasTeleported = false
        StateBadge.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
        StatusStroke.Color = Color3.fromRGB(138, 43, 226)
        MainText.Text = "SAFE & LIGHTWEIGHT"
        MainText.TextColor3 = Color3.fromRGB(240, 242, 250)
        SubText.Text = "System resumed"
    else
        StateBadge.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
        StatusStroke.Color = Color3.fromRGB(50, 52, 65)
        MainText.Text = "SYSTEM: PAUSED"
        MainText.TextColor3 = Color3.fromRGB(150, 155, 170)
        SubText.Text = "Paused by user"

        pcall(function()
            local seat = getVehicleSeat()
            if seat then seat.Throttle = 0 end
        end)
    end
end

KeybindBtn.MouseButton1Click:Connect(function()
    IsListeningForKey = true
    KeybindBtn.Text = "Press any key..."
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if IsListeningForKey then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            ToggleKey = input.KeyCode
            KeybindBtn.Text = "Key: [ " .. tostring(ToggleKey.Name) .. " ]"
            IsListeningForKey = false
            SubText.Text = "Key updated"
        end
        return
    end

    if gameProcessed then return end
    if input.KeyCode == ToggleKey then
        ToggleState()
    end
end)

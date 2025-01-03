local repo = "https://raw.githubusercontent.com/deividcomsono/LinoriaLib/refs/heads/main/"
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Window = Library:CreateWindow({
    Title = 'Grass Cutting Simulator',
    Center = true,
    AutoShow = true,
    Resizable = true,
    NotifySide = "Right",
    ShowCustomCursor = false,
    TabPadding = 2,
    MenuFadeTime = 0
})


-- Add Tabs
local Tabs = {
    Main = Window:AddTab('Main'),
    Extra = Window:AddTab('Extra'),  -- Tab for FOV settings
    UI_Settings = Window:AddTab('UI Settings'),
}

local LeftGroupBox = Tabs.Main:AddLeftGroupbox('Walk Path')
local FOVGroupBox = Tabs.Extra:AddLeftGroupbox('Field of View Settings') -- Group box for FOV
local ChangeDistanceGroupBox = Tabs.Extra:AddLeftGroupbox('Change Distance') -- New group box for Camera Max Zoom
local Groupbox = Tabs.Main:AddLeftGroupbox('Tool sizer')

-- Trolling group box
local TrollingGroupBox = Tabs.Extra:AddLeftGroupbox('Trolling') -- New Trolling GroupBox

-- Button to freeze the screen for 5 seconds
TrollingGroupBox:AddButton({
    Text = 'Freeze Screen for 5 sec',
    Func = function()
        print("Freezing screen for 5 seconds.")

        -- Create a blocking overlay
        local overlay = Instance.new("ScreenGui", game.Players.LocalPlayer:WaitForChild("PlayerGui"))
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 1, 0) -- Full screen
        frame.AnchorPoint = Vector2.new(0.5, 0.5) -- Center the frame
        frame.Position = UDim2.new(0.5, 0, 0.5, 0) -- Center the frame
        frame.BackgroundColor3 = Color3.new(0, 0, 0) -- Solid black color
        frame.BackgroundTransparency = 0 -- Opaque
        frame.Parent = overlay
        frame.ZIndex = 10 -- Make sure it appears above other elements

        -- Wait for the desired freezing duration
        wait(5) 

        overlay:Destroy() -- Remove the overlay
        print("Screen has been unfrozen.")
    end
})

-- Variables for FOV
local playerCamera = game:GetService("Workspace").CurrentCamera
local defaultFOV = 70 -- Default FOV value
local fovSlider -- Variable to store the FOV slider instance

-- FOV Slider
fovSlider = FOVGroupBox:AddSlider('FOVSlider', {
    Text = 'Field of View',
    Default = defaultFOV,
    Min = 1,
    Max = 120,
    Rounding = 0,
    Callback = function(Value)
        playerCamera.FieldOfView = Value
        print("Field of View set to:", Value)
    end,
})

FOVGroupBox:AddButton({
    Text = 'Reset FOV',
    Func = function()
        playerCamera.FieldOfView = defaultFOV -- Reset camera FOV
        fovSlider:SetValue(defaultFOV) -- Reset slider value
    end,
})


local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- Initialize grassObjects here

-- Variables for action loop
local actionEnabled = false -- To track when the action loop is running
local actionInterval = 1 -- Default interval for actions
local actionCoroutine = nil -- Track action coroutine

-- Variables for path following
local pathPoints = {}
local lineParts = {}
local delayTime = 0 
local delayEnabled = false
local repeatPathEnabled = false

-- Variable to determine if teleportation to grass objects is enabled
local teleportToGrassEnabled = false
local teleportSpeed = 1 -- Default speed multiplier for teleportation
local teleportRange = 50 -- Default teleport range
local teleportCoroutine = nil -- Track the teleportation coroutine

-- Function to continuously teleport to grass objects
local function startTeleportation()
    -- Only start a new coroutine if it's not already running
    if not teleportCoroutine then
        teleportCoroutine = coroutine.create(function()
            while teleportToGrassEnabled do
                -- Get the player's humanoid root part for teleportation
                local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
                local currentPosition = humanoidRootPart.Position
                
                -- Boolean to track if we teleported during this loop
                local didTeleport = false
                
                -- Check for grassObjects
                if grassObjects and grassObjects:IsA("Folder") then
                    -- Loop through all children in GrassObjects
                    for _, object in ipairs(grassObjects:GetChildren()) do
                        if object.Name == "g" then
                            local distance = (object.Position - currentPosition).Magnitude
                            if distance <= teleportRange then
                                humanoidRootPart.CFrame = object.CFrame
                                didTeleport = true -- Mark that we have teleported
                                wait(0) -- Yield briefly to let the teleportation occur
                            end
                        end
                    end
                else
                    warn("grassObjects is not defined or not a Folder.")
                end
                
                if didTeleport then
                    wait(teleportSpeed) -- Wait for the teleport speed duration after a teleport occurs
                else
                    wait(0.1) -- Brief wait if no teleportation occurred
                end
            end
            teleportCoroutine = nil -- Reset the teleport coroutine when done
        end)
        coroutine.resume(teleportCoroutine)
    end
end

local function drawPath()
    if #pathPoints < 2 then return end

    local startPoint = pathPoints[#pathPoints - 1]
    local endPoint = pathPoints[#pathPoints]
    local line = Instance.new("Part")

    line.Size = Vector3.new(0.4, 0.4, (endPoint - startPoint).Magnitude)
    line.Anchored = true
    line.BrickColor = BrickColor.new("Bright blue")
    line.Material = Enum.Material.Neon
    line.Position = (startPoint + endPoint) / 2
    line.CFrame = CFrame.lookAt(line.Position, endPoint)
    line.Parent = workspace

    line.CanCollide = false

    table.insert(lineParts, line)
end

-- Function to move the avatar along the path
local function followPath(reverse)
    local humanoid = character:FindFirstChildOfClass("Humanoid")

    if not humanoid then
        print("No humanoid found!")
        return
    end

    local pointsToFollow = (reverse and pathPoints) or pathPoints

    for i = (reverse and #pointsToFollow or 1), (reverse and 1 or #pointsToFollow), (reverse and -1 or 1) do
        local currentPoint = pointsToFollow[i]

        humanoid:MoveTo(currentPoint)
        local reached = humanoid.MoveToFinished:Wait()

        if delayEnabled then
            wait(delayTime)
        end

        if not reached then
            print("Movement not completed to point:", currentPoint)
            break
        end
    end

    print("Path followed!")
end

-- Function to start the action loop
local function startActionLoop()
    if actionCoroutine then return end -- Prevent starting a new loop if already running

    actionCoroutine = coroutine.create(function()
        while actionEnabled do
            actionToLoop() -- Execute the action
            wait(actionInterval) -- Wait for the specified interval
        end
    end)
    coroutine.resume(actionCoroutine)
end

local sizeValue = 1 -- Default size value

-- Slider to set size
Groupbox:AddSlider("ToolSize", {
    Text = "Size Multiplier",
    Default = sizeValue,
    Min = 1,
    Max = 500,
    Rounding = 0,

    Callback = function(value)
        sizeValue = value
    end
})

-- Button to confirm size change
-- Button to confirm size change
Groupbox:AddButton("Confirm Size Change", function()
    local toolFound = false

    -- Check each tool in the backpack
    for _, tool in ipairs(Players.LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            -- Directly resize the tool's TOUCH if it exists
            local TOUCH = tool:FindFirstChild("TOUCH")
            if TOUCH and TOUCH:IsA("BasePart") then
                toolFound = true
                -- Set the size of the TOUCH part to the confirmed size
                TOUCH.Size = Vector3.new(sizeValue, sizeValue, sizeValue)
                Library:Notify("Size updated to: " .. tostring(sizeValue) .. " for tool: " .. tool.Name) -- Notify user
            end
        end
    end
    
    if not toolFound then
        Library:Notify("Please dont equip your mower for it to change the size!")
    end
end)

-- Slider for walk speed
LeftGroupBox:AddSlider('WalkSpeedSlider', {
    Text = 'Walk Speed',
    Default = 16,
    Min = 16,
    Max = 100,
    Rounding = 0,
    Callback = function(Value)
        if character:FindFirstChildOfClass("Humanoid") then
            character:FindFirstChildOfClass("Humanoid").WalkSpeed = Value
        end
    end
})

-- Checkbox to enable delay
LeftGroupBox:AddToggle('DelayToggle', {
    Text = 'Enable Delay',
    Default = false,
    Tooltip = 'Enable this to set a delay between points.',
    Callback = function(Value)
        delayEnabled = Value
    end
})

-- Slider to set delay time
LeftGroupBox:AddSlider('DelaySlider', {
    Text = 'Delay Time (s)',
    Default = 0,
    Min = 0,
    Max = 5,
    Rounding = 1,
    Callback = function(Value)
        if Value < 0 then Value = 0 end
        delayTime = Value
    end,
})

-- Checkbox to repeat the path
LeftGroupBox:AddToggle('RepeatPathToggle', {
    Text = 'Repeat Path',
    Default = false,
    Tooltip = 'Enable this to repeat the path without removing it.',
    Callback = function(Value)
        repeatPathEnabled = Value
        if repeatPathEnabled then
            coroutine.wrap(function()
                while repeatPathEnabled do
                    if #pathPoints > 1 then
                        followPath() -- Go forward
                        followPath(true) -- Go backward
                    else
                        print("Add more points to the path.")
                    end
                    wait(delayTime) -- Wait between repetitions
                end
            end)() -- Start the loop in a coroutine
        end
    end
})

-- Reset path
LeftGroupBox:AddButton({
    Text = 'Reset Path',
    Func = function()
        pathPoints = {}
        for _, line in ipairs(lineParts) do
            line:Destroy()
        end
        lineParts = {}
        print("Path cleared!")
    end,
})

-- Add current position to the path
LeftGroupBox:AddButton({
    Text = 'Add Point to Path',
    Func = function()
        local position = character.HumanoidRootPart.Position
        table.insert(pathPoints, position)
        drawPath()
        print("Point added:", position)
    end,
})

-- Add the Camera Max Zoom Distance Slider to the Change Distance group box
local camZoomSlider -- Variable to store the Camera Max Zoom Distance slider instance
camZoomSlider = ChangeDistanceGroupBox:AddSlider('CameraMaxZoomDistanceSlider', {
    Text = 'Max Camera Zoom Distance',
    Default = player.CameraMaxZoomDistance, -- Set default to the current value
    Min = 0.5,
    Max = 10000,
    Rounding = 0,
    Callback = function(Value)
        player.CameraMaxZoomDistance = Value -- Update max zoom distance
        print("Camera Max Zoom Distance set to:", Value)
    end,
})

ChangeDistanceGroupBox:AddButton({
    Text = 'Reset Cam Zoom Distance',
    Func = function()
        player.CameraMaxZoomDistance = 128 -- Reset Camera Max Zoom Distance
        camZoomSlider:SetValue(128) -- Reset slider value
    end,
})



-- UI settings tab
local MenuGroup = Tabs.UI_Settings:AddLeftGroupbox('Menu Options')
MenuGroup:AddButton('Unload', function() Library:Unload() end)

MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })

Library.ToggleKeybind = Options.MenuKeybind

-- OnUnload function
Library:OnUnload(function()
    print('Unloaded!')
    Library.Unloaded = true
end)

-- Hand the library over to our managers
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

-- Build our configuration menu on the right side of our tab
SaveManager:SetFolder('MyScriptHub/specific-game')
SaveManager:BuildConfigSection(Tabs['UI Settings'])

-- Build our theme menu on the left side
ThemeManager:ApplyToTab(Tabs['UI Settings'])

-- Load the autoload configuration
SaveManager:LoadAutoloadConfig()
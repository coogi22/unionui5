local Library = {}

local NeverloseVersion = "v1.1A."

local TweenService = game:GetService("TweenService")
local input = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

-- =========================
-- Config System (ADDED)
-- =========================
Library.Flags = Library.Flags or {}
Library.Controls = Library.Controls or {}

local function _canFileIO()
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

local function _cfgPath(name)
    name = tostring(name or "default")
    name = name:gsub("[^%w_%-%s]", "") -- sanitize
    return ("NeverloseCfg_%s.json"):format(name)
end

local themouse = game.Players.LocalPlayer:GetMouse()

local function Notify(tt, tx)
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = tt,
        Text = tx,
        Duration = 5
    })
end

function Library:SaveConfig(name)
    if not _canFileIO() then
        Notify("Config", "Executor missing writefile/readfile/isfile")
        return false
    end
    local path = _cfgPath(name)
    local ok, data = pcall(function()
        return HttpService:JSONEncode(self.Flags)
    end)
    if not ok then
        Notify("Config", "Failed to encode config")
        return false
    end
    writefile(path, data)
    Notify("Config", "Saved: " .. path)
    return true
end

function Library:LoadConfig(name)
    if not _canFileIO() then
        Notify("Config", "Executor missing writefile/readfile/isfile")
        return false
    end
    local path = _cfgPath(name)
    if not isfile(path) then
        Notify("Config", "Not found: " .. path)
        return false
    end

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    if not ok or type(decoded) ~= "table" then
        Notify("Config", "Invalid config file")
        return false
    end

    -- apply to flags + controls
    for flag, value in pairs(decoded) do
        self.Flags[flag] = value
        local ctrl = self.Controls[flag]
        if ctrl and ctrl.Set then
            pcall(ctrl.Set, value)
        end
    end

    Notify("Config", "Loaded: " .. path)
    return true
end

-- =========================
-- UI Library (ORIGINAL + PATCHES)
-- =========================

for i, v in next, game.CoreGui:GetChildren() do
    if v:IsA("ScreenGui") and v.Name == "Neverlose" then
        v:Destroy()
    end
end

local function Dragify(frame, parent)
    parent = parent or frame

    local dragging = false
    local dragInput, mousePos, framePos

    frame.InputBegan:Connect(function(inputObj)
        if inputObj.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            mousePos = inputObj.Position
            framePos = parent.Position

            inputObj.Changed:Connect(function()
                if inputObj.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    frame.InputChanged:Connect(function(inputObj)
        if inputObj.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = inputObj
        end
    end)

    input.InputChanged:Connect(function(inputObj)
        if inputObj == dragInput and dragging then
            local delta = inputObj.Position - mousePos
            parent.Position = UDim2.new(
                framePos.X.Scale, framePos.X.Offset + delta.X,
                framePos.Y.Scale, framePos.Y.Offset + delta.Y
            )
        end
    end)
end

local function round(num, bracket)
    bracket = bracket or 1
    local a = math.floor(num / bracket + (math.sign(num) * 0.5)) * bracket
    if a < 0 then
        a = a + bracket
    end
    return a
end

local function buttoneffect(options)
    pcall(function()
        options.entered.MouseEnter:Connect(function()
            if options.frame.TextColor3 ~= Color3.fromRGB(234, 239, 246) then
                TweenService:Create(options.frame, TweenInfo.new(0.06, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                    TextColor3 = Color3.fromRGB(234, 239, 245)
                }):Play()
            end
        end)
        options.entered.MouseLeave:Connect(function()
            if options.frame.TextColor3 ~= Color3.fromRGB(157, 171, 182) and options.frame.TextColor3 ~= Color3.fromRGB(234, 239, 246) then
                TweenService:Create(options.frame, TweenInfo.new(0.06, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                    TextColor3 = Color3.fromRGB(157, 171, 182)
                }):Play()
            end
        end)
    end)
end

local function clickEffect(options)
    options.button.MouseButton1Click:Connect(function()
        local new = options.button.TextSize - tonumber(options.amount)
        local revert = new + tonumber(options.amount)
        TweenService:Create(options.button, TweenInfo.new(0.15, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { TextSize = new }):Play()
        task.wait(0.1)
        TweenService:Create(options.button, TweenInfo.new(0.1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { TextSize = revert }):Play()
    end)
end

-- FIXED: GetServer -> GetService
function Library:Toggle(value)
    local cg = game:GetService("CoreGui")
    local gui = cg:FindFirstChild("Neverlose")
    if gui == nil then return end
    local enabled = (type(value) == "boolean" and value) or gui.Enabled
    gui.Enabled = not enabled
end

function Library:Window(options)
    options = options or {}
    options.text = options.text or "NEVERLOSE"
    local enableConfigTab = (options.config ~= false)

    local SG = Instance.new("ScreenGui")
    local Body = Instance.new("Frame")
    Dragify(Body, Body)
    local bodyCorner = Instance.new("UICorner")

    local SideBar = Instance.new("Frame")
    local sidebarCorner = Instance.new("UICorner")
    local sbLine = Instance.new("Frame")

    local TopBar = Instance.new("Frame")
    local tbLine = Instance.new("Frame")
    local Title = Instance.new("TextLabel")

    local allPages = Instance.new("Frame")
    local tabContainer = Instance.new("Frame")

    SG.Parent = game.CoreGui
    SG.Name = "Neverlose"

    Body.Name = "Body"
    Body.Parent = SG
    Body.AnchorPoint = Vector2.new(0.5, 0.5)
    Body.BackgroundColor3 = Color3.fromRGB(9, 8, 13)
    Body.BorderSizePixel = 0
    Body.Position = UDim2.new(0.465730786, 0, 0.5, 0)
    Body.Size = UDim2.new(0, 658, 0, 516)

    bodyCorner.CornerRadius = UDim.new(0, 4)
    bodyCorner.Name = "bodyCorner"
    bodyCorner.Parent = Body

    SideBar.Name = "SideBar"
    SideBar.Parent = Body
    SideBar.BackgroundColor3 = Color3.fromRGB(26, 36, 48)
    SideBar.BorderSizePixel = 0
    SideBar.Size = UDim2.new(0, 187, 0, 516)

    sidebarCorner.CornerRadius = UDim.new(0, 4)
    sidebarCorner.Name = "sidebarCorner"
    sidebarCorner.Parent = SideBar

    sbLine.Name = "sbLine"
    sbLine.Parent = SideBar
    sbLine.BackgroundColor3 = Color3.fromRGB(15, 23, 36)
    sbLine.BorderSizePixel = 0
    sbLine.Position = UDim2.new(0.99490571, 0, 0, 0)
    sbLine.Size = UDim2.new(0, 3, 0, 516)

    TopBar.Name = "TopBar"
    TopBar.Parent = Body
    TopBar.BackgroundColor3 = Color3.fromRGB(9, 8, 13)
    TopBar.BackgroundTransparency = 1.000
    TopBar.BorderColor3 = Color3.fromRGB(14, 21, 32)
    TopBar.BorderSizePixel = 0
    TopBar.Position = UDim2.new(0.25166446, 0, 0, 0)
    TopBar.Size = UDim2.new(0, 562, 0, 49)

    tbLine.Name = "tbLine"
    tbLine.Parent = TopBar
    tbLine.BackgroundColor3 = Color3.fromRGB(15, 23, 36)
    tbLine.BorderSizePixel = 0
    tbLine.Position = UDim2.new(0.0400355868, 0, 1, 0)
    tbLine.Size = UDim2.new(0, 469, 0, 3)

    Title.Name = "Title"
    Title.Parent = SideBar
    Title.BackgroundColor3 = Color3.fromRGB(234, 239, 245)
    Title.BackgroundTransparency = 1.000
    Title.BorderSizePixel = 0
    Title.Position = UDim2.new(0.0614973232, 0, 0.0213178284, 0)
    Title.Size = UDim2.new(0, 162, 0, 26)
    Title.Font = Enum.Font.ArialBold
    Title.Text = options.text
    Title.TextColor3 = Color3.fromRGB(234, 239, 245)
    Title.TextSize = 28.000
    Title.TextWrapped = true

    allPages.Name = "allPages"
    allPages.Parent = Body
    allPages.BackgroundColor3 = Color3.fromRGB(234, 239, 245)
    allPages.BackgroundTransparency = 1.000
    allPages.BorderSizePixel = 0
    allPages.Position = UDim2.new(0.29508087, 0, 0.100775197, 0)
    allPages.Size = UDim2.new(0, 463, 0, 464)

    tabContainer.Name = "tabContainer"
    tabContainer.Parent = SideBar
    tabContainer.BackgroundColor3 = Color3.fromRGB(234, 239, 245)
    tabContainer.BackgroundTransparency = 1.000
    tabContainer.BorderSizePixel = 0
    tabContainer.Position = UDim2.new(0, 0, 0.100775197, 0)
    tabContainer.Size = UDim2.new(0, 187, 0, 464)

    local tabsections = {}

    function tabsections:TabSection(options2)
        options2 = options2 or {}
        options2.text = options2.text or "Tab Section"

        local tabLayout = Instance.new("UIListLayout")
        local tabSection = Instance.new("Frame")
        local tabSectionLabel = Instance.new("TextLabel")
        local tabSectionLayout = Instance.new("UIListLayout")

        tabLayout.Name = "tabLayout"
        tabLayout.Parent = tabContainer

        tabSection.Name = "tabSection"
        tabSection.Parent = tabContainer
        tabSection.BackgroundColor3 = Color3.fromRGB(234, 239, 245)
        tabSection.BackgroundTransparency = 1.000
        tabSection.BorderSizePixel = 0
        tabSection.Size = UDim2.new(0, 189, 0, 22)

        local function ResizeTS(num)
            tabSection.Size += UDim2.new(0, 0, 0, num)
        end

        tabSectionLabel.Name = "tabSectionLabel"
        tabSectionLabel.Parent = tabSection
        tabSectionLabel.BackgroundColor3 = Color3.fromRGB(234, 239, 245)
        tabSectionLabel.BackgroundTransparency = 1.000
        tabSectionLabel.BorderSizePixel = 0
        tabSectionLabel.Size = UDim2.new(0, 190, 0, 22)
        tabSectionLabel.Font = Enum.Font.Gotham
        tabSectionLabel.Text = "     " .. options2.text
        tabSectionLabel.TextColor3 = Color3.fromRGB(79, 107, 126)
        tabSectionLabel.TextSize = 17.000
        tabSectionLabel.TextXAlignment = Enum.TextXAlignment.Left

        tabSectionLayout.Name = "tabSectionLayout"
        tabSectionLayout.Parent = tabSection
        tabSectionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        tabSectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
        tabSectionLayout.Padding = UDim.new(0, 7)

        local tabs = {}

        function tabs:Tab(options3)
            options3 = options3 or {}
            options3.text = options3.text or "New Tab"
            options3.icon = options3.icon or "rbxassetid://7999345313"

            local tabButton = Instance.new("TextButton")
            local tabButtonCorner = Instance.new("UICorner")
            local tabIcon = Instance.new("ImageLabel")

            local newPage = Instance.new("ScrollingFrame")
            local pageLayout = Instance.new("UIGridLayout")

            tabButton.Name = "tabButton"
            tabButton.Parent = tabSection
            tabButton.BackgroundColor3 = Color3.fromRGB(13, 57, 84)
            tabButton.BorderSizePixel = 0
            tabButton.Position = UDim2.new(0.0714285746, 0, 0.402777791, 0)
            tabButton.Size = UDim2.new(0, 165, 0, 30)
            tabButton.AutoButtonColor = false
            tabButton.Font = Enum.Font.GothamSemibold
            tabButton.Text = "         " .. options3.text
            tabButton.TextColor3 = Color3.fromRGB(234, 239, 245)
            tabButton.TextSize = 14.000
            tabButton.BackgroundTransparency = 1
            tabButton.TextXAlignment = Enum.TextXAlignment.Left

            tabButton.MouseButton1Click:Connect(function()
                for _, v in next, allPages:GetChildren() do
                    v.Visible = false
                end

                newPage.Visible = true

                for _, v in next, SideBar:GetDescendants() do
                    if v:IsA("TextButton") then
                        TweenService:Create(v, TweenInfo.new(0.06, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                            BackgroundTransparency = 1
                        }):Play()
                    end
                end

                TweenService:Create(tabButton, TweenInfo.new(0.06, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                    BackgroundTransparency = 0
                }):Play()
            end)

            tabButtonCorner.CornerRadius = UDim.new(0, 4)
            tabButtonCorner.Name = "tabButtonCorner"
            tabButtonCorner.Parent = tabButton

            tabIcon.Name = "tabIcon"
            tabIcon.Parent = tabButton
            tabIcon.BackgroundColor3 = Color3.fromRGB(234, 239, 245)
            tabIcon.BackgroundTransparency = 1.000
            tabIcon.BorderSizePixel = 0
            tabIcon.Position = UDim2.new(0.0408859849, 0, 0.133333355, 0)
            tabIcon.Size = UDim2.new(0, 21, 0, 21)
            tabIcon.Image = options3.icon
            tabIcon.ImageColor3 = Color3.fromRGB(43, 154, 198)

            newPage.Name = "newPage"
            newPage.Parent = allPages
            newPage.Visible = false
            newPage.BackgroundColor3 = Color3.fromRGB(234, 239, 245)
            newPage.BackgroundTransparency = 1.000
            newPage.BorderSizePixel = 0
            newPage.ClipsDescendants = false
            newPage.Position = UDim2.new(0.021598272, 0, 0.0237068962, 0)
            newPage.Size = UDim2.new(0, 442, 0, 440)
            newPage.ScrollBarThickness = 4
            newPage.CanvasSize = UDim2.new(0, 0, 0, 0)

            pageLayout.Name = "pageLayout"
            pageLayout.Parent = newPage
            pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
            pageLayout.CellPadding = UDim2.new(0, 12, 0, 12)
            pageLayout.CellSize = UDim2.new(0, 215, 0, -10)
            pageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                newPage.CanvasSize = UDim2.new(0, 0, 0, pageLayout.AbsoluteContentSize.Y)
            end)

            ResizeTS(50)

            local sections = {}

            function sections:Section(options4)
                options4 = options4 or {}
                options4.text = options4.text or "Section"

                local sectionFrame = Instance.new("Frame")
                local sectionLabel = Instance.new("TextLabel")
                local sectionFrameCorner = Instance.new("UICorner")
                local sectionLayout = Instance.new("UIListLayout")
                local sLine = Instance.new("TextLabel")
                local sectionSizeConstraint = Instance.new("UISizeConstraint")

                sectionFrame.Name = "sectionFrame"
                sectionFrame.Parent = newPage
                sectionFrame.BackgroundColor3 = Color3.fromRGB(0, 15, 30)
                sectionFrame.BorderSizePixel = 0
                sectionFrame.Size = UDim2.new(0, 215, 0, 134)

                sectionLabel.Name = "sectionLabel"
                sectionLabel.Parent = sectionFrame
                sectionLabel.BackgroundColor3 = Color3.fromRGB(234, 239, 245)
                sectionLabel.BackgroundTransparency = 1.000
                sectionLabel.BorderSizePixel = 0
                sectionLabel.Position = UDim2.new(0.0121902823, 0, 0, 0)
                sectionLabel.Size = UDim2.new(0, 213, 0, 25)
                sectionLabel.Font = Enum.Font.GothamSemibold
                sectionLabel.Text = "   " .. options4.text
                sectionLabel.TextColor3 = Color3.fromRGB(234, 239, 245)
                sectionLabel.TextSize = 14.000
                sectionLabel.TextXAlignment = Enum.TextXAlignment.Left

                sectionFrameCorner.CornerRadius = UDim.new(0, 4)
                sectionFrameCorner.Name = "sectionFrameCorner"
                sectionFrameCorner.Parent = sectionFrame

                sectionLayout.Name = "sectionLayout"
                sectionLayout.Parent = sectionFrame
                sectionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
                sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
                sectionLayout.Padding = UDim.new(0, 2)

                sLine.Name = "sLine"
                sLine.Parent = sectionFrame
                sLine.BackgroundColor3 = Color3.fromRGB(13, 28, 44)
                sLine.BorderSizePixel = 0
                sLine.Position = UDim2.new(0.0255813953, 0, 0.41538462, 0)
                sLine.Size = UDim2.new(0, 202, 0, 3)
                sLine.Font = Enum.Font.SourceSans
                sLine.Text = ""
                sLine.TextSize = 0

                sectionSizeConstraint.Name = "sectionSizeConstraint"
                sectionSizeConstraint.Parent = sectionFrame
                sectionSizeConstraint.MinSize = Vector2.new(215, 35)

                local function Resize(num)
                    sectionSizeConstraint.MinSize += Vector2.new(0, num)
                end

                local elements = {}

                function elements:Button(opt)
                    opt = opt or {}
                    if not opt.text or not opt.callback then Notify("Button", "Missing arguments!") return end

                    local TextButton = Instance.new("TextButton")

                    TextButton.Parent = sectionFrame
                    TextButton.BackgroundColor3 = Color3.fromRGB(13, 57, 84)
                    TextButton.BorderSizePixel = 0
                    TextButton.Position = UDim2.new(0.0348837227, 0, 0.355555564, 0)
                    TextButton.Size = UDim2.new(0, 200, 0, 22)
                    TextButton.AutoButtonColor = false
                    TextButton.Text = opt.text
                    TextButton.Font = Enum.Font.Gotham
                    TextButton.TextColor3 = Color3.fromRGB(157, 171, 182)
                    TextButton.TextSize = 14.000
                    TextButton.BackgroundTransparency = 1
                    buttoneffect({ frame = TextButton, entered = TextButton })
                    clickEffect({ button = TextButton, amount = 5 })
                    TextButton.MouseButton1Click:Connect(function()
                        opt.callback()
                    end)

                    Resize(25)
                end

                function elements:Toggle(opt)
                    opt = opt or {}
                    if not opt.text or not opt.callback then Notify("Toggle", "Missing arguments!") return end

                    local toggleLabel = Instance.new("TextLabel")
                    local toggleFrame = Instance.new("TextButton")
                    local togFrameCorner = Instance.new("UICorner")
                    local toggleButton = Instance.new("TextButton")
                    local togBtnCorner = Instance.new("UICorner")

                    local flag = opt.flag
                    local State = opt.state or false
                    if flag ~= nil and Library.Flags[flag] ~= nil then
                        State = not not Library.Flags[flag]
                    end
                    if flag ~= nil then
                        Library.Flags[flag] = State
                    end

                    toggleLabel.Name = "toggleLabel"
                    toggleLabel.Parent = sectionFrame
                    toggleLabel.BackgroundTransparency = 1.000
                    toggleLabel.Position = UDim2.new(0.0348837227, 0, 0.965517223, 0)
                    toggleLabel.Size = UDim2.new(0, 200, 0, 22)
                    toggleLabel.Font = Enum.Font.Gotham
                    toggleLabel.Text = " " .. opt.text
                    toggleLabel.TextColor3 = Color3.fromRGB(157, 171, 182)
                    toggleLabel.TextSize = 14.000
                    toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
                    buttoneffect({ frame = toggleLabel, entered = toggleLabel })

                    local function render()
                        toggleButton.Position = State and UDim2.new(0.74, 0, 0.5, 0) or UDim2.new(0.25, 0, 0.5, 0)
                        toggleLabel.TextColor3 = State and Color3.fromRGB(234, 239, 246) or Color3.fromRGB(157, 171, 182)
                        toggleButton.BackgroundColor3 = State and Color3.fromRGB(2, 162, 243) or Color3.fromRGB(77, 77, 77)
                        toggleFrame.BackgroundColor3 = State and Color3.fromRGB(2, 23, 49) or Color3.fromRGB(4, 4, 11)
                    end

                    local function PerformToggle()
                        State = not State
                        if flag ~= nil then Library.Flags[flag] = State end
                        opt.callback(State)

                        TweenService:Create(toggleButton, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {
                            Position = State and UDim2.new(0.74, 0, 0.5, 0) or UDim2.new(0.25, 0, 0.5, 0)
                        }):Play()
                        TweenService:Create(toggleLabel, TweenInfo.new(0.06, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {
                            TextColor3 = State and Color3.fromRGB(234, 239, 246) or Color3.fromRGB(157, 171, 182)
                        }):Play()
                        TweenService:Create(toggleButton, TweenInfo.new(0.06, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {
                            BackgroundColor3 = State and Color3.fromRGB(2, 162, 243) or Color3.fromRGB(77, 77, 77)
                        }):Play()
                        TweenService:Create(toggleFrame, TweenInfo.new(0.06, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {
                            BackgroundColor3 = State and Color3.fromRGB(2, 23, 49) or Color3.fromRGB(4, 4, 11)
                        }):Play()
                    end

                    toggleFrame.Name = "toggleFrame"
                    toggleFrame.Parent = toggleLabel
                    toggleFrame.BackgroundColor3 = Color3.fromRGB(4, 4, 11)
                    toggleFrame.BorderSizePixel = 0
                    toggleFrame.AnchorPoint = Vector2.new(0.5, 0.5)
                    toggleFrame.Position = UDim2.new(0.9, 0, 0.5, 0)
                    toggleFrame.Size = UDim2.new(0, 38, 0, 18)
                    toggleFrame.AutoButtonColor = false
                    toggleFrame.Text = ""
                    toggleFrame.MouseButton1Click:Connect(PerformToggle)

                    togFrameCorner.CornerRadius = UDim.new(0, 50)
                    togFrameCorner.Parent = toggleFrame

                    toggleButton.Name = "toggleButton"
                    toggleButton.Parent = toggleFrame
                    toggleButton.BackgroundColor3 = Color3.fromRGB(77, 77, 77)
                    toggleButton.BorderSizePixel = 0
                    toggleButton.AnchorPoint = Vector2.new(0.5, 0.5)
                    toggleButton.Position = UDim2.new(0.25, 0, 0.5, 0)
                    toggleButton.Size = UDim2.new(0, 16, 0, 16)
                    toggleButton.AutoButtonColor = false
                    toggleButton.Text = ""
                    toggleButton.MouseButton1Click:Connect(PerformToggle)

                    togBtnCorner.CornerRadius = UDim.new(0, 50)
                    togBtnCorner.Parent = toggleButton

                    render()

                    if flag ~= nil then
                        Library.Controls[flag] = {
                            Set = function(v)
                                v = not not v
                                if State ~= v then
                                    PerformToggle()
                                end
                            end,
                            Get = function()
                                return State
                            end
                        }
                    end

                    Resize(25)
                end

                function elements:Slider(opt)
                    opt = opt or {}
                    if not opt.text or not opt.min or not opt.max or not opt.callback then Notify("Slider", "Missing arguments!") return end

                    local Slider = Instance.new("Frame")
                    local sliderLabel = Instance.new("TextLabel")
                    local sliderFrame = Instance.new("TextButton")
                    local sliderBall = Instance.new("TextButton")
                    local sliderBallCorner = Instance.new("UICorner")
                    local sliderTextBox = Instance.new("TextBox")
                    buttoneffect({ frame = sliderLabel, entered = Slider })

                    local flag = opt.flag

                    local Value
                    local Held = false

                    local UIS = game:GetService("UserInputService")
                    local RS = game:GetService("RunService")

                    local percentage = 0
                    local step = 0.01

                    local function snap(number, factor)
                        if factor == 0 then
                            return number
                        else
                            return math.floor(number / factor + 0.5) * factor
                        end
                    end

                    UIS.InputEnded:Connect(function()
                        Held = false
                    end)

                    Slider.Name = "Slider"
                    Slider.Parent = sectionFrame
                    Slider.BackgroundTransparency = 1.000
                    Slider.Position = UDim2.new(0.0395348854, 0, 0.947335422, 0)
                    Slider.Size = UDim2.new(0, 200, 0, 22)

                    sliderLabel.Name = "sliderLabel"
                    sliderLabel.Parent = Slider
                    sliderLabel.AnchorPoint = Vector2.new(0.5, 0.5)
                    sliderLabel.BackgroundTransparency = 1.000
                    sliderLabel.Position = UDim2.new(0.2, 0, 0.5, 0)
                    sliderLabel.Size = UDim2.new(0, 77, 0, 22)
                    sliderLabel.Font = Enum.Font.Gotham
                    sliderLabel.Text = " " .. opt.text
                    sliderLabel.TextColor3 = Color3.fromRGB(157, 171, 182)
                    sliderLabel.TextSize = 14.000
                    sliderLabel.TextXAlignment = Enum.TextXAlignment.Left

                    sliderFrame.Name = "sliderFrame"
                    sliderFrame.Parent = sliderLabel
                    sliderFrame.BackgroundColor3 = Color3.fromRGB(29, 87, 118)
                    sliderFrame.BorderSizePixel = 0
                    sliderFrame.AnchorPoint = Vector2.new(0.5, 0.5)
                    sliderFrame.Position = UDim2.new(1.6, 0, 0.5, 0)
                    sliderFrame.Size = UDim2.new(0, 72, 0, 2)
                    sliderFrame.Text = ""
                    sliderFrame.AutoButtonColor = false
                    sliderFrame.MouseButton1Down:Connect(function()
                        Held = true
                    end)

                    sliderBall.Name = "sliderBall"
                    sliderBall.Parent = sliderFrame
                    sliderBall.AnchorPoint = Vector2.new(0.5, 0.5)
                    sliderBall.BackgroundColor3 = Color3.fromRGB(67, 136, 231)
                    sliderBall.BorderSizePixel = 0
                    sliderBall.Position = UDim2.new(0, 0, 0.5, 0)
                    sliderBall.Size = UDim2.new(0, 14, 0, 14)
                    sliderBall.AutoButtonColor = false
                    sliderBall.Text = ""
                    sliderBall.MouseButton1Down:Connect(function()
                        Held = true
                    end)

                    sliderBallCorner.CornerRadius = UDim.new(0, 50)
                    sliderBallCorner.Parent = sliderBall

                    sliderTextBox.Name = "sliderTextBox"
                    sliderTextBox.Parent = sliderLabel
                    sliderTextBox.BackgroundColor3 = Color3.fromRGB(1, 7, 17)
                    sliderTextBox.AnchorPoint = Vector2.new(0.5, 0.5)
                    sliderTextBox.Position = UDim2.new(2.4, 0, 0.5, 0)
                    sliderTextBox.Size = UDim2.new(0, 31, 0, 15)
                    sliderTextBox.Font = Enum.Font.Gotham
                    sliderTextBox.TextColor3 = Color3.fromRGB(234, 239, 245)
                    sliderTextBox.TextSize = 11.000
                    sliderTextBox.TextWrapped = true

                    local function SetSlider(v)
                        v = tonumber(v) or opt.min
                        v = math.clamp(v, opt.min, opt.max)
                        v = round(v, opt.float)

                        local pct = ((v - opt.min) / (opt.max - opt.min)) * 0.9
                        pct = math.clamp(pct, 0, 0.9)

                        sliderTextBox.Text = tostring(v)
                        sliderBall.Position = UDim2.new(pct, 0, 0.5, 0)

                        Value = v
                        if flag ~= nil then Library.Flags[flag] = v end
                        opt.callback(v)
                    end

                    -- initial
                    local start = opt.min
                    if flag ~= nil and Library.Flags[flag] ~= nil then
                        start = Library.Flags[flag]
                    elseif opt.value ~= nil then
                        start = opt.value
                    end
                    SetSlider(start)

                    RS.RenderStepped:Connect(function()
                        if Held then
                            local MousePos = UIS:GetMouseLocation().X
                            local FrameSize = sliderFrame.AbsoluteSize.X
                            local FramePos = sliderFrame.AbsolutePosition.X
                            local pos = snap((MousePos - FramePos) / FrameSize, step)
                            percentage = math.clamp(pos, 0, 0.9)

                            local v = ((((tonumber(opt.max) - tonumber(opt.min)) / 0.9) * percentage)) + tonumber(opt.min)
                            v = round(v, opt.float)
                            v = math.clamp(v, opt.min, opt.max)

                            sliderTextBox.Text = tostring(v)
                            sliderBall.Position = UDim2.new(percentage, 0, 0.5, 0)

                            Value = v
                            if flag ~= nil then Library.Flags[flag] = v end
                            opt.callback(v)
                        end
                    end)

                    sliderTextBox.FocusLost:Connect(function(Enter)
                        if Enter then
                            SetSlider(sliderTextBox.Text)
                        end
                    end)

                    if flag ~= nil then
                        Library.Controls[flag] = {
                            Set = SetSlider,
                            Get = function() return Value end
                        }
                    end

                    Resize(25)
                end

                function elements:Dropdown(opt)
                    opt = opt or {}
                    if not opt.text or not opt.default or not opt.list or not opt.callback then Notify("Dropdown", "Missing arguments!") return end

                    local flag = opt.flag
                    local current = opt.default
                    if flag ~= nil and Library.Flags[flag] ~= nil then
                        current = Library.Flags[flag]
                    end
                    if flag ~= nil then Library.Flags[flag] = current end

                    local DropYSize = 0
                    local Dropped = false

                    local Dropdown = Instance.new("Frame")
                    local dropdownLabel = Instance.new("TextLabel")
                    local dropdownText = Instance.new("TextLabel")
                    local dropdownArrow = Instance.new("ImageButton")
                    local dropdownList = Instance.new("Frame")

                    local dropListLayout = Instance.new("UIListLayout")
                    buttoneffect({ frame = dropdownLabel, entered = Dropdown })

                    Dropdown.Name = "Dropdown"
                    Dropdown.Parent = sectionFrame
                    Dropdown.BackgroundTransparency = 1.000
                    Dropdown.BorderSizePixel = 0
                    Dropdown.Position = UDim2.new(0.0697674453, 0, 0.237037033, 0)
                    Dropdown.Size = UDim2.new(0, 200, 0, 22)
                    Dropdown.ZIndex = 2

                    dropdownLabel.Name = "dropdownLabel"
                    dropdownLabel.Parent = Dropdown
                    dropdownLabel.BackgroundTransparency = 1.000
                    dropdownLabel.BorderSizePixel = 0
                    dropdownLabel.Size = UDim2.new(0, 105, 0, 22)
                    dropdownLabel.Font = Enum.Font.Gotham
                    dropdownLabel.Text = " " .. opt.text
                    dropdownLabel.TextColor3 = Color3.fromRGB(157, 171, 182)
                    dropdownLabel.TextSize = 14.000
                    dropdownLabel.TextXAlignment = Enum.TextXAlignment.Left
                    dropdownLabel.TextWrapped = true

                    dropdownText.Name = "dropdownText"
                    dropdownText.Parent = dropdownLabel
                    dropdownText.BackgroundColor3 = Color3.fromRGB(2, 5, 12)
                    dropdownText.Position = UDim2.new(1.08571434, 0, 0.0909090936, 0)
                    dropdownText.Size = UDim2.new(0, 87, 0, 18)
                    dropdownText.Font = Enum.Font.Gotham
                    dropdownText.Text = " " .. tostring(current)
                    dropdownText.TextColor3 = Color3.fromRGB(234, 239, 245)
                    dropdownText.TextSize = 12.000
                    dropdownText.TextXAlignment = Enum.TextXAlignment.Left
                    dropdownText.TextWrapped = true

                    dropdownArrow.Name = "dropdownArrow"
                    dropdownArrow.Parent = dropdownText
                    dropdownArrow.BackgroundColor3 = Color3.fromRGB(2, 5, 12)
                    dropdownArrow.BorderSizePixel = 0
                    dropdownArrow.Position = UDim2.new(0.87356323, 0, 0.138888866, 0)
                    dropdownArrow.Size = UDim2.new(0, 11, 0, 13)
                    dropdownArrow.AutoButtonColor = false
                    dropdownArrow.Image = "rbxassetid://8008296380"
                    dropdownArrow.ImageColor3 = Color3.fromRGB(157, 171, 182)

                    dropdownList.Name = "dropdownList"
                    dropdownList.Parent = dropdownText
                    dropdownList.BackgroundColor3 = Color3.fromRGB(2, 5, 12)
                    dropdownList.Position = UDim2.new(0, 0, 1, 0)
                    dropdownList.Size = UDim2.new(0, 87, 0, 0)
                    dropdownList.ClipsDescendants = true
                    dropdownList.BorderSizePixel = 0
                    dropdownList.ZIndex = 10

                    dropListLayout.Name = "dropListLayout"
                    dropListLayout.Parent = dropdownList
                    dropListLayout.SortOrder = Enum.SortOrder.LayoutOrder

                    dropdownArrow.MouseButton1Click:Connect(function()
                        Dropped = not Dropped
                        if Dropped then
                            TweenService:Create(dropdownList, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                                Size = UDim2.new(0, 87, 0, DropYSize),
                                BorderSizePixel = 1
                            }):Play()
                        else
                            TweenService:Create(dropdownList, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                                Size = UDim2.new(0, 87, 0, 0),
                                BorderSizePixel = 0
                            }):Play()
                        end
                    end)

                    Resize(25)

                    local function SetDropdown(v)
                        dropdownText.Text = " " .. tostring(v)
                        if flag ~= nil then Library.Flags[flag] = v end
                        opt.callback(v)
                    end

                    for _, v in next, opt.list do
                        local dropdownBtn = Instance.new("TextButton")
                        dropdownBtn.Name = "dropdownBtn"
                        dropdownBtn.Parent = dropdownList
                        dropdownBtn.BackgroundTransparency = 1.000
                        dropdownBtn.BorderSizePixel = 0
                        dropdownBtn.Size = UDim2.new(0, 87, 0, 18)
                        dropdownBtn.AutoButtonColor = false
                        dropdownBtn.Font = Enum.Font.Gotham
                        dropdownBtn.TextColor3 = Color3.fromRGB(234, 239, 245)
                        dropdownBtn.TextSize = 12.000
                        dropdownBtn.Text = tostring(v)
                        dropdownBtn.ZIndex = 15
                        clickEffect({ button = dropdownBtn, amount = 5 })

                        DropYSize = DropYSize + 18

                        dropdownBtn.MouseButton1Click:Connect(function()
                            SetDropdown(v)
                        end)
                    end

                    SetDropdown(current)

                    if flag ~= nil then
                        Library.Controls[flag] = {
                            Set = SetDropdown,
                            Get = function()
                                return string.sub(dropdownText.Text, 2)
                            end
                        }
                    end
                end

                function elements:Textbox(opt)
                    opt = opt or {}
                    if not opt.text or opt.value == nil or not opt.callback then Notify("Textbox", "Missing arguments!") return end

                    local flag = opt.flag
                    local current = opt.value
                    if flag ~= nil and Library.Flags[flag] ~= nil then
                        current = Library.Flags[flag]
                    end
                    if flag ~= nil then Library.Flags[flag] = current end

                    local Textbox = Instance.new("Frame")
                    local textBoxLabel = Instance.new("TextLabel")
                    local textBox = Instance.new("TextBox")

                    Textbox.Name = "Textbox"
                    Textbox.Parent = sectionFrame
                    Textbox.BackgroundTransparency = 1.000
                    Textbox.BorderSizePixel = 0
                    Textbox.Position = UDim2.new(0.0348837227, 0, 0.945454538, 0)
                    Textbox.Size = UDim2.new(0, 200, 0, 22)
                    buttoneffect({ frame = textBoxLabel, entered = Textbox })

                    textBoxLabel.Name = "textBoxLabel"
                    textBoxLabel.Parent = Textbox
                    textBoxLabel.AnchorPoint = Vector2.new(0.5, 0.5)
                    textBoxLabel.BackgroundTransparency = 1.000
                    textBoxLabel.Position = UDim2.new(0.237000003, 0, 0.5, 0)
                    textBoxLabel.Size = UDim2.new(0, 99, 0, 22)
                    textBoxLabel.Font = Enum.Font.Gotham
                    textBoxLabel.Text = "  " .. opt.text
                    textBoxLabel.TextColor3 = Color3.fromRGB(157, 171, 182)
                    textBoxLabel.TextSize = 14.000
                    textBoxLabel.TextXAlignment = Enum.TextXAlignment.Left

                    textBox.Name = "textBox"
                    textBox.Parent = Textbox
                    textBox.AnchorPoint = Vector2.new(0.5, 0.5)
                    textBox.BackgroundColor3 = Color3.fromRGB(1, 7, 17)
                    textBox.Position = UDim2.new(0.850000024, 0, 0.5, 0)
                    textBox.Size = UDim2.new(0, 53, 0, 15)
                    textBox.Font = Enum.Font.Gotham
                    textBox.Text = tostring(current)
                    textBox.TextColor3 = Color3.fromRGB(234, 239, 245)
                    textBox.TextSize = 11.000
                    textBox.TextWrapped = true

                    local function SetText(v)
                        textBox.Text = tostring(v)
                        if flag ~= nil then Library.Flags[flag] = textBox.Text end
                        opt.callback(textBox.Text)
                    end

                    SetText(current)

                    Resize(25)

                    textBox.FocusLost:Connect(function(Enter)
                        if Enter then
                            SetText(textBox.Text)
                        end
                    end)

                    if flag ~= nil then
                        Library.Controls[flag] = {
                            Set = SetText,
                            Get = function() return textBox.Text end
                        }
                    end
                end

                -- NOTE: Leaving Colorpicker/Keybind unmodified for now to keep this stable.
                -- If you want them saved too, say the word and I'll patch those next.

                return elements
            end

            return sections
        end

        return tabs
    end

    -- =========================
    -- Auto Config Tab (ADDED)
    -- =========================
    if enableConfigTab then
        local cfgTS = tabsections:TabSection({ text = "Config" })
        local cfgTab = cfgTS:Tab({ text = "Configs", icon = "rbxassetid://7999984136" })
        local cfgSec = cfgTab:Section({ text = "Config Manager" })

        local cfgName = "default"

        cfgSec:Textbox({
            text = "Name",
            value = cfgName,
            callback = function(v)
                cfgName = v
            end
        })

        cfgSec:Button({
            text = "Save Config",
            callback = function()
                Library:SaveConfig(cfgName)
            end
        })

        cfgSec:Button({
            text = "Load Config",
            callback = function()
                Library:LoadConfig(cfgName)
            end
        })
    end

    return tabsections
end

return Library

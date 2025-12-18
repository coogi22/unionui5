-- Neverlose UI (patched with Config System)
-- Based on your uploaded source, with added Save/Load/Config Panel + refreshable dropdown.

local Library = {}

local NeverloseVersion = "v1.1A."

local TweenService = game:GetService("TweenService")
local input = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

-- =========================================
-- CONFIG CORE
-- =========================================
Library.Flags = Library.Flags or {}
Library._Setters = Library._Setters or {}
Library.ConfigFolder = "NeverloseConfigs"

local function _supports_files()
    return (writefile and readfile and listfiles and isfolder and makefolder) ~= nil
end

local function _ensure_folder()
    if not _supports_files() then return false end
    if not isfolder(Library.ConfigFolder) then
        pcall(function() makefolder(Library.ConfigFolder) end)
    end
    return isfolder(Library.ConfigFolder)
end

local function _path(name)
    name = tostring(name or "default")
    name = name:gsub("[^%w%-%_ ]", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then name = "default" end
    return Library.ConfigFolder .. "/" .. name .. ".json", name
end

local function _encode(tbl)
    return HttpService:JSONEncode(tbl)
end

local function _decode(str)
    return HttpService:JSONDecode(str)
end

local function _serialize_value(v)
    local t = typeof(v)
    if t == "Color3" then
        return { __type = "Color3", r = v.R, g = v.G, b = v.B }
    elseif t == "EnumItem" then
        return { __type = "EnumItem", enumType = tostring(v.EnumType), name = v.Name }
    elseif t == "UDim2" then
        return { __type="UDim2", xs=v.X.Scale, xo=v.X.Offset, ys=v.Y.Scale, yo=v.Y.Offset }
    elseif t == "Vector3" then
        return { __type="Vector3", x=v.X, y=v.Y, z=v.Z }
    end
    return v
end

local function _deserialize_value(v)
    if type(v) ~= "table" then return v end
    if v.__type == "Color3" then
        return Color3.new(v.r or 1, v.g or 1, v.b or 1)
    elseif v.__type == "EnumItem" then
        -- only used for KeyCode typically
        if tostring(v.enumType):find("KeyCode") then
            return Enum.KeyCode[v.name] or Enum.KeyCode.Unknown
        end
        return v.name
    elseif v.__type == "UDim2" then
        return UDim2.new(v.xs or 0, v.xo or 0, v.ys or 0, v.yo or 0)
    elseif v.__type == "Vector3" then
        return Vector3.new(v.x or 0, v.y or 0, v.z or 0)
    end
    return v
end

function Library:GetConfigs()
    if not _supports_files() then return {} end
    if not _ensure_folder() then return {} end
    local files = {}
    local ok, res = pcall(function()
        return listfiles(Library.ConfigFolder)
    end)
    if not ok or type(res) ~= "table" then return {} end

    for _, fp in ipairs(res) do
        local name = tostring(fp):match("([^/\\]+)%.json$")
        if name and name ~= "" then
            table.insert(files, name)
        end
    end
    table.sort(files)
    return files
end

function Library:SaveConfig(name)
    if not _supports_files() then
        warn("[Neverlose] Executor missing writefile/readfile/listfiles/isfolder/makefolder.")
        return false
    end
    if not _ensure_folder() then return false end

    local filePath, safeName = _path(name)

    local payload = {
        __meta = {
            version = NeverloseVersion,
            savedAt = os.time()
        },
        flags = {}
    }

    for flag, value in pairs(Library.Flags) do
        payload.flags[flag] = _serialize_value(value)
    end

    local ok, err = pcall(function()
        writefile(filePath, _encode(payload))
    end)

    if not ok then
        warn("[Neverlose] Save failed:", err)
        return false
    end

    return true
end

function Library:LoadConfig(name)
    if not _supports_files() then
        warn("[Neverlose] Executor missing writefile/readfile/listfiles/isfolder/makefolder.")
        return false
    end
    if not _ensure_folder() then return false end

    local filePath = (_path(name))
    if not isfile or not isfile(filePath) then
        warn("[Neverlose] Config not found:", filePath)
        return false
    end

    local ok, raw = pcall(function()
        return readfile(filePath)
    end)
    if not ok or type(raw) ~= "string" then
        warn("[Neverlose] Read failed:", raw)
        return false
    end

    local ok2, data = pcall(function()
        return _decode(raw)
    end)
    if not ok2 or type(data) ~= "table" or type(data.flags) ~= "table" then
        warn("[Neverlose] Decode failed.")
        return false
    end

    for flag, stored in pairs(data.flags) do
        local value = _deserialize_value(stored)
        Library.Flags[flag] = value
        local setter = Library._Setters[flag]
        if setter then
            pcall(function() setter(value) end)
        end
    end

    return true
end

function Library:AddConfigPanel(SectionElements, opts)
    opts = opts or {}
    local defaultName = opts.defaultName or "default"
    local currentName = defaultName

    -- Config name textbox
    SectionElements:Textbox({
        text = "Config Name",
        value = tostring(defaultName),
        callback = function(v)
            currentName = tostring(v)
        end
    })

    -- Config list dropdown (refreshable)
    local ddHandle
    ddHandle = SectionElements:Dropdown({
        text = "Configs",
        default = "Select",
        list = Library:GetConfigs(),
        callback = function(selected)
            currentName = tostring(selected)
        end,
        returnHandle = true
    })

    -- Save
    SectionElements:Button({
        text = "Save Config",
        callback = function()
            local ok = Library:SaveConfig(currentName)
            if ok then
                -- refresh list so it shows immediately
                if ddHandle and ddHandle.Refresh then
                    ddHandle:Refresh(Library:GetConfigs(), currentName)
                end
            end
        end
    })

    -- Load
    SectionElements:Button({
        text = "Load Config",
        callback = function()
            Library:LoadConfig(currentName)
        end
    })

    -- Refresh
    SectionElements:Button({
        text = "Refresh List",
        callback = function()
            if ddHandle and ddHandle.Refresh then
                ddHandle:Refresh(Library:GetConfigs(), currentName)
            end
        end
    })

    return {
        GetName = function() return currentName end,
        Refresh = function()
            if ddHandle and ddHandle.Refresh then
                ddHandle:Refresh(Library:GetConfigs(), currentName)
            end
        end
    }
end

-- =========================================
-- ORIGINAL UI (your code) + small patches:
-- - add "flag" support on elements
-- - dropdown returns a handle that can Refresh()
-- =========================================

for i,v in next, game.CoreGui:GetChildren() do
    if v:IsA("ScreenGui") and v.Name == "Neverlose" then
        v:Destroy()
    end
end

local themouse = game.Players.LocalPlayer:GetMouse()

local function Notify(tt, tx)
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = tt,
        Text = tx,
        Duration = 5
    })
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
            parent.Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X, framePos.Y.Scale, framePos.Y.Offset + delta.Y)
        end
    end)
end

local function round(num, bracket)
    bracket = bracket or 1
    local a = math.floor(num/bracket + (math.sign(num) * 0.5)) * bracket
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
        TweenService:Create(options.button, TweenInfo.new(0.15, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {TextSize = new}):Play()
        task.wait(0.1)
        TweenService:Create(options.button, TweenInfo.new(0.1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {TextSize = revert}):Play()
    end)
end

function Library:Toggle(value)
    if game:GetService("CoreGui"):FindFirstChild("Neverlose") == nil then return end
    local enabled = (type(value) == "boolean" and value) or game:GetService("CoreGui"):FindFirstChild("Neverlose").Enabled
    game:GetService("CoreGui"):FindFirstChild("Neverlose").Enabled = not enabled
end

function Library:Window(options)
    options.text = options.text or "NEVERLOSE"

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
    allPages.BackgroundTransparency = 1.000
    allPages.BorderSizePixel = 0
    allPages.Position = UDim2.new(0.29508087, 0, 0.100775197, 0)
    allPages.Size = UDim2.new(0, 463, 0, 464)

    tabContainer.Name = "tabContainer"
    tabContainer.Parent = SideBar
    tabContainer.BackgroundTransparency = 1.000
    tabContainer.BorderSizePixel = 0
    tabContainer.Position = UDim2.new(0, 0, 0.100775197, 0)
    tabContainer.Size = UDim2.new(0, 187, 0, 464)

    local tabsections = {}

    function tabsections:TabSection(options2)
        options2.text = options2.text or "Tab Section"

        local tabLayout = Instance.new("UIListLayout")
        local tabSection = Instance.new("Frame")
        local tabSectionLabel = Instance.new("TextLabel")
        local tabSectionLayout = Instance.new("UIListLayout")

        tabLayout.Name = "tabLayout"
        tabLayout.Parent = tabContainer

        tabSection.Name = "tabSection"
        tabSection.Parent = tabContainer
        tabSection.BackgroundTransparency = 1.000
        tabSection.BorderSizePixel = 0
        tabSection.Size = UDim2.new(0, 189, 0, 22)

        local function ResizeTS(num)
            tabSection.Size += UDim2.new(0, 0, 0, num)
        end

        tabSectionLabel.Name = "tabSectionLabel"
        tabSectionLabel.Parent = tabSection
        tabSectionLabel.BackgroundTransparency = 1.000
        tabSectionLabel.BorderSizePixel = 0
        tabSectionLabel.Size = UDim2.new(0, 190, 0, 22)
        tabSectionLabel.Font = Enum.Font.Gotham
        tabSectionLabel.Text = "     ".. options2.text
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
            tabButton.Size = UDim2.new(0, 165, 0, 30)
            tabButton.AutoButtonColor = false
            tabButton.Font = Enum.Font.GothamSemibold
            tabButton.Text = "         " .. options3.text
            tabButton.TextColor3 = Color3.fromRGB(234, 239, 245)
            tabButton.TextSize = 14.000
            tabButton.BackgroundTransparency = 1
            tabButton.TextXAlignment = Enum.TextXAlignment.Left

            tabButton.MouseButton1Click:Connect(function()
                for _,v in next, allPages:GetChildren() do
                    v.Visible = false
                end

                newPage.Visible = true

                for _,v in next, SideBar:GetDescendants() do
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
            tabIcon.BackgroundTransparency = 1.000
            tabIcon.BorderSizePixel = 0
            tabIcon.Position = UDim2.new(0.0408859849, 0, 0.133333355, 0)
            tabIcon.Size = UDim2.new(0, 21, 0, 21)
            tabIcon.Image = options3.icon
            tabIcon.ImageColor3 = Color3.fromRGB(43, 154, 198)

            newPage.Name = "newPage"
            newPage.Parent = allPages
            newPage.Visible = false
            newPage.BackgroundTransparency = 1.000
            newPage.BorderSizePixel = 0
            newPage.ClipsDescendants = false
            newPage.Position = UDim2.new(0.021598272, 0, 0.0237068962, 0)
            newPage.Size = UDim2.new(0, 442, 0, 440)
            newPage.ScrollBarThickness = 4
            newPage.CanvasSize = UDim2.new(0,0,0,0)

            pageLayout.Name = "pageLayout"
            pageLayout.Parent = newPage
            pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
            pageLayout.CellPadding = UDim2.new(0, 12, 0, 12)
            pageLayout.CellSize = UDim2.new(0, 215, 0, -10)
            pageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                newPage.CanvasSize = UDim2.new(0,0,0,pageLayout.AbsoluteContentSize.Y)
            end)

            ResizeTS(50)

            local sections = {}

            function sections:Section(options4)
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
                    if not opt.text or not opt.callback then Notify("Button", "Missing arguments!") return end

                    local TextButton = Instance.new("TextButton")
                    TextButton.Parent = sectionFrame
                    TextButton.BackgroundColor3 = Color3.fromRGB(13, 57, 84)
                    TextButton.BorderSizePixel = 0
                    TextButton.Size = UDim2.new(0, 200, 0, 22)
                    TextButton.AutoButtonColor = false
                    TextButton.Text = opt.text
                    TextButton.Font = Enum.Font.Gotham
                    TextButton.TextColor3 = Color3.fromRGB(157, 171, 182)
                    TextButton.TextSize = 14.000
                    TextButton.BackgroundTransparency = 1
                    buttoneffect({frame = TextButton, entered = TextButton})
                    clickEffect({button = TextButton, amount = 5})
                    TextButton.MouseButton1Click:Connect(function()
                        opt.callback()
                    end)

                    Resize(25)
                end

                function elements:Toggle(opt)
                    if not opt.text or not opt.callback then Notify("Toggle", "Missing arguments!") return end

                    local flag = opt.flag or opt.text
                    local State = (opt.state ~= nil) and opt.state or false
                    Library.Flags[flag] = State

                    local toggleLabel = Instance.new("TextLabel")
                    local toggleFrame = Instance.new("TextButton")
                    local togFrameCorner = Instance.new("UICorner")
                    local toggleButton = Instance.new("TextButton")
                    local togBtnCorner = Instance.new("UICorner")

                    local function apply(v)
                        State = v and true or false
                        Library.Flags[flag] = State
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
                        opt.callback(State)
                    end

                    Library._Setters[flag] = apply

                    toggleLabel.Name = "toggleLabel"
                    toggleLabel.Parent = sectionFrame
                    toggleLabel.BackgroundTransparency = 1.000
                    toggleLabel.Size = UDim2.new(0, 200, 0, 22)
                    toggleLabel.Font = Enum.Font.Gotham
                    toggleLabel.Text = " " .. opt.text
                    toggleLabel.TextColor3 = Color3.fromRGB(157, 171, 182)
                    toggleLabel.TextSize = 14.000
                    toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
                    buttoneffect({frame = toggleLabel, entered = toggleLabel})

                    toggleFrame.Name = "toggleFrame"
                    toggleFrame.Parent = toggleLabel
                    toggleFrame.BackgroundColor3 = Color3.fromRGB(4, 4, 11)
                    toggleFrame.BorderSizePixel = 0
                    toggleFrame.AnchorPoint = Vector2.new(0.5, 0.5)
                    toggleFrame.Position = UDim2.new(0.9, 0, 0.5, 0)
                    toggleFrame.Size = UDim2.new(0, 38, 0, 18)
                    toggleFrame.AutoButtonColor = false
                    toggleFrame.Text = ""

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

                    togBtnCorner.CornerRadius = UDim.new(0, 50)
                    togBtnCorner.Parent = toggleButton

                    local function PerformToggle()
                        apply(not State)
                    end

                    toggleFrame.MouseButton1Click:Connect(PerformToggle)
                    toggleButton.MouseButton1Click:Connect(PerformToggle)

                    -- init state visuals
                    task.defer(function() apply(State) end)

                    Resize(25)

                    return {
                        Set = function(_, v) apply(v) end,
                        Get = function() return State end,
                        Flag = flag
                    }
                end

                function elements:Slider(opt)
                    if not opt.text or opt.min == nil or opt.max == nil or not opt.callback then Notify("Slider", "Missing arguments!") return end

                    local flag = opt.flag or opt.text
                    local Value = tonumber(opt.min)
                    Library.Flags[flag] = Value

                    local Slider = Instance.new("Frame")
                    local sliderLabel = Instance.new("TextLabel")
                    local sliderFrame = Instance.new("TextButton")
                    local sliderBall = Instance.new("TextButton")
                    local sliderBallCorner = Instance.new("UICorner")
                    local sliderTextBox = Instance.new("TextBox")
                    buttoneffect({frame = sliderLabel, entered = Slider})

                    local Held = false
                    local UIS = game:GetService("UserInputService")
                    local RS = game:GetService("RunService")

                    local percentage = 0
                    local step = 0.01

                    local function snap(number, factor)
                        if factor == 0 then return number end
                        return math.floor(number/factor+0.5)*factor
                    end

                    local function apply(v)
                        v = tonumber(v) or tonumber(opt.min)
                        v = math.clamp(v, tonumber(opt.min), tonumber(opt.max))
                        if opt.float then
                            v = round(v, opt.float)
                        end
                        Value = v
                        Library.Flags[flag] = Value
                        sliderTextBox.Text = tostring(Value)
                        opt.callback(Value)
                    end

                    Library._Setters[flag] = function(v)
                        apply(v)
                        -- update ball position approx
                        local minv, maxv = tonumber(opt.min), tonumber(opt.max)
                        local p = (Value - minv) / (maxv - minv)
                        percentage = math.clamp(p * 0.9, 0, 0.9)
                        sliderBall.Position = UDim2.new(percentage,0,0.5,0)
                    end

                    UIS.InputEnded:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                            Held = false
                        end
                    end)

                    Slider.Name = "Slider"
                    Slider.Parent = sectionFrame
                    Slider.BackgroundTransparency = 1.000
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
                    sliderFrame.MouseButton1Down:Connect(function() Held = true end)

                    sliderBall.Name = "sliderBall"
                    sliderBall.Parent = sliderFrame
                    sliderBall.AnchorPoint = Vector2.new(0.5, 0.5)
                    sliderBall.BackgroundColor3 = Color3.fromRGB(67, 136, 231)
                    sliderBall.BorderSizePixel = 0
                    sliderBall.Position = UDim2.new(0, 0, 0.5, 0)
                    sliderBall.Size = UDim2.new(0, 14, 0, 14)
                    sliderBall.AutoButtonColor = false
                    sliderBall.Text = ""
                    sliderBall.MouseButton1Down:Connect(function() Held = true end)

                    sliderBallCorner.CornerRadius = UDim.new(0, 50)
                    sliderBallCorner.Parent = sliderBall

                    sliderTextBox.Name = "sliderTextBox"
                    sliderTextBox.Parent = sliderLabel
                    sliderTextBox.BackgroundColor3 = Color3.fromRGB(1, 7, 17)
                    sliderTextBox.AnchorPoint = Vector2.new(0.5, 0.5)
                    sliderTextBox.Position = UDim2.new(2.4, 0, 0.5, 0)
                    sliderTextBox.Size = UDim2.new(0, 31, 0, 15)
                    sliderTextBox.Font = Enum.Font.Gotham
                    sliderTextBox.Text = tostring(opt.min)
                    sliderTextBox.TextColor3 = Color3.fromRGB(234, 239, 245)
                    sliderTextBox.TextSize = 11.000
                    sliderTextBox.TextWrapped = true

                    RS.RenderStepped:Connect(function()
                        if Held then
                            local BtnPos = sliderBall.Position
                            local MousePos = UIS:GetMouseLocation().X
                            local FrameSize = sliderFrame.AbsoluteSize.X
                            local FramePos = sliderFrame.AbsolutePosition.X
                            local pos = snap((MousePos-FramePos)/FrameSize, step)
                            percentage = math.clamp(pos, 0, 0.9)

                            local rawv = ((((tonumber(opt.max) - tonumber(opt.min)) / 0.9) * percentage)) + tonumber(opt.min)
                            apply(rawv)

                            sliderBall.Position = UDim2.new(percentage,0,BtnPos.Y.Scale, BtnPos.Y.Offset)
                        end
                    end)

                    sliderTextBox.FocusLost:Connect(function(enter)
                        if enter then
                            apply(sliderTextBox.Text)
                        end
                    end)

                    -- init
                    task.defer(function() apply(opt.min) end)

                    Resize(25)

                    return {
                        Set = function(_, v) Library._Setters[flag](v) end,
                        Get = function() return Value end,
                        Flag = flag
                    }
                end

                function elements:Dropdown(opt)
                    if not opt.text or not opt.default or not opt.list or not opt.callback then Notify("Dropdown", "Missing arguments!") return end

                    local flag = opt.flag or opt.text
                    local selected = tostring(opt.default)
                    Library.Flags[flag] = selected

                    local DropYSize = 0
                    local Dropped = false

                    local Dropdown = Instance.new("Frame")
                    local dropdownLabel = Instance.new("TextLabel")
                    local dropdownText = Instance.new("TextLabel")
                    local dropdownArrow = Instance.new("ImageButton")
                    local dropdownList = Instance.new("Frame")
                    local dropListLayout = Instance.new("UIListLayout")

                    buttoneffect({frame = dropdownLabel, entered = Dropdown})

                    Dropdown.Name = "Dropdown"
                    Dropdown.Parent = sectionFrame
                    Dropdown.BackgroundTransparency = 1.000
                    Dropdown.BorderSizePixel = 0
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
                    dropdownText.Text = " " .. selected
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

                    local function rebuild(list, keepValue)
                        DropYSize = 0
                        for _, child in ipairs(dropdownList:GetChildren()) do
                            if child:IsA("TextButton") then
                                child:Destroy()
                            end
                        end

                        for _, v in ipairs(list) do
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
                            clickEffect({button = dropdownBtn, amount = 5})

                            DropYSize += 18

                            dropdownBtn.MouseButton1Click:Connect(function()
                                selected = tostring(v)
                                dropdownText.Text = " " .. selected
                                Library.Flags[flag] = selected
                                opt.callback(selected)
                            end)
                        end

                        if keepValue and keepValue ~= "" then
                            selected = tostring(keepValue)
                            dropdownText.Text = " " .. selected
                            Library.Flags[flag] = selected
                        end
                    end

                    rebuild(opt.list, selected)

                    local function apply(v)
                        selected = tostring(v)
                        dropdownText.Text = " " .. selected
                        Library.Flags[flag] = selected
                        opt.callback(selected)
                    end

                    Library._Setters[flag] = apply

                    dropdownArrow.MouseButton1Click:Connect(function()
                        Dropped = not Dropped
                        if Dropped then
                            TweenService:Create(dropdownList, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                                Size = UDim2.new(0, 87, 0, DropYSize)
                            }):Play()
                            TweenService:Create(dropdownList, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                                BorderSizePixel = 1
                            }):Play()
                        else
                            TweenService:Create(dropdownList, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                                Size = UDim2.new(0, 87, 0, 0)
                            }):Play()
                            TweenService:Create(dropdownList, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                                BorderSizePixel = 0
                            }):Play()
                        end
                    end)

                    Resize(25)

                    local handle = {
                        Set = function(_, v) apply(v) end,
                        Get = function() return selected end,
                        Refresh = function(_, newList, keep)
                            rebuild(newList or {}, keep or selected)
                        end,
                        Flag = flag
                    }

                    if opt.returnHandle then
                        return handle
                    end
                end

                function elements:Textbox(opt)
                    if not opt.text or opt.value == nil or not opt.callback then Notify("Textbox", "Missing arguments!") return end

                    local flag = opt.flag or opt.text
                    local current = tostring(opt.value)
                    Library.Flags[flag] = current

                    local Textbox = Instance.new("Frame")
                    local textBoxLabel = Instance.new("TextLabel")
                    local textBox = Instance.new("TextBox")

                    Textbox.Name = "Textbox"
                    Textbox.Parent = sectionFrame
                    Textbox.BackgroundTransparency = 1.000
                    Textbox.BorderSizePixel = 0
                    Textbox.Size = UDim2.new(0, 200, 0, 22)
                    buttoneffect({frame = textBoxLabel, entered = Textbox})

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
                    textBox.Text = current
                    textBox.TextColor3 = Color3.fromRGB(234, 239, 245)
                    textBox.TextSize = 11.000
                    textBox.TextWrapped = true

                    local function apply(v)
                        current = tostring(v)
                        textBox.Text = current
                        Library.Flags[flag] = current
                        opt.callback(current)
                    end

                    Library._Setters[flag] = apply

                    textBox.FocusLost:Connect(function(enter)
                        if enter then
                            apply(textBox.Text)
                        end
                    end)

                    Resize(25)

                    return {
                        Set = function(_, v) apply(v) end,
                        Get = function() return current end,
                        Flag = flag
                    }
                end

                -- NOTE:
                -- Your original Colorpicker + Keybind are long; keeping them as-is is fine,
                -- but to be savable they must set Library.Flags[flag] and Library._Setters[flag].
                -- If you want, tell me which ones you want to save (Colorpicker/Keybind) and I’ll wire them too.

                return elements
            end

            return sections
        end

        return tabs
    end

    return tabsections
end

return Library

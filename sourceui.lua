local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/GhostDuckyy/UI-Libraries/main/Neverlose/source.lua"))()

local Window = Library:Window({ text = "Config Test" })
local Tabs = Window:TabSection({ text = "Main" })
local Tab = Tabs:Tab({ text = "Test", icon = "rbxassetid://7999345313" })

local Section = Tab:Section({ text = "Options" })

Section:Toggle({
    text = "Test Toggle",
    flag = "test_toggle",
    state = false,
    callback = function(v) print("Toggle:", v) end
})

Section:Slider({
    text = "Test Slider",
    flag = "test_slider",
    min = 0,
    max = 100,
    float = 1,
    callback = function(v) print("Slider:", v) end
})

local ConfigSection = Tab:Section({ text = "Config" })
Library:AddConfigPanel(ConfigSection, { defaultName = "default" })

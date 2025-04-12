local component = require("component")
local term = require("term")
local event = require("event")
local shell = require("shell")
local gpu = component.gpu

-- Constants
local BG_COLOR = 0x170024    -- Dark purple
local TEXT_COLOR = 0xFFBFBF  -- Light pink
local HIGHLIGHT_COLOR = 0xff8080  -- Brighter pink for highlights

-- Save original colors
local originalBackground = gpu.getBackground()
local originalForeground = gpu.getForeground()

-- Get screen dimensions
local width, height = gpu.getResolution()

-- Menu options
local options = {
    { text = "Launch Client", file = "nonsense_client.lua" },
    { text = "Launch Server", file = "nonsense_server.lua" },
    { text = "Exit", file = nil }
}

-- Box drawing characters
local BOX = {
    TOP_LEFT = "╔",
    TOP_RIGHT = "╗",
    BOTTOM_LEFT = "╚",
    BOTTOM_RIGHT = "╝",
    HORIZONTAL = "═",
    VERTICAL = "║"
}

-- Draw a box
local function drawBox(x, y, w, h)
    -- Draw corners
    gpu.set(x, y, BOX.TOP_LEFT)
    gpu.set(x + w - 1, y, BOX.TOP_RIGHT)
    gpu.set(x, y + h - 1, BOX.BOTTOM_LEFT)
    gpu.set(x + w - 1, y + h - 1, BOX.BOTTOM_RIGHT)
    
    -- Draw horizontal lines
    for i = 1, w - 2 do
        gpu.set(x + i, y, BOX.HORIZONTAL)
        gpu.set(x + i, y + h - 1, BOX.HORIZONTAL)
    end
    
    -- Draw vertical lines
    for i = 1, h - 2 do
        gpu.set(x, y + i, BOX.VERTICAL)
        gpu.set(x + w - 1, y + i, BOX.VERTICAL)
    end
end

-- Draw centered text
local function drawCenteredText(text, y)
    local x = math.floor((width - #text) / 2)
    gpu.set(x, y, text)
end

-- Draw menu
local function drawMenu(selectedOption)
    -- Clear screen
    gpu.setBackground(BG_COLOR)
    gpu.fill(1, 1, width, height, " ")
    
    -- Draw title box
    local titleBoxWidth = 40
    local titleBoxHeight = 3
    local titleBoxX = math.floor((width - titleBoxWidth) / 2)
    local titleBoxY = math.floor(height / 2) - 6
    
    gpu.setForeground(TEXT_COLOR)
    drawBox(titleBoxX, titleBoxY, titleBoxWidth, titleBoxHeight)
    drawCenteredText("Nonsense Timer Setup", titleBoxY + 1)
    
    -- Draw options
    local optionsStartY = titleBoxY + 4
    for i, option in ipairs(options) do
        if i == selectedOption then
            gpu.setForeground(HIGHLIGHT_COLOR)
            drawCenteredText("> " .. option.text .. " <", optionsStartY + (i-1) * 2)
            gpu.setForeground(TEXT_COLOR)
        else
            drawCenteredText(option.text, optionsStartY + (i-1) * 2)
        end
    end
    
    -- Draw controls
    drawCenteredText("Use ↑↓ to select, Enter to confirm", height - 2)
end

-- Main menu loop
local function runMenu()
    local selectedOption = 1
    local running = true
    
    while running do
        drawMenu(selectedOption)
        
        local e = {event.pull()}
        if e[1] == "key_down" then
            local _, _, _, code = table.unpack(e)
            
            if code == 200 then  -- Up arrow
                selectedOption = selectedOption - 1
                if selectedOption < 1 then
                    selectedOption = #options
                end
            elseif code == 208 then  -- Down arrow
                selectedOption = selectedOption + 1
                if selectedOption > #options then
                    selectedOption = 1
                end
            elseif code == 28 then  -- Enter
                if selectedOption == #options then
                    -- Exit option
                    running = false
                else
                    -- Launch selected script
                    term.clear()
                    local success, err = pcall(function()
                        shell.execute(options[selectedOption].file)
                    end)
                    if not success then
                        term.clear()
                        print("Error launching " .. options[selectedOption].text .. ":")
                        print(err)
                        print("\nPress any key to return to menu...")
                        event.pull("key_down")
                    end
                end
            end
        end
    end
end

-- Run the menu
runMenu()

-- Restore original colors and clear screen
gpu.setBackground(originalBackground)
gpu.setForeground(originalForeground)
term.clear()
print("Setup closed") 
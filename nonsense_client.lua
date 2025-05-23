local component = require("component")
local computer = require("computer")
local gpu = component.gpu
local event = require("event")
local term = require("term")
local unicode = require("unicode")

-- Check for required components
if not component.isAvailable("modem") then
    error("This program requires a Network Card or Linked Card!")
end
if not component.isAvailable("gpu") then
    error("This program requires a Graphics Card!")
end

-- Constants
local PORT = 1234
local TIMEOUT = 5  -- seconds to wait for server
local MESSAGE_TYPES = {
    PRESENCE = "presence",
    TIME = "time",
    RESET = "reset",
    SHUTDOWN = "shutdown",
    ERROR = "error"
}

-- Colors
local TEXT_COLOR = 0xFFBFBF  -- Light pink
local BG_COLOR = 0x170024    -- Dark purple

-- Initialize components
local modem = component.modem
modem.open(PORT)

-- Configure wireless strength (max for Tier 2 is 400)
if modem.isWireless() then
    modem.setStrength(400)  -- Set to maximum range for Tier 2
end

-- Get screen dimensions
local width, height = gpu.getResolution()
if width < 70 or height < 20 then
    error("Screen too small! Minimum size: 70x20")
end

-- Initialize state
local isRunning = false
local serverFound = false
local currentTime = 0
local debugMessages = {}

-- Function to add debug message
local function debug(msg)
    local timestamp = os.date("%H:%M:%S")
    local message = timestamp .. ": " .. msg
    table.insert(debugMessages, message)
    if #debugMessages > 5 then
        table.remove(debugMessages, 1)
    end
    
    -- Draw debug messages at the bottom of the screen
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
    for i, message in ipairs(debugMessages) do
        -- Truncate message if it's too long for the screen
        if #message > width then
            message = message:sub(1, width - 3) .. "..."
        else
            -- Pad with spaces to clear previous content
            message = message .. string.rep(" ", width - #message)
        end
        gpu.set(1, height - 6 + i, message)
    end
    gpu.setBackground(BG_COLOR)
    gpu.setForeground(TEXT_COLOR)
end

-- Wait for server presence
debug("Waiting for server...")
debug("Make sure server is running and within wireless range")
local timeout = computer.uptime() + TIMEOUT

while not serverFound and computer.uptime() < timeout do
    -- Send a discovery request
    modem.broadcast(PORT, "ping")
    debug("Sending ping...")
    
    -- Wait for response
    local e = {event.pull(1, "modem_message")}
    if e[1] == "modem_message" then
        local _, _, from, port, _, message_type, data = table.unpack(e)
        debug("Received message: " .. message_type .. " from " .. from:sub(1,8))
        if port == PORT then
            -- Accept either a presence message or a time update as confirmation
            if message_type == MESSAGE_TYPES.PRESENCE or message_type == MESSAGE_TYPES.TIME then
                serverFound = true
                isRunning = true
                debug("Server found! Starting display...")
                os.sleep(1)  -- Give time to read the message
                break
            end
        end
    end
end

if not serverFound then
    error("No server found! Please check:\n1. Server is running\n2. Both computers have wireless cards\n3. Computers are within range (400 blocks)")
end

-- Set up double buffering
local originalBuffer = gpu.getScreen()
local secondaryBuffer = component.gpu.allocateBuffer(width, height)
gpu.setActiveBuffer(secondaryBuffer)

-- ASCII Art configuration
local LARGE_CHARS = {
    ["D"] = {
        "██████╗░",
        "██╔══██╗",
        "██║░░██║",
        "██║░░██║",
        "██║░░██║",
        "██║░░██║",
        "██████╔╝",
        "╚═════╝░"
    },
    ["N"] = {
        "███╗░░░██╗",
        "████╗░░██║",
        "██╔██╗░██║",
        "██║╚██╗██║",
        "██║░╚████║",
        "██║░░╚███║",
        "██║░░░██║",
        "╚═╝░░░╚═╝"
    },
    ["O"] = {
        "░██████╗░",
        "██╔═══██╗",
        "██║░░░██║",
        "██║░░░██║",
        "██║░░░██║",
        "██║░░░██║",
        "╚██████╔╝",
        "░╚═════╝░"
    },
    ["S"] = {
        "███████╗",
        "██╔════╝",
        "██║░░░░░",
        "███████╗",
        "╚════██║",
        "░░░░░██║",
        "███████║",
        "╚══════╝"
    },
    ["E"] = {
        "███████╗",
        "██╔════╝",
        "██║░░░░░",
        "█████╗░░",
        "██╔══╝░░",
        "██║░░░░░",
        "███████╗",
        "╚══════╝"
    },
    ["0"] = {
        "░██████╗░",
        "██╔═══██╗",
        "██║░░░██║",
        "██║░░░██║",
        "██║░░░██║",
        "██║░░░██║",
        "╚██████╔╝",
        "░╚═════╝░"
    },
    ["1"] = {
        "░██╗░",
        "███║░",
        "╚██║░",
        "░██║░",
        "░██║░",
        "░██║░",
        "░██║░",
        "░╚═╝░"
    },
    ["2"] = {
        "██████╗░",
        "╚════██╗",
        "░░░░██╔╝",
        "░░░██╔╝░",
        "░██╔╝░░",
        "██╔╝░░░",
        "███████╗",
        "╚══════╝"
    },
    ["3"] = {
        "██████╗░",
        "╚════██╗",
        "░░░░██╔╝",
        "░████╔╝░",
        "░╚═══██╗",
        "░░░░██╔╝",
        "██████╔╝",
        "╚═════╝░"
    },
    ["4"] = {
        "██╗░░██╗",
        "██║░░██║",
        "██║░░██║",
        "██║░░██║",
        "███████║",
        "╚════██║",
        "░░░░░██║",
        "░░░░░╚═╝"
    },
    ["5"] = {
        "██████╗░",
        "██╔═══╝░",
        "██║░░░░░",
        "██████╗░",
        "╚════██╗",
        "░░░░██╔╝",
        "██████╔╝",
        "╚═════╝░"
    },
    ["6"] = {
        "░██████╗",
        "██╔════╝",
        "██║░░░░░",
        "██████╗░",
        "██╔══██╗",
        "██║░░██║",
        "╚█████╔╝",
        "░╚════╝░"
    },
    ["7"] = {
        "██████╗",
        "╚════██╗",
        "░░░░██╔╝",
        "░░░██╔╝░",
        "░░██╔╝░░",
        "░██╔╝░░░",
        "░██║░░░░",
        "░╚═╝░░░░"
    },
    ["8"] = {
        "░█████╗░",
        "██╔══██╗",
        "██║░░██║",
        "╚█████╔╝",
        "██╔══██╗",
        "██║░░██║",
        "╚█████╔╝",
        "░╚════╝░"
    },
    ["9"] = {
        "░█████╗░",
        "██╔══██╗",
        "██║░░██║",
        "╚██████║",
        "░╚═══██║",
        "░░░░██╔╝",
        "░█████╔╝",
        "░╚════╝░"
    },
    [":"] = {
        "░░░",
        "██╗",
        "╚═╝",
        "░░░",
        "██╗",
        "╚═╝",
        "░░░",
        "░░░"
    }
}

local SMALL_CHARS = {
    ["T"] = {
        "████████╗",
        "╚══██╔══╝",
        "░░░██║░░░",
        "░░░██║░░░",
        "░░░██║░░░",
        "░░░╚═╝░░░"
    },
    ["I"] = {
        "██╗",
        "██║",
        "██║",
        "██║",
        "██║",
        "╚═╝"
    },
    ["M"] = {
        "███╗░░░███╗",
        "████╗░████║",
        "██╔████╔██║",
        "██║╚██╔╝██║",
        "██║░╚═╝░██║",
        "╚═╝░░░░░╚═╝"
    },
    ["E"] = {
        "███████╗",
        "██╔════╝",
        "█████╗░░",
        "██╔══╝░░",
        "███████╗",
        "╚══════╝"
    },
    ["S"] = {
        "███████╗",
        "██╔════╝",
        "███████╗",
        "╚════██║",
        "███████║",
        "╚══════╝"
    },
    ["N"] = {
        "███╗░░░██╗",
        "████╗░░██║",
        "██╔██╗░██║",
        "██║╚██╗██║",
        "██║░╚████║",
        "╚═╝░░╚═══╝"
    },
    ["C"] = {
        "██████╗",
        "██╔═══╝",
        "██║░░░░",
        "██║░░░░",
        "██████╗",
        "╚═════╝"
    },
    ["L"] = {
        "██╗░░░░",
        "██║░░░░",
        "██║░░░░",
        "██║░░░░",
        "██████╗",
        "╚═════╝"
    },
    ["A"] = {
        "░█████╗░",
        "██╔══██╗",
        "███████║",
        "██╔══██║",
        "██║░░██║",
        "╚═╝░░╚═╝"
    }
}

-- Box drawing characters
local BOX = {
    TOP_LEFT = "╔",
    TOP_RIGHT = "╗",
    BOTTOM_LEFT = "╚",
    BOTTOM_RIGHT = "╝",
    HORIZONTAL = "═",
    VERTICAL = "║",
    T_DOWN = "╦",
    T_UP = "╩",
    T_RIGHT = "╠",
    T_LEFT = "╣",
    CROSS = "╬",
    BACKGROUND = "░"
}

-- Drawing functions
local function measureText(text, charSet)
    local totalWidth = 0
    for i = 1, #text do
        local char = text:sub(i,i)
        if charSet[char] then
            totalWidth = totalWidth + unicode.len(charSet[char][1]) + 1
        end
    end
    return totalWidth - 1  -- Remove last spacing
end

local function drawText(text, x, y, charSet)
    local currentX = x
    for i = 1, #text do
        local char = text:sub(i,i)
        if charSet[char] then
            for row = 1, #charSet[char] do
                gpu.set(currentX, y + row - 1, charSet[char][row])
            end
            currentX = currentX + unicode.len(charSet[char][1]) + 1
        end
    end
    return #charSet[text:sub(1,1)]  -- Return height
end

local function centerText(text, y, charSet)
    local totalWidth = measureText(text, charSet)
    local x = math.floor((width - totalWidth) / 2)
    return drawText(text, x, y, charSet)
end

-- Format time for display
local function formatTime(seconds)
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    if days > 0 then
        return string.format("%dD %02d:%02d:%02d", days, hours, minutes, secs)
    else
        return string.format("%02d:%02d:%02d", hours, minutes, secs)
    end
end

-- Calculate maximum time width
local function getMaxTimeWidth()
    -- Calculate width of "999D 23:59:59" as worst case
    return measureText("999D ", LARGE_CHARS) + measureText("23:59:59", LARGE_CHARS)
end

-- Draw a box with dotted background
local function drawBox(x, y, width, height)
    -- Draw corners
    gpu.set(x, y, BOX.TOP_LEFT)
    gpu.set(x + width - 1, y, BOX.TOP_RIGHT)
    gpu.set(x, y + height - 1, BOX.BOTTOM_LEFT)
    gpu.set(x + width - 1, y + height - 1, BOX.BOTTOM_RIGHT)
    
    -- Draw horizontal lines
    for i = 1, width - 2 do
        gpu.set(x + i, y, BOX.HORIZONTAL)
        gpu.set(x + i, y + height - 1, BOX.HORIZONTAL)
    end
    
    -- Draw vertical lines
    for i = 1, height - 2 do
        gpu.set(x, y + i, BOX.VERTICAL)
        gpu.set(x + width - 1, y + i, BOX.VERTICAL)
    end
    
    -- Fill background
    for i = 1, width - 2 do
        for j = 1, height - 2 do
            gpu.set(x + i, y + j, BOX.BACKGROUND)
        end
    end
end

-- Draw connected boxes
local function drawConnectedBoxes(x, y, width, upperHeight, lowerHeight)
    -- Draw upper box
    drawBox(x, y, width, upperHeight)
    
    -- Draw lower box
    drawBox(x, y + upperHeight - 1, width, lowerHeight)
    
    -- Replace connection points
    gpu.set(x, y + upperHeight - 1, BOX.T_RIGHT)
    gpu.set(x + width - 1, y + upperHeight - 1, BOX.T_LEFT)
    for i = 1, width - 2 do
        gpu.set(x + i, y + upperHeight - 1, BOX.HORIZONTAL)
    end
end

-- Draw interface
local function drawInterface()
    -- Clear both buffers
    gpu.setBackground(BG_COLOR)
    gpu.fill(1, 1, width, height, " ")
    
    -- Calculate box dimensions
    local boxWidth = math.max(70, getMaxTimeWidth() + 8)  -- At least 70 chars wide or wider than time + padding
    local upperBoxHeight = 16  -- Height for NONSENSE and header
    local lowerBoxHeight = 11  -- Height for timer
    local boxX = math.floor((width - boxWidth) / 2)
    local boxY = math.floor((height - (upperBoxHeight + lowerBoxHeight - 1)) / 2)
    
    -- Draw boxes
    gpu.setForeground(TEXT_COLOR)
    drawConnectedBoxes(boxX, boxY, boxWidth, upperBoxHeight, lowerBoxHeight)
    
    -- Calculate text positions
    local headerY = boxY + 2
    local nonsenseY = boxY + 7
    local timerY = boxY + upperBoxHeight + 1
    
    -- Draw text
    gpu.setBackground(BG_COLOR)  -- Ensure correct background for text
    centerText("TIME SINCE LAST", headerY, SMALL_CHARS)
    centerText("NONSENSE", nonsenseY, LARGE_CHARS)
    
    -- Store positions for updateDisplay
    return timerY
end

-- Draw time text with special handling for days
local function drawTimeText(timeStr, y)
    local parts = {}
    local daysEnd = timeStr:find("D")
    
    if daysEnd then
        -- Split into days and time
        parts[1] = timeStr:sub(1, daysEnd)  -- includes the D
        parts[2] = timeStr:sub(daysEnd + 2) -- skip the space after D
    else
        parts[1] = timeStr
    end
    
    -- Calculate total width
    local totalWidth = 0
    for _, part in ipairs(parts) do
        totalWidth = totalWidth + measureText(part, LARGE_CHARS)
    end
    if #parts > 1 then
        totalWidth = totalWidth + 2  -- Add space between days and time
    end
    
    -- Draw centered
    local startX = math.floor((width - totalWidth) / 2)
    local currentX = startX
    
    -- Draw each part
    for i, part in ipairs(parts) do
        drawText(part, currentX, y, LARGE_CHARS)
        if i < #parts then
            currentX = currentX + measureText(part, LARGE_CHARS) + 2
        end
    end
end

-- Update display with current time
local function updateDisplay()
    -- Switch to secondary buffer
    gpu.setActiveBuffer(secondaryBuffer)
    
    -- Redraw everything and get timer position
    local timerY = drawInterface()
    
    -- Draw time
    gpu.setForeground(TEXT_COLOR)
    gpu.setBackground(BG_COLOR)
    drawTimeText(formatTime(currentTime), timerY)
    
    -- Copy to primary buffer
    gpu.setActiveBuffer(originalBuffer)
    gpu.bitblt(originalBuffer, 1, 1, width, height, secondaryBuffer)
end

-- Main display loop
debug("Connected to server!")

-- Initialize display
gpu.setBackground(BG_COLOR)
term.clear()

-- Initial display setup
local ok, err = pcall(function()
    updateDisplay()
end)
if not ok then
    error("Failed to initialize display: " .. tostring(err))
end

debug("Display initialized successfully")
debug("Waiting for time updates...")

-- Track last ping time
local lastPing = computer.uptime()
local lastTimeUpdate = computer.uptime()

while isRunning do
    local currentTime = computer.uptime()
    
    -- Send ping every second
    if currentTime - lastPing >= 1 then
        modem.broadcast(PORT, "ping")
        debug("Sending ping...")
        lastPing = currentTime
    end
    
    -- Check for stale connection (no time updates in 10 seconds)
    if currentTime - lastTimeUpdate > 10 then
        debug("Warning: No time updates received for 10 seconds")
        debug("Attempting to reconnect...")
        modem.broadcast(PORT, "ping")
        lastTimeUpdate = currentTime
    end
    
    local e = {event.pull(0.1)}
    
    if e[1] == "modem_message" then
        local _, _, from, port, _, message_type, message = table.unpack(e)
        if port == PORT then
            if message_type == MESSAGE_TYPES.TIME then
                debug("Received time update: " .. tostring(message))
                lastTimeUpdate = currentTime
                
                -- Ensure message is a number
                if type(message) == "number" then
                    currentTime = message
                    local ok, err = pcall(function()
                        updateDisplay()
                    end)
                    if not ok then
                        debug("Display update failed: " .. tostring(err))
                    end
                else
                    debug("Warning: Received invalid time value: " .. tostring(message))
                end
            elseif message_type == MESSAGE_TYPES.RESET then
                debug("Received reset command")
                currentTime = 0
                updateDisplay()
            elseif message_type == MESSAGE_TYPES.SHUTDOWN then
                debug("Received shutdown command")
                -- Clean shutdown
                gpu.setBackground(BG_COLOR)
                term.clear()
                isRunning = false
            end
        end
    elseif e[1] == "key_down" then
        local _, _, _, code = table.unpack(e)
        if code == 19 then  -- 'r' key
            debug("Sending reset command")
            modem.broadcast(PORT, "reset")
        elseif code == 16 then  -- 'q' key
            debug("Sending quit command")
            modem.broadcast(PORT, "quit")
            isRunning = false
        end
    end
end

-- Cleanup
debug("Shutting down client...")
gpu.freeBuffer(secondaryBuffer)
gpu.setActiveBuffer(originalBuffer)
gpu.setBackground(0x000000)  -- Black
gpu.setForeground(0xFFFFFF)  -- White
term.clear()
modem.close(PORT)
debug("Client shutdown complete") 
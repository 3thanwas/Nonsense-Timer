local component = require("component")
local computer = require("computer")
local event = require("event")
local serialization = require("serialization")
local term = require("term")
local gpu = component.gpu

-- Check for required components
if not component.isAvailable("modem") then
    error("This program requires a Network Card or Linked Card!")
end

if not component.isAvailable("gpu") then
    error("GPU required")
end

if not component.isAvailable("screen") then
    error("Screen required")
end

-- Constants
local PORT = 1234
local UPDATE_INTERVAL = 1  -- seconds
local MESSAGE_TYPES = {
    PRESENCE = "presence",
    TIME = "time",
    RESET = "reset",
    SHUTDOWN = "shutdown",
    ERROR = "error"
}

-- Initialize components
local modem = component.modem
modem.open(PORT)

-- Configure wireless strength (max for Tier 2 is 400)
if modem.isWireless() then
    modem.setStrength(400)  -- Set to maximum range for Tier 2
end

-- Set up screen
local width, height = gpu.getResolution()
local originalBackground = gpu.getBackground()
local originalForeground = gpu.getForeground()

-- Colors
local BG_COLOR = 0x170024  -- Dark purple
local TEXT_COLOR = 0xffbfbf  -- Light pink
local HIGHLIGHT_COLOR = 0xff8080  -- Brighter pink for highlights

-- State variables
local isRunning = true
local startTime = computer.uptime()
local connectedClients = {}
local lastBroadcast = 0
local debugMessages = {}

-- Format time for display
local function formatTime(seconds)
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    if days > 0 then
        return string.format("%d days, %02d:%02d:%02d", days, hours, minutes, secs)
    else
        return string.format("%02d:%02d:%02d", hours, minutes, secs)
    end
end

-- Draw a box with single line characters
local function drawBox(x, y, w, h)
    -- Box characters
    local chars = {
        tl = "┌", tr = "┐", bl = "└", br = "┘",
        h = "─", v = "│"
    }
    
    -- Draw corners
    gpu.set(x, y, chars.tl)
    gpu.set(x + w - 1, y, chars.tr)
    gpu.set(x, y + h - 1, chars.bl)
    gpu.set(x + w - 1, y + h - 1, chars.br)
    
    -- Draw horizontal lines
    for i = 1, w - 2 do
        gpu.set(x + i, y, chars.h)
        gpu.set(x + i, y + h - 1, chars.h)
    end
    
    -- Draw vertical lines
    for i = 1, h - 2 do
        gpu.set(x, y + i, chars.v)
        gpu.set(x + w - 1, y + i, chars.v)
    end
end

-- Function to add debug message
local function debug(msg)
    table.insert(debugMessages, os.date("%H:%M:%S") .. ": " .. msg)
    if #debugMessages > 5 then
        table.remove(debugMessages, 1)
    end
    -- Draw debug messages at the bottom of the screen
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
    for i, message in ipairs(debugMessages) do
        gpu.set(1, height - 6 + i, string.format("%-" .. width .. "s", message))
    end
    gpu.setBackground(BG_COLOR)
    gpu.setForeground(TEXT_COLOR)
end

-- Update display
local function updateDisplay()
    -- Clear screen
    gpu.setBackground(BG_COLOR)
    gpu.setForeground(TEXT_COLOR)
    gpu.fill(1, 1, width, height - 7, " ")  -- Leave space for debug messages
    
    -- Draw main box
    drawBox(2, 1, width - 2, height - 8)
    
    -- Draw title
    local title = "=== Nonsense Timer Server ==="
    gpu.set(math.floor((width - #title) / 2), 2, title)
    
    -- Draw timer
    local elapsed = computer.uptime() - startTime
    local timeStr = "Time since last nonsense: " .. formatTime(elapsed)
    gpu.set(4, 4, timeStr)
    
    -- Draw client information
    local clientCount = 0
    for _ in pairs(connectedClients) do
        clientCount = clientCount + 1
    end
    
    gpu.set(4, 6, string.format("Connected displays: %d", clientCount))
    
    -- List clients
    if clientCount > 0 then
        gpu.set(4, 7, "Active displays:")
        local row = 8
        for addr, lastSeen in pairs(connectedClients) do
            -- Remove stale clients (not seen in last 5 seconds)
            if computer.uptime() - lastSeen > 5 then
                connectedClients[addr] = nil
                debug("Client " .. addr:sub(1,8) .. " timed out")
            else
                local shortAddr = addr:sub(1, 8)
                gpu.set(6, row, string.format("- %s... (last seen %.1fs ago)", 
                    shortAddr, computer.uptime() - lastSeen))
                row = row + 1
            end
        end
    end
    
    -- Draw controls
    gpu.set(4, height - 9, "Press Ctrl+C to quit")
    
    -- Redraw debug messages
    for i, message in ipairs(debugMessages) do
        gpu.setBackground(0x000000)
        gpu.setForeground(0xFFFFFF)
        gpu.set(1, height - 6 + i, string.format("%-" .. width .. "s", message))
    end
end

-- Main server loop
debug("Nonsense Timer Server Starting...")

-- Initial display
updateDisplay()

-- Initial presence broadcast
debug("Broadcasting initial presence signal...")
modem.broadcast(PORT, MESSAGE_TYPES.PRESENCE)
lastBroadcast = computer.uptime()

while isRunning do
    -- Broadcast presence and time updates every second
    local currentTime = computer.uptime()
    if currentTime - lastBroadcast >= UPDATE_INTERVAL then
        local elapsedTime = currentTime - startTime
        debug("Broadcasting time update: " .. tostring(elapsedTime))
        modem.broadcast(PORT, MESSAGE_TYPES.PRESENCE)
        modem.broadcast(PORT, MESSAGE_TYPES.TIME, elapsedTime)
        lastBroadcast = currentTime
        updateDisplay()
    end
    
    -- Handle incoming messages
    local e = {event.pull(0.1)}  -- Check events frequently
    if e[1] == "modem_message" then
        local _, _, sender, port, _, msgType, ... = table.unpack(e)
        if port == PORT then
            debug("Received " .. msgType .. " from " .. sender:sub(1,8))
            if msgType == "ping" then
                connectedClients[sender] = computer.uptime()
                updateDisplay()
            elseif msgType == "reset" then
                debug("Resetting timer...")
                startTime = computer.uptime()
                modem.broadcast(PORT, MESSAGE_TYPES.RESET)
                updateDisplay()
            elseif msgType == "quit" then
                debug("Received quit command, shutting down...")
                modem.broadcast(PORT, MESSAGE_TYPES.SHUTDOWN)
                break
            end
        end
    elseif e[1] == "interrupted" then
        debug("Received interrupt, shutting down...")
        modem.broadcast(PORT, MESSAGE_TYPES.SHUTDOWN)
        break
    end
end

-- Clean shutdown
debug("Server shutdown initiated...")
modem.close(PORT)
debug("Server shutdown complete")

term.clear()
gpu.setBackground(originalBackground)
gpu.setForeground(originalForeground) 
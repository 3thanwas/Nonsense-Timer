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

-- Update display
local function updateDisplay()
    -- Clear screen
    gpu.setBackground(BG_COLOR)
    gpu.setForeground(TEXT_COLOR)
    gpu.fill(1, 1, width, height, " ")
    
    -- Draw main box
    drawBox(2, 1, width - 2, height - 1)
    
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
            else
                local shortAddr = addr:sub(1, 8)
                gpu.set(6, row, string.format("- %s... (last seen %.1fs ago)", 
                    shortAddr, computer.uptime() - lastSeen))
                row = row + 1
            end
        end
    end
    
    -- Draw controls
    gpu.set(4, height - 2, "Press Ctrl+C to quit")
end

-- Network message handler
local function handleMessage(_, _, sender, port, _, msgType, ...)
    if msgType == "ping" then
        connectedClients[sender] = computer.uptime()
    elseif msgType == "reset" then
        startTime = computer.uptime()
        modem.broadcast(port, "reset")
        updateDisplay()
    elseif msgType == "quit" then
        modem.broadcast(port, "shutdown")
        return false
    end
    return true
end

-- Main server loop
print("Nonsense Timer Server Starting...")

-- Initial display
updateDisplay()

-- Initial presence broadcast
modem.broadcast(PORT, MESSAGE_TYPES.PRESENCE)
lastBroadcast = computer.uptime()

while isRunning do
    -- Broadcast presence and time updates every second
    local currentTime = computer.uptime()
    if currentTime - lastBroadcast >= UPDATE_INTERVAL then
        modem.broadcast(PORT, MESSAGE_TYPES.PRESENCE)
        modem.broadcast(PORT, MESSAGE_TYPES.TIME, currentTime - startTime)
        lastBroadcast = currentTime
        updateDisplay()
    end
    
    -- Handle incoming messages
    local e = {event.pull(0.1)}  -- Check events frequently
    if e[1] == "modem_message" then
        if not handleMessage(table.unpack(e)) then
            break
        end
    elseif e[1] == "interrupted" then
        modem.broadcast(PORT, MESSAGE_TYPES.SHUTDOWN)
        break
    end
end

-- Clean shutdown
modem.close(PORT)
print("Server shutdown complete")

term.clear()
gpu.setBackground(originalBackground)
gpu.setForeground(originalForeground) 
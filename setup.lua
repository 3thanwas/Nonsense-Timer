local component = require("component")
local term = require("term")
local event = require("event")
local shell = require("shell")
local filesystem = require("filesystem")
local gpu = component.gpu

-- Constants
local BG_COLOR = 0x170024    -- Dark purple
local TEXT_COLOR = 0xFFBFBF  -- Light pink
local HIGHLIGHT_COLOR = 0xff8080  -- Brighter pink for highlights
local PORT_MIN = 1000        -- Minimum valid port
local PORT_MAX = 9999        -- Maximum valid port
local DEFAULT_PORT = 1234    -- Default port if none specified

-- Package information
local PACKAGE_NAME = "nonsense-timer"
local REQUIRED_FILES = {
    "nonsense_client.lua",
    "nonsense_server.lua"
}

-- Save original colors
local originalBackground = gpu.getBackground()
local originalForeground = gpu.getForeground()

-- Get screen dimensions
local width, height = gpu.getResolution()

-- Menu options
local options = {
    { text = "Configure Server", file = "nonsense_server.lua" },
    { text = "Prepare Client Drive", file = "nonsense_client.lua" },
    { text = "Update Files", file = nil },
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

-- List available drives
local function listDrives()
    local drives = {}
    for address, type in component.list("filesystem") do
        local proxy = component.proxy(address)
        -- Skip system drives and check if drive is writable
        if proxy.getLabel() ~= "tmpfs" and proxy.getLabel() ~= "rom" and proxy.isReadOnly() ~= true then
            local label = proxy.getLabel() or "Unnamed Drive"
            -- Safely get drive space information
            local spaceTotal = 0
            local spaceUsed = 0
            pcall(function()
                spaceTotal = proxy.spaceTotal() or 0
                spaceUsed = spaceTotal - (proxy.spaceAvailable() or 0)
            end)
            
            table.insert(drives, {
                address = address,
                label = label,
                spaceTotal = spaceTotal,
                spaceUsed = spaceUsed
            })
        end
    end
    return drives
end

-- Select a drive from the list
local function selectDrive(purpose)
    term.clear()
    local drives = listDrives()
    if #drives == 0 then
        print("No suitable drives found!")
        print("Press any key to continue...")
        event.pull("key_down")
        return nil
    end
    
    print("Select drive for " .. purpose .. ":")
    print("─────────────────────────────")
    for i, drive in ipairs(drives) do
        local usedSpace = math.floor(drive.spaceUsed / 1024)
        local totalSpace = math.floor(drive.spaceTotal / 1024)
        print(string.format("%d) %s (%dK/%dK used)", i, drive.label, usedSpace, totalSpace))
    end
    print("─────────────────────────────")
    print("Enter number (or 0 to cancel):")
    
    while true do
        local input = term.read()
        local num = tonumber(input)
        if num == 0 then return nil end
        if num and num >= 1 and num <= #drives then
            return drives[num]
        end
        print("Invalid selection. Try again:")
    end
end

-- Label a drive
local function labelDrive(drive)
    print("Current label: " .. drive.label)
    print("Enter new label (or press Enter to keep current):")
    local input = term.read():gsub("\n", "")
    if input ~= "" then
        local proxy = component.proxy(drive.address)
        proxy.setLabel(input)
        drive.label = input
    end
end

-- Create autorun script
local function createAutorun(drive, scriptName, port)
    local proxy = component.proxy(drive.address)
    local autorunContent = string.format([[
local component = require("component")
local shell = require("shell")
local fs = require("filesystem")

-- Mount this drive
local _, drive = ...
fs.mount(drive, "/home/nonsense-timer")

-- Set port if provided
if %d then
    os.setenv("NONSENSE_PORT", "%d")
end

-- Run the script
shell.execute("/home/nonsense-timer/%s")
]], port or 0, port or 0, scriptName)
    
    local file = proxy.open("autorun.lua", "w")
    proxy.write(file, autorunContent)
    proxy.close(file)
end

-- Configure port
local function configurePort()
    while true do
        print(string.format("Enter port number (%d-%d) [default: %d]:", PORT_MIN, PORT_MAX, DEFAULT_PORT))
        local input = term.read():gsub("\n", "")
        if input == "" then return DEFAULT_PORT end
        
        local port = tonumber(input)
        if port and port >= PORT_MIN and port <= PORT_MAX then
            return port
        end
        print("Invalid port number!")
    end
end

-- Check if OPPM is installed
local function checkOppm()
    if not filesystem.exists("/usr/bin/oppm") then
        print("Installing OPPM...")
        local result = shell.execute("wget -f https://raw.githubusercontent.com/OpenPrograms/OpenPrograms.github.io/master/repos.cfg /etc/oppm.cfg")
        if not result then
            error("Failed to download OPPM configuration")
            return false
        end
        result = shell.execute("wget -f https://raw.githubusercontent.com/OpenPrograms/OpenPrograms.github.io/master/oppm/oppm.lua /usr/bin/oppm")
        if not result then
            error("Failed to download OPPM")
            return false
        end
        shell.execute("chmod +x /usr/bin/oppm")
    end
    return true
end

-- Update package repository
local function updateRepository()
    print("Updating package repository...")
    return shell.execute("oppm update")
end

-- Install required package
local function installPackage()
    print("Installing Nonsense Timer package...")
    return shell.execute("oppm install " .. PACKAGE_NAME)
end

-- Create program directory if it doesn't exist
local function ensureDirectory()
    local programDir = "/home/nonsense-timer"
    if not filesystem.exists(programDir) then
        filesystem.makeDirectory(programDir)
    end
    return programDir
end

-- Update/download all required files
local function updateFiles()
    term.clear()
    print("Updating Nonsense Timer files...")
    
    -- Check and install OPPM if needed
    if not checkOppm() then
        print("Failed to install OPPM")
        return false
    end
    
    -- Update OPPM repository
    if not updateRepository() then
        print("Failed to update package repository")
        return false
    end
    
    -- Install package
    if not installPackage() then
        print("Failed to install package")
        return false
    end
    
    print("\nAll files updated successfully!")
    print("Press any key to continue...")
    event.pull("key_down")
    return true
end

-- Copy file to drive
local function copyFile(filename, sourcePath, targetPath)
    if not filesystem.exists(sourcePath .. "/" .. filename) then
        error("Source file not found: " .. sourcePath .. "/" .. filename)
        return false
    end
    
    -- Ensure target directory exists
    if not filesystem.exists(targetPath) then
        filesystem.makeDirectory(targetPath)
    end
    
    -- Copy the file
    local success = filesystem.copy(
        filesystem.concat(sourcePath, filename),
        filesystem.concat(targetPath, filename)
    )
    
    if not success then
        error("Failed to copy file: " .. filename)
        return false
    end
    return true
end

-- Configure server
local function configureServer()
    term.clear()
    print("=== Server Configuration ===")
    
    -- Select and configure drive
    local drive = selectDrive("server installation")
    if not drive then return end
    
    -- Label drive if desired
    print("\nWould you like to label/relabel the drive? (y/n)")
    if term.read():lower():sub(1,1) == "y" then
        labelDrive(drive)
    end
    
    -- Configure port
    local port = configurePort()
    
    -- Create autorun script and copy server files
    print("\nPreparing drive...")
    createAutorun(drive, "nonsense_server.lua", port)
    
    -- Copy server file to drive
    local mountPath = "/mnt/" .. drive.address:sub(1,3)
    local success = pcall(function()
        -- Ensure drive is mounted
        if not filesystem.exists(mountPath) then
            filesystem.mount(component.proxy(drive.address), mountPath)
        end
        
        -- Copy from installed location to drive
        copyFile(
            "nonsense_server.lua",
            "/home/nonsense-timer",
            filesystem.concat(mountPath, "nonsense-timer")
        )
    end)
    
    if success then
        print("\nServer configuration complete!")
        print("You can now reboot the computer to start the server.")
    else
        print("\nError configuring server!")
    end
    print("Press any key to continue...")
    event.pull("key_down")
end

-- Prepare client drive
local function prepareClientDrive()
    term.clear()
    print("=== Client Drive Preparation ===")
    
    -- Select and configure drive
    local drive = selectDrive("client installation")
    if not drive then return end
    
    -- Label drive if desired
    print("\nWould you like to label/relabel the drive? (y/n)")
    if term.read():lower():sub(1,1) == "y" then
        labelDrive(drive)
    end
    
    -- Create autorun script and copy client files
    print("\nPreparing drive...")
    createAutorun(drive, "nonsense_client.lua")
    
    -- Copy client file to drive
    local mountPath = "/mnt/" .. drive.address:sub(1,3)
    local success = pcall(function()
        -- Ensure drive is mounted
        if not filesystem.exists(mountPath) then
            filesystem.mount(component.proxy(drive.address), mountPath)
        end
        
        -- Copy from installed location to drive
        copyFile(
            "nonsense_client.lua",
            "/home/nonsense-timer",
            filesystem.concat(mountPath, "nonsense-timer")
        )
    end)
    
    if success then
        print("\nClient drive preparation complete!")
        print("You can now insert this drive into any computer to run the client.")
    else
        print("\nError preparing client drive!")
    end
    print("Press any key to continue...")
    event.pull("key_down")
end

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
                elseif options[selectedOption].text == "Update Files" then
                    updateFiles()
                elseif options[selectedOption].text == "Configure Server" then
                    configureServer()
                elseif options[selectedOption].text == "Prepare Client Drive" then
                    prepareClientDrive()
                end
            end
        end
    end
end

-- Initial setup
if not updateFiles() then
    print("Initial setup failed. Please check your internet connection.")
    return
end

-- Run the menu
runMenu()

-- Restore original colors and clear screen
gpu.setBackground(originalBackground)
gpu.setForeground(originalForeground)
term.clear()
print("Setup closed") 
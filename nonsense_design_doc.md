# Nonsense Timer Network Display - Design Document

## Core Components

### Server (nonsense_server.lua)
- [T] Network initialization
  - [X] Modem component check
  - [X] Port configuration (1234)
  - [T] Broadcast presence signal
- [T] Timer management
  - [T] Track uptime
  - [T] Broadcast updates every 1 second
  - [T] Include server status in broadcasts
- [T] Reset handling
  - [T] Accept reset signals from any client
  - [T] Reset internal timer
  - [T] Broadcast reset event to all clients
- [T] Shutdown handling
  - [T] Accept quit signals from any client
  - [T] Broadcast shutdown signal to all clients
  - [T] Clean termination of server process
- [T] Server Display
  - [X] Screen component check
  - [X] Connected clients counter
  - [X] Active client list with last seen times
  - [X] Current timer in plain text
  - [X] Box border around display
  - [X] Auto-refresh every second
  - [X] Status messages
    - [X] Server start/stop
    - [X] Client connect/disconnect
    - [X] Reset events
  - [X] Color scheme matching client
    - [X] Background: #170024 (dark purple)
    - [X] Text: #ffbfbf (light pink)

### Client (nonsense_client.lua)
- [X] Hardware Requirements
  - [X] Network Card/Linked Card check
  - [X] GPU component check
  - [X] Screen resolution detection (minimum 70x20)

- [X] Network Dependencies
  - [X] Require server connection to start
  - [X] Exit if server connection lost
  - [X] Only display data received from server

- [X] Display Components
  - [X] Large ASCII Art (8 lines high)
    - [X] Numbers (0-9)
    - [X] Colon (:)
    - [X] Letters for "NONSENSE"
    - [X] Letter "D" for days
  - [X] Small ASCII Art (6 lines high)
    - [X] Letters for "TIME SINCE LAST"
  - [X] Color scheme
    - [X] Background: #170024 (dark purple)
    - [X] Text: #ffbfbf (light pink)
  - [X] Box Drawing
    - [X] Double-line box characters
    - [X] Connected boxes with T-joints
    - [X] Dotted background (░)

- [X] Screen Management
  - [X] Double buffering implementation
  - [X] Complete screen refresh on each update
  - [X] Clean screen clear on shutdown
  - [X] Dynamic width adjustment for time display

- [X] Layout
  - [X] Upper box (16 lines)
    - [X] "TIME SINCE LAST" in small ASCII art
    - [X] "NONSENSE" in large ASCII art
  - [X] Lower box (11 lines)
    - [X] Timer display in large ASCII art
    - [X] Days and time formatting
  - [X] Connected box design
    - [X] Proper T-joints
    - [X] Consistent dotted background
    - [X] Dynamic width based on content

- [X] User Input
  - [X] 'r' key for reset (keycode 19)
    - [X] Send reset signal to server
  - [X] 'q' key for quit (keycode 16)
    - [X] Send quit signal to server
    - [X] Clean screen clear
    - [X] Orderly shutdown

### Setup Menu (setup.lua)
- [X] User Interface
  - [X] Title box with program name
  - [X] Selectable menu options
  - [X] Visual highlighting of selected option
  - [X] User controls display
  - [X] Color scheme matching main program
    - [X] Background: #170024 (dark purple)
    - [X] Text: #ffbfbf (light pink)
    - [X] Highlight: #ff8080 (bright pink)

- [X] Menu Options
  - [X] Launch Client
  - [X] Launch Server
  - [X] Exit

- [X] Input Handling
  - [X] Arrow key navigation
  - [X] Enter key selection
  - [X] Clean exit handling

- [X] Script Management
  - [X] Error handling for script launches
  - [X] Terminal state preservation
  - [X] Return to menu after script exit
  - [X] Proper cleanup on exit

## Network Protocol
- [T] Message Types
  - [X] Server presence signal
  - [X] Time updates (every 1s)
  - [X] Reset signals
  - [X] Shutdown signals
  - [X] Error messages

## Testing Checklist
- [T] Server
  - [X] Starts successfully
  - [X] Broadcasts presence
  - [X] Sends updates every 1s
  - [T] Handles multiple clients
  - [T] Processes reset requests
  - [T] Manages shutdown sequence
  - [X] Display updates correctly
  - [X] Removes stale clients (>5s)

- [X] Client
  - [X] Requires server to start
  - [X] Connects only to active server
  - [X] Displays received data correctly
  - [X] Updates without artifacts
  - [X] Handles key inputs
  - [X] Resets properly
  - [X] Shuts down cleanly
  - [X] Exits on server disconnect

- [X] Setup Menu
  - [X] Displays correctly
  - [X] Handles navigation
  - [X] Launches scripts properly
  - [X] Handles errors gracefully
  - [X] Returns to menu after script exit
  - [X] Cleans up on exit

## Error Handling
- [X] Server not found on client start
- [X] Server disconnect during operation
- [T] Network message corruption
- [X] Screen resolution too small
- [X] Missing required components
- [X] Script launch failures

## Known Issues
- Client list may overflow if more than ~10 clients connect (scrolling not implemented)
- Server display does not handle terminal resize events

## Future Enhancements
- [X] Add days to timer display
- [X] Client connection counter
- [ ] Network status indicator
- [ ] Custom reset messages
- [ ] Configuration file for colors/port
- [ ] Scrollable client list
- [ ] Terminal resize handling
- [ ] Add version information to setup menu
- [ ] Add configuration options to setup menu

Status Key:
- [ ] Not Started
- [T] In Testing
- [E] Has Errors
- [X] Completed 
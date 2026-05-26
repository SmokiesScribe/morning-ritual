-- =========================================================
-- Morning Ritual — Hammerspoon Automation
-- =========================================================
--
-- Created by Victoria Griffin
-- Writing Woods — https://writingwoods.com
--
-- What this does:
-- Creates a simple morning flow when your Mac wakes:
-- settle → meditate → affirmation → planning → optional writing session
--
-- You only need to edit the CONFIGURATION section below.
--
-- First-time setup:
-- 1. Install Hammerspoon: https://www.hammerspoon.org
-- 2. Open the README for full setup instructions.
-- 3. Paste this file into init.lua.
-- 4. Reload Hammerspoon.
--
-- Permissions:
-- If apps do not open, windows do not resize, or hotkeys do not work:
-- System Settings → Privacy & Security → Accessibility → enable Hammerspoon.
--
-- How to copy a file path:
-- In Finder, right-click the file.
-- Hold Option.
-- Click "Copy [filename] as Pathname."
-- Paste that path into the matching file path setting below.
--
-- Hotkeys:
-- ⌘⌥⌃R = run ritual manually
-- Esc   = skip current timer phase, with confirmation
-- ⌘⌥⌃K = emergency stop
-- ⌘⌥⌃D = reset today's run date
-- ⌘⌥⌃S = test writing session launch
-- ⌘⌥⌃L = reload Hammerspoon config
--
-- File paths:
-- Use a FULL file path, not just a folder.
-- Good: "/Users/name/Documents/Morning Affirmation.txt"
-- Bad:  "/Users/name/Documents"
--
-- How app/file choices work:
-- - If a file path is provided and exists, the script opens that file/project.
-- - If no file path is provided, the script opens the app.
--
-- Special behavior:
-- If affirmationApp is set to "Notes",
-- the script appends a dated entry to a single ongoing note.
-- =========================================================

local settings = hs.settings

-- =========================================================
-- CONFIGURATION — EDIT THIS SECTION
-- =========================================================

local config = {
    -- -----------------------------------------------------
    -- Which steps should be included?
    -- Set any of these to false to skip that part.
    -- -----------------------------------------------------

    includeSettle = true,
    includeMeditation = true,
    includeAffirmation = true,
    includePlanning = true,
    offerWritingSession = true,

    -- -----------------------------------------------------
    -- Timing
    -- -----------------------------------------------------

    settleSeconds = 30,
    meditationMinutes = 5,

    -- -----------------------------------------------------
    -- Apps and Files
    --
    -- For each step, provide an app or a file path.
    --
    -- If a file path is provided, that file will be opened.
    -- Otherwise, the app specified will be opened.
    --
    -- Important:
    -- If using a file, this must be the full file path, not a folder.
    -- Example: /Users/greatauthor/Library/Documents/Shiny-Novel.scriv
    -- -----------------------------------------------------

    -- -----------------------------------------------------
    -- AFFIRMATION
    --
    -- Examples: Notes, TextEdit, Microsoft Word, Pages, Obsidian, etc.
    -- -----------------------------------------------------

    affirmationApp = "Notes",
    affirmationFilePath = "",
    affirmationNoteTitle = "Morning Affirmation",
    affirmationDateEmoji = "☀️",

    -- -----------------------------------------------------
    -- PLANNING
    --
    -- Examples: Todoist, Reminders, Microsoft Word, Pages, etc.
    -- -----------------------------------------------------

    planningApp = "Todoist",
    planningFilePath = "",

    -- -----------------------------------------------------
    -- WRITING SESSION
    --
    -- Examples: Scrivener, Microsoft Word, Pages, etc.
    -- -----------------------------------------------------

    writingApp = "Scrivener",
    writingProjectPath = "/Users/torigriffin/Library/CloudStorage/OneDrive-Personal/WRITING/Novels/Holler Born/Holler Born.scriv",
    writingSuccessMessage = "You are a writer.",

    -- -----------------------------------------------------
    -- Messages
    -- -----------------------------------------------------

    completionTitle = "Morning ritual complete",
    completionMessage = "Good work",
    startWritingButtonText = "Start Writing Session",
    doneButtonText = "Done",

    -- -----------------------------------------------------
    -- Sound
    --
    -- Built-in macOS options include:
    -- "Glass", "Hero", "Ping", "Pop", "Submarine", "Funk"
    -- -----------------------------------------------------

    chimeSound = "Glass",

    -- -----------------------------------------------------
    -- Hotkeys / testing
    -- -----------------------------------------------------

    hotkeyMods = { "cmd", "alt", "ctrl" },

    -- Allows the ritual to be triggered manually with ⌘⌥⌃R,
    -- even if it has already run today.
    manualAlwaysRuns = true,
}

-- =========================================================
-- DO NOT EDIT BELOW THIS LINE UNLESS YOU WANT TO CUSTOMIZE CODE
-- =========================================================

-- =========================
-- State
-- =========================

local state = {
    ritualCanvas = nil,
    ritualTimer = nil,
    completionWatcher = nil,

    remainingSeconds = 0,
    currentPhase = "settle",

    skipDialogOpen = false,
}

-- =========================
-- Date Helpers
-- =========================

local function todayString()
    return os.date("%Y-%m-%d")
end

local function shouldRunMorningRoutine()
    return settings.get("lastMorningRoutineDate") ~= todayString()
end

local function markMorningRoutineDone()
    settings.set("lastMorningRoutineDate", todayString())
end

-- =========================
-- General Helpers
-- =========================

local function playChime()
    local sound = hs.sound.getByName(config.chimeSound)

    if sound then
        sound:play()
    end
end

local function formatTime(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d", minutes, secs)
end

-- Resize an app window to fill the usable screen without entering macOS fullscreen Space mode.
local function fillScreenWindow(appName)
    hs.timer.doAfter(0.5, function()
        local app = hs.appfinder.appFromName(appName)
        if not app then return end

        app:activate(true)

        local win = app:mainWindow()
        if not win then return end

        win:raise()

        -- If the app is already in macOS fullscreen, exit that first.
        if win:isFullScreen() then
            win:setFullScreen(false)
            hs.timer.usleep(300000)
        end

        local screen = win:screen() or hs.screen.mainScreen()
        local frame = screen:frame()

        win:setFrame({
            x = frame.x,
            y = frame.y,
            w = frame.w,
            h = frame.h,
        })
    end)
end

-- Opens either:
-- 1. the provided file/project path (if it exists)
-- 2. otherwise the specified app
local function openAppOrFile(appName, filePath)
    local fileExists = filePath and filePath ~= "" and hs.fs.attributes(filePath)

    if fileExists then
        hs.execute("open " .. string.format("%q", filePath))
    elseif appName and appName ~= "" then
        hs.application.launchOrFocus(appName)
    else
        print("[Morning Ritual] No app or file configured.")
    end
end

-- =========================
-- Cleanup / Safety
-- =========================

local function stopCompletionWatcher()
    if state.completionWatcher then
        state.completionWatcher:stop()
        state.completionWatcher = nil
    end
end

local function closeRitualScreen()
    if state.ritualTimer then
        state.ritualTimer:stop()
        state.ritualTimer = nil
    end

    if state.ritualCanvas then
        state.ritualCanvas:delete()
        state.ritualCanvas = nil
    end
end

local function emergencyStop()
    closeRitualScreen()
    stopCompletionWatcher()
    hs.alert.show("Morning ritual closed")
end

-- =========================
-- Writing Session
-- =========================

local function openWritingSession()
    openAppOrFile(config.writingApp, config.writingProjectPath)

    hs.timer.doAfter(3, function()
        fillScreenWindow(config.writingApp)
        hs.alert.show(config.writingSuccessMessage)
    end)
end

-- =========================
-- Completion Flow
-- =========================

local function startCompletionWatcher()
    stopCompletionWatcher()

    state.completionWatcher = hs.timer.doEvery(2, function()
        local affirmationAppName = config.affirmationApp == "Notes" and "Notes" or config.affirmationApp
        local planningAppName = config.planningApp

        local affirmationApp = affirmationAppName and hs.appfinder.appFromName(affirmationAppName)
        local planningApp = planningAppName and hs.appfinder.appFromName(planningAppName)

        local affirmationVisible = affirmationApp and affirmationApp:mainWindow() and affirmationApp:mainWindow():isVisible()
        local planningVisible = planningApp and planningApp:mainWindow() and planningApp:mainWindow():isVisible()

        if not affirmationVisible and not planningVisible then
            stopCompletionWatcher()

            local button = hs.dialog.blockAlert(
                config.completionTitle,
                config.completionMessage,
                config.startWritingButtonText,
                config.doneButtonText,
                "NSInformationalAlertStyle"
            )

            if config.offerWritingSession and (button == config.startWritingButtonText or button == 1000) then
                openWritingSession()
            end
        end
    end)
end

-- =========================
-- Affirmation / Planning Flow
-- =========================

local openAffirmation
local openAppleNotesAffirmation

local function openPlanningAndAffirmation()
    if config.includePlanning then
        openAppOrFile(config.planningApp, config.planningFilePath)

        hs.timer.doAfter(0.8, function()
            fillScreenWindow(config.planningApp)

            if config.includeAffirmation then
                hs.timer.doAfter(0.5, openAffirmation)
            else
                startCompletionWatcher()
                markMorningRoutineDone()
            end
        end)
    elseif config.includeAffirmation then
        openAffirmation()
    else
        startCompletionWatcher()
        markMorningRoutineDone()
    end
end

openAppleNotesAffirmation = function()
    local dateHeader = os.date("%A, %B %d"):gsub(" 0", " ")

    local script = string.format([[
        tell application "Notes"
            activate
            set targetName to "%s"
            set todayHeader to "%s"
            set entryText to "<br><br>☀️<br><br><b>" & todayHeader & "</b><br><br>"
            set foundNote to missing value

            repeat with acc in accounts
                repeat with f in folders of acc
                    repeat with n in notes of f
                        if name of n is targetName then
                            set foundNote to n
                            exit repeat
                        end if
                    end repeat
                    if foundNote is not missing value then exit repeat
                end repeat
                if foundNote is not missing value then exit repeat
            end repeat

            if foundNote is not missing value then
                set body of foundNote to body of foundNote & entryText
                show foundNote
            else
                make new note at folder "Notes" with properties {name:targetName, body:entryText}
            end if
        end tell
    ]], config.affirmationNoteTitle, dateHeader)

    hs.osascript.applescript(script)
    fillScreenWindow("Notes")
    startCompletionWatcher()
    markMorningRoutineDone()
end

openAffirmation = function()
    if config.affirmationApp == "Notes" then
        openAppleNotesAffirmation()
    else
        openAppOrFile(config.affirmationApp, config.affirmationFilePath)
        fillScreenWindow(config.affirmationApp)
        startCompletionWatcher()
        markMorningRoutineDone()
    end
end

-- =========================
-- Meditation Screen UI
-- =========================

local function applyPhaseStyle()
    if not state.ritualCanvas then return end

    if state.currentPhase == "settle" then
        state.ritualCanvas["background"].fillColor = { red = 0.06, green = 0.09, blue = 0.075, alpha = 1 }
        state.ritualCanvas["orb"].fillColor = { red = 0.95, green = 0.62, blue = 0.22, alpha = 0.14 }
        state.ritualCanvas["titleText"].text = "Welcome to your day."
        state.ritualCanvas["bodyText"].text = "Settle in. Get comfortable."
    elseif state.currentPhase == "meditate" then
        state.ritualCanvas["background"].fillColor = { red = 0.025, green = 0.045, blue = 0.075, alpha = 1 }
        state.ritualCanvas["orb"].fillColor = { red = 0.35, green = 0.58, blue = 0.95, alpha = 0.13 }
        state.ritualCanvas["titleText"].text = "Meditate"
        state.ritualCanvas["bodyText"].text = "Breathe. Just exist."
    end
end

local function updateCanvasText()
    if not state.ritualCanvas then return end

    applyPhaseStyle()
    state.ritualCanvas["timerText"].text = formatTime(state.remainingSeconds)
end

local function drawRitualScreen()
    local screen = hs.screen.mainScreen()
    local frame = screen:fullFrame()

    state.ritualCanvas = hs.canvas.new(frame)
    state.ritualCanvas:level(hs.canvas.windowLevels.screenSaver)
    state.ritualCanvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)

    state.ritualCanvas:appendElements(
        {
            id = "background",
            type = "rectangle",
            action = "fill",
            fillColor = { red = 0.06, green = 0.09, blue = 0.075, alpha = 1 },
            frame = { x = 0, y = 0, w = frame.w, h = frame.h },
        },
        {
            id = "orb",
            type = "circle",
            action = "fill",
            fillColor = { red = 0.95, green = 0.62, blue = 0.22, alpha = 0.14 },
            frame = { x = frame.w / 2 - 90, y = frame.h * 0.19, w = 180, h = 180 },
        },
        {
            id = "titleText",
            type = "text",
            text = "Welcome to your day.",
            textSize = 40,
            textColor = { white = 0.94, alpha = 1 },
            textAlignment = "center",
            frame = { x = 0, y = frame.h * 0.18, w = frame.w, h = 130 },
        },
        {
            id = "timerText",
            type = "text",
            text = "00:00",
            textSize = 86,
            textColor = { white = 0.98, alpha = 1 },
            textAlignment = "center",
            frame = { x = 0, y = frame.h * 0.46, w = frame.w, h = 110 },
        },
        {
            id = "bodyText",
            type = "text",
            text = "Settle in. Get comfortable.",
            textSize = 23,
            textColor = { white = 0.68, alpha = 1 },
            textAlignment = "center",
            frame = { x = 0, y = frame.h * 0.62, w = frame.w, h = 60 },
        },
        {
            type = "text",
            text = "Esc = skip ahead   •   ⌘⌥⌃K = close ritual",
            textSize = 16,
            textColor = { white = 0.46, alpha = 1 },
            textAlignment = "center",
            frame = { x = 0, y = frame.h - 85, w = frame.w, h = 40 },
        }
    )

    state.ritualCanvas:show()
end

-- =========================
-- Ritual Phase Flow
-- =========================

local function startAffirmationPhase()
    closeRitualScreen()
    openPlanningAndAffirmation()
end

local function startMeditationPhase()
    playChime()

    state.currentPhase = "meditate"
    state.remainingSeconds = config.meditationMinutes * 60

    updateCanvasText()
end

local function skipCurrentPhase()
    if not state.ritualCanvas then return end

    if state.currentPhase == "settle" then
        startMeditationPhase()
    elseif state.currentPhase == "meditate" then
        playChime()
        startAffirmationPhase()
    end
end

local function startRitualTimer()
    state.ritualTimer = hs.timer.doEvery(1, function()
        state.remainingSeconds = state.remainingSeconds - 1
        updateCanvasText()

        if state.remainingSeconds <= 0 then
            if state.currentPhase == "settle" then
                startMeditationPhase()
            elseif state.currentPhase == "meditate" then
                playChime()
                startAffirmationPhase()
            end
        end
    end)
end

local function startMorningRitual()
    closeRitualScreen()
    stopCompletionWatcher()

    if config.includeSettle then
        state.currentPhase = "settle"
        state.remainingSeconds = config.settleSeconds
        drawRitualScreen()
        updateCanvasText()
        startRitualTimer()
    elseif config.includeMeditation then
        state.currentPhase = "meditate"
        state.remainingSeconds = config.meditationMinutes * 60
        drawRitualScreen()
        updateCanvasText()
        playChime()
        startRitualTimer()
    else
        openPlanningAndAffirmation()
    end
end

local function runMorningRoutine(force)
    if force or shouldRunMorningRoutine() then
        startMorningRitual()
    end
end

-- =========================
-- Wake Watcher
-- =========================

local caffeineWatcher = hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.systemDidWake then
        runMorningRoutine(false)
    end
end)

caffeineWatcher:start()

-- =========================
-- Hotkeys
-- =========================

hs.hotkey.bind(config.hotkeyMods, "R", function()
    runMorningRoutine(config.manualAlwaysRuns)
end)

hs.hotkey.bind({}, "escape", function()
    if not state.ritualCanvas then return end
    if state.skipDialogOpen then return end

    state.skipDialogOpen = true

    -- Lower the fullscreen canvas briefly so the confirmation dialog appears above it.
    state.ritualCanvas:level(hs.canvas.windowLevels.modalPanel - 1)

    local button = hs.dialog.blockAlert(
        "Skip this part?",
        "Choose intentionally.",
        "Keep going",
        "Skip",
        "NSInformationalAlertStyle"
    )

    if state.ritualCanvas then
        state.ritualCanvas:level(hs.canvas.windowLevels.screenSaver)
    end

    state.skipDialogOpen = false

    if button == "Skip" then
        skipCurrentPhase()
    end
end)

hs.hotkey.bind(config.hotkeyMods, "K", function()
    emergencyStop()
end)

hs.hotkey.bind(config.hotkeyMods, "D", function()
    settings.set("lastMorningRoutineDate", nil)
    hs.alert.show("Morning ritual date reset")
end)

hs.hotkey.bind(config.hotkeyMods, "S", function()
    openWritingSession()
end)

hs.hotkey.bind(config.hotkeyMods, "L", function()
    hs.reload()
end)

hs.alert.show("Morning ritual loaded")

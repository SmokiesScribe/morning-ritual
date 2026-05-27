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
-- Space   = continue / skip current ritual phase
-- ⌘⌥⌃R = run ritual manually
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

    settleSeconds = 45,
    meditationMinutes = 5,
    meditationCompletePauseSeconds = 15,

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
    affirmationNoteTitle = "☀️ Morning Affirmation",

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
    writingProjectPath = "",
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
    ritualActive = false,
    caffeineAssertion = nil,

    ritualCanvas = nil,
    ritualTimer = nil,
    completionWatcher = nil,

    continueHotkey = nil,

    remainingSeconds = 0,
    currentPhase = nil,
    phaseIndex = 0,

    openedAppPhase = false,
    skipDialogOpen = false,

    meditationSkipped = false,
}

-- =========================
-- Forward Declarations
-- =========================

local advanceToNextPhase
local startRitualTimer
local skipCurrentPhase
local endMorningRitual

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
        sound:volume(0.7)
        sound:play()
    end
end

local function formatTime(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d", minutes, secs)
end

local function fillScreenWindow(appName)
    hs.timer.doAfter(0.5, function()
        local app = hs.appfinder.appFromName(appName)
        if not app then return end

        app:activate(true)

        local win = app:mainWindow()
        if not win then return end

        win:raise()

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

local function preventSleep()
    hs.caffeinate.set("displayIdle", true, true)
end

local function allowSleep()
    hs.caffeinate.set("displayIdle", false, true)
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

local function stopRitualHotkeys()
    if state.continueHotkey then
        state.continueHotkey:delete()
        state.continueHotkey = nil
    end
end

local function startRitualHotkeys()
    stopRitualHotkeys()

    state.continueHotkey = hs.hotkey.bind({}, "space", function()
        skipCurrentPhase()
    end)
end

endMorningRitual = function()
    state.ritualActive = false
    state.currentPhase = nil
    state.phaseIndex = 0

    allowSleep()
    closeRitualScreen()
    stopCompletionWatcher()
    stopRitualHotkeys()
end

local function emergencyStop()
    endMorningRitual()
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

local function showCompletionPrompt()
    if config.offerWritingSession then
        local button = hs.dialog.blockAlert(
            config.completionTitle,
            config.completionMessage,
            config.startWritingButtonText,
            config.doneButtonText,
            "NSInformationalAlertStyle"
        )

        if button == config.startWritingButtonText or button == 1000 then
            openWritingSession()
        end
    else
        hs.alert.show(config.completionTitle)
    end
end

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
            showCompletionPrompt()
        end
    end)
end

-- =========================
-- Affirmation / Planning
-- =========================

local function openAppleNotesAffirmation()
    local script = string.format([[
        tell application "Notes"
            activate
            set targetName to "%s"
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
                show foundNote
            else
                set foundNote to make new note at folder "Notes" with properties {name:targetName, body:""}
                show foundNote
            end if
        end tell
    ]], config.affirmationNoteTitle)

    hs.osascript.applescript(script)
end

local function openAffirmation()
    if config.affirmationApp == "Notes" then
        openAppleNotesAffirmation()
    else
        openAppOrFile(config.affirmationApp, config.affirmationFilePath)
    end
end

-- =========================
-- Ritual Screen UI
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
    if state.ritualCanvas then return end

    local screen = hs.screen.mainScreen()
    local frame = screen:fullFrame()

    state.ritualCanvas = hs.canvas.new(frame)

    -- Safer than screenSaver level while developing.
    state.ritualCanvas:level(hs.canvas.windowLevels.floating)
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
            text = "Space = continue   •   ⌘⌥⌃K = close ritual",
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

local phases = {
    {
        id = "settle",
        enabled = function()
            return config.includeSettle
        end,
        start = function()
            state.currentPhase = "settle"
            state.remainingSeconds = config.settleSeconds

            drawRitualScreen()
            updateCanvasText()
            startRitualTimer()
        end,
    },
    {
        id = "meditate",
        enabled = function()
            return config.includeMeditation
        end,
        start = function()
            state.currentPhase = "meditate"
            state.remainingSeconds = config.meditationMinutes * 60

            drawRitualScreen()
            playChime()
            updateCanvasText()
            startRitualTimer()
        end,
    },
    {
        id = "meditationComplete",
        enabled = function()
            return config.includeMeditation and not state.meditationSkipped
        end,
        start = function()
            state.currentPhase = "meditationComplete"
            state.remainingSeconds = 0

            playChime()
            drawRitualScreen()

            state.ritualCanvas["background"].fillColor = { red = 0.035, green = 0.065, blue = 0.05, alpha = 1 }
            state.ritualCanvas["orb"].fillColor = { red = 0.95, green = 0.82, blue = 0.38, alpha = 0.12 }
            state.ritualCanvas["titleText"].text = "Meditation complete"
            state.ritualCanvas["timerText"].text = "Take a deep breath."
            state.ritualCanvas["bodyText"].text = "Press Space to continue."

            hs.timer.doAfter(config.meditationCompletePauseSeconds, function()
                if state.ritualActive and state.currentPhase == "meditationComplete" then
                    advanceToNextPhase()
                end
            end)
        end,
    },
    {
        id = "planning",
        enabled = function()
            return config.includePlanning
        end,
        start = function()
            state.currentPhase = "planning"
            state.openedAppPhase = true

            closeRitualScreen()
            openAppOrFile(config.planningApp, config.planningFilePath)

            hs.timer.doAfter(0.8, advanceToNextPhase)
        end,
    },
    {
        id = "affirmation",
        enabled = function()
            return config.includeAffirmation
        end,
        start = function()
            state.currentPhase = "affirmation"
            state.openedAppPhase = true

            closeRitualScreen()
            openAffirmation()

            hs.timer.doAfter(0.8, advanceToNextPhase)
        end,
    },
}

local function finishMorningRitual()
    local openedAppPhase = state.openedAppPhase

    markMorningRoutineDone()
    endMorningRitual()

    if openedAppPhase then
        startCompletionWatcher()
    else
        showCompletionPrompt()
    end
end

advanceToNextPhase = function()
    if not state.ritualActive then return end

    state.phaseIndex = state.phaseIndex + 1

    while state.phaseIndex <= #phases do
        local phase = phases[state.phaseIndex]

        if phase.enabled() then
            phase.start()
            return
        end

        state.phaseIndex = state.phaseIndex + 1
    end

    finishMorningRitual()
end

skipCurrentPhase = function()
    if not state.ritualActive then return end

    if state.currentPhase == "meditate" then
        if state.skipDialogOpen then return end

        state.skipDialogOpen = true

        local button = hs.dialog.blockAlert(
            "Skip meditation?",
            "Choose intentionally.",
            "Keep meditating",
            "Skip",
            "NSInformationalAlertStyle"
        )

        state.skipDialogOpen = false

        if button ~= "Skip" then
            return
        end

        state.meditationSkipped = true
    end

    advanceToNextPhase()
end

startRitualTimer = function()
    if state.ritualTimer then
        state.ritualTimer:stop()
        state.ritualTimer = nil
    end

    state.ritualTimer = hs.timer.doEvery(1, function()
        state.remainingSeconds = state.remainingSeconds - 1
        updateCanvasText()

        if state.remainingSeconds <= 0 then
            state.ritualTimer:stop()
            state.ritualTimer = nil
            advanceToNextPhase()
        end
    end)
end

local function startMorningRitual()
    endMorningRitual()

    state.ritualActive = true
    state.phaseIndex = 0
    state.openedAppPhase = false
    state.skipDialogOpen = false
    state.meditationSkipped = false

    preventSleep()
    startRitualHotkeys()
    advanceToNextPhase()
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
-- Permanent Hotkeys
-- =========================
-- These are allowed to exist outside the ritual lifecycle.

hs.hotkey.bind(config.hotkeyMods, "R", function()
    runMorningRoutine(config.manualAlwaysRuns)
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

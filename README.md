# Morning Ritual

A morning automation for macOS using Hammerspoon.

Current version: 1.0.1

Morning Ritual creates a calm transition into meaningful work by guiding you through optional phases:

- settling in
- meditation
- affirmation or journaling
- planning
- an optional writing session

The goal is to reduce friction and encourage intentional, positive habits.

---

# Features

- Full-screen meditation timer
- Optional settle-in countdown
- Optional writing-session launch
- Support for apps OR files/projects
- Apple Notes integration with dated entries
- Automatically runs after your Mac wakes
- Manual trigger hotkey
- Fully configurable

---

# Requirements

- macOS
- Hammerspoon

Download Hammerspoon:

https://www.hammerspoon.org

---
# Installation

## 1. Install Hammerspoon

Download Hammerspoon here:

https://www.hammerspoon.org

Open the downloaded file and drag Hammerspoon into your Applications folder.

Then launch Hammerspoon.

You should now see a small Hammerspoon icon in your Mac menu bar near the clock.

---

## 2. Open the Hammerspoon Config Folder

Click the Hammerspoon menu bar icon.

Choose:

`Open Config`

This opens Hammerspoon’s configuration folder in Finder.

---

## 3. Open `init.lua`

Inside the folder, look for a file called:

`init.lua`

This is Hammerspoon’s main configuration file.

If the file does not exist yet:

- open TextEdit
- create a new document
- choose Format → Make Plain Text
- choose File → Save
- navigate to the Hammerspoon config folder that opened earlier
- save the file as:

`init.lua`

Important:
- save it inside the Hammerspoon config folder
- make sure the filename is exactly:

`init.lua`

not:

`init.lua.txt`

---

## 4. Paste the Morning Ritual Script

Download the zip file from this repository.

Open `init.lua`.

Delete any existing text.

Copy the contents of `morning-ritual.lua` into `init.lua`

Save the file.

---

## 5. Reload Hammerspoon

Click the Hammerspoon menu bar icon again.

Choose:

`Reload Config`

If everything worked, you should see:

`Morning ritual loaded`

appear briefly on your screen.

---

# Permissions

macOS may block automation features until permissions are enabled.

If:
- apps do not open
- windows do not resize
- hotkeys do not work
- Notes automation fails

Enable Hammerspoon here:

System Settings  
→ Privacy & Security  
→ Accessibility

You may also be prompted for Automation permissions.

---

# Basic Usage

The ritual automatically runs the first time your Mac wakes each day.

You can also manually trigger it:

`⌘⌥⌃R`

---

# Hotkeys

| Hotkey | Action |
|---|---|
| ⌘⌥⌃R | Manually start the ritual |
| Esc | Skip current timer phase |
| ⌘⌥⌃K | Emergency stop |
| ⌘⌥⌃D | Reset today's run date |
| ⌘⌥⌃S | Test writing-session launch |
| ⌘⌥⌃L | Reload Hammerspoon config |

---

# Configuration

You only need to edit the `CONFIGURATION` section near the top of the script.

---

# Include or Skip Steps

```lua
includeSettle = true,
includeMeditation = true,
includeAffirmation = true,
includePlanning = true,
offerWritingSession = true,
```

Set any of these to `false` to disable that part of the ritual.

---

# Meditation Timing

```lua
settleSeconds = 30,
meditationMinutes = 5,
```

---

# Using Apps vs Files

The script supports both:
- opening apps
- opening specific files/projects

Behavior:
- if a file path exists, the file/project opens
- otherwise the app opens
- if `affirmationApp = "Notes"`, special Apple Notes behavior is used

---

# Apple Notes Example

```lua
affirmationApp = "Notes",
affirmationFilePath = "",
affirmationNoteTitle = "Morning Affirmation",
```

This appends dated entries into one ongoing Apple Note.

---

# TextEdit Example

```lua
affirmationApp = "TextEdit",
affirmationFilePath = "/Users/name/Documents/Affirmation.txt",
```

---

# Microsoft Word Example

```lua
writingApp = "Microsoft Word",
writingProjectPath = "/Users/name/Documents/My Draft.docx",
```

---

# Scrivener Example

```lua
writingApp = "Scrivener",
writingProjectPath = "/Users/name/Documents/My Novel.scriv",
```

---

# How to Copy a File Path

In Finder:

1. Right-click the file
2. Hold `Option`
3. Click:

`Copy [filename] as Pathname`

4. Paste into the config

Example:

```lua
writingProjectPath = "/Users/name/Documents/My Novel.scriv"
```

---

# Common App Names

Examples:

- Notes
- TextEdit
- Microsoft Word
- Pages
- Obsidian
- Todoist
- Things3
- Reminders
- Scrivener

---

# Troubleshooting

## “It opens the folder instead of the file”

You used a folder path instead of a file path.

Bad:

```lua
"/Users/name/Documents"
```

Good:

```lua
"/Users/name/Documents/Affirmation.txt"
```

---

## “The app opens but does not resize”

Enable Accessibility permissions for Hammerspoon.

---

## “Notes automation is not working”

Apple Notes automation may require:
- Accessibility permissions
- Automation permissions
- Notes already configured on your Mac

---

# Philosophy

This is not designed to maximize output.

It is designed to reduce friction, foster
positive habits, and celebrate showing up.

Use what helps.
Remove what doesn’t.

---

# License

Released under the MIT License. See `LICENSE` for details.

---

Created by Victoria Griffin  
Writing Woods — https://writingwoods.com

If Morning Ritual has been meaningful or useful to you:
https://writingwoods.com/support

---

# Changelog

1.0.1 - June 8, 2026
- Prevent caffeine watcher from going stale

1.0.0 - May 20, 2026
- Initial Release

                                                                   
                              *=-=*@@                              
                           +-+##%@@@                               
                         ==##%%%@@                                 
                       +-*%%#%%@@                                  
                      ==#%%%%%@@                                   
                     %=%%%%%%@@@                                   
                  %  =#%#%%%%@@                                    
                 +@@@*%%%%%%%@@                                    
                 +%@@*%%%%%%%@@              *--*@                 
                #*%@@*%%%%%%@@@       +==-=##%%%%@@                
                +#%%#*%%%%%%%@@  *+=+*#%%%%#%%@@@@@                
                +#%%%%%%%%%%%@@   @@%#%%%%%%%%@@                   
                *#%%%%%%%%%%%%@     *#%%%%%%%%@@                   
                %##%%%%%%%%%%%%@    *#%%%%%%%%@@                   
                @%#%%%%%%%%%%%%%@   *%%#%%%#%%%@                   
                 @%%%%%%%%%%%%%%%@@%*%%%%%%%%%%@@                  
                  @%%%%%%%%%%%%%%%%#+%#%#%%%%%#%@@                 
                   @@@%%%%%%%%%%%%%%%%%%%%%%%%%%%@@                
                  *=*%%%*#%#%%%%%%%%%%%%%%%%%%%%%@@                
                  @@#%%%%%%%%%%%%%%%%%%%%%%%%%%%%@@                
                    @%%%%%%%%%%%%%%%%%%%#%%%%%#%%@@                
                     @@@%%%#%%%%%%%%%%%%%%%%%%%#@@@                
                        @@@@@@@@@@@##%%%%%%%%%%@@@                 
          -=+****%@          @@#+=+#%%%%%%%%%%%@@                  
        ==%@@@@@@%*=*@        @@@@@@@@@@%%%%%%%@@                  
       *+%@@@    *#%#%@@         %%%@@@@%%%##%%%@@                 
       +#%@@     @%%%###@@   =-=*####*#@@@%%#%%#%@                 
       *#%@@      @@@@@@@@*-+###%###%###@@%###%%%@@                
       @##%@            +-####%##*##%%##%@@###%#%%@                
        @%%###@      --+#%%%#%#%#%##%##%@@ @%%#%%%@@               
         @@%%#**+++**#%##%%#%%%%%%%##%@@@   @%%%%%%@               
           @@@@@@@@@@@*%#%%####%%%%@@@@@@@   @#%%%%@@              
               @@@@@ =*%%%#%%%%##%####%#%%#%@ @%%%%##*%@           
                    @#%%%%%%@%%@%%%%%%%%%%%@@@ @@%%@%%@@@          
                     @@@@@@@@@@@@@@@@@@@@@@@@   @@@@@@@@           

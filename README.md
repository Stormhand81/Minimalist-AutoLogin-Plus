# Minimalist AutoLogin Plus

Minimalist AutoLogin Plus focuses on clarity, simplicity, and flow.

It delivers a clean and distraction-free login screen by removing non-essential interface elements. The result is a focused entry point into the game, where visual noise is reduced to the bare minimum and attention stays exactly where it should be.

The addon enables automatic login without the need to manually type account credentials, streamlining the process from launch to character selection.

At the character selection screen, it also allows characters to be reordered directly in the list, giving players full control over how their characters are organized and accessed.

This addon is not about adding more —  
it is about keeping only what truly matters.

---

## Installation

1. Download or clone the repository.
2. Place the files inside your World of Warcraft directory, following this structure:

```text
Data\Interface\GlueXML\GlueXML.toc
Data\Interface\GlueXML\AutoLogin.xml
Data\Interface\GlueXML\AutoLogin.lua
```


Make sure the folder structure matches exactly, otherwise the addon will not load correctly.

---

## Key Features

- Minimalist login screen with optional hidden account interface
- Cleaner account and character selection flow
- Improved character ordering and selection logic
- Safer defaults to prevent accidental character selection
- Reliable behavior when returning from `/logout`
- Lightweight, efficient, and non-intrusive
- Compatible with SuperWoW 1.4+

---

## Design Philosophy

Minimalist AutoLogin Plus is built around a single principle:

**Less interface. More intention.**

Every element that does not serve clarity is removed or silenced.  
Every action behaves in a predictable and consistent way.

The addon stays invisible — until it is needed.



### Security Note

Account credentials are stored locally using SuperWoW file storage APIs.
Passwords are not transmitted and never leave the client environment.


---

## Compatibility

- **Client:** Turtle WoW  
- **Dependency:** SuperWoW 1.4 or newer  
- **Localization:** Inherits existing AutoLogin localization support

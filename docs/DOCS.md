# Earthling — Documentation

A private, minimal travel journal for macOS. Your entries are plain Markdown files in your app's private sandbox. No accounts, no subscriptions, no servers.

---

## Contents

- [Building & Installing Earthling](#building--installing-earthling)
- [Getting Started](#getting-started)
- [Writing Entries](#writing-entries)
- [Markdown](#markdown)
- [Photos](#photos)
- [Themes](#themes)
- [Map View](#map-view)
- [Sorting Entries](#sorting-entries)
- [Export](#export)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Your Files](#your-files)
- [Privacy](#privacy)
- [Backup & Migration](#backup--migration)
- [Uninstalling Completely](#uninstalling-completely)
- [Troubleshooting](#troubleshooting)

---

## Building & Installing Earthling

Earthling is distributed as source code. You build it yourself using Xcode — no paid Apple Developer account is required. A free Apple ID is sufficient.

### Step 1 — Install Xcode

1. Open the **App Store** on your Mac, search for **Xcode**, and click **Get** 
2. Wait for the download to complete (it is large — allow 30–60 minutes depending on your connection)
3. Open Xcode once after installing — it will install additional components on first launch
4. Accept the license agreement when prompted

### Step 2 — Add your Apple ID to Xcode

A free Apple ID is required to sign the app for local use. If you do not have one, create one at [appleid.apple.com](https://appleid.apple.com) — no payment method required.

1. Open Xcode
2. **Xcode → Settings** 
3. Click the **Accounts** tab
4. Click **+** in the bottom left → **Add Apple ID**
5. Sign in with your Apple ID
6. Close Settings

### Step 3 — Get the Earthling source code

**Option A — Download as ZIP (simplest):**
1. Go to [github.com/internet-elephant/earthling](https://github.com/internet-elephant/earthling)
2. Click the green **Code** button → **Download ZIP**
3. Unzip the downloaded file
4. Move the resulting folder somewhere permanent — your Documents folder is fine

**Option B — Clone with git:**
```bash
git clone https://github.com/internet-elephant/earthling.git
```

### Step 4 — Open the project in Xcode

1. Open Xcode
2. **File → Open**
3. Navigate to the Earthling folder
4. Select **Earthling.xcodeproj** and click **Open**

### Step 5 — Add the Textual package dependency

Earthling uses the [Textual](https://github.com/gonzalezreal/textual) package for Markdown rendering. You need to add it once:

1. In Xcode: **File → Add Package Dependencies**
2. Paste this URL into the search bar:
   ```
   https://github.com/gonzalezreal/textual
   ```
3. Press **Return**
4. Click **Add Package**
5. Make sure **Textual** is checked on the next screen
6. Click **Add Package** again

### Step 6 — Configure signing

1. Click the **Earthling** project icon (blue) at the top of the left sidebar
2. Click **Earthling** under **TARGETS**
3. Click **Signing & Capabilities**
4. Select your Apple ID under **Team**
5. Leave **Automatically manage signing** checked

### Step 7 — Build and run

1. Make sure the destination at the top of the Xcode window shows **My Mac**
2. Press **⌘R** or click the **▶** Play button
3. Earthling will build and launch automatically

On first launch macOS may ask you to confirm you want to run the app — click **Open**.

---

## Getting Started

### First Launch

When you open Earthling for the first time, the detail panel shows a welcome screen cycling through "safe travels" in different languages. Click **✎ new entry** to write your first entry.

### The Layout

| Panel | Purpose |
|---|---|
| **Left — Sidebar** | List of all entries, toolbar buttons, sort control |
| **Right — Detail** | Full entry view, map view, or welcome screen |

The sidebar can be resized by dragging the divider between panels.

---

## Writing Entries

### Creating an Entry

Click **✎** in the toolbar or press **⌘N**.

### Entry Fields

| Field | Required | Notes |
|---|---|---|
| **Date** | Yes | Auto-filled with today. Tap to change |
| **Location** | Yes | City name with MapKit autocomplete |
| **Sublocation** | No | Neighbourhood, district, arrondissement, trail, etc. |
| **Body** | No | Free-form Markdown text |

### Location Autocomplete

As you type, Earthling queries Apple's MapKit for suggestions. Selecting one fills in city, region, country, continent, and GPS coordinates automatically.

Location queries go to Apple's servers using a rotating anonymous identifier — not your Apple ID. Once saved, coordinates are stored locally and never transmitted anywhere.

If offline, type the city manually — the entry will save without GPS coordinates and won't appear as a map pin.

### Editing an Entry

Select an entry, then click **✏** or double-click the text. Click **Save** (**⌘S**) or **Cancel** (**Escape**) when done.

### Deleting an Entry

Click **🗑** in read mode. A confirmation dialog appears before anything is deleted. Deletion removes the `.md` file, photo subfolder, and any empty parent folders. **This cannot be undone.**

---

## Markdown

Earthling renders Markdown via the [Textual](https://github.com/gonzalezreal/swift-markdown-ui) library.

### Supported Syntax

| Element | Syntax |
|---|---|
| **Bold** | `**text**` |
| *Italic* | `*text*` |
| Heading 1 | `# Heading` |
| Heading 2 | `## Heading` |
| Heading 3 | `### Heading` |
| Bullet list | `- item` |
| Numbered list | `1. item` |
| Blockquote | `> text` |
| Inline code | `` `code` `` |
| Code block | ```` ``` ```` |
| Horizontal rule | `---` |
| Link | `[text](url)` |

Strikethrough (`~~text~~`) is not supported. HTML tags are not processed.

### Markdown Cheat Sheet

Available in edit mode — click **M↓** in the toolbar or press **⌘/**.

---

## Photos

### Adding Photos

In edit mode, add photos by:
1. **Toolbar button** — click **⊞** to open a file picker
2. **Drag from Finder** — drag images onto the entry panel
3. **Drop zone** — drag onto the dashed area at the bottom

Supported formats: JPEG, PNG, HEIC, WebP, TIFF, and others.

Tags are inserted automatically at cursor position:
- Single: `![photo:filename.jpg]`
- Gallery: `![gallery:file1.jpg|file2.jpg]`

### Photo Options

Click a thumbnail in the edit strip:

| Option | Values |
|---|---|
| **Alignment** | Left · Center · Right |
| **Size** | Small · Medium · Large · Full |
| **Caption** | Free text |

### Reordering

Drag thumbnails in the edit strip. The gallery tag updates automatically.

### Removing

Click **×** on a thumbnail, then **Save**.

---

## Themes

Open **Settings** (**⌘,**) to choose from 10 themes.

### Light Themes

| Theme | Character |
|---|---|
| **Modern** | Clean white, system sans-serif |
| **Warm** | Cream tones, serif typeface |
| **Lavender** | Soft purple |
| **Sage** | Muted green |
| **Rose** | Warm pink |
| **Arctic** | Cool blue-white |

### Dark Themes

| Theme | Character |
|---|---|
| **Dark** | Near-black, light text |
| **Terminal** | True black, green monospaced |
| **Slate** | Deep blue-grey |
| **Dusk** | Deep purple-black |

---

## Map View

Click the map button in the sidebar toolbar. Pins appear for every entry with GPS coordinates. Click a pin to jump to that entry.

Entries created with manually typed locations will not have coordinates and won't appear as pins.

---

## Sorting Entries

Click **↕** in the sidebar toolbar:

| Option | Sorts by |
|---|---|
| **Entry Date (Newest)** | Entry date, newest first — default |
| **Entry Date (Oldest)** | Entry date, oldest first |
| **Date Added (Newest)** | File creation date, newest first |
| **Date Added (Oldest)** | File creation date, oldest first |

---

## Export

Click **⬆** to enter export mode. Select entries, then choose a format.

**JSON** — full structured export with all fields. Best for archiving or importing elsewhere.

**CSV** — one row per entry, spreadsheet-friendly. Photo metadata not included.

**PDF** — formatted document. Options for single entry, one file per entry, or combined with page break choices.

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| **⌘,** | Open Settings |
| **Escape** | Cancel / exit edit mode |
| **⌘/** | Markdown cheat sheet (edit mode) |

---

## Your Files

### Where Files Live

```
~/Library/Containers/com.donuts.Earthling/Data/Documents/Earthling/
```

Private to Earthling, not synced by iCloud Drive. To open in Finder use **Go → Go to Folder** (**⌘⇧G**) and paste the path above.

### Folder Structure

```
Earthling/
  {Continent}/
    {Country}/
      {City}/
        {date}-{city}-{shortID}.md
        {shortID}/
          {date}-{city}-{photoname}.jpg
```

### The Frontmatter Format

```
---
id: 550e8400-e29b-41d4-a716-446655440000
date: 2026-03-14T00:00:00Z
city: Kyoto
region: Kyoto Prefecture
country: Japan
continent: Asia
sublocation: Gion
latitude: 35.0116
longitude: 135.7681
createdAt: 2026-03-14T09:23:11Z
photos: [{"id":"...","filename":"...","alignment":"center","size":"medium","caption":""}]
---
```

| Field | Notes |
|---|---|
| `id` | Unique identifier — do not change |
| `date` | Entry date as set in the app |
| `latitude` / `longitude` | Optional — only present if MapKit autocomplete was used |
| `photos` | Single-line JSON array |

### Reading Files Without the App

Any text editor can open `.md` files. Changes made externally are picked up on next app launch.

Do not change the `id` field. The `photos` JSON line must stay on one line. The opening `---` must be the very first line of the file.

---

## Privacy

| What | Where it goes |
|---|---|
| **Entry text** | Your Mac only |
| **Photos** | Your Mac only |
| **GPS coordinates** | Your Mac only — never transmitted |
| **Location search** | Apple's servers briefly for lookup, via anonymous identifier |
| **Analytics** | Nowhere |
| **Accounts** | None |

No data is ever transmitted to Internet Elephant or any third party.

---

## Backup & Migration

### Backing Up

Your entries are in:
```
~/Library/Containers/com.donuts.Earthling/Data/Documents/Earthling/
```

Time Machine backs this up automatically. For manual backup, copy the folder to an external drive or export entries to JSON or PDF.

This path is inside the app sandbox and is **not** synced by iCloud Drive.

### Moving to a New Mac

1. Copy `~/Library/Containers/com.donuts.Earthling/Data/Documents/Earthling/` to an external drive
2. Install Earthling on the new Mac and launch once to create the sandbox
3. Quit Earthling
4. Copy your `Earthling/` folder into the same path on the new Mac
5. Relaunch — all entries load immediately

---

## Uninstalling Completely

**1. Delete the app:**
```
/Applications/Earthling.app
```

**2. Delete all entries and data** (export first if you want a copy):
```
~/Library/Containers/com.donuts.Earthling/
```

To reach the Library folder, hold **Option** and click **Go** in the menu bar.

---

## Troubleshooting

**Entries not appearing** — Check the sandbox folder exists at the correct path and relaunch.

**"Entry could not be saved"** — Check available disk space. Quit and relaunch.

**Location autocomplete not working** — Requires an internet connection. You can type the city manually and save without autocomplete.

**Map pin missing** — Only entries created using MapKit autocomplete have coordinates. Manually typed locations will not appear on the map.

**Photos not showing** — The photo file may have been moved. In edit mode, remove the broken tag and re-add the photo.

**Slow with long entries** — Entries over 100KB switch to plain text rendering automatically. A notice appears at the top of the entry.

**App blocked on another Mac** — Go to **System Settings → Privacy & Security** and click **Open Anyway**.

---

*Earthling is open source software released under the MIT License. Built with [Textual](https://github.com/gonzalezreal/textual), Apple MapKit, SwiftUI, and AppKit. Design and development with [Claude](https://claude.ai) by Anthropic.*

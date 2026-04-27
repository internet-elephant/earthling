# Earthling — User Guide

A private, minimal travel journal for macOS. Your entries are plain Markdown files in your app's private sandbox. No accounts, no subscriptions, no servers.

---

## Contents

- [Building & Installing Earthling](#building--installing-earthling)
- [Features](#features)
- [Data Storage](#data-storage)
- [Markdown Support](#markdown-support)
- [Known Behaviours and Limitations](#known-behaviours-and-limitations)
- [License](#license)

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
3. Navigate to the Earthling folder you unzipped
4. Select **Earthling.xcodeproj** and click **Open**

### Step 5 — Add the Textual package dependency

Earthling uses the [Textual](https://github.com/gonzalezreal/textual) package for Markdown rendering. You need to add it once:

1. In Xcode: **File → Add Package Dependencies**
2. Paste this URL into the search bar:
   ```
   https://github.com/gonzalezreal/textual
   ```
3. Press **Return** — Xcode will find the package
4. Click **Add Package**
5. On the next screen make sure **Textual** is checked
6. Click **Add Package** again

### Step 6 — Configure signing

1. Click the **Earthling** project icon (blue) at the top of the left sidebar
2. Click **Earthling** under **TARGETS**
3. Click the **Signing & Capabilities** tab
4. Under **Team**, select your Apple ID from the dropdown
5. Leave **Automatically manage signing** checked

### Step 7 — Build and run

1. Make sure the destination at the top of the Xcode window shows **My Mac**
2. Press **⌘R** or click the **▶** Play button
3. Earthling will build and launch automatically

On first launch macOS may ask you to confirm you want to run the app — click **Open**.

---

## Features

- **Journal entries** with date, city (via MapKit autocomplete), optional sublocation, and freeform Markdown body
- **Photo support** — inline photos and galleries with per-photo captions, alignment, and size controls
- **Markdown rendering** — headings, bold, italic, code, blockquotes, lists, horizontal rules
- **10 themes** — five light, five dark, with serif, sans-serif, and monospaced typography options
- **Map view** — pins at every city you've visited, powered by GPS coordinates captured silently at entry creation
- **Export** — JSON, CSV, and PDF (single entry, one per entry, or combined)
- **Sort** — by entry date or date added, ascending or descending
- **Data portability** — all entries stored as human-readable Markdown files, accessible without the app

---

## Data Storage

Earthling stores all data in the app's private sandbox container:

```
~/Library/Containers/com.donuts.Earthling/Data/Documents/Earthling/
```

This location is managed by macOS and is private to Earthling — other apps cannot access it. It is not synced by iCloud Drive. Your entries stay on your Mac unless you explicitly export them.

To access your files directly in Finder, paste this path into **Go → Go to Folder** (**⌘⇧G**):

```
~/Library/Containers/com.donuts.Earthling/Data/Documents/Earthling
```

### Folder hierarchy

```
Earthling/
  {Continent}/
    {Country}/
      {City}/
        {date}-{city}-{shortID}.md
        {shortID}/
          {date}-{city}-{photoname}.jpg
```

### Entry file format

Each entry is a Markdown file with YAML frontmatter:

```
---
id: 550E8400-E29B-41D4-A716-446655440000
date: 2026-03-15T00:00:00Z
city: Kyoto
region: Kyoto Prefecture
country: Japan
continent: Asia
sublocation: Gion
latitude: 35.0116
longitude: 135.7681
createdAt: 2026-03-15T09:23:11Z
photos: [{"id":"...","filename":"...","alignment":"center","size":"medium","caption":""}]
---

Your journal text goes here. Supports **Markdown**.
```

### Photo tags

```
Single photo:
![photo:2026-03-15-Kyoto-shrine.jpg]

Gallery:
![gallery:2026-03-15-Kyoto-temple.jpg|2026-03-15-Kyoto-gate.jpg]
```

---

## Markdown Support

Earthling renders Markdown via the [Textual](https://github.com/gonzalezreal/swift-markdown-ui) package.

| Syntax | Result |
|---|---|
| `# Heading 1` | Large heading |
| `## Heading 2` | Medium heading |
| `### Heading 3` | Small heading |
| `**bold**` | Bold text |
| `*italic*` | Italic text |
| `***bold italic***` | Bold and italic |
| `` `code` `` | Inline code |
| `- item` | Bullet list |
| `1. item` | Numbered list |
| `> quote` | Blockquote |
| `---` | Horizontal rule |

**Note:** Strikethrough (`~~text~~`) is not supported and will display as plain text.

---

## Known Behaviours and Limitations

**Large entries** — Entries over 100KB are displayed as plain text rather than rendered Markdown. The entry is stored correctly in full and exports normally.

**Gallery sizing** — Gallery rows render best with two or three photos.

**GPS coordinates** — Coordinates are only captured when a city is selected from the MapKit autocomplete dropdown. Manually typed locations will not appear on the map.

**Sublocation field** — Limited to 50 characters. The following characters are not permitted: `/ \ : * ? " < > |`

**Animated GIFs** — GIFs display as static images and will not animate.

**App on another Mac** — If you copy your built app to another Mac, macOS will show a security warning on first launch. Go to **System Settings → Privacy & Security** and click **Open Anyway**.

---

## License

MIT License — see [LICENSE](https://github.com/internet-elephant/earthling/blob/main/LICENSE) for details.

If you build something with Earthling, a mention is appreciated.

---

## Acknowledgments

See [ACKNOWLEDGMENTS.md](https://github.com/internet-elephant/earthling/blob/main/ACKNOWLEDGMENTS.md).

---

*Copyright (c) 2026 Internet Elephant*

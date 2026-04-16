# Kong Brand Theme Reference

This file contains the complete Kong brand styling extracted from the official 2026 Kong template slides. All presentations MUST follow these guidelines.

## Theme Selection

Kong has two official themes: **Dark** (default) and **Light**. If the user does not specify, use Dark. If ambiguous, ask:

> "Do you want the dark or light Kong theme? Dark is the default."

---

## Slide Dimensions

Both themes use: **10" x 5.625"** (`LAYOUT_16x9`)

---

## Color Palettes

### Dark Theme

| Role | Hex | Usage |
|------|-----|-------|
| **Background** | `000000` to `0A0A0A` | Slide background, near-black |
| **Primary text** | `FFFFFF` | Titles, headings, body text |
| **Accent (Kong Neon Green)** | `CCFF00` | Key words in titles, stat numbers, accent shapes, icons, section labels |
| **Secondary text** | `AAB4BB` | Subheadings, captions, muted labels |
| **Muted text** | `8A8F89` | Descriptions, supporting copy |
| **Dark shape fill** | `30352F` | Card backgrounds, content blocks |
| **Darker green** | `92B600` | Secondary accent, progress bars |
| **Pale green tint** | `F5FFCB` | Light accent for contrast elements |
| **Divider lines** | `8A8F89` | Grid lines, separators |

### Light Theme

| Role | Hex | Usage |
|------|-----|-------|
| **Background** | `D7DED4` | Slide background, warm gray-green |
| **Primary text** | `42453E` | Titles, headings, body text |
| **Accent (Kong Neon Green)** | `CCFF00` | Same usage as dark theme |
| **Secondary text** | `737772` | Subheadings, captions |
| **Muted text** | `666666` | Descriptions, supporting copy |
| **Card/shape fill** | `42453E` | Dark cards on light background |
| **Deep green fill** | `273216` | Logo badges, dark accents |
| **Light gray fill** | `B3BAB2` | Subtle shape backgrounds |
| **Darker green** | `92B600` | Secondary accent |
| **Pale green tint** | `F5FFCB` | Light accent |
| **Divider lines** | `42453E` | Grid lines, separators |

---

## Typography

### Font Stack

Kong uses the **Funnel** font family as its primary typeface. These are Google Fonts and may not be installed on every system. pptxgenjs will embed the font name and PowerPoint will substitute if unavailable. This is acceptable.

| Weight | Font Name | Usage |
|--------|-----------|-------|
| Display/Hero | `Funnel Display` | Hero titles on title slides (dark theme only) |
| SemiBold | `Funnel Sans SemiBold` | Slide titles, section headers |
| Medium | `Funnel Sans Medium` | Subheadings, labels, stats |
| Regular | `Funnel Sans` | Body text, descriptions |
| Light | `Funnel Sans Light` | Captions, fine print, footer text |

Secondary font: `Urbanist` (used sparingly for taglines or stylistic contrast).

**Fallback stack**: If Funnel fonts are unavailable, use `Calibri` for body and `Calibri Light` for light weight. Never use Arial as the primary font.

### Font Sizes

| Element | Size (pt) | Weight | Notes |
|---------|-----------|--------|-------|
| Hero title (title slide) | 60-72 | Bold | Funnel Display or Funnel Sans SemiBold |
| Slide title | 36 | Bold | Funnel Sans SemiBold |
| Section label (e.g. "OUR MISSION") | 9-10 | Bold, uppercase | Funnel Sans SemiBold, often in accent color |
| Subtitle / subheading | 22-24 | Bold | Funnel Sans Medium |
| Body text | 14-16 | Regular | Funnel Sans |
| Supporting/description | 12-13 | Regular | Funnel Sans |
| Stat numbers | 48-72 | Bold | Kong Neon Green, Funnel Sans SemiBold |
| Stat labels | 10-12 | Regular | Muted color |
| Captions / fine print | 8-9 | Light | Funnel Sans Light |
| Footer text | 7-8 | Light | Funnel Sans Light |

---

## Slide Structure and Patterns

### Footer Bar

Every content slide (not title or closing slides) should have a footer bar at the very bottom:

- Height: ~0.35"
- Y position: 5.27" (bottom of 5.625" slide)
- Contents (left to right):
  - Kong logo mark (small, neon green) at x=0.4"
  - "AI CONNECTIVITY" label in neon green, uppercase, 7pt
  - "© Kong Inc." in muted color, 7pt
  - "CONFIDENTIAL | NOT TO BE SHARED EXTERNALLY" right-aligned, muted, 7pt (use "CONFIDENTIAL" in accent color)
  - Slide number right-aligned, 7pt

In pptxgenjs, add this as a reusable function:

```javascript
function addKongFooter(slide, slideNum, theme) {
  const isLight = theme === 'light';
  const footerY = 5.27;
  const barColor = isLight ? '42453E' : '1A1A1A';
  const accentColor = 'CCFF00';
  const mutedColor = isLight ? '737772' : 'AAB4BB';

  // Footer bar background
  slide.addShape(pres.shapes.RECTANGLE, {
    x: 0, y: footerY, w: 10, h: 0.355,
    fill: { color: barColor }
  });

  // AI CONNECTIVITY label
  slide.addText("AI\nCONNECTIVITY", {
    x: 0.55, y: footerY + 0.02, w: 1, h: 0.33,
    fontSize: 6, fontFace: 'Funnel Sans SemiBold',
    color: accentColor, lineSpacingMultiple: 0.9,
    bold: true, margin: 0
  });

  // © Kong Inc.
  slide.addText("© Kong Inc.", {
    x: 1.5, y: footerY, w: 1.5, h: 0.355,
    fontSize: 7, fontFace: 'Funnel Sans Light',
    color: mutedColor, valign: 'middle', margin: 0
  });

  // Confidential notice
  slide.addText([
    { text: "CONFIDENTIAL", options: { color: accentColor, bold: true } },
    { text: " | NOT TO BE SHARED EXTERNALLY", options: { color: mutedColor } }
  ], {
    x: 5.5, y: footerY, w: 3.8, h: 0.355,
    fontSize: 7, fontFace: 'Funnel Sans Light',
    align: 'right', valign: 'middle', margin: 0
  });

  // Slide number
  slide.addText(String(slideNum), {
    x: 9.4, y: footerY, w: 0.5, h: 0.355,
    fontSize: 7, fontFace: 'Funnel Sans Light',
    color: mutedColor, align: 'right', valign: 'middle', margin: 0
  });
}
```

### Title Slide (Slide 1)

- Full background in neon green (#CCFF00) or use branded background image
- Large hero title in white (dark theme) or dark (#42453E, light theme), 60-72pt bold
- Kong logo top-left
- Subtitle: "The Unified API and AI Platform" in muted color
- Date and speaker name at bottom-left
- No footer bar on title slides

### Section Divider Slides

- Full-bleed background (branded imagery or solid accent color)
- Large bold statement text centered, white on dark, 36-48pt
- One key word or phrase highlighted in Kong Neon Green
- No footer bar, or minimal footer

### Stats/Metrics Slides

- 2x3 or 3x2 grid layout
- Large stat numbers in Kong Neon Green, 48-72pt bold
- Short description below each stat in muted color, 10-12pt
- Thin divider lines (#8A8F89 dark / #42453E light) between grid cells
- Title + description at top of slide

### Content Slides

- Section label at top (uppercase, 9-10pt, Kong Neon Green)
- Slide title below (36pt bold, primary text color)
- Content area with generous margins (0.5" minimum from edges)
- Cards or content blocks use dark shape fills (#30352F dark / #42453E light)

### Numbered Steps / Values Slides

- Large circled or plain numbers (1, 2, 3) in neon green
- Each with a bold heading and description text below
- Arranged in columns (2-col or 3-col layouts)

### Timeline Slides

- Horizontal flow with numbered milestones
- Month/quarter labels in accent color
- Descriptions below each milestone
- Connected by a horizontal line or bar

### Closing / Thank You Slide

- "Thank you!" in large white text
- "Ready for what's next?" in neon green bold
- "Let's talk" as call to action
- Kong contact info: Kong Inc., contact@konghq.com, address
- Konghq.com link in accent color
- Large Kong wordmark/logo as background element (bottom half)
- No standard footer bar

---

## Visual Motifs

### Grid/Crosshair Pattern
The Kong template uses subtle grid crosshair marks (thin lines in muted color) at regular intervals. This is a distinctive brand element. When creating from scratch, you can approximate this with thin lines at grid intersection points, but it is optional and should not clutter the slide.

### Branded Background Imagery
The official templates use Kong's signature "palm/fan" abstract green imagery on key slides (title, section dividers, closing). When creating from scratch without access to these images, use solid backgrounds instead. Do NOT use stock photography as a substitute.

### Accent Color Usage
The neon green (#CCFF00) is the single accent color. Never introduce additional accent colors. Use it for:
- Key words in titles (partial color highlighting)
- Stat numbers
- Section labels
- Icons and small shape accents
- Buttons/CTAs
- The Kong logo

---

## Do NOT

- Use any color palette other than Kong's (no blue, no coral, no generic palettes)
- Use Arial, Times New Roman, or other non-Kong fonts as primary
- Add underline accents below titles
- Use rounded rectangles with accent borders
- Add stock photography backgrounds
- Use gradient fills on shapes
- Introduce secondary accent colors beyond the defined palette
- Make slides that look generic or could belong to any company

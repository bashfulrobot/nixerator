# GNOME Human Interface Guidelines for Compose Desktop

## Spacing System

The canonical spacing unit is **12px**. Use multiples or halves:

| Context                           | Spacing    |
| --------------------------------- | ---------- |
| Window edge to content            | 12px       |
| Between controls and labels       | 12px       |
| Between groups/sections           | 24px (2x)  |
| Between related items in a group  | 6px (0.5x) |
| Padding inside cards/containers   | 12px       |
| Indentation for subordinate items | 12px       |

In Compose, define these as constants:

```kotlin
object HigSpacing {
    val unit = 12.dp
    val half = 6.dp
    val double = 24.dp
    val triple = 36.dp
}
```

## Typography Scale

GNOME HIG type styles mapped to Material 3:

| HIG Style         | Material 3       | Usage                      |
| ----------------- | ---------------- | -------------------------- |
| `large-title`     | `displayLarge`   | Greeters, splash (rare)    |
| `title-1`         | `headlineLarge`  | Major section headers      |
| `title-2`         | `headlineMedium` | Subsection headers         |
| `title-3`         | `titleLarge`     | Card titles, dialog titles |
| `title-4`         | `titleMedium`    | Group headers              |
| `heading`         | `titleSmall`     | Window titles, bold labels |
| `body`            | `bodyLarge`      | Default text               |
| `caption-heading` | `labelLarge`     | Bold sub-labels            |
| `caption`         | `bodySmall`      | Secondary text, timestamps |

Rules:

- Never use italic or oblique styles
- Never use ALL CAPS (use sentence case everywhere)
- System font only -- do not bundle custom fonts
- Use relative sizing for accessibility -- users can adjust system font size

## Navigation Patterns

### Sidebar Navigation (primary)

For apps with 3-7 top-level areas:

- Sidebar is always visible on desktop widths (>800px)
- Collapses to hamburger menu on narrow windows
- Active item highlighted with a subtle background tint
- Use flat/ghost button styling -- no heavy filled buttons
- Icons + labels for each item
- Optional: collapsible groups for sub-navigation

### Header Bar

Every window has a header bar:

- Window title centered or left-aligned
- Primary action buttons on the right (1-2 max)
- Back button on the left when navigating into detail views
- Search toggle in the header bar (not a separate search screen)
- No separator line below the header bar (flat design)

### Content Patterns

- **Master-detail**: sidebar list + detail pane (e.g., accounts list + account detail)
- **Grid view**: responsive card grid for overview/dashboard screens
- **List view**: for data-dense views (filterable, sortable)
- **Tabs**: for parallel views within a single context (e.g., account detail tabs)

## Components

### Buttons

| Type                      | When to use                           |
| ------------------------- | ------------------------------------- |
| Suggested (filled accent) | Primary action per view (one only)    |
| Default (outlined)        | Secondary actions                     |
| Flat (ghost)              | Tertiary, navigation, toolbar actions |
| Destructive (filled red)  | Delete, remove -- always with undo    |

### Cards

- 12px internal padding
- Subtle border or elevation (1-2dp shadow)
- Round corners (12dp radius matches GNOME aesthetic)
- Cards are clickable as a whole -- not individual elements within

### Dialogs

- Use sparingly -- prefer inline editing and undo
- Title + body text + actions
- Maximum 2 action buttons (cancel + confirm)
- Destructive confirmations: button text describes the action ("Delete account", not "OK")

### Search

- Reveal search field in header bar via toggle button or Ctrl+F
- Filter results live as user types
- Show "No results" state with helpful message
- Clear button (X) in the search field

## Adaptive Layout Breakpoints

```kotlin
object Breakpoints {
    val compact = 600.dp    // single column, sidebar hidden
    val medium = 840.dp     // sidebar visible, content adapts
    val expanded = 1200.dp  // full layout, wider content areas
}
```

- Use `BoxWithConstraints` or window size state to switch layouts
- Design from the smallest breakpoint up
- Constrain max content width (max ~720dp for text-heavy content) to maintain readability
- Lists scale well across all widths -- prefer them for adaptive designs

## Color and Theming

- Follow Material 3 dynamic color but with GNOME-flavored semantics
- Semantic colors for status: green (healthy/success), orange (warning/at-risk), red (critical/error), blue (info)
- Light and dark themes must both be fully supported
- System theme detection with polling (freedesktop portal > GTK setting > KDE setting)
- Never rely on color alone -- pair with icons, text, or patterns

## Unicode Typography

Always use proper typographic characters:

- Quotes: `"` `"` (U+201C, U+201D) not `"`
- Apostrophe: `'` (U+2019) not `'`
- Ellipsis: `...` (U+2026) not three dots
- En dash: `--` (U+2013) for ranges
- Multiplication: `x` (U+00D7) not letter x

# macOS Human Interface Guidelines for Compose Desktop

## Menu Bar

Every macOS app must have a proper menu bar. Compose Desktop provides the `MenuBar` composable:

```kotlin
MenuBar {
    Menu("File") {
        Item("New Window", onClick = { /* ... */ }, shortcut = KeyShortcut(Key.N, meta = true))
        Item("Close Window", onClick = { /* ... */ }, shortcut = KeyShortcut(Key.W, meta = true))
    }
    Menu("Edit") {
        Item("Undo", onClick = { /* ... */ }, shortcut = KeyShortcut(Key.Z, meta = true))
        Item("Redo", onClick = { /* ... */ }, shortcut = KeyShortcut(Key.Z, meta = true, shift = true))
        Separator()
        Item("Cut", onClick = { /* ... */ }, shortcut = KeyShortcut(Key.X, meta = true))
        Item("Copy", onClick = { /* ... */ }, shortcut = KeyShortcut(Key.C, meta = true))
        Item("Paste", onClick = { /* ... */ }, shortcut = KeyShortcut(Key.V, meta = true))
        Item("Select All", onClick = { /* ... */ }, shortcut = KeyShortcut(Key.A, meta = true))
    }
    Menu("View") {
        // Map views to Cmd+1, Cmd+2, etc.
        Item("Dashboard", onClick = { /* ... */ }, shortcut = KeyShortcut(Key.One, meta = true))
        Item("Accounts", onClick = { /* ... */ }, shortcut = KeyShortcut(Key.Two, meta = true))
    }
    Menu("Window") {
        Item("Minimize", onClick = { /* ... */ }, shortcut = KeyShortcut(Key.M, meta = true))
    }
    Menu("Help") {
        Item("Search", onClick = { /* ... */ })
    }
}
```

### Required Menus

| Menu            | Contents                                  |
| --------------- | ----------------------------------------- |
| App (automatic) | About, Preferences (Cmd+,), Quit (Cmd+Q)  |
| File            | New, Open, Close, Save (if applicable)    |
| Edit            | Undo, Redo, Cut, Copy, Paste, Select All  |
| View            | App-specific view toggles, sidebar toggle |
| Window          | Minimize, Zoom, full screen               |
| Help            | Search, documentation links               |

App-specific menus go between Edit and Window.

## Keyboard Shortcuts

### Platform Modifier Abstraction

```kotlin
// Detect platform once
val isMacOS = System.getProperty("os.name").lowercase().contains("mac")

// Use in shortcuts
val primaryModifier = if (isMacOS) Key.MetaLeft else Key.CtrlLeft
```

### Standard Shortcuts

| Action       | macOS       | Linux               |
| ------------ | ----------- | ------------------- |
| Copy         | Cmd+C       | Ctrl+C              |
| Paste        | Cmd+V       | Ctrl+V              |
| Cut          | Cmd+X       | Ctrl+X              |
| Undo         | Cmd+Z       | Ctrl+Z              |
| Redo         | Cmd+Shift+Z | Ctrl+Shift+Z        |
| Save         | Cmd+S       | Ctrl+S              |
| Find         | Cmd+F       | Ctrl+F              |
| Settings     | Cmd+,       | (in-app navigation) |
| Quit         | Cmd+Q       | Ctrl+Q              |
| New Window   | Cmd+N       | Ctrl+N              |
| Close Window | Cmd+W       | Ctrl+W              |

Every menu item that performs an action should have a keyboard shortcut.

## Window Management

- Support resizable windows (Compose Desktop default)
- Persist window size and position in config across sessions
- Support full-screen mode
- Minimum window size: set reasonable minimums (e.g., 800x600)
- On macOS, closing all windows should NOT quit the app (standard macOS behavior) -- keep the process alive for the Dock icon

```kotlin
Window(
    onCloseRequest = { /* hide window, don't exit on macOS */ },
    state = rememberWindowState(
        width = config.windowWidth.dp,
        height = config.windowHeight.dp
    ),
    title = "My App"
) { /* ... */ }
```

## Native Packaging

```kotlin
macOS {
    bundleID = "com.company.myapp"
    minimumSystemVersion = "12.0"
    iconFile.set(project.file("icons/icon.icns"))
    dockName = "My App"  // what shows in the Dock

    signing {
        sign.set(true)
        identity.set("Developer ID Application: ...")
    }
    notarization {
        appleID.set("...")
        password.set("@keychain:NOTARIZE_PASSWORD")
        teamID.set("...")
    }
}
```

## macOS-Specific UX

- **Preferences**: always accessible via Cmd+, (maps to Settings screen)
- **About dialog**: provided automatically by Compose Desktop; customize via `aboutDialog { }`
- **Dark mode**: detect via `defaults read -g AppleInterfaceStyle` -- returns "Dark" if dark mode, error if light
- **Accent color**: respect system accent color where possible
- **Drag and drop**: support file drag-and-drop for import workflows
- **Touch Bar**: not worth supporting (Apple deprecated it)
- **Notification Center**: use `java.awt.SystemTray` for basic notifications; limited compared to native

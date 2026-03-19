# Security Guide for Compose Desktop Apps

## SQLite Encryption at Rest

### sqlite-mc (SQLite3MultipleCiphers)

The recommended approach for encrypting SQLite on JVM desktop:

```kotlin
// build.gradle.kts
dependencies {
    implementation("io.toxicity.sqlite:sqlite-mc:VERSION")
}
```

```kotlin
// Driver creation with encryption
fun createEncryptedDriver(dbPath: String, keyring: SecureStorage): SqlDriver {
    val key = keyring.retrieve("db-encryption-key")
        ?: generateAndStoreKey(keyring)

    val driver = JdbcSqliteDriver(
        url = "jdbc:sqlite:file:$dbPath",
        properties = Properties().apply {
            put("key", key)
        }
    )

    // Set essential PRAGMAs
    driver.execute(null, "PRAGMA journal_mode=WAL;", 0)
    driver.execute(null, "PRAGMA synchronous=NORMAL;", 0)
    driver.execute(null, "PRAGMA foreign_keys=ON;", 0)
    driver.execute(null, "PRAGMA busy_timeout=5000;", 0)

    return driver
}

private fun generateAndStoreKey(keyring: SecureStorage): String {
    val key = SecureRandom().let { random ->
        ByteArray(32).also { random.nextBytes(it) }
            .joinToString("") { "%02x".format(it) }
    }
    keyring.store("db-encryption-key", key)
    return key
}
```

### Key Management

- Generate a random 256-bit key on first launch
- Store it in the OS keyring (never in config files, env vars, or source)
- The key is retrieved from the keyring on every app launch
- If the keyring entry is deleted, the database becomes inaccessible (this is the correct behavior -- data at rest is protected)
- Consider a key rotation strategy for long-lived deployments

## OS Keyring Integration

### java-keyring

```kotlin
// build.gradle.kts
dependencies {
    implementation("com.github.javakeyring:java-keyring:1.0.4")
}
```

```kotlin
// expect/actual pattern for secure storage
expect class PlatformSecureStorage() : SecureStorage

// Common interface
interface SecureStorage {
    fun store(key: String, value: String)
    fun retrieve(key: String): String?
    fun delete(key: String)
}

// JVM actual (works on both Linux and macOS)
actual class PlatformSecureStorage : SecureStorage {
    private val keyring = Keyring.create()
    private val serviceName = "com.company.myapp"

    override fun store(key: String, value: String) {
        keyring.setPassword(serviceName, key, value)
    }

    override fun retrieve(key: String): String? {
        return try {
            keyring.getPassword(serviceName, key)
        } catch (e: PasswordAccessException) {
            null
        }
    }

    override fun delete(key: String) {
        try {
            keyring.deletePassword(serviceName, key)
        } catch (e: PasswordAccessException) {
            // Already deleted
        }
    }
}
```

### Platform Backends

| Platform | Backend | Daemon Required |
|----------|---------|-----------------|
| Linux | libsecret (GNOME Keyring or KWallet) | `gnome-keyring-daemon` or `kwalletd5` |
| macOS | Keychain Services | Built-in |

On Linux, if no keyring daemon is running (e.g., headless or minimal WM), fall back to a file-based encrypted store with a user-provided passphrase. Log a warning that security is reduced.

## Subprocess Safety

When spawning external processes (e.g., AI CLI tools):

```kotlin
// CORRECT: explicit argument list
val process = ProcessBuilder(listOf("claude", "--print"))
    .redirectInput(ProcessBuilder.Redirect.PIPE)
    .redirectOutput(ProcessBuilder.Redirect.PIPE)
    .redirectErrorStream(true)
    .start()

// WRONG: shell interpolation (command injection risk)
// Runtime.getRuntime().exec("claude --print $userInput")
```

Rules:
- Always use `ProcessBuilder` with a `List<String>` of arguments
- Never pass user input through a shell (no `sh -c "..."`)
- Set timeouts on process execution (5 minutes is a reasonable max for AI tools)
- Clean up temp files in `finally` blocks, not just on success
- Validate that the binary path exists and is executable before spawning
- Capture and handle stderr separately from stdout when possible

## Input Validation

SQLDelight parameterized queries prevent SQL injection by default. Additional validation:

- Validate business rules before database operations (e.g., email format, date ranges, string lengths)
- Sanitize content before rendering in Markdown views (XSS prevention)
- Validate file paths -- reject path traversal (`../`) in user-provided file names
- Limit file sizes for imports to prevent memory exhaustion
- Validate TOML config values on load, not just structure

## File System Security

- Use platform-appropriate directories (XDG on Linux, `~/Library/Application Support/` on macOS)
- Set restrictive file permissions on database and config files: `PosixFilePermissions.fromString("rw-------")`
- Create directories with restrictive permissions: `700` for app data directories
- Temp files should be created in a dedicated temp directory under the app's data path, not in the global `/tmp`

## Network Security (if applicable)

- Use TLS 1.2+ for all network connections
- Pin certificates if connecting to known servers
- Validate SSL certificates -- never disable certificate verification
- Use `OkHttp` or `Ktor` with proper timeout configuration
- Handle network errors gracefully -- never expose raw error messages to the UI

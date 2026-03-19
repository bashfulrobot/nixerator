# Testing Patterns for Compose Desktop

## Test Dependencies

```kotlin
// build.gradle.kts - desktopTest
val desktopTest by getting {
    dependencies {
        implementation(kotlin("test"))
        implementation(compose.desktop.uiTestJUnit4)
        implementation(compose.desktop.currentOs)
        implementation("app.cash.turbine:turbine:1.1.0")
        implementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")
        implementation("io.insert-koin:koin-test:4.0.0")
    }
}
```

## Component / ViewModel Testing

### With Turbine for Flow assertions

```kotlin
class AccountListComponentTest {
    private val fakeRepo = FakeAccountRepository()

    @Test
    fun `loading state transitions to loaded with accounts`() = runTest {
        fakeRepo.setAccounts(listOf(testAccount("Acme"), testAccount("Globex")))
        val component = DefaultAccountListComponent(
            componentContext = TestComponentContext(),
            repository = fakeRepo
        )

        component.state.test {
            // First emission is loading
            val loading = awaitItem()
            assertTrue(loading.isLoading)

            // Second emission has data
            val loaded = awaitItem()
            assertFalse(loaded.isLoading)
            assertEquals(2, loaded.accounts.size)
            assertEquals("Acme", loaded.accounts[0].name)
        }
    }

    @Test
    fun `search filters accounts by name`() = runTest {
        fakeRepo.setAccounts(listOf(
            testAccount("Acme Corp"),
            testAccount("Globex Inc"),
            testAccount("Acme Labs")
        ))
        val component = DefaultAccountListComponent(
            componentContext = TestComponentContext(),
            repository = fakeRepo
        )

        component.state.test {
            skipItems(1) // skip loading
            awaitItem() // initial loaded state

            component.onSearchChanged("Acme")
            val filtered = awaitItem()
            assertEquals(2, filtered.accounts.size)
            assertTrue(filtered.accounts.all { "Acme" in it.name })
        }
    }
}
```

### Test Helpers

```kotlin
// Reusable test fixtures
fun testAccount(
    name: String,
    health: HealthStatus = HealthStatus.HEALTHY,
    arr: Long = 100_000L,
) = Account(
    id = UUID.randomUUID().toString(),
    name = name,
    health = health,
    arr = arr,
    // ... defaults for all other fields
)

// Fake repository that holds state in memory
class FakeAccountRepository : AccountRepository {
    private val _accounts = MutableStateFlow<List<Account>>(emptyList())

    fun setAccounts(accounts: List<Account>) {
        _accounts.value = accounts
    }

    override fun observeAll(): Flow<List<Account>> = _accounts
    override suspend fun getById(id: String): Account? =
        _accounts.value.find { it.id == id }
    // ... other methods
}

// Test ComponentContext for Decompose
fun TestComponentContext(): ComponentContext =
    DefaultComponentContext(lifecycle = LifecycleRegistry())
```

## UI Testing

### Basic Compose Desktop Tests

```kotlin
class DashboardScreenTest {
    @get:Rule
    val rule = createComposeRule()

    @Test
    fun `dashboard shows account count`() {
        val component = FakeDashboardComponent(
            state = DashboardState(
                accounts = listOf(testAccount("A"), testAccount("B")),
                isLoading = false
            )
        )

        rule.setContent {
            MaterialTheme {
                DashboardContent(component)
            }
        }

        rule.onNodeWithText("2 Accounts").assertIsDisplayed()
    }

    @Test
    fun `clicking account card triggers navigation`() {
        var navigatedTo: String? = null
        val component = FakeDashboardComponent(
            state = DashboardState(
                accounts = listOf(testAccount("Acme")),
                isLoading = false
            ),
            onAccountClick = { navigatedTo = it }
        )

        rule.setContent {
            MaterialTheme {
                DashboardContent(component)
            }
        }

        rule.onNodeWithText("Acme").performClick()
        assertNotNull(navigatedTo)
    }

    @Test
    fun `loading state shows progress indicator`() {
        val component = FakeDashboardComponent(
            state = DashboardState(isLoading = true)
        )

        rule.setContent {
            MaterialTheme {
                DashboardContent(component)
            }
        }

        rule.onNodeWithTag("loading-indicator").assertIsDisplayed()
        rule.onNodeWithTag("account-grid").assertDoesNotExist()
    }
}
```

### Accessibility Testing

```kotlin
@Test
fun `all interactive elements are focusable`() {
    rule.setContent {
        MaterialTheme {
            AccountListContent(fakeComponent)
        }
    }

    // Verify all buttons have content descriptions
    rule.onAllNodesWithRole(Role.Button)
        .assertAll(hasContentDescription())

    // Verify keyboard navigation works
    rule.onNodeWithTag("search-field").performClick()
    rule.onNodeWithTag("search-field").assertIsFocused()
}
```

## Database Migration Testing

```kotlin
class MigrationTest {
    @Test
    fun `migration from v1 to v2 preserves account data`() {
        val dbPath = createTempFile("test", ".db").absolutePath

        // Create v1 schema and insert data
        val v1Driver = JdbcSqliteDriver("jdbc:sqlite:$dbPath")
        v1Driver.execute(null, V1_CREATE_TABLES, 0)
        v1Driver.execute(null, "INSERT INTO Account (id, name) VALUES ('1', 'Acme')", 0)
        v1Driver.close()

        // Run migration
        val v2Driver = JdbcSqliteDriver("jdbc:sqlite:$dbPath")
        UpsightDatabase.Schema.migrate(v2Driver, oldVersion = 1, newVersion = 2)

        // Verify data survived
        val result = v2Driver.executeQuery(null, "SELECT name FROM Account WHERE id = '1'", parameters = 0)
        assertTrue(result.next().value)
        assertEquals("Acme", result.getString(0))

        // Verify new columns exist
        val newCol = v2Driver.executeQuery(null, "SELECT health_status FROM Account WHERE id = '1'", parameters = 0)
        assertTrue(newCol.next().value)

        v2Driver.close()
    }

    @Test
    fun `migration backup is created before destructive changes`() {
        val dbDir = createTempDirectory("migration-test")
        val dbPath = dbDir.resolve("test.db").toString()

        // Setup and run migration that drops a table
        // ...

        // Verify backup exists
        val backups = dbDir.listDirectoryEntries("*.backup-*")
        assertTrue(backups.isNotEmpty(), "Migration should create a backup")
    }
}
```

## Config File Testing

```kotlin
class ConfigManagerTest {
    @Test
    fun `atomic write survives crash simulation`() = runTest {
        val configDir = createTempDirectory("config-test")
        val manager = ConfigManager(configDir)

        // Write initial config
        manager.update { copy(windowWidth = 1024) }

        // Simulate crash during write by checking no partial files remain
        val files = configDir.listDirectoryEntries()
        val tempFiles = files.filter { it.name.endsWith(".tmp") }
        assertTrue(tempFiles.isEmpty(), "No temp files should remain after write")

        // Config should be readable
        val loaded = ConfigManager(configDir).current
        assertEquals(1024, loaded.windowWidth)
    }

    @Test
    fun `malformed config falls back to defaults with backup`() {
        val configDir = createTempDirectory("config-test")
        configDir.resolve("config.toml").writeText("invalid [[[ toml content")

        val manager = ConfigManager(configDir)

        // Should load defaults
        assertEquals(AppConfig(), manager.current)

        // Should create backup of malformed file
        val backups = configDir.listDirectoryEntries("*.bak")
        assertTrue(backups.isNotEmpty())
    }

    @Test
    fun `concurrent updates are serialized`() = runTest {
        val configDir = createTempDirectory("config-test")
        val manager = ConfigManager(configDir)

        // Launch 50 concurrent updates
        val jobs = (1..50).map { i ->
            launch {
                manager.update { copy(windowWidth = i) }
            }
        }
        jobs.joinAll()

        // Final state should be one of the values (not corrupted)
        val final = manager.current.windowWidth
        assertTrue(final in 1..50)
    }
}
```

## Test Organization

```
src/
  desktopTest/
    kotlin/
      com/app/
        component/          -- Component/ViewModel tests
        repository/         -- Repository tests (in-memory DB)
        database/           -- Migration and schema tests
        config/             -- Config manager tests
        ui/                 -- Compose UI tests
        fixtures/           -- Shared test data and fakes
          FakeAccountRepository.kt
          FakeConfigManager.kt
          TestFixtures.kt   -- testAccount(), testContact(), etc.
```

Run all tests: `./gradlew desktopTest`
Run specific test: `./gradlew desktopTest --tests "com.app.component.AccountListComponentTest"`

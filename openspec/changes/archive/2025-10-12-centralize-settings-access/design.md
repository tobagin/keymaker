# Settings Centralization Design

## Context

KeyMaker uses GLib.Settings for persistent configuration storage with two schemas:
1. **Main schema** (`io.github.tobagin.keysmith`) - 16 keys for window state, preferences, defaults
2. **Tunneling schema** (`io.github.tobagin.keysmith.tunneling`) - 1 key for tunnel configurations

Current state:
- **11 files** directly instantiate Settings with `#if DEVELOPMENT` conditionals
- **Existing SettingsManager** in `src/utils/Settings.vala` has lazy-loaded static instances but limited convenience methods
- **Only 4 files** currently use SettingsManager (DiagnosticConfigurationDialog, DiagnosticsPage, tunneling/Manager)
- **34 direct settings access calls** across the codebase

## Goals / Non-Goals

### Goals
1. **Single point of Settings instantiation** - all Settings objects created in SettingsManager
2. **Type-safe property access** - properties for all schema keys with correct types
3. **Remove duplication** - eliminate 11 instances of duplicated `#if DEVELOPMENT` code
4. **Maintain existing API** - SettingsManager already has static properties `.app` and `.tunneling`, keep them
5. **Gradual migration** - change each file individually to minimize risk

### Non-Goals
- NOT changing the GSettings schema itself
- NOT adding new settings keys (out of scope)
- NOT changing how settings are stored on disk
- NOT adding settings validation beyond GSettings defaults
- NOT creating a new settings abstraction layer (use existing SettingsManager)

## Decisions

### Decision 1: Expand SettingsManager with property accessors

**Choice:** Add C#-style properties to SettingsManager for all schema keys.

**Rationale:**
- Vala properties provide natural get/set syntax
- Type safety at compile time (int properties return int, etc.)
- Consistent with existing code style in SettingsManager
- No runtime overhead vs direct access

**Pattern:**
```vala
public static int window_width {
    get { return app.get_int("window-width"); }
    set { app.set_int("window-width", value); }
}
```

**Alternatives considered:**
1. **Method-based API** (`get_window_width()`, `set_window_width()`) - More verbose, less idiomatic Vala
2. **Direct app.get_int() everywhere** - No type safety, requires knowing key names as strings
3. **Per-file Settings instances** - Current approach, leads to duplication

### Decision 2: Keep static access pattern

**Choice:** Continue using `SettingsManager.app` and property access via static methods.

**Rationale:**
- Settings are truly global application state
- Static access avoids passing Settings objects through constructors
- Existing code already uses this pattern successfully
- Matches GLib.Settings.sync() pattern (also static)

**Trade-offs:**
- ✅ Convenient access from anywhere
- ✅ No dependency injection complexity
- ⚠️ Harder to mock in unit tests (but Settings is rarely unit tested anyway)

### Decision 3: Migrate incrementally by file

**Choice:** Change one file at a time, test, then move to next.

**Order:**
1. Expand SettingsManager first (add all properties)
2. Migrate backend files (4 files)
3. Migrate model files (1 file)
4. Migrate UI files (6 files)
5. Remove old instances

**Rationale:**
- Lower risk - can test after each file
- Easy to revert if issues found
- Matches Git best practices (small, focused commits)

## Architecture

### Current State
```
┌─────────────────┐
│  Application    │──> new Settings(APP_ID)
└─────────────────┘

┌─────────────────┐
│  TotpManager    │──> new Settings(APP_ID)
└─────────────────┘

┌─────────────────┐
│  KeysPage       │──> new Settings(DEV ? "Devel" : APP_ID)
└─────────────────┘

... (8 more files with duplicate patterns)
```

### Target State
```
┌─────────────────────────────────┐
│      SettingsManager            │
│  ┌───────────────────────────┐  │
│  │ static app: GLib.Settings │  │ <── Single instance
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ Properties:               │  │
│  │  - window_width          │  │
│  │  - window_height         │  │
│  │  - default_key_type      │  │
│  │  - show_fingerprints     │  │
│  │  ... (all 16 keys)       │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
         ▲        ▲        ▲
         │        │        │
    ┌────┴───┐ ┌─┴────┐ ┌─┴────────┐
    │  App   │ │ TOTP │ │ KeysPage │
    └────────┘ └──────┘ └──────────┘
```

## Implementation Pattern

### Before (duplicated 11 times):
```vala
private Settings settings;

construct {
#if DEVELOPMENT
    settings = new Settings("io.github.tobagin.keysmith.Devel");
#else
    settings = new Settings("io.github.tobagin.keysmith");
#endif
}

// Later in code:
var width = settings.get_int("window-width");
settings.set_int("window-width", 1024);
```

### After (centralized):
```vala
// No private Settings field needed

// Later in code:
var width = SettingsManager.window_width;
SettingsManager.window_width = 1024;

// Or direct access if needed:
var width = SettingsManager.app.get_int("window-width");
```

## Migration Strategy

### Step-by-step for each file:

1. **Remove private field:** Delete `private Settings settings;`
2. **Remove initialization:** Delete the `#if DEVELOPMENT` block
3. **Replace access:** Change `settings.get_*()` to `SettingsManager.property` or `SettingsManager.app.get_*()`
4. **Test:** Build and verify functionality works

### Special Cases:

**Complex types (Variant):**
```vala
// Keep direct access for complex types
var plans = SettingsManager.app.get_value("rotation-plans");
SettingsManager.app.set_value("rotation-plans", plans);

// Or add convenience methods:
var plans = SettingsManager.get_rotation_plans();
SettingsManager.set_rotation_plans(plans);
```

**Tunneling schema:**
```vala
// Use existing SettingsManager.tunneling property
var configs = SettingsManager.tunneling.get_value("configurations");
```

## Risks / Trade-offs

### Risk 1: Breaking existing Settings behavior
- **Likelihood:** Low
- **Mitigation:** SettingsManager already works correctly, we're just using it more
- **Test:** Run full application test after migration

### Risk 2: Property access overhead
- **Likelihood:** Very low
- **Impact:** Negligible - Vala properties compile to direct method calls
- **Measurement:** No measurable performance difference expected

### Risk 3: Merge conflicts
- **Likelihood:** Medium (if other PRs touch same files)
- **Mitigation:** Complete migration in short timeframe, communicate with team
- **Recovery:** Easy to revert individual file migrations

### Trade-off: Static vs Injected
- **Chosen:** Static access
- **Given up:** Easier unit testing with mocks
- **Justified:** Settings access is integration-level concern, not unit-level

## Validation

### Build Validation
```bash
# After each file migration:
./scripts/build.sh --dev
flatpak run io.github.tobagin.keysmith.Devel

# Test the affected feature
# Example: After migrating GenerateDialog, test key generation
```

### Functional Validation
- [ ] Window state persists across restarts
- [ ] Preferences dialog reads/writes correctly
- [ ] Default key type is respected in generation
- [ ] Fingerprints toggle works
- [ ] Theme preference applies correctly
- [ ] Auto-refresh interval works
- [ ] Diagnostics settings persist
- [ ] Rotation plans are saved/loaded
- [ ] Tunnel configurations persist

### Code Validation
```bash
# No remaining direct Settings instantiation (except in SettingsManager):
grep -r "new Settings\|new GLib.Settings" src/ --include="*.vala" | grep -v "src/utils/Settings.vala"
# Should return empty after migration

# All imports removed:
grep -r "private Settings settings" src/ --include="*.vala"
# Should return empty after migration
```

## Open Questions

None - the pattern is well-established and proven in the existing SettingsManager implementation.

## References

- Existing implementation: `src/utils/Settings.vala`
- Schema definition: `data/io.github.tobagin.keysmith.gschema.xml.in`
- GLib.Settings documentation: https://docs.gtk.org/gio/class.Settings.html
- Vala properties: https://wiki.gnome.org/Projects/Vala/Tutorial#Properties

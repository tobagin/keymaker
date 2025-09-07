# Key Maker - Architecture Documentation

This document describes the modular architecture of Key Maker after the CODEX-PLAN refactoring.

## Overview

Key Maker is organized into focused, testable modules with clear separation of concerns:

- **Utilities**: Shared infrastructure for logging, filesystem operations, command execution, and settings
- **Data Models**: Core domain objects (SSH keys, configurations, plans)
- **Backend Modules**: Business logic organized by functional area
- **UI Layer**: GTK4/Libadwaita interface components

## Module Structure

```
src/
├── application.vala           # Main application entry point
├── main.vala                 # Program entry point
├── config.vala               # Build-time configuration
│
├── utils/                    # Shared utilities
│   ├── filesystem.vala       # File operations & SSH directory management
│   ├── command.vala          # Subprocess execution wrapper
│   ├── log.vala             # Structured logging with categories
│   └── settings.vala        # Centralized settings access
│
├── models/                   # Data structures
│   ├── enums.vala           # Core enumerations
│   ├── ssh-key.vala         # SSH key data model
│   └── key-service-mapping.vala # Key-to-service associations
│
├── backend/                  # Business logic modules
│   ├── ssh-operations/       # SSH key operations
│   │   ├── generation.vala   # Key generation (ssh-keygen)
│   │   ├── metadata.vala     # Fingerprints, types, bit sizes
│   │   └── mutate.vala       # Delete keys, change passphrases
│   │
│   ├── rotation/             # Key rotation system
│   │   ├── plan.vala         # Rotation planning data structures
│   │   ├── runner.vala       # Rotation orchestration
│   │   ├── deploy.vala       # Deploy keys to targets (ssh-copy-id)
│   │   └── rollback.vala     # Rollback failed rotations
│   │
│   ├── vault/               # Emergency backup system
│   │   ├── backup-entry.vala # Backup data models
│   │   └── vault-io.vala     # File I/O operations
│   │
│   ├── tunneling/           # SSH tunnel management
│   │   ├── configuration.vala # Tunnel configurations
│   │   ├── active-tunnel.vala # Individual tunnel processes
│   │   └── manager.vala      # Central tunnel management
│   │
│   ├── ssh-operations.vala   # Main SSH operations facade
│   ├── key-rotation.vala     # Key rotation facade
│   ├── ssh-tunneling.vala    # Tunneling facade
│   ├── emergency-vault.vala  # Emergency vault (legacy)
│   ├── key-scanner.vala      # Scan filesystem for keys
│   ├── ssh-agent.vala        # SSH agent interaction
│   ├── ssh-config.vala       # SSH config file management
│   ├── connection-diagnostics.vala # Connection testing
│   └── key-selection-manager.vala  # Key selection logic
│
└── ui/                       # User interface
    ├── window.vala           # Main application window
    ├── key-list.vala         # Key list widget
    ├── key-row.vala          # Individual key row
    └── dialogs/              # Various dialog implementations
```

## Design Principles

### 1. Facade Pattern
Major backend modules use the facade pattern:

```vala
// External interface remains stable
public class SSHOperations {
    public static async SSHKey generate_key(KeyGenerationRequest request) {
        return yield SSHGeneration.generate_key(request);
    }
}

// Internal implementation is modular
namespace SSHGeneration {
    public static async SSHKey generate_key(KeyGenerationRequest request) {
        // Focused implementation
    }
}
```

### 2. Centralized Utilities

All modules use shared utilities for consistency:

```vala
// Instead of scattered subprocess code:
var launcher = new SubprocessLauncher();
var subprocess = launcher.spawnv(cmd);

// Use centralized command utility:
var result = yield KeyMaker.Command.run_capture(cmd);

// Instead of hardcoded paths/permissions:
Posix.chmod(file.get_path(), 0x180);

// Use filesystem utility:
KeyMaker.Filesystem.chmod_private(file);
```

### 3. Structured Logging

Consistent logging across all modules:

```vala
KeyMaker.Log.info(KeyMaker.Log.Categories.SSH_OPS, "Generated key: %s", fingerprint);
KeyMaker.Log.error(KeyMaker.Log.Categories.VAULT, "Backup failed: %s", error);
```

### 4. Settings Management

Centralized settings with typed access:

```vala
// Instead of direct GSettings usage:
var settings = new GSettings("io.github.tobagin.keysmith");
settings.set_boolean("auto-add-keys", true);

// Use settings manager:
KeyMaker.SettingsManager.set_auto_add_keys_to_agent(true);
```

## Module Responsibilities

### SSH Operations (`backend/ssh-operations/`)

- **Generation**: Creates new SSH keys using ssh-keygen
- **Metadata**: Extracts fingerprints, key types, and bit sizes  
- **Mutate**: Deletes keys and changes passphrases

### Key Rotation (`backend/rotation/`)

- **Plan**: Data structures for rotation planning and tracking
- **Runner**: Orchestrates the multi-stage rotation process
- **Deploy**: Deploys keys to remote servers via ssh-copy-id
- **Rollback**: Handles rollback when rotations fail

### Tunneling (`backend/tunneling/`)

- **Configuration**: Tunnel configuration data and validation
- **ActiveTunnel**: Manages individual tunnel processes
- **Manager**: Central coordination of all tunnels

### Emergency Vault (`backend/vault/`)

- **BackupEntry**: Data models for backup metadata
- **VaultIO**: Safe file operations with proper permissions

### Utilities (`utils/`)

- **Filesystem**: SSH directory management and permission helpers
- **Command**: Consistent subprocess execution with error handling
- **Log**: Structured logging with categorization
- **Settings**: Centralized configuration access

## Data Flow

### Key Generation Flow
```
UI Request → SSHOperations.generate_key() → SSHGeneration.generate_key() → 
Command.run_capture("ssh-keygen ...") → Filesystem.chmod_private() → 
SSHKey model returned
```

### Key Rotation Flow
```
UI Request → KeyRotationManager.execute_plan() → RotationRunner.start_rotation() →
RotationPlan stages → RotationDeploy.deploy_key_to_target() →
Command.run_capture("ssh-copy-id ...") → Success/Rollback
```

### Tunnel Management Flow
```
UI Request → SSHTunneling.start_tunnel() → TunnelingManager.start_tunnel() →
ActiveTunnel.start() → Subprocess for SSH tunnel → Status monitoring
```

## Error Handling

### Consistent Error Types
All modules use `KeyMakerError` with specific types:
- `OPERATION_FAILED`: General operation failures
- `SUBPROCESS_FAILED`: Command execution failures  
- `KEY_NOT_FOUND`: Missing key files
- `OPERATION_CANCELLED`: User cancellation

### Logging Integration
Errors are automatically logged with appropriate categories:

```vala
try {
    yield operation();
} catch (KeyMakerError e) {
    KeyMaker.Log.error(KeyMaker.Log.Categories.SSH_OPS, "Operation failed: %s", e.message);
    throw e;
}
```

## Testing Strategy

### Module Isolation
Each module can be tested independently:

```vala
// Test SSH generation without UI
var request = new KeyGenerationRequest();
request.key_type = SSHKeyType.RSA;
var key = yield SSHGeneration.generate_key(request);
assert(key.key_type == SSHKeyType.RSA);
```

### Utility Testing
Core utilities have focused, unit-testable interfaces:

```vala
// Test filename sanitization
var safe_name = KeyMaker.Filesystem.safe_base_filename("user/../key", "fallback", 20);
assert(!safe_name.contains("/"));
```

## Migration Path

The refactoring maintains backward compatibility:

1. **Facade Pattern**: Public APIs remain unchanged
2. **Gradual Migration**: Internal code can be migrated incrementally
3. **Settings Compatibility**: Existing settings continue to work
4. **UI Compatibility**: No UI changes required initially

## Performance Considerations

### Async Operations
All I/O operations are asynchronous to prevent UI blocking:

```vala
// Key scanning doesn't block UI
yield KeyScanner.scan_ssh_directory_with_cancellable(cancellable);
```

### Subprocess Optimization
Centralized command execution allows for:
- Connection pooling for repeated operations
- Timeout management
- Output caching where appropriate

### Settings Caching
Settings manager provides caching to reduce GSettings calls.

## Security

### Permission Management
Centralized filesystem operations ensure consistent permissions:
- Private keys: 0600 (owner read/write only)
- Public keys: 0644 (world readable)
- SSH directory: 0700 (owner access only)

### Command Safety
All subprocess operations use argument arrays, never shell strings, preventing injection attacks.

### Key Handling
Sensitive data (private keys, passphrases) are handled with care:
- Minimal time in memory
- No logging of sensitive content
- Secure file operations

## Future Extensions

The modular architecture enables easy extension:

### New Key Types
Add support in `ssh-operations/generation.vala` and `models/enums.vala`

### New Tunnel Types
Extend `tunneling/configuration.vala` with new `TunnelType` variants

### New Backup Methods
Add modules to `vault/` directory following existing patterns

### Additional Utilities
Add new shared utilities to `utils/` directory

## Dependencies

- **GTK4**: UI framework
- **Libadwaita**: Modern GNOME UI components  
- **GLib**: Core utilities and async operations
- **GIO**: File operations and settings
- **JSON-GLib**: Configuration serialization
- **Posix**: File permissions

## Build System

Meson build system with:
- Automatic dependency detection
- Blueprint UI compilation
- Schema compilation
- Translation support
- Development/production profiles
# Contributing to SSHer

Thank you for your interest in contributing to SSHer! This document provides guidelines and information for contributors.

## Development Setup

### Prerequisites

- **Vala**: >= 0.56
- **GTK4**: >= 4.8  
- **Libadwaita**: >= 1.4
- **Meson**: >= 1.0
- **Blueprint Compiler**: For UI development

### Building

```bash
# Development build
./scripts/build.sh --dev

# Production build  
./scripts/build.sh

# Run from source
./scripts/build.sh --dev --run
```

### Project Structure

See [docs/architecture.md](docs/architecture.md) for detailed architectural information.

## Code Style Guidelines

### Vala Conventions

#### Naming
- **Classes**: `PascalCase` (e.g., `SSHKeyManager`)
- **Methods**: `snake_case` (e.g., `generate_key_pair`)
- **Properties**: `snake_case` (e.g., `key_type`)
- **Constants**: `UPPER_SNAKE_CASE` (e.g., `DEFAULT_KEY_SIZE`)
- **Enums**: `PascalCase` with `UPPER_SNAKE_CASE` values
  ```vala
  public enum SSHKeyType {
      RSA,
      ECDSA,
      ED25519
  }
  ```

#### File Organization
- One main class per file
- File names match the main class in lowercase with hyphens
- Place related enums and data classes in the same file

#### Async Operations
Always use async for I/O operations:

```vala
// ✅ Good
public async void save_configuration() throws KeyMakerError {
    yield file.replace_contents_async(data);
}

// ❌ Bad - blocks UI thread
public void save_configuration() throws KeyMakerError {
    file.replace_contents(data);
}
```

#### Error Handling
Use specific error types and proper logging:

```vala
// ✅ Good
try {
    yield perform_operation();
} catch (KeyMakerError e) {
    KeyMaker.Log.error(KeyMaker.Log.Categories.SSH_OPS, "Operation failed: %s", e.message);
    throw e;
} catch (Error e) {
    throw new KeyMakerError.OPERATION_FAILED("Unexpected error: %s", e.message);
}

// ❌ Bad - swallows errors
try {
    yield perform_operation();  
} catch (Error e) {
    // Silent failure
}
```

### Code Quality

#### Comments
- Document public APIs with clear descriptions
- Explain complex algorithms or business logic
- Avoid obvious comments

```vala
// ✅ Good
/**
 * Generate SSH key pair using ssh-keygen subprocess.
 * Sets proper file permissions and validates the result.
 */
public async SSHKey generate_key(KeyGenerationRequest request) throws KeyMakerError {

// ❌ Bad  
// Generate key
public async SSHKey generate_key(KeyGenerationRequest request) throws KeyMakerError {
```

#### Module Structure
Follow the established patterns:

```vala
/*
 * SSHer - [Module Purpose]
 * 
 * [Brief description of module responsibilities]
 */

namespace KeyMaker {
    public class [ClassName] {
        // Implementation
    }
}
```

#### Logging
Use structured logging with appropriate categories:

```vala
KeyMaker.Log.info(KeyMaker.Log.Categories.SSH_OPS, "Generated key: %s", fingerprint);
KeyMaker.Log.debug(KeyMaker.Log.Categories.VAULT, "Backup completed in %s", duration);
KeyMaker.Log.error(KeyMaker.Log.Categories.TUNNELING, "Connection failed: %s", error);
```

Available categories: `VAULT`, `SSH_OPS`, `ROTATION`, `TUNNELING`, `DIAGNOSTICS`, `AGENT`, `CONFIG`, `UI`, `SCANNER`

#### Utilities Usage
Always use shared utilities instead of rolling your own:

```vala
// ✅ Use filesystem utility
KeyMaker.Filesystem.chmod_private(key_file);
KeyMaker.Filesystem.ensure_ssh_dir();

// ✅ Use command utility  
var result = yield KeyMaker.Command.run_capture(cmd);

// ✅ Use settings manager
KeyMaker.SettingsManager.set_auto_add_keys_to_agent(true);

// ❌ Don't duplicate functionality
Posix.chmod(file.get_path(), 0x180);
var subprocess = launcher.spawnv(cmd);
```

### UI Development

#### Blueprint Templates
Use Blueprint for UI definitions:

```blueprint
template $KeyMakerDialog : Adw.Dialog {
  title: _("Dialog Title");
  default-width: 600;
  default-height: 400;
  
  content: Adw.ToolbarView {
    [top]
    Adw.HeaderBar {}
    
    content: Gtk.Box {
      orientation: vertical;
      spacing: 12;
      margin-start: 12;
      margin-end: 12;
      margin-top: 12;
      margin-bottom: 12;
    };
  };
}
```

#### Accessibility
- Always provide meaningful labels
- Use proper focus management  
- Support keyboard navigation
- Test with screen readers when possible

#### Responsive Design
- Design for different screen sizes
- Use appropriate breakpoints
- Test on mobile form factors

## Testing

### Unit Tests
Write tests for business logic:

```vala
public void test_key_generation() {
    var request = new KeyGenerationRequest();
    request.key_type = SSHKeyType.RSA;
    request.key_size = 2048;
    
    var key = yield SSHGeneration.generate_key(request);
    
    assert(key.key_type == SSHKeyType.RSA);
    assert(key.bit_size == 2048);
    assert(key.fingerprint.length > 0);
}
```

### Integration Tests
Test module interactions:

```vala
public void test_rotation_workflow() {
    var plan = new RotationPlan(test_key);
    plan.add_target(new RotationTarget("test-server", "user"));
    
    var runner = new RotationRunner(plan);
    yield runner.start_rotation();
    
    assert(plan.current_stage == RotationStage.COMPLETED);
}
```

### Manual Testing
- Test on different Linux distributions
- Verify SSH operations with real keys
- Test error conditions and edge cases

## Submitting Changes

### Commit Messages
Follow conventional commit format:

```
feat(ssh-ops): add ED25519 key generation support

Add support for generating ED25519 keys using ssh-keygen.
Includes proper key validation and error handling.

Fixes #123
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

### Pull Requests

1. **Create a branch**: `git checkout -b feature/description`
2. **Make your changes** following the guidelines above
3. **Write tests** for new functionality
4. **Update documentation** if needed
5. **Test thoroughly** including edge cases
6. **Submit PR** with clear description

#### PR Description Template
```markdown
## Summary
Brief description of changes

## Changes Made
- Specific change 1
- Specific change 2  
- Specific change 3

## Testing
- [ ] Unit tests added/updated
- [ ] Manual testing completed
- [ ] No regressions introduced

## Documentation
- [ ] Architecture docs updated (if needed)
- [ ] Comments added for complex logic
- [ ] README updated (if needed)
```

### Code Review Process

1. **Automated checks** must pass (build, tests, linting)
2. **Manual review** by maintainers
3. **Address feedback** promptly and courteously
4. **Squash commits** before merge if requested

## Security Considerations

### SSH Key Handling
- Never log private key content
- Minimize time sensitive data stays in memory
- Use proper file permissions (0600 for private keys)
- Validate all inputs from external sources

### Subprocess Execution  
- Always use argument arrays, never shell strings
- Validate command arguments before execution
- Use timeouts to prevent hanging processes
- Handle subprocess failures gracefully

### File Operations
- Validate file paths to prevent directory traversal
- Use atomic operations where possible
- Check permissions before accessing files
- Handle race conditions in file operations

## Performance Guidelines

### Async Operations
- Use async for all I/O operations
- Provide cancellation support for long-running operations
- Update progress indicators for user feedback

### Memory Management
- Avoid keeping large data in memory unnecessarily
- Use streams for large file operations
- Clean up resources promptly

### UI Responsiveness
- Never block the main thread
- Use background threads for heavy computations
- Batch UI updates to avoid excessive redraws

## Documentation

### API Documentation
Document all public APIs:

```vala
/**
 * Generate SSH key pair with specified parameters.
 * 
 * Creates both private and public key files in ~/.ssh directory
 * with appropriate permissions. The operation is atomic - if it
 * fails, no files are left behind.
 *
 * @param request Key generation parameters
 * @return Generated SSH key object
 * @throws KeyMakerError if generation fails
 */
public async SSHKey generate_key(KeyGenerationRequest request) throws KeyMakerError;
```

### User Documentation
- Update help content for new features
- Include screenshots for UI changes
- Write clear, step-by-step instructions

## Getting Help

- **Architecture Questions**: See [docs/architecture.md](docs/architecture.md)
- **Build Issues**: Check build logs and dependencies
- **Feature Discussions**: Open GitHub issues for discussion
- **Bug Reports**: Include steps to reproduce, expected vs actual behavior

## License

By contributing to SSHer, you agree that your contributions will be licensed under the same license as the project (GPL-3.0-or-later).
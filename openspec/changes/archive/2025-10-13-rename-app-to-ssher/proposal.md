# Proposal: Rename App to SSHer

## Overview
Rename the application from "Key Maker" to "SSHer" across all user-facing surfaces while maintaining the existing application ID (`io.github.tobagin.keysmith`) for continuity and to avoid breaking existing installations.

## Motivation
The new name "SSHer" better reflects:
- The application's core focus on SSH key management
- A more concise and memorable brand identity
- Improved discoverability in app stores and search results
- Professional naming convention aligned with other SSH tools

The app ID will remain `io.github.tobagin.keysmith` to:
- Preserve existing user data, settings, and configurations
- Avoid breaking Flatpak installations and updates
- Maintain compatibility with system integrations (desktop files, schema paths, etc.)
- Follow semantic stability practices for application identifiers

## Scope
This change affects multiple capabilities:
- **Application Branding**: Update display name throughout the UI
- **Documentation**: Update all user-facing and developer documentation
- **Metadata**: Modify desktop files, metainfo, and build configuration
- **Internationalization**: Update translation files and templates
- **Code Comments**: Update copyright headers and code documentation

## Impact Analysis

### User Impact
- Users will see the new "SSHer" name in:
  - Application launcher and menus
  - Window titles and about dialog
  - App store listings (Flathub)
  - Documentation and help resources
- No data loss or migration required
- Seamless updates for existing installations
- Settings and preferences preserved

### Developer Impact
- Update build scripts to use new display name
- Modify translation workflow for new app name
- Update repository metadata and documentation
- No API or architectural changes required

### Breaking Changes
None. The application ID remains stable, ensuring backward compatibility.

## Dependencies
None. This is a standalone branding change.

## Alternatives Considered
1. **Change both name and app ID**: Rejected due to breaking changes for existing users
2. **Keep current name**: Rejected as it doesn't align with rebranding goals
3. **Use "SSH Manager" or similar**: Rejected as less distinctive and memorable

## Success Criteria
- All user-facing text displays "SSHer" consistently
- Application ID remains `io.github.tobagin.keysmith`
- All translations updated or marked for translation
- Documentation reflects new branding
- Build system produces correct metadata
- Existing installations update seamlessly

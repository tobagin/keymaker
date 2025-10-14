# Design: Rename App to SSHer

## Technical Approach

### Architecture Overview
This change is purely a branding update that affects string literals and metadata without modifying the application's core functionality or architecture. The implementation follows a systematic approach to update all occurrences while preserving the application ID.

### Key Technical Decisions

#### 1. Preserve Application ID
**Decision**: Keep `io.github.tobagin.keysmith` as the stable application identifier.

**Rationale**:
- Application IDs are fundamental to the system (GSettings paths, D-Bus names, XDG directories)
- Changing it would break existing installations and require data migration
- Users would lose settings, preferences, and cached data
- Flatpak permissions and sandbox configurations would need reconfiguration
- The ID doesn't need to match the display name semantically

**Implementation**:
- Keep all `APP_ID` references unchanged in build system
- Maintain GSettings schema path (`/io/github/tobagin/keysmith/`)
- Preserve desktop file name (`io.github.tobagin.keysmith.desktop`)
- Keep metainfo XML name (`io.github.tobagin.keysmith.metainfo.xml`)

#### 2. Update Display Name Only
**Decision**: Change `APP_NAME` from "Key Maker" to "SSHer" in build configuration.

**Rationale**:
- Display names are flexible and can be changed without breaking compatibility
- Users expect application names to evolve with branding
- Translation systems already separate display names from identifiers
- GTK/Libadwaita handle display name changes gracefully

**Implementation**:
- Modify `meson.build` to set `app_name = 'SSHer'` (and `'SSHer (Devel)'` for dev builds)
- Update `Config.vala.in` template substitutions (already uses `@APP_NAME@`)
- All UI components reference `Config.APP_NAME` dynamically

### Component Changes

#### Build System (meson.build)
```vala
if get_option('profile') == 'development'
    app_id = 'io.github.tobagin.keysmith.Devel'
    app_name = 'SSHer (Devel)'  // Changed from 'Key Maker (Devel)'
else
    app_id = 'io.github.tobagin.keysmith'
    app_name = 'SSHer'  // Changed from 'Key Maker'
endif
```

#### Desktop Entry Template
- `Name=@APP_NAME@` already uses variable substitution
- No code changes needed; build system handles substitution

#### Metainfo XML Template
- `<name>@APP_NAME@</name>` uses variable substitution
- Update description text to reference "SSHer" instead of "Key Maker"
- Add new release entry documenting the rebrand

#### Documentation Files
Update references in:
- README.md (title, badges, descriptions)
- CONTRIBUTING.md
- docs/architecture.md
- FLATPAK.md
- Other documentation files

#### Translation Files (po/*.po)
- Extract new template with updated app name
- Update existing translations or mark for retranslation
- Translators will localize "SSHer" appropriately

#### Code Comments
Update copyright headers and inline comments:
- File headers: "SSHer - SSH Key Management Application"
- Code comments referencing "Key Maker" contextually
- Keep functional/technical comments unchanged

### Implementation Strategy

#### Phase 1: Core Metadata
1. Update build configuration (meson.build)
2. Modify metainfo XML description
3. Verify desktop entry template

#### Phase 2: Documentation
1. Update README.md and main documentation
2. Modify contributing guidelines
3. Update architecture documentation
4. Review and update all markdown files

#### Phase 3: Code Comments
1. Update copyright headers in source files
2. Modify contextual comments referencing app name
3. Preserve technical comments unchanged

#### Phase 4: Translations
1. Regenerate translation template
2. Update Spanish translation (es.po)
3. Mark new strings for translation

#### Phase 5: Release Notes
1. Add release entry to metainfo.xml
2. Document the rename in release notes
3. Communicate change to users

### Testing Strategy

#### Build Verification
- Build production version: `./scripts/build.sh`
- Build development version: `./scripts/build.sh --dev`
- Verify both show correct names ("SSHer" / "SSHer (Devel)")

#### Runtime Verification
- Launch application and verify window title
- Check About dialog shows "SSHer"
- Verify application launcher displays "SSHer"
- Confirm settings persistence (app ID unchanged)

#### Metadata Verification
- Check desktop file name: `io.github.tobagin.keysmith.desktop`
- Verify metainfo ID: `io.github.tobagin.keysmith`
- Confirm GSettings path: `/io/github/tobagin/keysmith/`
- Validate translation template generation

### Risk Mitigation

#### Minimal Risk Areas
- **Display name changes**: Low risk, standard practice
- **Documentation updates**: No functional impact
- **Translation updates**: Handled by i18n system

#### Monitored Areas
- **Build system changes**: Test both profiles (dev/prod)
- **Template substitution**: Verify all `@APP_NAME@` replacements
- **Translation extraction**: Ensure msgid updates propagate

### Rollback Plan
If issues arise:
1. Revert meson.build changes
2. Restore metainfo.xml description
3. Rollback documentation changes
4. Rebuild and redeploy

Since the app ID is unchanged, no data migration or user intervention required.

## Performance Considerations
None. This is a compile-time string substitution with zero runtime impact.

## Security Considerations
None. No changes to functionality, permissions, or security boundaries.

## Accessibility Considerations
- Screen readers will announce new app name "SSHer"
- Ensure name is clear and pronounceable
- Translation teams should provide localized versions

## Future Considerations
- Consider updating repository name (separate decision)
- Evaluate GitHub URL updates (backward compatibility via redirects)
- Plan communication strategy for existing users

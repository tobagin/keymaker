# Implementation Tasks: Rename App to SSHer

## Phase 1: Core Build Configuration
- [x] Update meson.build to set app_name to 'SSHer' for production builds
- [x] Update meson.build to set app_name to 'SSHer (Devel)' for development builds
- [x] Verify app_id remains 'io.github.tobagin.keysmith' unchanged
- [x] Run production build and verify desktop file shows "Name=SSHer"
- [x] Run development build and verify desktop file shows "Name=SSHer (Devel)"

## Phase 2: Application Metadata Files
- [x] Update data/io.github.tobagin.keysmith.metainfo.xml.in description to reference "SSHer"
- [x] Add new release entry documenting the rebrand from "Key Maker" to "SSHer"
- [x] Update metainfo summary and description paragraphs
- [x] Update screenshot captions to reference "SSHer" where appropriate
- [x] Verify desktop entry template already uses @APP_NAME@ variable substitution

## Phase 3: Primary Documentation
- [x] Update README.md title to "# SSHer"
- [x] Update README.md introduction paragraph to reference "SSHer"
- [x] Update README.md feature descriptions using "SSHer"
- [x] Update CONTRIBUTING.md to reference "SSHer"
- [x] Update docs/architecture.md to reference "SSHer"
- [x] Update FLATPAK.md to reference "SSHer"

## Phase 4: Secondary Documentation
- [x] Update RELEASE.md to reference "SSHer"
- [x] Update REFACTORING-COMPLETE.md references
- [x] Update TESTING-TODO.md references
- [x] Update CODEX-PLAN.md references
- [x] Update CLOUD-INTEGRATION-ROADMAP.md references
- [x] Update CONVERSION-SUMMARY.md references
- [x] Update REFACTORING-PLAN.md references
- [x] Update PHASE0.md references

## Phase 5: Source Code Comments
- [x] Update copyright headers in src/Application.vala
- [x] Update copyright headers in src/Main.vala
- [x] Update copyright headers in src/Window.vala
- [x] Update copyright headers in all src/ui/dialogs/*.vala files
- [x] Update copyright headers in all src/ui/pages/*.vala files
- [x] Update copyright headers in all src/backend/**/*.vala files
- [x] Update copyright headers in all src/models/*.vala files
- [x] Update copyright headers in all src/utils/*.vala files
- [x] Update copyright headers in all tests/*.vala files

## Phase 6: UI Blueprint Files
- [x] Review data/ui/window.blp for "Key Maker" references
- [x] Review data/ui/dialogs/*.blp files for application name references
- [x] Review data/ui/pages/*.blp files for application name references
- [x] Review data/ui/widgets/*.blp files for application name references
- [x] Update any hardcoded "Key Maker" strings found

## Phase 7: Translation Files
- [x] Regenerate translation template: `ninja -C build keysmith-pot`
- [x] Update po/es.po to replace "Key Maker" with "SSHer"
- [x] Mark new strings as translated or fuzzy as appropriate
- [x] Verify msgid updates for application name strings
- [x] Test that translations load correctly after updates

## Phase 8: Build Scripts and Configuration
- [x] Review scripts/build.sh for any "Key Maker" references in comments
- [x] Review packaging/io.github.tobagin.keysmith.yml for display name
- [x] Review packaging/io.github.tobagin.keysmith.Devel.yml for display name
- [x] Update Flatpak manifest comments if needed
- [x] Verify meson-vala.build has no hardcoded name references

## Phase 9: Git Repository Metadata
- [x] Update .git/config description if present
- [x] Review .gitignore for any name-specific patterns (unlikely)
- [x] Update test-simple.vala references if present

## Phase 10: Build and Runtime Verification
- [x] Clean build directory: `rm -rf build`
- [x] Run production build: `./scripts/build.sh`
- [x] Verify production build succeeds
- [x] Install and launch production build
- [x] Verify window title shows "SSHer"
- [x] Verify About dialog shows "SSHer"
- [x] Verify settings persist (app ID unchanged)
- [x] Run development build: `./scripts/build.sh --dev`
- [x] Verify development build succeeds
- [x] Install and launch development build
- [x] Verify window title shows "SSHer (Devel)"
- [x] Verify both versions can run side-by-side

## Phase 11: Documentation Verification
- [x] Read through updated README.md for consistency
- [x] Read through updated CONTRIBUTING.md for accuracy
- [x] Verify all documentation links still work
- [x] Check that repository references are appropriate
- [x] Ensure no "Key Maker" references remain in user-facing docs

## Phase 12: Final Validation
- [x] Run `openspec validate rename-app-to-ssher --strict`
- [x] Fix any validation issues reported
- [x] Commit all changes with descriptive message
- [ ] Create pull request documenting the rebrand
- [ ] Update PR description with migration notes

## Success Criteria
All tasks completed with:
- ✅ Production and development builds succeed
- ✅ Application displays "SSHer" in all UI elements
- ✅ Application ID remains `io.github.tobagin.keysmith`
- ✅ Settings and user data preserved
- ✅ Translations updated or marked for translation
- ✅ Documentation reflects new branding
- ✅ No "Key Maker" references in user-facing content
- ✅ OpenSpec validation passes

# i18n-configuration Specification Delta

## MODIFIED Requirements

### Requirement: Application Name Translation Support
The internationalization system SHALL support translation of the "SSHer" application name while maintaining gettext domain consistency.

#### Scenario: Translation template includes SSHer name
- **GIVEN** translation template generation process
- **WHEN** running `ninja -C build keysmith-pot`
- **THEN** template SHALL include "SSHer" as translatable string
- **AND** gettext domain SHALL remain "keysmith"
- **AND** .pot file SHALL be updated with new app name

#### Scenario: Existing translations updated for SSHer
- **GIVEN** existing translation files (e.g., po/es.po)
- **WHEN** updating translations after name change
- **THEN** "Key Maker" translations SHALL be replaced with "SSHer"
- **AND** translation strings SHALL maintain proper context
- **AND** fuzzy matching SHALL assist translators with updates

#### Scenario: New strings marked for translation
- **GIVEN** documentation and UI text referencing "SSHer"
- **WHEN** extracting translatable strings
- **THEN** all "SSHer" references SHALL be marked for translation where appropriate
- **AND** technical identifiers SHALL NOT be marked translatable
- **AND** brand name "SSHer" MAY be kept untranslated per locale conventions

### Requirement: Translation Context Preservation
The system SHALL preserve translation context and maintain consistency across the application after renaming.

#### Scenario: Translation comments updated
- **GIVEN** source code with translator comments
- **WHEN** updating references from "Key Maker" to "SSHer"
- **THEN** translator comments SHALL be updated to reflect new name
- **AND** context SHALL remain clear for translators
- **AND** translation quality SHALL not degrade

#### Scenario: Gettext domain remains unchanged
- **GIVEN** application rename to "SSHer"
- **WHEN** configuring internationalization
- **THEN** gettext domain SHALL remain "keysmith"
- **AND** GSchema gettext-domain SHALL remain "keysmith"
- **AND** meson GETTEXT_PACKAGE SHALL remain "keysmith"
- **AND** existing translations SHALL load correctly

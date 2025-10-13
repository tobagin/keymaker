# i18n-configuration Specification

## Purpose

This specification defines the internationalization (i18n) configuration requirements for KeyMaker, ensuring consistency across gettext domain settings, proper string extraction, and best practices for translatable content. It establishes patterns to prevent configuration drift and ensures security warnings maintain their intent across translations.

Created from add-security-warnings change (2025-10-12). Verification confirmed that gettext domain configuration is correct and consistent.

## Requirements

### Requirement: Gettext Domain Consistency Verification
The system's internationalization configuration SHALL maintain consistency between GSchema gettext domain and meson build configuration.

#### Scenario: Verify GSchema gettext domain
- **GIVEN** GSchema file at `data/io.github.tobagin.keysmith.gschema.xml.in`
- **WHEN** examining line 2 of the schema file
- **THEN** gettext-domain attribute SHALL be set to "keysmith"
- **AND** SHALL match the meson project name
- **AND** SHALL be documented as verified and correct

#### Scenario: Verify meson gettext package
- **GIVEN** meson.build configuration file
- **WHEN** examining GETTEXT_PACKAGE configuration
- **THEN** GETTEXT_PACKAGE SHALL be set to meson.project_name()
- **AND** meson.project_name() SHALL evaluate to 'keysmith'
- **AND** SHALL match GSchema gettext-domain

#### Scenario: Validate consistency across configurations
- **GIVEN** both GSchema and meson.build are configured
- **WHEN** comparing gettext domains
- **THEN** GSchema gettext-domain SHALL equal meson GETTEXT_PACKAGE
- **AND** both SHALL equal project name 'keysmith'
- **AND** SHALL be consistent for proper i18n string extraction

#### Scenario: Document verification for future reference
- **GIVEN** gettext domain consistency is verified
- **WHEN** configuration files are reviewed
- **THEN** system SHALL include comments explaining correct configuration
- **AND** SHALL reference this verification in documentation
- **AND** SHALL help prevent future mismatches

### Requirement: String Extraction Validation
The system SHALL validate that translatable strings are properly extracted into .pot files using the correct gettext domain.

#### Scenario: Run string extraction build target
- **GIVEN** project is configured with meson
- **WHEN** running `ninja -C build keysmith-pot`
- **THEN** build system SHALL extract all translatable strings
- **AND** SHALL create/update .pot template file
- **AND** SHALL complete without errors

#### Scenario: Verify warning strings in pot file
- **GIVEN** security warning strings are marked with _()
- **WHEN** examining generated .pot file
- **THEN** all warning dialog strings SHALL be present
- **AND** SHALL include proper source file references
- **AND** SHALL maintain correct context and comments

#### Scenario: Validate string metadata
- **GIVEN** strings are extracted to .pot file
- **WHEN** examining string entries
- **THEN** each string SHALL have source location comment
- **AND** SHALL include line number reference
- **AND** SHALL maintain translator comments if provided
- **AND** SHALL use correct msgid format

### Requirement: Gettext Domain Documentation
The system SHALL maintain clear documentation about gettext domain configuration to prevent future inconsistencies.

#### Scenario: Document current configuration
- **GIVEN** i18n configuration is verified as correct
- **WHEN** adding documentation
- **THEN** system SHALL document that gettext-domain="keysmith" is correct
- **AND** SHALL explain relationship to meson.project_name()
- **AND** SHALL provide example of proper usage
- **AND** SHALL warn against changing domain without matching changes

#### Scenario: Add inline configuration comments
- **GIVEN** GSchema and meson.build files
- **WHEN** reviewing configuration settings
- **THEN** system MAY add comments explaining gettext domain
- **AND** SHOULD reference verification date
- **AND** SHOULD note that consistency is required

#### Scenario: Cross-reference in refactoring plan
- **GIVEN** REFACTORING-PLAN.md mentions i18n domain concerns
- **WHEN** Phase 7 is completed
- **THEN** plan SHALL be updated to reflect verification results
- **AND** SHALL note that configuration is correct as-is
- **AND** SHALL mark i18n domain verification as complete

### Requirement: Prevent Future Gettext Domain Mismatches
The system SHALL establish patterns and checks to prevent gettext domain configuration drift.

#### Scenario: Template for new translatable strings
- **GIVEN** developers add new user-facing strings
- **WHEN** writing translatable text
- **THEN** strings SHALL use `_("text")` pattern for translation
- **AND** SHALL use C_("context", "text") for ambiguous terms
- **AND** SHALL not hardcode alternate domains
- **AND** SHALL rely on project-wide GETTEXT_PACKAGE setting

#### Scenario: Code review checklist item
- **GIVEN** code changes include new user-facing strings
- **WHEN** code is reviewed
- **THEN** reviewer SHOULD verify _() usage
- **AND** SHOULD check that strings will extract properly
- **AND** SHOULD ensure no alternate gettext domains introduced

#### Scenario: Build-time validation
- **GIVEN** project uses gettext for i18n
- **WHEN** build process runs
- **THEN** system SHOULD validate that .pot extraction succeeds
- **AND** MAY add CI check for string extraction
- **AND** MAY warn if new strings are not extracted

### Requirement: Internationalization Best Practices for Security Messages
The system SHALL follow i18n best practices specifically for security-critical warning messages.

#### Scenario: Complete sentences for security warnings
- **GIVEN** security warning messages are written
- **WHEN** marking strings for translation
- **THEN** system SHALL use complete sentences
- **AND** SHALL avoid string concatenation for translation
- **AND** SHALL provide full context for translators

#### Scenario: Avoid technical jargon in translatable strings
- **GIVEN** security messages target general users
- **WHEN** writing warning text
- **THEN** system SHALL use plain language where possible
- **AND** SHALL define technical terms when necessary
- **AND** SHALL ensure concepts translate across languages

#### Scenario: Cultural sensitivity in security warnings
- **GIVEN** warnings may be translated to many languages
- **WHEN** writing warning messages
- **THEN** system SHALL avoid idioms or culture-specific references
- **AND** SHALL use clear, direct language
- **AND** SHALL ensure message intent is preserved in translation

#### Scenario: Preserve warning severity in translation
- **GIVEN** security warnings use specific tone and urgency
- **WHEN** messages are translated
- **THEN** system SHALL use appropriate terminology (SHALL/MUST)
- **AND** SHALL maintain consistent severity indicators
- **AND** SHOULD provide translator notes about message importance

# Implementation Tasks

## 1. Backend Implementation
- [x] 1.1 Create `KnownHostsManager.vala` class structure
- [x] 1.2 Implement known_hosts file parser (parse_known_hosts_file method)
- [x] 1.3 Add support for hashed hostname format
- [x] 1.4 Implement support for multiple key types (RSA, ECDSA, Ed25519)
- [x] 1.5 Add known_hosts file writer (save_known_hosts_file method)
- [x] 1.6 Implement entry removal functionality (remove_entry method)
- [x] 1.7 Implement batch removal for multiple entries
- [x] 1.8 Add duplicate entry detection logic
- [x] 1.9 Implement entry merging functionality
- [x] 1.10 Add host reachability testing (async connectivity check)
- [x] 1.11 Implement stale entry detection

## 2. Data Models
- [x] 2.1 Create `KnownHostEntry` class to represent a known_hosts entry
- [x] 2.2 Add properties: hostname, ip_addresses, key_type, fingerprint, key_data
- [x] 2.3 Implement fingerprint calculation (SHA256 and MD5)
- [x] 2.4 Add status tracking (verified, stale, conflict)
- [x] 2.5 Implement comparison methods for duplicate detection

## 3. UI Page Implementation
- [x] 3.1 Create UI blueprint file `data/ui/pages/known_hosts_page.blp`
- [x] 3.2 Create `KnownHostsPage.vala` class
- [x] 3.3 Implement known hosts list view with columns (hostname, key type, fingerprint)
- [x] 3.4 Add search/filter functionality
- [x] 3.5 Implement empty state display
- [x] 3.6 Add selection handling (single and multiple)
- [x] 3.7 Connect remove button with confirmation dialog
- [x] 3.8 Implement "Remove Stale Entries" batch action
- [x] 3.9 Add "Import/Export" buttons and handlers
- [x] 3.10 Implement refresh functionality

## 4. Host Key Verification Dialog
- [x] 4.1 Create UI blueprint file `data/ui/dialogs/host_key_verification_dialog.blp`
- [x] 4.2 Create `HostKeyVerificationDialog.vala` class
- [x] 4.3 Implement fingerprint display (SHA256 and MD5 formats)
- [x] 4.4 Add manual verification input field
- [x] 4.5 Implement comparison logic and result display
- [x] 4.6 Add trusted sources database for common services (GitHub, GitLab, etc.)
- [x] 4.7 Implement automatic verification against trusted sources
- [x] 4.8 Add link to official documentation for verification

## 5. Key Conflict Handling
- [x] 5.1 Create `HostKeyConflictDialog.vala` for conflict resolution
- [x] 5.2 Display old and new fingerprints side-by-side
- [x] 5.3 Add warning message about MITM attacks
- [x] 5.4 Implement "Update Key" action (framework in place, needs SSH integration)
- [x] 5.5 Implement "Reject Key" action
- [x] 5.6 Add audit logging for key updates

## 6. Import/Export Functionality
- [x] 6.1 Implement export_known_hosts method with file chooser
- [x] 6.2 Implement import_known_hosts method with validation
- [x] 6.3 Add merge logic for imported entries (avoid duplicates)
- [x] 6.4 Create import summary dialog
- [x] 6.5 Handle import errors gracefully

## 7. Integration
- [x] 7.1 Add Known Hosts page to main window navigation
- [x] 7.2 Update `src/ui/Window.vala` to include new page
- [x] 7.3 Add navigation item to sidebar
- [x] 7.4 Update build system (`meson.build`) to include new files
- [x] 7.5 Add new files to UI blueprint resources (gresource.xml)
- [x] 7.6 Integrate with existing toast notification system

## 8. Internationalization
- [x] 8.1 Mark all user-facing strings with `_()` for translation
- [x] 8.2 Update translation template with new strings (automatic during build)
- [x] 8.3 Verify i18n domain consistency (use "keymaker")

## 9. Testing & Validation
- [ ] 9.1 Test with various known_hosts file formats
- [ ] 9.2 Test hashed hostname entries
- [ ] 9.3 Test all key types (RSA, ECDSA, Ed25519)
- [ ] 9.4 Test removal of single and multiple entries
- [ ] 9.5 Test import/export functionality
- [ ] 9.6 Test duplicate detection and merging
- [ ] 9.7 Test stale entry detection
- [ ] 9.8 Test host key conflict scenarios
- [ ] 9.9 Test verification against trusted sources
- [ ] 9.10 Verify proper error handling for file permission errors

## 10. Documentation
- [ ] 10.1 Add documentation comments to KnownHostsManager class
- [ ] 10.2 Document the known_hosts file format handling
- [ ] 10.3 Update user documentation with new feature
- [ ] 10.4 Add screenshots of Known Hosts page to docs

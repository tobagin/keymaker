# Implementation Tasks

## 1. Backend Infrastructure Updates

- [ ] 1.1 Add `AWS` to `CloudProviderType` enum
- [ ] 1.2 Register AWSProvider in CloudProviderManager
- [ ] 1.3 Update `src/meson.build` to include AWS source files

## 2. Implement AWS Signature Version 4

- [ ] 2.1 Create `src/backend/cloud/AWSRequestSigner.vala` class
- [ ] 2.2 Implement canonical request construction (method, URI, query, headers, payload)
- [ ] 2.3 Implement string to sign generation (algorithm, timestamp, scope, hashed request)
- [ ] 2.4 Implement signing key derivation (HMAC chain with date, region, service)
- [ ] 2.5 Implement signature computation (HMAC-SHA256 of string to sign)
- [ ] 2.6 Implement Authorization header formatting
- [ ] 2.7 Add ISO8601 timestamp generation for X-Amz-Date header
- [ ] 2.8 Add SHA256 hashing using GLib.Checksum
- [ ] 2.9 Add HMAC-SHA256 using GLib.Hmac
- [ ] 2.10 Add URL encoding for AWS parameters

## 3. Implement AWS Provider Backend

- [ ] 3.1 Create `src/backend/cloud/AWSProvider.vala` implementing CloudProvider interface
- [ ] 3.2 Implement `authenticate()` - Validate credentials via iam:GetUser
- [ ] 3.3 Implement `list_keys()` - Call ListSSHPublicKeys + GetSSHPublicKey for details
- [ ] 3.4 Implement `deploy_key()` - Call UploadSSHPublicKey
- [ ] 3.5 Implement `remove_key()` - Call DeleteSSHPublicKey
- [ ] 3.6 Implement `is_authenticated()` - Check Secret Service for AWS credentials
- [ ] 3.7 Implement `get_provider_name()` - Return "AWS IAM"
- [ ] 3.8 Add IAM API endpoint: `https://iam.amazonaws.com/`

## 4. AWS API Request/Response Handling

- [ ] 4.1 Implement AWS IAM POST request builder (x-www-form-urlencoded)
- [ ] 4.2 Add AWS API action parameter construction (Action=ListSSHPublicKeys, etc.)
- [ ] 4.3 Implement XML response parser using GLib's MarkupParser
- [ ] 4.4 Parse ListSSHPublicKeys response (<SSHPublicKeyId>, <Status>)
- [ ] 4.5 Parse GetSSHPublicKey response (<SSHPublicKeyBody>, <UploadDate>, <Fingerprint>)
- [ ] 4.6 Parse UploadSSHPublicKey response (key ID extraction)
- [ ] 4.7 Parse AWS error responses (<Code>, <Message>)
- [ ] 4.8 Handle paginated responses (Marker, IsTruncated) for ListSSHPublicKeys

## 5. AWS Credential Management

- [ ] 5.1 Create AWS credentials input dialog UI
- [ ] 5.2 Add text entries for Access Key ID and Secret Access Key
- [ ] 5.3 Add region dropdown (us-east-1, us-west-2, eu-west-1, ap-southeast-1, etc.)
- [ ] 5.4 Add security warning label with link to IAM policy documentation
- [ ] 5.5 Implement credential validation (call iam:GetUser)
- [ ] 5.6 Store Access Key ID in Secret Service (service="keymaker-aws-access-key-id")
- [ ] 5.7 Store Secret Access Key in Secret Service (service="keymaker-aws-secret-access-key")
- [ ] 5.8 Store region in GSettings (cloud-provider-aws-region)
- [ ] 5.9 Implement credential retrieval for API calls
- [ ] 5.10 Implement credential revocation (delete from Secret Service)

## 6. Update Cloud Providers Page UI

- [ ] 6.1 Add AWS provider card to CloudProvidersPage
- [ ] 6.2 Place below Bitbucket card (or last provider)
- [ ] 6.3 Display connection status: "Connected to AWS as <username> (<region>)"
- [ ] 6.4 Add "Configure Credentials" button
- [ ] 6.5 Add "Revoke Credentials" button (in addition to Disconnect)
- [ ] 6.6 Show key count with limit: "SSH keys: 3/5"
- [ ] 6.7 Display AWS key list: Key ID, Status, Fingerprint, Upload Date
- [ ] 6.8 Disable "Deploy" button when 5 keys exist (show tooltip)

## 7. Create AWS Credentials Dialog

- [ ] 7.1 Create `data/ui/dialogs/aws_credentials_dialog.blp`
- [ ] 7.2 Create `src/ui/dialogs/AWSCredentialsDialog.vala`
- [ ] 7.3 Add Access Key ID entry field with validation (format: AKIA...)
- [ ] 7.4 Add Secret Access Key entry field (password input)
- [ ] 7.5 Add region dropdown with common regions
- [ ] 7.6 Add security warning banner
- [ ] 7.7 Add "Test Connection" button (validates credentials)
- [ ] 7.8 Add link to IAM policy documentation
- [ ] 7.9 Show validation errors (invalid key format, access denied)
- [ ] 7.10 Update `data/ui/meson.build` to include new Blueprint file

## 8. AWS Error Handling

- [ ] 8.1 Map AccessDenied to user-friendly message with IAM policy guidance
- [ ] 8.2 Map InvalidClientTokenId to "Invalid Access Key ID"
- [ ] 8.3 Map SignatureDoesNotMatch to "Incorrect Secret Access Key"
- [ ] 8.4 Map NoSuchEntity to "User or key not found"
- [ ] 8.5 Map LimitExceeded to "5 key limit reached"
- [ ] 8.6 Handle network errors (unreachable endpoint)
- [ ] 8.7 Handle XML parsing errors
- [ ] 8.8 Log AWS Request IDs for debugging (from x-amzn-RequestId header)

## 9. AWS Key Limit Handling

- [ ] 9.1 Track key count after list operation
- [ ] 9.2 Display "3/5" key count in provider card
- [ ] 9.3 Disable "Deploy Key" button when count >= 5
- [ ] 9.4 Show tooltip: "AWS limit reached (5 keys). Delete a key to upload new one."
- [ ] 9.5 Handle LimitExceeded error on upload attempt
- [ ] 9.6 Refresh key list after deletion to update count

## 10. Security Implementation

- [ ] 10.1 Implement no-logging policy for credentials (audit all log statements)
- [ ] 10.2 Ensure HTTPS-only for AWS API calls
- [ ] 10.3 Add Access Key ID format validation (AKIA* or ASIA*)
- [ ] 10.4 Add Secret Access Key length validation (40 characters)
- [ ] 10.5 Overwrite credential strings in memory after use (best effort)
- [ ] 10.6 Add warning dialog before storing credentials
- [ ] 10.7 Document minimal IAM policy in help text

## 11. GSettings Schema Updates

- [ ] 11.1 Add `cloud-provider-aws-connected` boolean key
- [ ] 11.2 Add `cloud-provider-aws-username` string key
- [ ] 11.3 Add `cloud-provider-aws-region` string key (default: "us-east-1")
- [ ] 11.4 Update `data/io.github.tobagin.keysmith.gschema.xml.in`

## 12. Internationalization

- [ ] 12.1 Mark all AWS UI strings with _() for translation
- [ ] 12.2 Add i18n for "AWS IAM", "Configure Credentials", error messages
- [ ] 12.3 Update po/POTFILES with new AWS files

## 13. Testing

- [ ] 13.1 Test AWS credential validation (valid, invalid Access Key ID, invalid Secret Key)
- [ ] 13.2 Test key operations (list, upload, delete)
- [ ] 13.3 Test AWS Signature V4 implementation (compare with AWS CLI --debug output)
- [ ] 13.4 Test XML response parsing (valid responses, error responses)
- [ ] 13.5 Test 5-key limit handling (upload 5 keys, attempt 6th)
- [ ] 13.6 Test region selection (us-east-1, eu-west-1, ap-southeast-1)
- [ ] 13.7 Test IAM permission errors (AccessDenied)
- [ ] 13.8 Test paginated key list (if user has many keys)
- [ ] 13.9 Test credential revocation
- [ ] 13.10 Test AWS + OAuth providers all connected simultaneously
- [ ] 13.11 Test offline mode with AWS (should show cached keys)
- [ ] 13.12 Test credential storage/retrieval from Secret Service

## 14. Documentation

- [ ] 14.1 Update README with AWS IAM support
- [ ] 14.2 Document AWS credential setup process
- [ ] 14.3 Provide example IAM policy JSON with minimal permissions
- [ ] 14.4 Document 5-key limit
- [ ] 14.5 Document security best practices (don't use root account, rotate credentials)
- [ ] 14.6 Add troubleshooting guide for AWS errors

## 15. Unit Tests for Signature V4

- [ ] 15.1 Create test suite for AWSRequestSigner
- [ ] 15.2 Test canonical request construction
- [ ] 15.3 Test string to sign generation
- [ ] 15.4 Test signing key derivation
- [ ] 15.5 Test signature computation
- [ ] 15.6 Compare output with official AWS test vectors
- [ ] 15.7 Test timestamp formatting (ISO8601)

## 16. Final Review

- [ ] 16.1 Verify CloudProvider interface unchanged (no AWS-specific leaks)
- [ ] 16.2 Audit code for credential logging (ensure none exists)
- [ ] 16.3 Verify HTTPS enforcement for all AWS calls
- [ ] 16.4 Test with all providers connected (GitHub, GitLab, Bitbucket, AWS)
- [ ] 16.5 Verify binary size increase is minimal (<50 KB)
- [ ] 16.6 Run production build
- [ ] 16.7 Update OpenSpec tasks.md to mark all items complete

# Add AWS IAM Integration (Phase 4)

## Why

AWS is the largest cloud platform, and many developers use EC2 instances that require SSH key management. Unlike GitHub/GitLab/Bitbucket, AWS uses IAM (Identity and Access Management) with **API keys instead of OAuth**. This proposal adds AWS integration to enable users to manage SSH public keys for EC2 instances directly from KeyMaker.

This phase introduces a new authentication pattern (API keys) to the cloud provider infrastructure, expanding beyond OAuth-only providers.

## What Changes

- Add AWS IAM authentication using Access Key ID + Secret Access Key
- Implement `AWSProvider` class following the `CloudProvider` interface
- Add AWS SDK-like signature generation (AWS Signature Version 4) using libsoup
- Add AWS IAM SSH key operations:
  - List SSH public keys (`iam:ListSSHPublicKeys`)
  - Upload SSH public keys (`iam:UploadSSHPublicKey`)
  - Delete SSH public keys (`iam:DeleteSSHPublicKey`)
  - Get key details (`iam:GetSSHPublicKey`)
- Add AWS credentials configuration dialog (Access Key ID, Secret Access Key, Region)
- Update Cloud Providers page UI to show AWS card
- Add secure storage for AWS credentials in Secret Service

**Dependencies**: Reuses libsoup-3.0 from Phase 1; adds AWS request signing logic (no new external dependencies)

## Impact

- **Affected specs**: Modifies `cloud-provider-integration` capability
- **Affected code**:
  - `src/backend/cloud/AWSProvider.vala` - New provider implementation
  - `src/backend/cloud/AWSRequestSigner.vala` - AWS Signature V4 implementation
  - `src/backend/cloud/CloudProviderType.vala` - Add AWS enum value
  - `src/backend/cloud/CloudProviderManager.vala` - Register AWS provider
  - `src/ui/pages/CloudProvidersPage.vala` - Add AWS card to UI
  - `src/ui/dialogs/AWSCredentialsDialog.vala` - API key input dialog
  - GSettings schema - Add AWS-specific keys
- **Dependencies on previous phases**: Requires Phase 1 (GitHub) to be complete
- **New authentication pattern**: First non-OAuth provider (API keys)

## Breaking Changes

None. This is purely additive.

## Sequencing

**MUST complete Phase 1 (GitHub integration) before starting Phase 4.**
Phases 2-3 (GitLab, Bitbucket) are NOT required.

Phase 4 is architecturally significant because it validates that the `CloudProvider` interface works for both OAuth and API key authentication.

## Security Considerations

AWS credentials (Access Key ID + Secret Access Key) are **highly sensitive**. Unlike OAuth tokens that can be revoked easily, leaked AWS keys can result in unauthorized access to cloud resources. This proposal includes:
- Secret Service storage for credentials (encrypted)
- Warning dialog: "AWS credentials grant access to your cloud resources. Keep them secure."
- No credential logging (even in debug mode)
- Option to use IAM roles with limited permissions

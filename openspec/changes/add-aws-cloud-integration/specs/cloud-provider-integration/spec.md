# Cloud Provider Integration Specification (Phase 4)

## MODIFIED Requirements

### Requirement: Cloud Provider Interface
The system SHALL support cloud providers with different authentication mechanisms including OAuth (GitHub, GitLab, Bitbucket) and API keys (AWS).

#### Scenario: AWS provider registration
- **WHEN** application starts
- **THEN** the system SHALL register AWSProvider with CloudProviderManager and assign CloudProviderType.AWS

#### Scenario: API key authentication support
- **WHEN** AWS provider authentication is initiated
- **THEN** the system SHALL use Access Key ID and Secret Access Key instead of OAuth flow

## ADDED Requirements

### Requirement: AWS IAM Authentication
The system SHALL support authentication with AWS IAM using Access Key ID and Secret Access Key.

#### Scenario: AWS credentials configuration
- **WHEN** user clicks "Configure Credentials" on AWS provider card
- **THEN** the system SHALL show a dialog prompting for Access Key ID, Secret Access Key, and AWS Region

#### Scenario: Credential validation
- **WHEN** user provides AWS credentials
- **THEN** the system SHALL validate them by calling `iam:GetUser` API and display error if validation fails

#### Scenario: Security warning display
- **WHEN** AWS credentials dialog is shown
- **THEN** the system SHALL display warning "AWS credentials grant access to your cloud resources. Keep them secure. Consider using IAM users with limited permissions."

#### Scenario: AWS region selection
- **WHEN** configuring AWS credentials
- **THEN** the system SHALL allow region selection from dropdown (us-east-1, us-west-2, eu-west-1, ap-southeast-1, etc.) with default us-east-1

#### Scenario: Username retrieval
- **WHEN** AWS credential validation succeeds
- **THEN** the system SHALL call `iam:GetUser` to retrieve IAM username and store it for display

### Requirement: AWS Signature Version 4 Request Signing
The system SHALL sign all AWS IAM API requests using AWS Signature Version 4 algorithm.

#### Scenario: Canonical request construction
- **WHEN** making an AWS IAM API request
- **THEN** the system SHALL construct canonical request including HTTP method, URI, query string, headers, and payload

#### Scenario: String to sign generation
- **WHEN** signing AWS request
- **THEN** the system SHALL generate string to sign with format "AWS4-HMAC-SHA256\n<timestamp>\n<credential_scope>\n<hashed_canonical_request>"

#### Scenario: Signing key derivation
- **WHEN** generating AWS signature
- **THEN** the system SHALL derive signing key using HMAC-SHA256 chain: HMAC(HMAC(HMAC(HMAC("AWS4" + SecretAccessKey, date), region), "iam"), "aws4_request")

#### Scenario: Authorization header construction
- **WHEN** request signature is computed
- **THEN** the system SHALL include Authorization header with format "AWS4-HMAC-SHA256 Credential=<access_key_id>/<credential_scope>, SignedHeaders=<signed_headers>, Signature=<signature>"

#### Scenario: Timestamp handling
- **WHEN** signing AWS requests
- **THEN** the system SHALL use ISO8601 timestamp in format "YYYYMMDD'T'HHMMSS'Z'" (UTC) for X-Amz-Date header

### Requirement: AWS IAM SSH Key Operations
The system SHALL support listing, uploading, and deleting SSH public keys via AWS IAM API.

#### Scenario: List AWS SSH keys
- **WHEN** AWS provider is authenticated
- **THEN** the system SHALL call `Action=ListSSHPublicKeys&UserName=<username>` and parse XML response for key IDs and status

#### Scenario: Upload SSH key to AWS
- **WHEN** user deploys a key to AWS
- **THEN** the system SHALL call `Action=UploadSSHPublicKey&UserName=<username>&SSHPublicKeyBody=<url_encoded_key>` with POST method

#### Scenario: Delete SSH key from AWS
- **WHEN** user removes a key from AWS
- **THEN** the system SHALL call `Action=DeleteSSHPublicKey&UserName=<username>&SSHPublicKeyId=<key_id>` with POST method

#### Scenario: Get SSH key details
- **WHEN** listing AWS keys
- **THEN** the system SHALL call `Action=GetSSHPublicKey&UserName=<username>&SSHPublicKeyId=<key_id>&Encoding=SSH` for each key to retrieve full details

#### Scenario: Parse AWS XML responses
- **WHEN** receiving AWS IAM API response
- **THEN** the system SHALL parse XML format (not JSON) and extract key metadata from `<SSHPublicKey>` elements

### Requirement: AWS Credential Storage
The system SHALL securely store AWS credentials in GNOME Secret Service.

#### Scenario: Store Access Key ID
- **WHEN** AWS credentials are validated
- **THEN** the system SHALL store Access Key ID in Secret Service with schema attributes `service="keymaker-aws-access-key-id"`, `account=<access_key_id>`

#### Scenario: Store Secret Access Key
- **WHEN** AWS credentials are validated
- **THEN** the system SHALL store Secret Access Key in Secret Service with schema attributes `service="keymaker-aws-secret-access-key"`, `account=<access_key_id>`

#### Scenario: Retrieve credentials for API calls
- **WHEN** making AWS IAM API request
- **THEN** the system SHALL retrieve both Access Key ID and Secret Access Key from Secret Service using Access Key ID as lookup key

#### Scenario: Revoke AWS credentials
- **WHEN** user clicks "Disconnect" or "Revoke Credentials" on AWS provider
- **THEN** the system SHALL delete both Access Key ID and Secret Access Key from Secret Service

### Requirement: AWS IAM Endpoint Configuration
The system SHALL use correct AWS IAM API endpoints and handle regional considerations.

#### Scenario: IAM global endpoint
- **WHEN** making AWS IAM API requests
- **THEN** the system SHALL use global endpoint `https://iam.amazonaws.com/` (not regional endpoints)

#### Scenario: Region in signature
- **WHEN** signing AWS requests
- **THEN** the system SHALL use user-selected region in credential scope (e.g., `<date>/us-east-1/iam/aws4_request`)

#### Scenario: Content-Type header
- **WHEN** making AWS IAM API POST requests
- **THEN** the system SHALL include header `Content-Type: application/x-www-form-urlencoded`

#### Scenario: User-Agent header
- **WHEN** making AWS API requests
- **THEN** the system SHALL include `User-Agent: KeyMaker/<version>` header

### Requirement: AWS Error Handling
The system SHALL handle AWS-specific error responses and provide user-friendly messages.

#### Scenario: AccessDenied error
- **WHEN** AWS API returns `<Code>AccessDenied</Code>`
- **THEN** the system SHALL display "Insufficient IAM permissions. Ensure your user has iam:ListSSHPublicKeys, iam:UploadSSHPublicKey, iam:DeleteSSHPublicKey policies."

#### Scenario: InvalidClientTokenId error
- **WHEN** AWS API returns `<Code>InvalidClientTokenId</Code>`
- **THEN** the system SHALL display "Invalid Access Key ID. Check your AWS credentials."

#### Scenario: SignatureDoesNotMatch error
- **WHEN** AWS API returns `<Code>SignatureDoesNotMatch</Code>`
- **THEN** the system SHALL display "Incorrect Secret Access Key or request signing failed. Verify your credentials."

#### Scenario: NoSuchEntity error
- **WHEN** AWS API returns `<Code>NoSuchEntity</Code>`
- **THEN** the system SHALL display "AWS user or key not found."

#### Scenario: LimitExceeded error
- **WHEN** AWS API returns `<Code>LimitExceeded</Code>`
- **THEN** the system SHALL display "AWS SSH key limit reached (5 keys per IAM user). Delete an existing key before uploading."

#### Scenario: Parse AWS error XML
- **WHEN** AWS API returns error response (4xx/5xx)
- **THEN** the system SHALL parse XML format `<ErrorResponse><Error><Code>...</Code><Message>...</Message></Error></ErrorResponse>` and extract error details

### Requirement: Cloud Providers Page AWS Integration
The system SHALL display AWS provider card on Cloud Providers page.

#### Scenario: AWS card placement
- **WHEN** user views Cloud Providers page
- **THEN** AWS provider card SHALL appear below Bitbucket card (or last OAuth provider) with title "AWS IAM"

#### Scenario: Connection status display
- **WHEN** AWS provider is configured
- **THEN** the card SHALL show "Connected to AWS as <username> (<region>)"

#### Scenario: Configure Credentials button
- **WHEN** AWS provider is not connected
- **THEN** the card SHALL show "Configure Credentials" button to initiate credential input

#### Scenario: Revoke Credentials button
- **WHEN** AWS provider is connected
- **THEN** the card SHALL show "Revoke Credentials" button in addition to "Disconnect"

#### Scenario: Key list display for AWS
- **WHEN** AWS keys are loaded
- **THEN** the system SHALL display key ID (APKA...), status (Active/Inactive), fingerprint, upload date

### Requirement: AWS IAM Key Limit Handling
The system SHALL handle AWS's 5 keys per user limit gracefully.

#### Scenario: Display key count
- **WHEN** AWS provider is connected
- **THEN** the provider card SHALL show "SSH keys: <count>/5"

#### Scenario: Warn before limit
- **WHEN** user has 5 AWS SSH keys
- **THEN** deploy button SHALL be disabled with tooltip "AWS limit reached (5 keys). Delete a key to upload new one."

#### Scenario: Deployment failure at limit
- **WHEN** attempting to deploy 6th key to AWS
- **THEN** the system SHALL display error "AWS SSH key limit exceeded. Each IAM user can have maximum 5 SSH keys."

### Requirement: AWS Credential Security
The system SHALL enforce security best practices for AWS credential handling.

#### Scenario: No credential logging
- **WHEN** AWS credentials are stored or used
- **THEN** the system SHALL NOT log Access Key ID or Secret Access Key to application logs (even in debug mode)

#### Scenario: Secure transmission
- **WHEN** making AWS API requests
- **THEN** the system SHALL only use HTTPS (enforce TLS)

#### Scenario: Memory wiping
- **WHEN** AWS credentials are no longer needed in memory
- **THEN** the system SHOULD overwrite credential strings before deallocation (best effort in Vala)

#### Scenario: Permission documentation
- **WHEN** AWS credentials dialog is shown
- **THEN** the dialog SHALL include link to documentation showing example IAM policy with minimal required permissions

### Requirement: No AWS SDK Dependency
The system SHALL implement AWS API interactions without depending on official AWS SDKs.

#### Scenario: Lightweight implementation
- **WHEN** building KeyMaker with AWS support
- **THEN** the build SHALL NOT require aws-sdk-cpp, boto3, or other heavyweight AWS SDKs

#### Scenario: Manual signature implementation
- **WHEN** signing AWS requests
- **THEN** the system SHALL use custom `AWSRequestSigner` class with GLib's Checksum and Hmac utilities

#### Scenario: Binary size impact
- **WHEN** AWS provider is included
- **THEN** binary size increase SHALL be minimal (<50 KB for AWS-specific code)

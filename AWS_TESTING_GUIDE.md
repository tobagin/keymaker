# AWS IAM Integration - Testing Guide

## Prerequisites

Before you can test the AWS integration, you need:

### 1. AWS Account
- You need an AWS account (free tier works fine)
- Sign up at: https://aws.amazon.com/

### 2. IAM User with Credentials
You need to create an IAM user with API access credentials. Here's how:

#### Step-by-Step IAM User Setup

**A. Create IAM User**

1. Log into AWS Console: https://console.aws.amazon.com/
2. Navigate to **IAM** service (search for "IAM" in the top search bar)
3. Click **Users** in the left sidebar
4. Click **Create user** button
5. Enter user name: `ssher-test-user` (or any name you prefer)
6. Click **Next**

**B. Set Permissions**

1. Select **Attach policies directly**
2. Click **Create policy** (opens in new tab)
3. Click **JSON** tab
4. Paste this policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:GetUser",
        "iam:ListSSHPublicKeys",
        "iam:GetSSHPublicKey",
        "iam:UploadSSHPublicKey",
        "iam:DeleteSSHPublicKey"
      ],
      "Resource": "arn:aws:iam::*:user/${aws:username}"
    }
  ]
}
```

5. Click **Next**
6. Policy name: `SSHer-SSH-Key-Management`
7. Description: `Allows SSHer app to manage SSH public keys for IAM users`
8. Click **Create policy**
9. Go back to the user creation tab
10. Click the refresh icon next to **Create policy**
11. Search for `SSHer-SSH-Key-Management`
12. Check the box next to it
13. Click **Next**

**C. Create Access Key**

1. Click **Create user**
2. Click on the newly created user
3. Go to **Security credentials** tab
4. Scroll down to **Access keys**
5. Click **Create access key**
6. Select **Application running outside AWS**
7. Check "I understand..." checkbox
8. Click **Next**
9. Description: `SSHer desktop app`
10. Click **Create access key**
11. **IMPORTANT**: Copy both:
    - **Access key ID** (starts with AKIA)
    - **Secret access key** (40 characters)
12. Click **Download .csv file** as backup
13. Click **Done**

**⚠️ SECURITY WARNING**: Never share or commit these credentials! The secret access key is shown only once.

## Testing the Integration

### Step 1: Launch SSHer

```bash
# Run the development build
flatpak run io.github.tobagin.keysmith.Devel

# Or if you want verbose logging:
flatpak run io.github.tobagin.keysmith.Devel -v
```

### Step 2: Navigate to Cloud Providers

1. Click **Cloud Providers** in the left sidebar
2. You should see the Cloud Providers page

### Step 3: Add AWS Account

1. Click the **Add Account** button (or the "+" icon)
2. A dialog appears: "Choose a cloud provider to connect"
3. In the dropdown, select **AWS IAM**
4. Click **OK**

### Step 4: Enter Credentials

The AWS Credentials dialog appears. Enter:

1. **Access Key ID**:
   - Paste the Access Key ID from step 2C
   - Format: `AKIA...` (20 characters)
   - Should auto-validate format

2. **Secret Access Key**:
   - Paste the Secret Access Key
   - Format: 40 characters
   - Field will be masked (password field)

3. **AWS Region**:
   - Select your preferred region (or leave as us-east-1)
   - Common choices:
     - `us-east-1` (N. Virginia) - default
     - `us-west-2` (Oregon)
     - `eu-west-1` (Ireland)
     - `ap-southeast-1` (Singapore)

4. Review the **Required Permissions** section
5. Review the **Security Best Practices** section

6. Click **Connect**

### Step 5: Watch for Success

You should see:
- Spinner starts spinning
- Status: "Validating credentials..."
- Status: "Connecting to AWS IAM..."
- Status: "Connected successfully!" (green checkmark)
- Dialog closes automatically after 1 second

### Step 6: Verify Connection

Back on the Cloud Providers page, you should now see:

```
┌─────────────────────────────────────┐
│ 🟢 AWS IAM (your-username)         │
│ Connected                           │
│ Region: us-east-1                   │
│                                     │
│ SSH Keys: 0/5                       │
│                                     │
│ [Deploy Key] [Refresh] [Disconnect] │
└─────────────────────────────────────┘
```

## Test Scenarios

### Test 1: List SSH Keys (Should Be Empty)

**Expected**: You should see "No SSH keys found" or an empty list

**If you see keys**: You might have existing SSH keys from previous testing

### Test 2: Deploy a New SSH Key

1. Click **Deploy Key** button
2. A dialog appears showing your local SSH keys
3. Select an SSH key (e.g., `~/.ssh/id_ed25519.pub`)
4. Click **Deploy**
5. Wait for deployment...
6. Success message: "Key deployed successfully"

**Verify**:
- Key count updates: "SSH Keys: 1/5"
- Key appears in the list with:
  - Key ID (APKA... format)
  - Status (Active)
  - Fingerprint (SHA256:...)
  - Upload date

### Test 3: Deploy Multiple Keys

Repeat Test 2 with different keys:
- id_rsa.pub
- id_ecdsa.pub
- id_ed25519.pub (if you have multiple)

**Expected**:
- Key count increments: 2/5, 3/5, etc.
- All keys appear in the list

### Test 4: Test 5-Key Limit

Try to deploy a 6th key when you have 5 deployed.

**Expected**:
- "Deploy Key" button becomes disabled (greyed out)
- Tooltip: "AWS limit reached (5 keys). Delete a key to upload new one."
- If you try anyway: Error message "AWS limit reached..."

### Test 5: Delete a Key

1. Right-click on a key in the list (or click the delete icon)
2. Confirm deletion
3. Wait for deletion...
4. Success message: "Key deleted successfully"

**Verify**:
- Key count decrements: "SSH Keys: 4/5"
- Key disappears from list
- "Deploy Key" button re-enables

### Test 6: Refresh Keys

1. Click **Refresh** button
2. Watch spinner...
3. Key list reloads

**Expected**: Same keys as before (no changes)

### Test 7: Disconnect and Reconnect

**Disconnect**:
1. Click **Disconnect** button
2. Confirm disconnection
3. AWS account card disappears or shows "Disconnected"

**Reconnect**:
1. Click **Connect** or **Configure Credentials**
2. Dialog appears (credentials still stored)
3. Click **Connect** again
4. Should reconnect without re-entering credentials

### Test 8: App Restart (Auto-Connect)

1. Close SSHer completely
2. Relaunch: `flatpak run io.github.tobagin.keysmith.Devel`
3. Navigate to Cloud Providers

**Expected**:
- AWS account automatically reconnects
- Shows: "Connected to AWS as your-username"
- Keys are listed
- No manual login required

### Test 9: Invalid Credentials

1. Disconnect from AWS
2. Add AWS account again
3. Enter **invalid** Access Key ID (e.g., "AKIA123456789INVALID")
4. Click **Connect**

**Expected**:
- Error message: "Invalid Access Key ID. Please check your credentials."
- OR "Invalid Access Key ID format. Must start with AKIA or ASIA."

### Test 10: Wrong Secret Key

1. Disconnect
2. Add AWS account
3. Enter correct Access Key ID
4. Enter **wrong** Secret Access Key
5. Click **Connect**

**Expected**:
- Error message: "Invalid Secret Access Key. Please check your credentials."
- OR "Invalid Secret Access Key length. Must be 40 characters."

### Test 11: Insufficient Permissions

This is harder to test, but if your IAM user lacks permissions:

**Expected**:
- Error message: "Access denied. Ensure your IAM user has the required permissions (iam:ListSSHPublicKeys, iam:UploadSSHPublicKey, iam:DeleteSSHPublicKey, iam:GetSSHPublicKey)."

### Test 12: Multi-Provider (GitHub + AWS)

1. Connect to GitHub (if you haven't)
2. Connect to AWS
3. Both should work simultaneously

**Expected**:
- Both providers show as connected
- Can deploy keys to both
- Can switch between them

## Verifying in AWS Console

You can verify SSHer's actions in the AWS Console:

1. Go to IAM Console: https://console.aws.amazon.com/iam/
2. Click **Users** → your test user
3. Click **Security credentials** tab
4. Scroll to **SSH keys for AWS CodeCommit**
5. You should see the keys you deployed from SSHer!

## Troubleshooting

### Problem: "Invalid Access Key ID format"
**Solution**: Ensure it starts with AKIA or ASIA and is 20 characters

### Problem: "Invalid Secret Access Key length"
**Solution**: Must be exactly 40 characters

### Problem: "Access denied"
**Solution**: Check your IAM policy matches the one in Step 2B

### Problem: "Connection timeout"
**Solution**: Check your internet connection and firewall

### Problem: Keys not showing in AWS Console
**Solution**:
- Refresh the AWS Console page
- Check the correct IAM user
- Look under "Security credentials" → "SSH keys for AWS CodeCommit"

### Problem: Can't deploy 5th key
**Solution**: AWS IAM has a hard limit of 5 SSH keys per user. Delete one to add another.

## Cleanup After Testing

When you're done testing:

1. **Delete Test Keys from AWS**:
   - In SSHer, delete all deployed keys
   - OR in AWS Console → IAM → User → Security credentials → Delete SSH keys

2. **Delete Access Key**:
   - AWS Console → IAM → User → Security credentials
   - Under "Access keys", click "Actions" → "Deactivate" or "Delete"

3. **Delete IAM User (Optional)**:
   - AWS Console → IAM → Users
   - Select the test user → Delete user

4. **Disconnect in SSHer**:
   - Click "Disconnect" on the AWS provider card

## Success Criteria

✅ The integration is working correctly if:

1. You can connect with valid credentials
2. Invalid credentials show appropriate errors
3. You can list SSH keys (empty or existing)
4. You can deploy new SSH keys
5. Deployed keys appear in AWS Console
6. You can delete SSH keys
7. Deleted keys disappear from AWS Console
8. The 5-key limit is enforced
9. Auto-reconnect works after app restart
10. Region selection is persisted

## Getting Help

If you encounter issues:

1. **Check Logs**:
   ```bash
   flatpak run io.github.tobagin.keysmith.Devel -v
   ```

2. **Check Files**:
   - Implementation notes: `AWS_INTEGRATION_STATUS.md`
   - Code: `src/backend/cloud/AWSProvider.vala`
   - Dialog: `src/ui/dialogs/AWSCredentialsDialog.vala`

3. **Common Issues**:
   - Credentials: Double-check copy-paste from AWS Console
   - Permissions: Verify IAM policy is attached
   - Network: Check firewall/proxy settings
   - Region: Try different regions if one fails

## Additional Testing (Advanced)

### Test Region Selection
- Try different regions (us-west-2, eu-west-1, etc.)
- Verify region is saved
- Check keys are accessible from all regions (IAM is global)

### Test Error Recovery
- Disconnect internet mid-operation
- Reconnect and retry
- Should show network error

### Test Concurrent Operations
- Deploy multiple keys quickly
- Should queue properly

## Reporting Issues

If you find bugs, please include:
- OS and version
- SSHer version
- AWS region
- Error message (exact text)
- Steps to reproduce
- Expected vs actual behavior
- Logs (with credentials redacted!)

---

**Happy Testing! 🧪**

This integration has been implemented and is ready for your validation. Please test thoroughly and report any issues you encounter.

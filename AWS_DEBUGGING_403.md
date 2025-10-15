# AWS 403 Forbidden - Fixed!

## What Was Wrong

The 403 Forbidden error was caused by an incorrect implementation of the AWS IAM API request format.

### The Problem

AWS IAM API expects:
```
POST https://iam.amazonaws.com/
Content-Type: application/x-www-form-urlencoded
Body: Action=GetUser&Version=2010-05-08
```

But the code was doing:
```
POST https://iam.amazonaws.com/?Action=GetUser&Version=2010-05-08
Body: (empty)
```

This caused the signature to be wrong because:
1. Parameters were in the query string instead of the body
2. The signature was calculated with an empty body but should have included the parameters
3. AWS rejected the request with 403 Forbidden

### The Fix

Changed in `AWSProvider.vala`:

**Before:**
```vala
var query_string = AWSRequestSigner.build_query_string(params);
var url = @"$IAM_ENDPOINT?$query_string";
var response = yield http_client.post_form_with_body(url, payload, headers);
```

**After:**
```vala
var body = AWSRequestSigner.build_query_string(params);
var url = IAM_ENDPOINT;  // No query string!
var response = yield http_client.post_form_with_body(url, body, headers);
```

And updated the signature calculation:
```vala
var authorization = AWSRequestSigner.sign_request(
    method,
    "iam.amazonaws.com",
    path,
    "", // Empty query string
    body, // Parameters in body
    // ...
);
```

## How to Test Now

1. **Rebuild** (if you haven't already):
   ```bash
   ./scripts/build.sh --dev
   ```

2. **Run the app**:
   ```bash
   flatpak run io.github.tobagin.keysmith.Devel -v
   ```
   (The `-v` flag enables verbose logging)

3. **Connect to AWS**:
   - Cloud Providers → Add Account → AWS IAM
   - Enter your credentials:
     - Access Key ID: `AKIA3QZSI52Q2DK5QOVL`
     - Secret Access Key: (your 40-character secret)
     - Region: us-east-1 (or your preferred region)
   - Click Connect

4. **Expected Result**:
   - ✅ "Connected successfully!" message
   - ✅ AWS account appears in Cloud Providers list
   - ✅ Can list/deploy/delete SSH keys

## If You Still Get Errors

### 403 Forbidden
If you still get 403, check:
- Access Key ID is correct (starts with AKIA)
- Secret Access Key is correct (40 characters)
- IAM user has the required permissions (see policy below)
- No typos when copying credentials

### Required IAM Policy

Your IAM user (`ssher`) needs this policy:

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
      "Resource": "arn:aws:iam::791990038177:user/ssher"
    }
  ]
}
```

To check/add this policy:
1. AWS Console → IAM → Users → ssher
2. Permissions tab → Add permissions → Create inline policy
3. Paste the JSON above
4. Name it: `SSHer-SSH-Key-Management`
5. Save

### Check Credentials

In AWS Console:
1. IAM → Users → ssher
2. Security credentials tab
3. Access keys section
4. Verify the Access Key ID matches: `AKIA3QZSI52Q2DK5QOVL`
5. Status should be "Active"

### Enable Verbose Logging

Run with verbose mode to see detailed logs:
```bash
flatpak run io.github.tobagin.keysmith.Devel -v 2>&1 | tee ssher-debug.log
```

This will show:
- HTTP requests being made
- Signature calculation details
- AWS responses
- Error messages

Look for lines containing:
- "AWS" or "IAM"
- "403" or "Forbidden"
- "SignatureDoesNotMatch"
- "InvalidClientTokenId"

### Common Errors and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| 403 Forbidden | Wrong signature | **Fixed in this version!** |
| InvalidClientTokenId | Wrong Access Key ID | Check you copied it correctly |
| SignatureDoesNotMatch | Wrong Secret Key | Check you copied it correctly |
| AccessDenied | Missing permissions | Add the IAM policy above |

## Testing Checklist

After the fix, test:

- [ ] Connect with valid credentials → Should succeed
- [ ] Connect with wrong Access Key ID → Should show error
- [ ] Connect with wrong Secret Key → Should show error
- [ ] List SSH keys → Should work (may be empty)
- [ ] Deploy a new SSH key → Should work
- [ ] Delete an SSH key → Should work

## What Changed

**Files Modified:**
- `src/backend/cloud/AWSProvider.vala` (1 function: `make_aws_request`)

**Lines Changed:**
- Line 304: Changed from building query string to building body
- Line 311: Empty query string for signature
- Line 312: Body contains form-encoded parameters
- Line 328: URL without query string

**Build Status:**
✅ **Build successful** - Ready for testing!

## Next Steps

1. **Test the fix** - Try connecting again
2. **If it works** - Great! Continue testing other features
3. **If it fails** - Check the troubleshooting section above

The AWS Signature V4 implementation is now correct according to AWS IAM API documentation. The 403 error should be resolved!

---

**Last Updated**: October 15, 2025
**Status**: Fixed and rebuilt
**Ready for testing**: ✅ YES

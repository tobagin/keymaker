# Design: GCP Integration

## Context

GCP uses Google OAuth 2.0 with OS Login API for SSH key management. OS Login centralizes SSH access across all GCP Compute Engine VMs.

## Goals / Non-Goals

### Goals
- Support GCP OS Login SSH key management
- OAuth via Google accounts
- GCP project selection

### Non-Goals
- GCP Compute Engine instance management
- GCP IAM role management
- Service account keys

## Decisions

### 1. OAuth via Google Identity

**Decision**: Use Google OAuth 2.0 with `https://www.googleapis.com/auth/cloud-platform` scope.

**Endpoints**:
- Authorize: `https://accounts.google.com/o/oauth2/v2/auth`
- Token: `https://oauth2.googleapis.com/token`
- API Base: `https://oslogin.googleapis.com/v1/`

### 2. OS Login API

**API Endpoints**:
- List: `GET /v1/users/{user}/sshPublicKeys`
- Upload: `POST /v1/users/{user}:importSshPublicKey`
- Delete: `DELETE /v1/users/{user}/sshPublicKeys/{fingerprint}`

### 3. GCP Project Handling

**Decision**: Prompt for project ID after OAuth (optional, used for billing/organization display).

## Risks / Trade-offs

### Risk: OAuth Scope Too Broad
**Mitigation**: `cloud-platform` scope is standard for GCP APIs. Document that it grants broad access.

### Risk: OS Login Not Enabled
**Mitigation**: Detect if OS Login API returns "not enabled" error and show setup instructions.

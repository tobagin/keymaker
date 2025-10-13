# Design: Azure DevOps Integration

## Context

Azure DevOps uses Microsoft identity platform OAuth 2.0 with unique characteristics:
- OAuth via Microsoft Account (MSA) or Azure Active Directory (AAD)
- API uses Visual Studio Team Services (VSTS) endpoints
- SSH key management via Personal Access Tokens API
- Organization-scoped access (dev.azure.com/{organization})

## Goals / Non-Goals

### Goals
- Support Azure DevOps SSH key management
- OAuth via Microsoft identity platform
- Organization selection support

### Non-Goals
- Azure Active Directory admin features
- Azure VM SSH key management (different from DevOps)
- On-premises Azure DevOps Server

## Decisions

### 1. OAuth via Microsoft Identity Platform

**Decision**: Use Microsoft identity platform OAuth 2.0 with `vso.profile` and `vso.tokens` scopes.

**Endpoints**:
- Authorize: `https://login.microsoftonline.com/common/oauth2/v2.0/authorize`
- Token: `https://login.microsoftonline.com/common/oauth2/v2.0/token`
- API Base: `https://app.vssps.visualstudio.com/_apis/`

**Scopes**: `vso.profile vso.tokens` (read profile + manage tokens)

### 2. Azure DevOps Organization Handling

**Decision**: Prompt user for organization name after OAuth.

**Rationale**: Users can belong to multiple Azure DevOps organizations. Store primary organization in GSettings.

### 3. SSH Key API

**API Endpoints**:
- List: `GET https://app.vssps.visualstudio.com/_apis/Tokens/SessionTokens?api-version=7.0`
- Create: `POST https://app.vssps.visualstudio.com/_apis/Tokens/SessionTokens?api-version=7.0`
- Delete: `DELETE https://app.vssps.visualstudio.com/_apis/Tokens/SessionTokens/{tokenId}?api-version=7.0`

## Risks / Trade-offs

### Risk: Complex OAuth Flow
**Mitigation**: Microsoft OAuth is well-documented. Reuse GitHub OAuth pattern.

### Risk: Organization Discovery
**Mitigation**: Call `/organizations` API after auth to list user's organizations. Let user select primary org.

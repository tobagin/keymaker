# Design Document: Phase 1 File Naming Standardization

## Context

KeyMaker is a Vala/GTK4 application for SSH key management. The codebase has grown to ~75 Vala files with inconsistent naming conventions inherited from early development. The current `kebab-case.vala` naming violates Vala community standards and creates friction for contributors familiar with standard Vala projects.

This is Phase 1 of a multi-phase refactoring effort documented in [REFACTORING-PLAN.md](../../../REFACTORING-PLAN.md). It serves as the foundation for subsequent phases (completing features, removing legacy code, consolidating subprocess calls, etc.).

### Stakeholders
- **Primary**: Current and future contributors
- **Secondary**: Build system maintainers
- **Affected**: All developers with open branches

### Current State
- ~75 Vala files use `kebab-case.vala` (non-standard)
- ~40 Blueprint files use `snake_case.blp` (correct, no changes)
- 5 main organizational files sit in parent directories instead of subdirectories
- Meson build files reference old names

## Goals / Non-Goals

### Goals
1. **Standardize Vala naming**: All `.vala` files use `PascalCase.vala` matching class names
2. **Preserve git history**: Use `git mv` for all renames so `git log --follow` works
3. **Maintain functionality**: Zero behavior changes, only file renames
4. **Update build system**: All meson.build files reference new names
5. **Improve organization**: Move main files into their subdirectories
6. **Foundation for future work**: Enable remaining refactoring phases

### Non-Goals
- Changing code logic or behavior
- Modifying Blueprint files (already correct)
- Renaming classes or namespaces
- Changing directory structure (folders already correct)
- Updating documentation beyond naming conventions
- Modifying git hooks or CI configuration

## Decisions

### Decision 1: Use PascalCase for Vala Files
**Rationale**: This is the standard Vala community convention (Granite, elementary OS, GNOME projects all use this). It matches the class names inside files, making navigation intuitive.

**Alternatives Considered**:
- Keep `kebab-case`: Rejected - non-standard, confusing for contributors
- Use `camelCase`: Rejected - even less common in Vala ecosystem
- Mixed approach: Rejected - consistency is key

**Impact**: Positive developer experience, aligns with ecosystem expectations.

### Decision 2: Single Automated Script
**Rationale**: Manual renames are error-prone. A script ensures consistency, completeness, and can be reviewed/tested before execution.

**Alternatives Considered**:
- Manual renames: Rejected - high risk of mistakes, time-consuming
- IDE refactoring tools: Rejected - may not preserve git history correctly
- Gradual migration: Rejected - creates temporary inconsistency

**Implementation**:
```bash
#!/bin/bash
set -e  # Exit on any error
# Use git mv for each file to preserve history
git mv src/old-name.vala src/NewName.vala
```

### Decision 3: Move Main Files into Subdirectories
**Rationale**: Files like `ssh-operations.vala` coordinate submodules in `ssh_operations/` but sit in parent directory. Moving them improves logical organization.

**Files Affected**:
- `backend/ssh-operations.vala` → `backend/ssh_operations/SshOperations.vala`
- `backend/key-rotation.vala` → `backend/rotation/KeyRotation.vala`
- `backend/ssh-tunneling.vala` → `backend/tunneling/SshTunneling.vala`
- `backend/emergency-vault.vala` → `backend/vault/EmergencyVault.vala`
- `backend/connection-diagnostics.vala` → `backend/diagnostics/ConnectionDiagnostics.vala`

**Alternatives Considered**:
- Keep in parent: Rejected - creates organizational confusion
- Create new `main/` directory: Rejected - over-engineered

### Decision 4: Blueprint Files Unchanged
**Rationale**: Blueprint files already use correct `snake_case.blp` convention. Changing them would break GTK's builder integration with no benefit.

**Evidence**: GTK documentation recommends `snake_case` for UI files. All GNOME projects follow this.

### Decision 5: Single Atomic Commit
**Rationale**: All renames + meson.build updates in one commit prevents intermediate broken states and simplifies git history.

**Commit Message Format**:
```
refactor: Rename all Vala files to PascalCase convention

- Renamed ~75 Vala files from kebab-case to PascalCase
- Moved main organizational files into subdirectories
- Updated all meson.build files to reference new names
- Blueprint files remain unchanged (already correct snake_case)
- Git history preserved using git mv

Phase 1 of comprehensive refactoring plan.
Establishes foundation for future refactoring phases.
```

**Alternatives Considered**:
- Multiple commits (per directory): Rejected - creates many broken intermediate states
- Separate commits (renames vs meson): Rejected - breaks builds between commits

## Risks / Trade-offs

### Risk 1: Merge Conflicts for Open PRs
**Severity**: MEDIUM
**Likelihood**: HIGH
**Mitigation**:
- Announce change in advance with timeline
- Complete quickly (1-2 days from start to merge)
- Provide rebase instructions for affected developers
- Consider rebasing open PRs proactively

**Rebase Instructions for Affected PRs**:
```bash
git fetch origin
git rebase origin/main
# Resolve any conflicts using new filenames
# IDE may show "file deleted + file added" - treat as rename
```

### Risk 2: Build System Updates Incomplete
**Severity**: HIGH (breaks builds)
**Likelihood**: LOW (mitigated by testing)
**Mitigation**:
- Comprehensive script review before execution
- Test development build immediately after
- Test production build before pushing
- Verify clean build from scratch works

**Detection**: Build errors will be immediate and obvious during testing phase.

### Risk 3: Git History Navigation
**Severity**: LOW
**Likelihood**: LOW
**Mitigation**:
- Always use `git mv` (preserves history)
- Document that `git log --follow <file>` shows full history
- Test history preservation on sample file before bulk operation

**Verification**:
```bash
# After renames, verify history preserved:
git log --follow src/backend/KeyScanner.vala
# Should show commits from when it was key-scanner.vala
```

### Risk 4: IDE/Editor Confusion
**Severity**: LOW
**Likelihood**: MEDIUM
**Mitigation**:
- Most modern IDEs handle git renames correctly
- Close and reopen project after pulling changes
- Clear any cached indexes (varies by IDE)

**VSCode**: Usually handles automatically
**GNOME Builder**: Restart project after pull
**vim/emacs**: May need to close and reopen files

### Trade-off: Temporary Disruption vs Long-term Benefit
**Accept**: Short-term disruption (1-2 days of potential conflicts)
**Gain**: Long-term consistency, easier onboarding, ecosystem alignment

This is a necessary foundation change that gets harder to do as project grows. Doing it now (after Phase 0 completion) is optimal timing.

## Migration Plan

### Phase 1: Preparation (30 minutes)
1. Announce change in project chat/discussion
2. Identify all open PRs and notify owners
3. Create feature branch `refactor/phase-1-naming`
4. Document current state (file count, directory structure)

### Phase 2: Script Creation (1 hour)
1. Create `scripts/rename_vala_files.sh`
2. Add all git mv commands organized by directory
3. Review script completeness against file list
4. Test script on single directory first
5. Make script executable and commit it

### Phase 3: Execution (30 minutes)
1. Run script and verify output
2. Check git status shows expected renames
3. Review sample of renamed files
4. Update all meson.build files
5. Stage all changes

### Phase 4: Testing (1 hour)
1. Clean build artifacts: `rm -rf _build/ _inst/`
2. Run development build: `./scripts/build.sh --dev`
3. Fix any build errors
4. Launch and test application
5. Run production build: `./scripts/build.sh`
6. Verify both builds succeed

### Phase 5: Commit & Push (15 minutes)
1. Review all staged changes
2. Commit with descriptive message
3. Push branch to remote
4. Create draft PR for review

### Phase 6: Merge (24 hours)
1. Request review from maintainers
2. Address any feedback
3. Get approval
4. Merge to main
5. Delete feature branch

### Phase 7: Post-Merge Support (ongoing)
1. Notify affected PR owners to rebase
2. Assist with any rebase conflicts
3. Update any documentation referencing old names
4. Monitor for issues in next 48 hours

### Rollback Plan
If critical issues discovered post-merge:

```bash
# Option 1: Revert the commit (preserves history)
git revert <commit-hash>

# Option 2: Hard reset (only if no one has pulled)
git reset --hard <commit-before-rename>
git push --force

# Option 3: Forward fix (preferred if issues are localized)
# Fix specific issues and commit fixes
```

**Criteria for Rollback**:
- Build completely broken and unfixable within 2 hours
- Data loss or corruption detected
- Multiple critical bugs introduced

**Note**: Rollback unlikely needed since changes are purely structural.

## Open Questions

### Q1: Should we rename in multiple smaller PRs?
**Answer**: No. Single atomic PR prevents broken intermediate states and simplifies review. The change is mechanical and low-risk.

### Q2: Do we need to update string literals in code?
**Answer**: No. String literals (e.g., error messages) don't reference filenames. Only meson.build files need updates.

### Q3: What about files in data/, po/, build-aux/?
**Answer**: Out of scope. This phase only touches `src/**/*.vala` files. Blueprint files in `data/ui/` are already correct.

### Q4: Should we lint for naming compliance going forward?
**Answer**: Future enhancement. Consider adding to Phase 4 or later. Could use pre-commit hook or CI check.

### Q5: Will this affect translations (gettext)?
**Answer**: No. Translation keys are class/UI element based, not filename based. .pot files regenerate correctly.

## Success Metrics

### Immediate (within 1 day)
- [ ] All 75+ Vala files renamed to PascalCase
- [ ] Development build succeeds
- [ ] Production build succeeds
- [ ] Application launches and runs correctly
- [ ] No console errors or warnings

### Short-term (within 1 week)
- [ ] All open PRs rebased successfully
- [ ] No regression bugs reported
- [ ] Git history preserved (verified with `--follow`)
- [ ] New contributors report improved clarity

### Long-term (within 1 month)
- [ ] Remaining refactoring phases unblocked
- [ ] Contributing documentation updated
- [ ] No naming inconsistencies introduced

## References

- [REFACTORING-PLAN.md](../../../REFACTORING-PLAN.md) - Complete refactoring plan
- [Vala Naming Conventions](https://wiki.gnome.org/Projects/Vala/Tutorial#Naming_Conventions)
- [GNOME Guidelines](https://developer.gnome.org/documentation/guidelines/programming/coding-style.html)
- [Git mv Documentation](https://git-scm.com/docs/git-mv)

## Approval Checklist

Before implementation:
- [ ] Proposal reviewed by maintainers
- [ ] Design approved
- [ ] Timeline communicated to contributors
- [ ] Open PRs identified and owners notified
- [ ] Script reviewed for completeness
- [ ] Testing plan agreed upon

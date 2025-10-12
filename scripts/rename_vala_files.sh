#!/bin/bash
# Phase 1 Refactoring: Rename all Vala files to PascalCase convention
# This script uses git mv to preserve file history

set -e  # Exit on any error

echo "===== Phase 1: File Naming Standardization ====="
echo "Starting Vala file renames using git mv..."
echo ""

# Track rename count
RENAME_COUNT=0

# Root level
echo "[1/9] Renaming root level files..."
git mv src/application.vala src/Application.vala
git mv src/main.vala src/Main.vala
RENAME_COUNT=$((RENAME_COUNT + 2))

# Models (4 files)
echo "[2/9] Renaming models/ files..."
git mv src/models/enums.vala src/models/Enums.vala
git mv src/models/key-service-mapping.vala src/models/KeyServiceMapping.vala
git mv src/models/page-models.vala src/models/PageModels.vala
git mv src/models/ssh-key.vala src/models/SshKey.vala
RENAME_COUNT=$((RENAME_COUNT + 4))

# Backend root (12 files, excluding main coordinator files that will move)
echo "[3/9] Renaming backend/ root files..."
git mv src/backend/backup-manager.vala src/backend/BackupManager.vala
git mv src/backend/diagnostic-history.vala src/backend/DiagnosticHistory.vala
git mv src/backend/emergency-vault-old.vala src/backend/EmergencyVaultOld.vala
git mv src/backend/key-scanner.vala src/backend/KeyScanner.vala
git mv src/backend/key-selection-manager.vala src/backend/KeySelectionManager.vala
git mv src/backend/ssh-agent.vala src/backend/SshAgent.vala
git mv src/backend/ssh-config.vala src/backend/SshConfig.vala
git mv src/backend/totp-manager.vala src/backend/TotpManager.vala
RENAME_COUNT=$((RENAME_COUNT + 8))

# Backend/ssh_operations subdirectory (create if needed, move + rename 4 files)
echo "[4/9] Moving and renaming backend/ssh_operations/ files..."
if [ ! -d "src/backend/ssh_operations" ]; then
    mkdir -p src/backend/ssh_operations
fi
git mv src/backend/ssh-operations.vala src/backend/ssh_operations/SshOperations.vala
git mv src/backend/ssh-operations/generation.vala src/backend/ssh_operations/Generation.vala
git mv src/backend/ssh-operations/metadata.vala src/backend/ssh_operations/Metadata.vala
git mv src/backend/ssh-operations/mutate.vala src/backend/ssh_operations/Mutate.vala
# Remove old directory if empty
if [ -d "src/backend/ssh-operations" ] && [ -z "$(ls -A src/backend/ssh-operations)" ]; then
    rmdir src/backend/ssh-operations
fi
RENAME_COUNT=$((RENAME_COUNT + 4))

# Backend/rotation subdirectory (move main + rename 6 files)
echo "[5/9] Moving and renaming backend/rotation/ files..."
git mv src/backend/key-rotation.vala src/backend/rotation/KeyRotation.vala
git mv src/backend/rotation/deploy.vala src/backend/rotation/Deploy.vala
git mv src/backend/rotation/plan-manager.vala src/backend/rotation/PlanManager.vala
git mv src/backend/rotation/plan.vala src/backend/rotation/Plan.vala
git mv src/backend/rotation/rollback.vala src/backend/rotation/Rollback.vala
git mv src/backend/rotation/runner.vala src/backend/rotation/Runner.vala
RENAME_COUNT=$((RENAME_COUNT + 6))

# Backend/tunneling subdirectory (move main + rename 4 files)
echo "[6/9] Moving and renaming backend/tunneling/ files..."
git mv src/backend/ssh-tunneling.vala src/backend/tunneling/SshTunneling.vala
git mv src/backend/tunneling/active-tunnel.vala src/backend/tunneling/ActiveTunnel.vala
git mv src/backend/tunneling/configuration.vala src/backend/tunneling/Configuration.vala
git mv src/backend/tunneling/manager.vala src/backend/tunneling/Manager.vala
RENAME_COUNT=$((RENAME_COUNT + 4))

# Backend/vault subdirectory (move main + rename 3 files)
echo "[7/9] Moving and renaming backend/vault/ files..."
git mv src/backend/emergency-vault.vala src/backend/vault/EmergencyVault.vala
git mv src/backend/vault/backup-entry.vala src/backend/vault/BackupEntry.vala
git mv src/backend/vault/vault-io.vala src/backend/vault/VaultIo.vala
RENAME_COUNT=$((RENAME_COUNT + 3))

# Backend/diagnostics subdirectory (move main + rename 1 file)
echo "[8/9] Moving and renaming backend/diagnostics/ files..."
if [ ! -d "src/backend/diagnostics" ]; then
    mkdir -p src/backend/diagnostics
fi
git mv src/backend/connection-diagnostics.vala src/backend/diagnostics/ConnectionDiagnostics.vala
RENAME_COUNT=$((RENAME_COUNT + 1))

# UI directory (3 root + 6 pages + 1 action + 32 dialogs + 2 widgets = 44 files)
echo "[9/9] Renaming ui/ files..."

# UI root (3 files)
git mv src/ui/key-list.vala src/ui/KeyList.vala
git mv src/ui/key-row.vala src/ui/KeyRow.vala
git mv src/ui/rotation-plan-actions.vala src/ui/RotationPlanActions.vala
git mv src/ui/window.vala src/ui/Window.vala
RENAME_COUNT=$((RENAME_COUNT + 4))

# UI/pages (6 files)
git mv src/ui/pages/backup-page.vala src/ui/pages/BackupPage.vala
git mv src/ui/pages/diagnostics-page.vala src/ui/pages/DiagnosticsPage.vala
git mv src/ui/pages/hosts-page.vala src/ui/pages/HostsPage.vala
git mv src/ui/pages/keys-page.vala src/ui/pages/KeysPage.vala
git mv src/ui/pages/rotation-page.vala src/ui/pages/RotationPage.vala
git mv src/ui/pages/tunnels-page.vala src/ui/pages/TunnelsPage.vala
RENAME_COUNT=$((RENAME_COUNT + 6))

# UI/widgets (1 file - note: rotation-plan-rows.vala)
git mv src/ui/widgets/rotation-plan-rows.vala src/ui/widgets/RotationPlanRows.vala
RENAME_COUNT=$((RENAME_COUNT + 1))

# UI/dialogs (32 files)
git mv src/ui/dialogs/about-dialog.vala src/ui/dialogs/AboutDialog.vala
git mv src/ui/dialogs/add-key-to-agent-dialog.vala src/ui/dialogs/AddKeyToAgentDialog.vala
git mv src/ui/dialogs/add-target-dialog.vala src/ui/dialogs/AddTargetDialog.vala
git mv src/ui/dialogs/backup-center-dialog.vala src/ui/dialogs/BackupCenterDialog.vala
git mv src/ui/dialogs/change-passphrase-dialog.vala src/ui/dialogs/ChangePassphraseDialog.vala
git mv src/ui/dialogs/connection-diagnostics-dialog.vala src/ui/dialogs/ConnectionDiagnosticsDialog.vala
git mv src/ui/dialogs/connection-diagnostics-runner-dialog.vala src/ui/dialogs/ConnectionDiagnosticsRunnerDialog.vala
git mv src/ui/dialogs/connection-test-dialog.vala src/ui/dialogs/ConnectionTestDialog.vala
git mv src/ui/dialogs/copy-id-dialog.vala src/ui/dialogs/CopyIdDialog.vala
git mv src/ui/dialogs/create-backup-dialog.vala src/ui/dialogs/CreateBackupDialog.vala
git mv src/ui/dialogs/create-tunnel-dialog.vala src/ui/dialogs/CreateTunnelDialog.vala
git mv src/ui/dialogs/delete-key-dialog.vala src/ui/dialogs/DeleteKeyDialog.vala
git mv src/ui/dialogs/diagnostic-configuration-dialog.vala src/ui/dialogs/DiagnosticConfigurationDialog.vala
git mv src/ui/dialogs/diagnostic-html-report-dialog.vala src/ui/dialogs/DiagnosticHtmlReportDialog.vala
git mv src/ui/dialogs/diagnostic-results-view-dialog.vala src/ui/dialogs/DiagnosticResultsViewDialog.vala
git mv src/ui/dialogs/diagnostic-type-selection-dialog.vala src/ui/dialogs/DiagnosticTypeSelectionDialog.vala
git mv src/ui/dialogs/emergency-vault-dialog.vala src/ui/dialogs/EmergencyVaultDialog.vala
git mv src/ui/dialogs/generate-dialog.vala src/ui/dialogs/GenerateDialog.vala
git mv src/ui/dialogs/help-dialog.vala src/ui/dialogs/HelpDialog.vala
git mv src/ui/dialogs/key-details-dialog.vala src/ui/dialogs/KeyDetailsDialog.vala
git mv src/ui/dialogs/key-rotation-dialog-old.vala src/ui/dialogs/KeyRotationDialogOld.vala
git mv src/ui/dialogs/key-rotation-dialog.vala src/ui/dialogs/KeyRotationDialog.vala
git mv src/ui/dialogs/key-service-mapping-dialog.vala src/ui/dialogs/KeyServiceMappingDialog.vala
git mv src/ui/dialogs/plan-details-dialog.vala src/ui/dialogs/PlanDetailsDialog.vala
git mv src/ui/dialogs/preferences-dialog.vala src/ui/dialogs/PreferencesDialog.vala
git mv src/ui/dialogs/restore-backup-dialog.vala src/ui/dialogs/RestoreBackupDialog.vala
git mv src/ui/dialogs/rotation-plan-editor-dialog.vala src/ui/dialogs/RotationPlanEditorDialog.vala
git mv src/ui/dialogs/shortcuts-dialog.vala src/ui/dialogs/ShortcutsDialog.vala
git mv src/ui/dialogs/ssh-agent-dialog.vala src/ui/dialogs/SshAgentDialog.vala
git mv src/ui/dialogs/ssh-config-dialog.vala src/ui/dialogs/SshConfigDialog.vala
git mv src/ui/dialogs/ssh-host-edit-dialog.vala src/ui/dialogs/SshHostEditDialog.vala
git mv src/ui/dialogs/ssh-tunneling-dialog.vala src/ui/dialogs/SshTunnelingDialog.vala
git mv src/ui/dialogs/terminal-dialog.vala src/ui/dialogs/TerminalDialog.vala
RENAME_COUNT=$((RENAME_COUNT + 33))

# Utils (7 files)
echo "Renaming utils/ files..."
git mv src/utils/async-queue.vala src/utils/AsyncQueue.vala
git mv src/utils/batch-processor.vala src/utils/BatchProcessor.vala
git mv src/utils/command.vala src/utils/Command.vala
git mv src/utils/connection-pool.vala src/utils/ConnectionPool.vala
git mv src/utils/filesystem.vala src/utils/Filesystem.vala
git mv src/utils/log.vala src/utils/Log.vala
git mv src/utils/settings.vala src/utils/Settings.vala
RENAME_COUNT=$((RENAME_COUNT + 7))

echo ""
echo "===== Rename Summary ====="
echo "Total files renamed: $RENAME_COUNT"
echo "Expected: ~83 files"
echo ""
echo "All renames completed successfully!"
echo "Next step: Update meson.build files to reference new names"

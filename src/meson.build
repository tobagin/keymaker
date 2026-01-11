# Source files
sources = files(
    'Main.vala',
    'Application.vala',
    'models/Enums.vala',
    'models/SshKey.vala',
    'models/KeyServiceMapping.vala',
    'models/PageModels.vala',
    'models/KnownHostEntry.vala',
    'backend/ssh_operations/SshOperations.vala',
    'backend/ssh_operations/Generation.vala',
    'backend/ssh_operations/Metadata.vala',
    'backend/ssh_operations/Mutate.vala',
    'backend/KeyScanner.vala',
    'backend/SshAgent.vala',
    'backend/SshConfig.vala',
    'backend/KeySelectionManager.vala',
    'backend/KnownHostsManager.vala',

    'ui/Window.vala',
    'ui/pages/KeysPage.vala',
    'ui/pages/HostsPage.vala',
    'ui/pages/KnownHostsPage.vala',

    'ui/pages/BackupPage.vala',

    'ui/KeyList.vala',
    'ui/KeyRow.vala',
    'ui/dialogs/GenerateDialog.vala',
    'ui/dialogs/KeyDetailsDialog.vala',
    'ui/dialogs/ChangePassphraseDialog.vala',
    'ui/dialogs/CopyIdDialog.vala',
    'ui/dialogs/DeleteKeyDialog.vala',
    'ui/dialogs/PreferencesDialog.vala',
    'ui/dialogs/HelpDialog.vala',
    'ui/dialogs/AboutDialog.vala',
    'ui/dialogs/ShortcutsDialog.vala',
    'ui/dialogs/SshAgentDialog.vala',
    'ui/dialogs/AddKeyToAgentDialog.vala',
    'ui/dialogs/KeyServiceMappingDialog.vala',
    'ui/dialogs/SshConfigDialog.vala',
    'ui/dialogs/SshHostEditDialog.vala',
    'ui/dialogs/TerminalDialog.vala',
    'ui/dialogs/HostKeyVerificationDialog.vala',
    'ui/dialogs/HostKeyConflictDialog.vala',



    'backend/BackupManager.vala',
    'backend/TotpManager.vala',
    'backend/vault/EmergencyVault.vala',
    'backend/vault/BackupEntry.vala',
    'backend/vault/VaultIo.vala',
    'ui/dialogs/EmergencyVaultDialog.vala',
    'ui/dialogs/BackupCenterDialog.vala',
    'ui/dialogs/CreateBackupDialog.vala',
    'ui/dialogs/RestoreBackupDialog.vala',
    'ui/dialogs/BackupDetailsDialog.vala',
    'ui/dialogs/EmergencyBackupDetailsDialog.vala',
    'ui/dialogs/EmergencyBackupAuthDialog.vala',

    'ui/helpers/BackupHelpers.vala',
    'utils/Filesystem.vala',
    'utils/Command.vala',
    'utils/Log.vala',
    'utils/Settings.vala',
    'utils/ConnectionPool.vala',
    'utils/BatchProcessor.vala',
    'utils/AsyncQueue.vala',
)

dependencies_list = [
    gtk_dep,
    adw_dep,
    gio_dep,
    gee_dep,
    json_dep,
    vte_dep,
    math_dep,
    soup_dep,
    secret_dep,
]

if webkit_dep.found()
    dependencies_list += [webkit_dep]
endif

# Build executable
executable(
    'keymaker',
    sources,
    config_vala,
    ui_resources,
    dependencies: dependencies_list,
    vala_args: vala_args,
    c_args: c_args,
    install: true,
    install_dir: get_option('bindir')
)

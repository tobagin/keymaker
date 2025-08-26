# Source files
sources = files(
    'main.vala',
    'application.vala',
    'models/enums.vala',
    'models/ssh-key.vala',
    'backend/ssh-operations.vala',
    'backend/key-scanner.vala',
    'ui/window.vala',
    'ui/key-list.vala',
    'ui/key-row.vala',
    'ui/dialogs/generate-dialog.vala',
    'ui/dialogs/key-details-dialog.vala',
    'ui/dialogs/change-passphrase-dialog.vala',
    'ui/dialogs/copy-id-dialog.vala',
    'ui/dialogs/delete-key-dialog.vala',
    'ui/dialogs/preferences-dialog.vala',
    'ui/dialogs/help-dialog.vala',
    'ui/dialogs/about-dialog.vala',
    'ui/dialogs/shortcuts-dialog.vala',
)

# Build executable
executable(
    'keymaker',
    sources,
    config_vala,
    ui_resources,
    dependencies: [
        gtk_dep,
        adw_dep,
        gio_dep,
    ],
    vala_args: vala_args,
    c_args: c_args,
    install: true,
    install_dir: get_option('bindir')
)
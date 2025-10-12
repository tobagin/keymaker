# Blueprint compiler
blueprint_compiler = find_program('blueprint-compiler', required: true)

# Try to find girepository path
girepository_paths = [
  '/usr/lib/x86_64-linux-gnu/girepository-1.0',
  '/usr/lib64/girepository-1.0',
  '/usr/lib/girepository-1.0',
  '/usr/local/lib/girepository-1.0'
]

typelib_path = ''
foreach path : girepository_paths
  if run_command('test', '-d', path, check: false).returncode() == 0
    typelib_path = path
    break
  endif
endforeach

# Compile blueprints
blueprints = []

# Prepare blueprint compiler command
blueprint_cmd = [
  blueprint_compiler,
  'compile',
  '--output', '@OUTPUT@'
]

# Add typelib-path if found
if typelib_path != ''
  blueprint_cmd += ['--typelib-path', typelib_path]
endif

blueprint_cmd += ['@INPUT@']

# Compile window.blp
window_ui = custom_target(
    'window.ui',
    input: files('window.blp'),
    output: 'window.ui',
    command: blueprint_cmd
)
blueprints += window_ui

# Compile other UI files
ui_files = [
  # Widgets
  'widgets/key_list.blp',
  'widgets/key_row.blp',

  # Dialogs
  'dialogs/add_key_to_agent_dialog.blp',
  'dialogs/add_target_dialog.blp',
  'dialogs/backup_center_dialog.blp',
  'dialogs/change_passphrase_dialog.blp',
  'dialogs/connection_diagnostics_dialog.blp',
  'dialogs/connection_diagnostics_runner_dialog.blp',
  'dialogs/connection_test_dialog.blp',
  'dialogs/copy_id_dialog.blp',
  'dialogs/create_backup_dialog.blp',
  'dialogs/create_tunnel_dialog.blp',
  'dialogs/diagnostic_configuration_dialog.blp',
  'dialogs/diagnostic_html_report_dialog.blp',
  'dialogs/diagnostic_results_view_dialog.blp',
  'dialogs/diagnostic_type_selection_dialog.blp',
  'dialogs/emergency_vault_dialog.blp',
  'dialogs/generate_dialog.blp',
  'dialogs/key_details_dialog.blp',
  'dialogs/key_rotation_dialog.blp',
  'dialogs/key_service_mapping_dialog.blp',
  'dialogs/plan_details_dialog.blp',
  'dialogs/preferences_dialog.blp',
  'dialogs/restore_backup_dialog.blp',
  'dialogs/rotation_plan_editor_dialog.blp',
  'dialogs/shortcuts_dialog.blp',
  'dialogs/ssh_agent_dialog.blp',
  'dialogs/ssh_config_dialog.blp',
  'dialogs/ssh_host_edit_dialog.blp',
  'dialogs/ssh_tunneling_dialog.blp',
  'dialogs/terminal_dialog.blp',

  # Pages
  'pages/backup_page.blp',
  'pages/diagnostics_page.blp',
  'pages/hosts_page.blp',
  'pages/keys_page.blp',
  'pages/rotation_page.blp',
  'pages/tunnels_page.blp',
]

foreach ui_file : ui_files
  # Extract just the filename without path for output
  # Split by '/' and take the last element
  ui_parts = ui_file.split('/')
  ui_basename = ui_parts[ui_parts.length() - 1]
  ui_name = ui_basename.replace('.blp', '.ui')

  compiled_ui = custom_target(
    ui_name,
    input: ui_file,
    output: ui_name,
    command: blueprint_cmd
  )

  blueprints += compiled_ui
endforeach

# Configure gresource template
gresource_xml = configure_file(
    input: '../keysmith.gresource.xml.in',
    output: 'keysmith.gresource.xml',
    configuration: conf_data
)

# Generate resources
ui_resources = gnome.compile_resources(
    'keysmith-resources',
    gresource_xml,
    source_dir: [meson.current_build_dir(), 'data'],
    dependencies: blueprints,
    c_name: 'keysmith'
)

# Make ui_resources available to parent directories
set_variable('ui_resources', ui_resources)
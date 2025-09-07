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
  'key_list.blp',
  'key_row.blp',
  'generate_dialog.blp',
  'copy_id_dialog.blp',
  'change_passphrase_dialog.blp',
  'key_details_dialog.blp',
  'preferences_dialog.blp',
  'shortcuts_dialog.blp',
  'ssh_agent_dialog.blp',
  'add_key_to_agent_dialog.blp',
  'key_service_mapping_dialog.blp',
  'ssh_config_dialog.blp',
  'ssh_host_edit_dialog.blp',
  'terminal_dialog.blp',
  'connection_test_dialog.blp',
  'connection_diagnostics_dialog.blp',
  'connection_diagnostics_runner_dialog.blp',
  'key_rotation_dialog.blp',
  'rotation_plan_editor_dialog.blp',
  'add_target_dialog.blp',
  'plan_details_dialog.blp',
  'emergency_vault_dialog.blp',
  'create_backup_dialog.blp',
  'restore_backup_dialog.blp',
  'ssh_tunneling_dialog.blp',
  'create_tunnel_dialog.blp',
  'diagnostic_results_view_dialog.blp',
]

foreach ui_file : ui_files
  ui_name = ui_file.replace('.blp', '.ui')
  
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
    input: 'keysmith.gresource.xml.in',
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
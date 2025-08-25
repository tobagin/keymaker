# Find blueprint compiler
blueprint_compiler = find_program('blueprint-compiler', required: true)

# Blueprint UI files
ui_files = [
  'window.blp',
  'generate_dialog.blp',
  'key_list.blp',
  'key_row.blp',
  'change_passphrase_dialog.blp',
  'copy_id_dialog.blp',
  'key_details_dialog.blp',
  'preferences_dialog.blp',
]

# Compile Blueprint files to UI files
compiled_ui_files = []
foreach ui_file : ui_files
  # Convert .blp to .ui
  ui_name = ui_file.replace('.blp', '.ui')
  
  compiled_ui = custom_target(
    ui_name,
    input: ui_file,
    output: ui_name,
    command: [blueprint_compiler, 'compile', '--output', '@OUTPUT@', '@INPUT@'],
  )
  
  compiled_ui_files += compiled_ui
endforeach

# Create a dependency for the compiled UI files
ui_resources = gnome.compile_resources(
  'keymaker-ui',
  'keymaker.gresource.xml',
  dependencies: compiled_ui_files,
  source_dir: meson.current_build_dir(),
  install: true,
  install_dir: get_option('datadir') / 'keymaker',
  gresource_bundle: true
)
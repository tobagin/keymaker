# Blueprint compiler
blueprint_compiler = find_program('blueprint-compiler', required: true)

# Compile blueprints
blueprints = []

# Compile window.blp
window_ui = custom_target(
    'window.ui',
    input: files('window.blp'),
    output: 'window.ui',
    command: [
        blueprint_compiler,
        'compile',
        '--output', '@OUTPUT@',
        '--typelib-path', '/usr/lib/x86_64-linux-gnu/girepository-1.0',
        '@INPUT@'
    ]
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
]

foreach ui_file : ui_files
  ui_name = ui_file.replace('.blp', '.ui')
  
  compiled_ui = custom_target(
    ui_name,
    input: ui_file,
    output: ui_name,
    command: [
        blueprint_compiler,
        'compile',
        '--output', '@OUTPUT@',
        '--typelib-path', '/usr/lib/x86_64-linux-gnu/girepository-1.0',
        '@INPUT@'
    ],
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
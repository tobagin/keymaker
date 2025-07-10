# Desktop file
desktop_file = i18n.merge_file(
  input: 'io.github.tobagin.keysmith.desktop.in',
  output: 'io.github.tobagin.keysmith.desktop',
  type: 'desktop',
  po_dir: '../po',
  install: true,
  install_dir: get_option('datadir') / 'applications'
)

# Validate desktop file
desktop_utils = find_program('desktop-file-validate', required: false)
if desktop_utils.found()
  test('Validate desktop file', desktop_utils,
    args: [desktop_file]
  )
endif

# AppStream metadata
appstream_file = i18n.merge_file(
  input: 'io.github.tobagin.keysmith.metainfo.xml.in',
  output: 'io.github.tobagin.keysmith.metainfo.xml',
  po_dir: '../po',
  install: true,
  install_dir: get_option('datadir') / 'metainfo'
)

# Validate appstream file
appstream_util = find_program('appstream-util', required: false)
if appstream_util.found()
  test('Validate appstream file', appstream_util,
    args: ['validate', appstream_file]
  )
endif

# GSettings schema
gsettings_schema = configure_file(
  input: 'io.github.tobagin.keysmith.gschema.xml',
  output: 'io.github.tobagin.keysmith.gschema.xml',
  copy: true
)

# Install GSettings schema
install_data(gsettings_schema,
  install_dir: get_option('datadir') / 'glib-2.0' / 'schemas'
)

# Compile GSettings schema for local development
gnome.compile_schemas(depend_files: gsettings_schema)

# Blueprint UI files
subdir('ui')

# Install icons
subdir('icons')

# Install screenshots (for documentation and future use)
install_subdir('screenshots',
  install_dir: get_option('datadir') / 'keysmith'
)
# Configure desktop template
desktop_template = configure_file(
  input: 'io.github.tobagin.keysmith.desktop.in',
  output: 'io.github.tobagin.keysmith.desktop.configured',
  configuration: conf_data
)

# Desktop file
desktop_file = i18n.merge_file(
  input: desktop_template,
  output: '@0@.desktop'.format(app_id),
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

# AppStream metadata (skip i18n for development builds to avoid ITS rules issues)
if get_option('profile') == 'development'
  appstream_file = configure_file(
    input: 'io.github.tobagin.keysmith.metainfo.xml.in',
    output: '@0@.metainfo.xml'.format(app_id),
    configuration: conf_data,
    install: true,
    install_dir: get_option('datadir') / 'metainfo'
  )
else
  appstream_configured = configure_file(
    input: 'io.github.tobagin.keysmith.metainfo.xml.in',
    output: '@0@.metainfo.xml.in'.format(app_id),
    configuration: conf_data
  )
  
  appstream_file = i18n.merge_file(
    input: appstream_configured,
    output: '@0@.metainfo.xml'.format(app_id),
    po_dir: '../po',
    install: true,
    install_dir: get_option('datadir') / 'metainfo'
  )
endif

# Metainfo validation
appstreamcli = find_program('appstreamcli', required: false)
if appstreamcli.found()
  test('Validate metainfo',
    appstreamcli,
    args: ['validate', '--no-net', appstream_file],
    suite: 'validation'
  )
endif

# GSettings schema
gsettings_schema = configure_file(
  input: 'io.github.tobagin.keysmith.gschema.xml.in',
  output: '@0@.gschema.xml'.format(app_id),
  configuration: conf_data
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
  install_dir: get_option('datadir') / 'keymaker'
)
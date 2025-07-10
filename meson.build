project('keysmith',
  version: '1.0.0',
  meson_version: '>= 0.59.0',
  default_options: [
    'warning_level=2',
    'werror=false',
  ]
)

# Import modules
gnome = import('gnome')
python = import('python')
i18n = import('i18n')

# Application information
APPLICATION_ID = 'io.github.tobagin.keysmith'
PKGDATA_DIR = get_option('prefix') / get_option('datadir') / meson.project_name()
MODULE_DIR = PKGDATA_DIR / 'keysmith'

# Find Python installation
python_bin = python.find_installation('python3')
if not python_bin.found()
  error('Python 3 not found')
endif

# Check Python version
if not python_bin.language_version().version_compare('>= 3.9')
  error('Python 3.9 or newer is required')
endif

# Dependency checks
dependency('glib-2.0', version: '>= 2.66')
dependency('gtk4', version: '>= 4.6')
dependency('libadwaita-1', version: '>= 1.2')

# Configuration data
conf = configuration_data()
conf.set('PYTHON', python_bin.full_path())
conf.set('VERSION', meson.project_version())
conf.set('APPLICATION_ID', APPLICATION_ID)
conf.set('PKGDATA_DIR', PKGDATA_DIR)
conf.set('MODULE_DIR', MODULE_DIR)
conf.set('LOCALE_DIR', get_option('prefix') / get_option('localedir'))

# Install Python module
install_subdir('keysmith', install_dir: python_bin.get_install_dir())

# Generate and install executable script
keysmith_script = configure_file(
  input: 'keysmith.in',
  output: 'keysmith',
  configuration: conf,
  install: true,
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x'
)

# Install data files
subdir('data')

# Install translation files
subdir('po')

# Post-install script
gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true,
)
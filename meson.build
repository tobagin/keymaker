project('KeySmith', 'python',
  version : '0.1.0',
  meson_version : '>= 0.50.0',
  default_options : ['warning_level=2'])

python3 = import('python').find_installation(pure: false)
py_installation = python3.install_sources(
  python3.get_install_dir() / 'keysmith',
  subdir: 'keysmith'
)

gnome = import('gnome')
i18n = import('i18n')

keysmith_name = 'io.github.tobagin.KeySmith'
keysmith_exec = 'keysmith'

# Main application executable
executable(keysmith_exec,
  sources: py_installation,
  install: true,
  gui_app: true
)

# Install .desktop file
install_data(
  'data/' + keysmith_name + '.desktop',
  install_dir: get_option('datadir') / 'applications'
)

# Install AppData file
install_data(
  'data/' + keysmith_name + '.appdata.xml',
  install_dir: get_option('datadir') / 'metainfo'
)

# Install icon
install_data(
  'data/icons/' + keysmith_name + '.svg',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'scalable' / 'apps'
)

# GSettings schema
install_data(
  'data/' + keysmith_name + '.gschema.xml',
  install_dir: get_option('datadir') / 'glib-2.0' / 'schemas'
)

# Translations
po_dir = join_paths(meson.source_root(), 'po')
gnome.post_install_update_icon_cache(true)

# subdir('po') # We'll enable this later when po files are created

meson.add_install_script('meson_post_install.py')

project(
    'keysmith',
    'vala', 'c',
    version: '1.2.0',
    meson_version: '>= 1.0.0',
    default_options: [
        'warning_level=1',
        'werror=false',
    ],
    license: 'GPL-3.0-or-later'
)

if get_option('profile') == 'development'
    app_id = 'io.github.tobagin.keysmith.Devel'
    app_name = 'Keymaker'
else
    app_id = 'io.github.tobagin.keysmith'
    app_name = 'Keymaker'
endif

# Import modules
gnome = import('gnome')
i18n = import('i18n')

# Dependencies
gtk_dep = dependency('gtk4', version: '>= 4.8')
adw_dep = dependency('libadwaita-1', version: '>= 1.8')
gio_dep = dependency('gio-2.0', version: '>= 2.76')
gee_dep = dependency('gee-0.8')
json_dep = dependency('json-glib-1.0')
vte_dep = dependency('vte-2.91-gtk4', version: '>= 0.70')
webkit_dep = dependency('webkitgtk-6.0', required: false)
soup_dep = dependency('libsoup-3.0', version: '>= 3.0')
secret_dep = dependency('libsecret-1', version: '>= 0.20')

# Build configuration
cc = meson.get_compiler('c')
valac = meson.get_compiler('vala')
math_dep = cc.find_library('m', required: false)

# Configuration data
conf_data = configuration_data()
# For config.vala template (which includes quotes in the template)
conf_data.set('APP_ID', app_id)
conf_data.set('APP_NAME', app_name)
conf_data.set('VERSION', meson.project_version())
# Gettext domain verified 2025-10-12 Phase 7: Must match gettext-domain in gschema.xml.in
conf_data.set('GETTEXT_PACKAGE', meson.project_name())
conf_data.set('LOCALEDIR', get_option('prefix') / get_option('localedir'))
# For GSchema path (convert dots to slashes)
conf_data.set('APP_PATH', app_id.replace('.', '/'))
conf_data.set('DATADIR', get_option('prefix') / get_option('datadir'))

# Make conf_data available to subdirs
set_variable('conf_data', conf_data)
set_variable('app_id', app_id)

# Generate dynamic config file
config_vala = configure_file(
    input: 'src/Config.vala.in',
    output: 'Config.vala',
    configuration: conf_data
)

# Vala arguments
vala_args = [
    '--target-glib=2.78',
    '--pkg=posix',
]

if get_option('profile') == 'development'
    vala_args += ['-D', 'DEVELOPMENT']
endif

if webkit_dep.found()
    vala_args += ['-D', 'HAS_WEBKIT']
endif

# C arguments
c_args = [
    '-DGETTEXT_PACKAGE="' + meson.project_name() + '"',
    '-DLOCALEDIR="' + get_option('prefix') / get_option('localedir') + '"',
]

# Make build arguments available to subdirs
set_variable('vala_args', vala_args)
set_variable('c_args', c_args)

# Add subdirectories
subdir('data')
subdir('src')
subdir('po')

# Tests (disabled for now - will be added in next phase)
# if get_option('profile') == 'development'
#     subdir('tests')
# endif

# Print summary
summary({
    'Version': meson.project_version(),
    'App ID': app_id,
    'Prefix': get_option('prefix'),
    'Bindir': get_option('bindir'),
    'Datadir': get_option('datadir'),
}, section: 'Configuration')

summary({
    'GTK4': gtk_dep.version(),
    'LibAdwaita': adw_dep.version(),
    'GLib': gio_dep.version(),
    'libsoup': soup_dep.version(),
    'libsecret': secret_dep.version(),
}, section: 'Dependencies')

# Post-install tasks
gnome.post_install(
    glib_compile_schemas: true,
    gtk_update_icon_cache: true,
    update_desktop_database: true,
)
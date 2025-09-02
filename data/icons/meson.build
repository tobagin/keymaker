# Install hicolor icons
icon_sizes = ['16x16', '24x24', '32x32', '48x48', '64x64', '96x96', '128x128', '256x256', '512x512']

foreach size : icon_sizes
  install_data(
    'hicolor' / size / 'apps' / 'io.github.tobagin.keysmith.png',
    install_dir: get_option('datadir') / 'icons' / 'hicolor' / size / 'apps',
    rename: '@0@.png'.format(app_id)
  )
endforeach

# Install custom symbolic icons
install_data(
  'hicolor/scalable/actions/io.github.tobagin.keysmith-qr-code-symbolic.svg',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'scalable' / 'actions',
  rename: 'qr-code-symbolic.svg'
)
i18n.merge_file(
    input: 'display.metainfo.xml.in',
    output: gettext_name + '.metainfo.xml',
    po_dir: meson.project_source_root() / 'po' / 'extra',
    type: 'xml',
    install: true,
    install_dir: get_option('datadir') / 'metainfo',
)

gresource = gnome.compile_resources(
    'gresource',
    'display.gresource.xml'
)

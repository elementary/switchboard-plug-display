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

install_data(
    'display.gschema.xml',
    install_dir: datadir / 'glib-2.0' / 'schemas',
    rename: 'io.elementary.settings.display.gschema.xml'
)
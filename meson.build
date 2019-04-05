project(
    'display',
    'vala', 'c',
    version: '2.1.7'
)

gettext_name = meson.project_name() + '-plug'
gnome = import('gnome')
i18n = import('i18n')

add_project_arguments(
    '-DGETTEXT_PACKAGE="@0@"'.format(gettext_name),
    language:'c'
)

asresources = gnome.compile_resources(
    'as-resources', 'data/' + 'io.elementary.switchboard.display.gresource.xml',
    source_dir: 'data',
    c_name: 'as'
)

subdir('data')
subdir('src')
subdir('po')

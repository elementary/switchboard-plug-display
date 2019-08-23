project(
    'display',
    'vala', 'c',
    version: '2.1.8'
)

gettext_name = meson.project_name() + '-plug'
gnome = import('gnome')
i18n = import('i18n')

prefix = get_option('prefix')
datadir = join_paths(prefix, get_option('datadir'))
libdir = join_paths(prefix, get_option('libdir'))

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

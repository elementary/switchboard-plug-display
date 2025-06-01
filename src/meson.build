plug_files = files(
    'Utils.vala',
    'SettingsDaemon.vala',
    'DisplayPlug.vala',
    'Interfaces/GalaDBus.vala',
    'Interfaces/NightLightManager.vala',
    'Interfaces/MutterDisplayConfig.vala',
    'Interfaces/SensorManager.vala',
    'Objects/VirtualMonitor.vala',
    'Objects/MonitorMode.vala',
    'Objects/MonitorManager.vala',
    'Objects/Monitor.vala',
    'Objects/MonitorLayoutManager.vala',
    'Objects/MonitorLayoutProfile.vala',
    'Views/NightLightView.vala',
    'Views/DisplaysView.vala',
    'Views' / 'FiltersView.vala',
    'Widgets/DisplayWidget.vala',
    'Widgets/DisplaysOverlay.vala',
)

switchboard_dep = dependency('switchboard-3')
switchboard_plugsdir = switchboard_dep.get_pkgconfig_variable('plugsdir', define_variable: ['libdir', libdir])

shared_module(
    meson.project_name(),
    plug_files,
    config_file,
    gresource,
    dependencies: [
        dependency('glib-2.0'),
        dependency('gio-2.0'),
        dependency('gobject-2.0'),
        dependency('granite-7'),
        dependency('gtk4'),
        dependency('libadwaita-1'),
        meson.get_compiler('vala').find_library('posix'),
        switchboard_dep
    ],
    install: true,
    install_dir : join_paths(switchboard_plugsdir, 'hardware')
)

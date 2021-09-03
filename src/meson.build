plug_files = files(
    'Utils.vala',
    'SettingsDaemon.vala',
    'DisplayPlug.vala',
    'Interfaces/NightLightManager.vala',
    'Interfaces/MutterDisplayConfig.vala',
    'Objects/VirtualMonitor.vala',
    'Objects/MonitorMode.vala',
    'Objects/MonitorManager.vala',
    'Objects/Monitor.vala',
    'Views/NightLightView.vala',
    'Views/DisplaysView.vala',
    'Widgets/DisplayWindow.vala',
    'Widgets/DisplayWidget.vala',
    'Widgets/DisplaysOverlay.vala',
)

switchboard_dep = dependency('switchboard-2.0')
switchboard_plugsdir = switchboard_dep.get_pkgconfig_variable('plugsdir', define_variable: ['libdir', libdir])

shared_module(
    meson.project_name(),
    plug_files,
    config_file,
    asresources,
    dependencies: [
        dependency('glib-2.0'),
        dependency('gio-2.0'),
        dependency('gobject-2.0'),
        dependency('granite'),
        dependency('gtk+-3.0'),
        dependency('libhandy-1', version: '>=0.83.0'),
        meson.get_compiler('vala').find_library('posix'),
        switchboard_dep
    ],
    install: true,
    install_dir : join_paths(switchboard_plugsdir, 'hardware')
)

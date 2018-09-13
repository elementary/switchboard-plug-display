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
    'Objects/MonitorConfigurationService.vala',
    'Views/NightLightView.vala',
    'Views/DisplaysView.vala',
    'Widgets/DisplayWindow.vala',
    'Widgets/DisplayWidget.vala',
    'Widgets/DisplaysOverlay.vala',
)

switchboard_dep = dependency('switchboard-2.0')

shared_module(
    meson.project_name(),
    plug_files,
    dependencies: [
        dependency('glib-2.0'),
        dependency('gio-2.0'),
        dependency('gobject-2.0'),
        dependency('granite'),
        dependency('gtk+-3.0'),
        meson.get_compiler('vala').find_library('posix'),
        switchboard_dep
    ],
    install: true,
    install_dir : join_paths(switchboard_dep.get_pkgconfig_variable('plugsdir'), 'hardware')
)

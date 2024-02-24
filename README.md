# Display Settings
[![Packaging status](https://repology.org/badge/tiny-repos/switchboard-plug-display.svg)](https://repology.org/metapackage/switchboard-plug-display)
[![Translation status](https://l10n.elementary.io/widgets/switchboard/-/switchboard-plug-display/svg-badge.svg)](https://l10n.elementary.io/engage/switchboard/?utm_source=widget)

Extension for [System Settings](https://github.com/elementary/switchboard) to manage multiple monitor setups.

![screenshot](data/screenshot.png?raw=true)

## Building and Installation

You'll need the following dependencies:

* libadwaita-1-dev
* libgranite-7-dev
* libgtk-4-dev
* libswitchboard-3-dev
* meson
* valac

Run `meson` to configure the build environment and then `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`

    ninja install

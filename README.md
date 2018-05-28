# Switchboard Display Plug
[![Packaging status](https://repology.org/badge/tiny-repos/switchboard-plug-display.svg)](https://repology.org/metapackage/switchboard-plug-display)
[![l10n](https://l10n.elementary.io/widgets/switchboard/switchboard-plug-display/svg-badge.svg)](https://l10n.elementary.io/projects/switchboard/switchboard-plug-display)

Extension for [Switchboard](https://github.com/elementary/switchboard) to manage multiple monitor setups.

## Building and Installation

You'll need the following dependencies:

* libgranite-dev
* libgtk-3-dev
* libswitchboard-2.0-dev
* meson
* valac

Run `meson` to configure the build environment and then `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`

    sudo ninja install

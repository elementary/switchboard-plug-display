/*
 * SPDX-License-Identifier: LGPL-2.0-or-later
 * SPDX-FileCopyrightText: 2014-2023 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 *              Oleksandr Lynok <oleksandr.lynok@gmail.com>
 */

public class Display.DisplaysView : Gtk.Box {
    public DisplaysOverlay displays_overlay;

    private Gtk.ComboBoxText dpi_combo;
    private Gtk.Box rotation_lock_box;

    private const string TOUCHSCREEN_SETTINGS_PATH = "org.gnome.settings-daemon.peripherals.touchscreen";

    construct {
            displays_overlay = new DisplaysOverlay () {
                vexpand = true
            };

            var mirror_label = new Gtk.Label (_("Mirror Display:"));
            var mirror_switch = new Gtk.Switch ();

            var mirror_box = new Gtk.Box (HORIZONTAL, 6) {
                margin_top = 6,
                margin_end = 6,
                margin_bottom = 6,
                margin_start = 6,
                valign = CENTER
            };
            mirror_box.append (mirror_label);
            mirror_box.append (mirror_switch);

            var dpi_label = new Gtk.Label (_("Scaling factor:"));

            dpi_combo = new Gtk.ComboBoxText ();
            dpi_combo.append_text (_("LoDPI") + " (1×)");
            dpi_combo.append_text (_("HiDPI") + " (2×)");
            dpi_combo.append_text (_("HiDPI") + " (3×)");

            var dpi_box = new Gtk.Box (HORIZONTAL, 6) {
                margin_top = 6,
                margin_end = 6,
                margin_bottom = 6,
                margin_start = 6
            };
            dpi_box.append (dpi_label);
            dpi_box.append (dpi_combo);

            var detect_button = new Gtk.Button.with_label (_("Detect Displays"));

            var apply_button = new Gtk.Button.with_label (_("Apply"));
            apply_button.add_css_class (Granite.STYLE_CLASS_SUGGESTED_ACTION);
            apply_button.sensitive = false;

            var button_box = new Gtk.Box (HORIZONTAL, 6) {
                homogeneous = true,
                margin_top = 6,
                margin_end = 6,
                margin_bottom = 6,
                margin_start = 6,
                valign = CENTER
            };
            button_box.append (detect_button);
            button_box.append (apply_button);

            var action_bar = new Gtk.ActionBar ();
            action_bar.add_css_class (Granite.STYLE_CLASS_FLAT);
            action_bar.pack_start (dpi_box);
            action_bar.pack_start (mirror_box);

            var schema_source = GLib.SettingsSchemaSource.get_default ();
            var rotation_lock_schema = schema_source.lookup (TOUCHSCREEN_SETTINGS_PATH, true);
            if (rotation_lock_schema != null) {
                rotation_lock_box = new Gtk.Box (HORIZONTAL, 6) {
                    margin_top = 6,
                    margin_end = 6,
                    margin_bottom = 6,
                    margin_start = 6,
                    valign = CENTER
                };

                action_bar.pack_start (rotation_lock_box);

                detect_accelerometer.begin ();
            } else {
                info ("Schema \"org.gnome.settings-daemon.peripherals.touchscreen\" is not installed on your system.");
            }

            action_bar.pack_end (button_box);

            orientation = VERTICAL;
            append (new Gtk.Separator (HORIZONTAL));
            append (displays_overlay);
            append (action_bar);

            displays_overlay.configuration_changed.connect ((changed) => {
                apply_button.sensitive = changed;
            });

            unowned Display.MonitorManager monitor_manager = Display.MonitorManager.get_default ();
            mirror_box.sensitive = monitor_manager.monitors.size > 1;
            monitor_manager.notify["monitor-number"].connect (() => {
                mirror_box.sensitive = monitor_manager.monitors.size > 1;
            });

            detect_button.clicked.connect (() => displays_overlay.rescan_displays ());
            apply_button.clicked.connect (() => {
                monitor_manager.set_monitor_config ();
                apply_button.sensitive = false;
            });

            dpi_combo.active = (int)monitor_manager.virtual_monitors[0].scale - 1;

            dpi_combo.changed.connect (() => {
                monitor_manager.set_scale_on_all_monitors ((double)(dpi_combo.active + 1));
            });

            mirror_switch.active = monitor_manager.is_mirrored;
            mirror_switch.notify["active"].connect (() => {
                if (mirror_switch.active) {
                    monitor_manager.enable_clone_mode ();
                } else {
                    monitor_manager.disable_clone_mode ();
                }

                apply_button.sensitive = true;
            });
    }

    private async void detect_accelerometer () {
        bool has_accelerometer = false;

        try {
            SensorProxy sensors = yield GLib.Bus.get_proxy (BusType.SYSTEM, "net.hadess.SensorProxy", "/net/hadess/SensorProxy");
            has_accelerometer = sensors.has_accelerometer;
        } catch (Error e) {
            info ("Unable to connect to SensorProxy bus, probably means no accelerometer supported: %s", e.message);
        }

        if (has_accelerometer) {
            var touchscreen_settings = new GLib.Settings (TOUCHSCREEN_SETTINGS_PATH);

            var rotation_lock_label = new Gtk.Label (_("Rotation Lock:"));
            var rotation_lock_switch = new Gtk.Switch ();

            rotation_lock_box.append (rotation_lock_label);
            rotation_lock_box.append (rotation_lock_switch);

            touchscreen_settings.bind ("orientation-lock", rotation_lock_switch, "state", DEFAULT);

        }
    }

    [DBus (name = "net.hadess.SensorProxy")]
    private interface SensorProxy : GLib.DBusProxy {
        public abstract bool has_accelerometer { get; }
    }
}

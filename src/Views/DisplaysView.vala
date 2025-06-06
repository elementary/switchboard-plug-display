/*
 * SPDX-License-Identifier: LGPL-2.0-or-later
 * SPDX-FileCopyrightText: 2014-2023 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 *              Oleksandr Lynok <oleksandr.lynok@gmail.com>
 */

public class Display.DisplaysView : Gtk.Box {
    public DisplaysOverlay displays_overlay;

    private Gtk.DropDown dpi_dropdown;
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

            dpi_dropdown = new Gtk.DropDown.from_strings ({
                _("LoDPI") + " (1×)",
                _("HiDPI") + " (2×)",
                _("HiDPI") + " (3×)"
            });

            var dpi_box = new Gtk.Box (HORIZONTAL, 6) {
                margin_top = 6,
                margin_end = 6,
                margin_bottom = 6,
                margin_start = 6
            };

            dpi_box.append (dpi_label);
            dpi_box.append (dpi_dropdown);

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

            unowned Display.MonitorManager monitor_manager = Display.MonitorManager.get_default ();
            if (monitor_manager.global_scale_required) {
                action_bar.pack_start (dpi_box);
            }

            action_bar.pack_start (mirror_box);

            if (SensorManager.get_default ().has_accelerometer) {
                var schema_source = GLib.SettingsSchemaSource.get_default ();
                var rotation_lock_schema = schema_source.lookup (TOUCHSCREEN_SETTINGS_PATH, true);
                if (rotation_lock_schema != null) {
                    var rotation_lock_switch = new Gtk.Switch ();

                    var rotation_lock_label = new Gtk.Label (_("Rotation Lock:")) {
                        mnemonic_widget = rotation_lock_switch
                    };

                    rotation_lock_box = new Gtk.Box (HORIZONTAL, 6) {
                        margin_top = 6,
                        margin_end = 6,
                        margin_bottom = 6,
                        margin_start = 6,
                        valign = CENTER
                    };
                    rotation_lock_box.append (rotation_lock_label);
                    rotation_lock_box.append (rotation_lock_switch);

                    action_bar.pack_start (rotation_lock_box);

                    var touchscreen_settings = new GLib.Settings (TOUCHSCREEN_SETTINGS_PATH);
                    touchscreen_settings.bind ("orientation-lock", rotation_lock_switch, "active", DEFAULT);
                } else {
                    info ("Schema \"org.gnome.settings-daemon.peripherals.touchscreen\" is not installed on your system.");
                }
            }

            action_bar.pack_end (button_box);

            orientation = VERTICAL;
            append (new Gtk.Separator (HORIZONTAL));
            append (displays_overlay);
            append (action_bar);

            displays_overlay.configuration_changed.connect ((changed) => {
                apply_button.sensitive = changed;
            });

            mirror_box.sensitive = monitor_manager.monitors.size > 1;
            monitor_manager.notify["monitor-number"].connect (() => {
                mirror_box.sensitive = monitor_manager.monitors.size > 1;
            });

            detect_button.clicked.connect (() => displays_overlay.rescan_displays ());
            apply_button.clicked.connect (() => {
                try {
                    monitor_manager.set_monitor_config ();
                } catch (Error e) {
                    show_error_dialog (e.message);
                }
                apply_button.sensitive = false;
            });

            dpi_dropdown.selected = (int)monitor_manager.virtual_monitors[0].scale - 1;

            dpi_dropdown.notify["selected"].connect (() => {
                try {
                    monitor_manager.set_scale_on_all_monitors ((double)(dpi_dropdown.selected + 1));
                    warning ("Setting scale to %f", (double)(dpi_dropdown.selected + 1));
                } catch (Error e) {
                    show_error_dialog (e.message);
                }
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

    private void show_error_dialog (string details) {
        var error_dialog = new Granite.MessageDialog.with_image_from_icon_name (
            _("Failed to apply display settings"),
            _("This can be caused by an invalid configuration."),
            "dialog-error"
        );
        error_dialog.show_error_details (details);
        error_dialog.response.connect (error_dialog.destroy);
        error_dialog.present ();
    }
}

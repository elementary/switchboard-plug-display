/*-
 * Copyright (c) 2014-2018 elementary LLC.
 *
 * This software is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this software; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 *              Oleksandr Lynok <oleksandr.lynok@gmail.com>
 */

public class Display.DisplaysView : Gtk.Grid {
    public DisplaysOverlay displays_overlay;

    private Gtk.ComboBoxText dpi_combo;

    construct {
            displays_overlay = new DisplaysOverlay ();

            var mirror_label = new Gtk.Label (_("Mirror Display:"));
            var mirror_switch = new Gtk.Switch ();

            var mirror_grid = new Gtk.Grid ();
            mirror_grid.margin = 12;
            mirror_grid.column_spacing = 6;
            mirror_grid.add (mirror_label);
            mirror_grid.add (mirror_switch);

            var dpi_label = new Gtk.Label (_("Pixel Doubled:"));
            var dpi_switch = new Gtk.Switch ();

            var dpi_grid = new Gtk.Grid ();
            dpi_grid.margin = 12;
            dpi_grid.column_spacing = 6;
            dpi_grid.add (dpi_label);
            dpi_grid.add (dpi_switch);

            var detect_button = new Gtk.Button.with_label (_("Detect Displays"));

            var apply_button = new Gtk.Button.with_label (_("Apply"));
            apply_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
            apply_button.sensitive = false;

            var button_grid = new Gtk.Grid ();
            button_grid.margin = 12;
            button_grid.column_homogeneous = true;
            button_grid.column_spacing = 6;
            button_grid.orientation = Gtk.Orientation.HORIZONTAL;
            button_grid.add (detect_button);
            button_grid.add (apply_button);

            var action_bar = new Gtk.ActionBar ();
            action_bar.get_style_context ().add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);
            action_bar.pack_start (dpi_grid);
            action_bar.pack_start (mirror_grid);

            if (Utils.has_touchscreen ()) {
                var schema_source = GLib.SettingsSchemaSource.get_default ();
                var rotation_lock_schema = schema_source.lookup ("org.gnome.settings-daemon.peripherals.touchscreen", true);
                if (rotation_lock_schema != null) {
                    var touchscreen_settings = new GLib.Settings.full (rotation_lock_schema, null, null);

                    var rotation_lock_label = new Gtk.Label (_("Rotation Lock:"));
                    var rotation_lock_switch = new Gtk.Switch ();

                    var rotation_lock_grid = new Gtk.Grid ();
                    rotation_lock_grid.margin = 12;
                    rotation_lock_grid.column_spacing = 6;
                    rotation_lock_grid.orientation = Gtk.Orientation.HORIZONTAL;
                    rotation_lock_grid.add (rotation_lock_label);
                    rotation_lock_grid.add (rotation_lock_switch);

                    action_bar.pack_start (rotation_lock_grid);

                    touchscreen_settings.bind ("orientation-lock", rotation_lock_switch, "state", SettingsBindFlags.DEFAULT);
                } else {
                    info ("Schema \"org.gnome.settings-daemon.peripherals.touchscreen\" is not installed on your system.");
                }
            }

            action_bar.pack_end (button_grid);

            orientation = Gtk.Orientation.VERTICAL;
            add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
            add (displays_overlay);
            add (action_bar);
            show_all ();

            displays_overlay.configuration_changed.connect ((changed) => {
                apply_button.sensitive = changed;
            });

            unowned Display.MonitorManager monitor_manager = Display.MonitorManager.get_default ();
            mirror_grid.sensitive = monitor_manager.monitors.size > 1;
            monitor_manager.notify["monitor-number"].connect (() => {
                mirror_grid.sensitive = monitor_manager.monitors.size > 1;
            });

            detect_button.clicked.connect (() => displays_overlay.rescan_displays ());
            apply_button.clicked.connect (() => {
                monitor_manager.set_monitor_config ();
                apply_button.sensitive = false;
            });

			dpi_switch.notify["active"].connect (() => {
					monitor_manager.set_scale_on_all_monitors ((double)(dpi_switch.active)+1.0);
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
}

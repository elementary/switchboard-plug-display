/*-
 * Copyright (c) 2014-2016 elementary LLC.
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
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 *              Oleksandr Lynok <oleksandr.lynok@gmail.com>
 */

public class Display.Plug : Switchboard.Plug {
    public static Plug plug;
    private Gtk.Grid main_grid;
    private DisplaysView displays_view;
    private Gtk.Stack stack;
    private MirrorDisplay mirror_display;

    public Plug () {
        var settings = new Gee.TreeMap<string, string?> (null, null);
        settings.set ("display", null);
        Object (category: Category.HARDWARE,
                code_name: Build.PLUGCODENAME,
                display_name: _("Displays"),
                description: _("Configure resolution and position of monitors and projectors"),
                icon: "preferences-desktop-display",
                supported_settings: settings);
        plug = this;
    }

    public override Gtk.Widget get_widget () {
        if (main_grid == null) {
            main_grid = new Gtk.Grid ();
            main_grid.orientation = Gtk.Orientation.VERTICAL;
            main_grid.column_spacing = 6;
            displays_view = new DisplaysView ();
            var action_bar = new Gtk.ActionBar ();
            action_bar.get_style_context ().add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);
            
            var mirror_grid = new Gtk.Grid ();
            mirror_grid.margin = 12;
            mirror_grid.column_spacing = 6;
            mirror_grid.orientation = Gtk.Orientation.HORIZONTAL;
            var mirror_label = new Gtk.Label (_("Mirror Display:"));
            var mirror_switch = new Gtk.Switch ();
            mirror_grid.add (mirror_label);
            mirror_grid.add (mirror_switch);

            action_bar.pack_start (mirror_grid);

            Gtk.Grid rotation_lock_grid = new Gtk.Grid ();
            if (!has_touchscreen ()) {
                var schema_source = GLib.SettingsSchemaSource.get_default ();
                var rotation_lock_schema = schema_source.lookup ("org.gnome.settings-daemon.peripherals.touchscreen", true);
                if (rotation_lock_schema != null) {
                    var touchscreen_settings = new GLib.Settings.full (rotation_lock_schema, null, null);

                    rotation_lock_grid = new Gtk.Grid ();
                    rotation_lock_grid.margin = 12;
                    rotation_lock_grid.column_spacing = 6;
                    rotation_lock_grid.orientation = Gtk.Orientation.HORIZONTAL;
                    var rotation_lock_label = new Gtk.Label (_("Rotation Lock:"));
                    var rotation_lock_switch = new Gtk.Switch ();
                    rotation_lock_grid.add (rotation_lock_label);
                    rotation_lock_grid.add (rotation_lock_switch);
                    
                    action_bar.pack_start (rotation_lock_grid);

                    touchscreen_settings.bind ("orientation-lock",
                                                rotation_lock_switch,
                                                "state",
                                                SettingsBindFlags.DEFAULT);
                } else {
                    info ("Schema \"org.gnome.settings-daemon.peripherals.touchscreen\" is not installed on your system.");
                }
            }
            
            var button_grid = new Gtk.Grid ();
            button_grid.margin = 12;
            button_grid.column_homogeneous = true;
            button_grid.column_spacing = 6;
            button_grid.orientation = Gtk.Orientation.HORIZONTAL;
            var detect_button = new Gtk.Button.with_label (_("Detect Displays"));
            var apply_button = new Gtk.Button.with_label (_("Apply"));
            apply_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
            apply_button.sensitive = false;
            button_grid.add (detect_button);
            button_grid.add (apply_button);

            action_bar.pack_end (button_grid);
    
            mirror_display = new MirrorDisplay ();

            stack = new Gtk.Stack ();
            stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
            stack.add (displays_view);
            stack.add (mirror_display);

            main_grid.add (stack);
            main_grid.add (action_bar);
            main_grid.show_all ();

            displays_view.configuration_changed.connect ((changed) => {
                apply_button.sensitive = changed;
            });

            mirror_grid.sensitive = displays_view.active_displays > 1;
            displays_view.notify["active-displays"].connect (() => {
                mirror_grid.sensitive = displays_view.active_displays > 1;
            });

            mirror_display.configuration_changed.connect ((changed) => {
                apply_button.sensitive = changed;
            });

            detect_button.clicked.connect (() => displays_view.rescan_displays ());
            apply_button.clicked.connect (() => {
                var rr_screen = new Gnome.RRScreen (Gdk.Screen.get_default ());
                var rr_config = new Gnome.RRConfig.current (rr_screen);
                if (rr_config.get_clone ()) {
                    mirror_display.apply_configuration ();
                } else {
                    displays_view.apply_configuration ();
                }

                apply_button.sensitive = false;
            });

            var rr_screen = new Gnome.RRScreen (Gdk.Screen.get_default ());
            var rr_config = new Gnome.RRConfig.current (rr_screen);
            mirror_switch.active = rr_config.get_clone ();
            if (rr_config.get_clone ()) {
                stack.set_visible_child (mirror_display);
            }

            mirror_switch.notify["active"].connect (() => {
                var rr_screen2 = new Gnome.RRScreen (Gdk.Screen.get_default ());
                var rr_config2 = new Gnome.RRConfig.current (rr_screen2);
                if (mirror_switch.active) {
                    unowned Gnome.RRMode highest_mode = null;
                    foreach (unowned Gnome.RRMode mode in rr_screen2.list_clone_modes ()) {
                        if (highest_mode == null) {
                            highest_mode = mode;
                        } else if (mode.get_width () > highest_mode.get_width ()) {
                            highest_mode = mode;
                        }
                    }

                    if (highest_mode == null)
                        return;

                    foreach (unowned Gnome.RROutputInfo output in rr_config2.get_outputs ()) {
                        if (output.is_connected ()) {
                            int x, y;
                            output.get_geometry (out x, out y, null, null);
                            output.set_geometry (x, y, (int)highest_mode.get_width (), (int)highest_mode.get_height ());
                        }
                    }

                    rr_config2.set_clone (true);
                    stack.set_visible_child (mirror_display);
                } else {
                    rr_config2.set_clone (false);
                    unowned Gnome.RROutputInfo[] outputs = rr_config2.get_outputs ();
                    foreach (unowned Gnome.RROutputInfo output in outputs) {
                        if (output.is_connected ()) {
                            int x, y;
                            output.get_geometry (out x, out y, null, null);
                            output.set_geometry (x, y, output.get_preferred_width (), output.get_preferred_height ());
                        }
                    }

                    int x = 0;
                    foreach (unowned Gnome.RROutputInfo output in outputs) {
                        if (output.is_connected () && output.is_active ()) {
                            int width, height;
                            output.get_geometry (null, null, out width, out height);
                            output.set_geometry (x, 0, width, height);

                            x += width;
                        }
                    }

                    foreach (unowned Gnome.RROutputInfo output in outputs) {
                        if (!(output.is_connected () && output.is_active ())) {
                            int width, height;
                            output.get_geometry (null, null, out width, out height);
                            output.set_geometry (x, 0, width, height);

                            x += width;
                        }
                    }

                    stack.set_visible_child (displays_view);
                }

                rr_config2.sanitize ();
                try {
                    rr_config2.apply_persistent (rr_screen2);
                } catch (Error e) {
                    critical (e.message);
                }
            });
        }

        return main_grid;
    }

    public override void shown () {
        displays_view.show_windows ();
    }

    public override void hidden () {
        displays_view.hide_windows ();
    }

    public override void search_callback (string location) {
        
    }

    // 'search' returns results like ("Keyboard → Behavior → Duration", "keyboard<sep>behavior")
    public override async Gee.TreeMap<string, string> search (string search) {
        var search_results = new Gee.TreeMap<string, string> ((GLib.CompareDataFunc<string>)strcmp, (Gee.EqualDataFunc<string>)str_equal);
        search_results.set ("%s → %s".printf (display_name, _("Screen Resolution")), "");
        search_results.set ("%s → %s".printf (display_name, _("Screen Rotation")), "");
        search_results.set ("%s → %s".printf (display_name, _("Primary display")), "");
        search_results.set ("%s → %s".printf (display_name, _("Screen mirroring")), "");
        return search_results;
    }

    private static bool has_touchscreen () {
        var display = Gdk.Display.get_default ();
        if (display != null) {
            var manager = display.get_device_manager ();
            foreach (var device in manager.list_devices (Gdk.DeviceType.SLAVE)) {
                if (device.get_source () == Gdk.InputSource.TOUCHSCREEN) {
                    return true;
                }
            }
        }
        return false;
    }
}

public Switchboard.Plug get_plug (Module module) {
    debug ("Activating Display plug");
    var plug = new Display.Plug ();
    return plug;
}

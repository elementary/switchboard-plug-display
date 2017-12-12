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
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 *              Oleksandr Lynok <oleksandr.lynok@gmail.com>
 */

public class Display.Plug : Switchboard.Plug {
    public static Plug plug;
    private Gtk.Grid grid;
    private DisplaysView displays_view;

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
        if (grid == null) {
            displays_view = new DisplaysView ();

            grid = new Gtk.Grid ();
            grid.orientation = Gtk.Orientation.VERTICAL;

            var interface_settings_schema = SettingsSchemaSource.get_default ().lookup ("org.gnome.settings-daemon.plugins.color", false);
            if (interface_settings_schema != null) {
                if (interface_settings_schema.has_key ("night-light-enabled")) {

                    var nightlight_view = new NightLightView ();

                    var stack = new Gtk.Stack ();
                    stack.add_titled (displays_view, "displays", _("Displays"));
                    stack.add_titled (nightlight_view, "nightlight", _("Night Light"));

                    var stack_switcher = new Gtk.StackSwitcher ();
                    stack_switcher.halign = Gtk.Align.CENTER;
                    stack_switcher.homogeneous = true;
                    stack_switcher.margin = 12;
                    stack_switcher.stack = stack;

                    grid.add (stack_switcher);
                    grid.add (stack);
                }
            } else {
                grid.add (displays_view);
            }

            grid.show_all ();
        }

        return grid;
    }

    public override void shown () {
        displays_view.displays_overlay.show_windows ();
    }

    public override void hidden () {
        displays_view.displays_overlay.hide_windows ();
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

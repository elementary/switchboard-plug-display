/*-
 * Copyright (c) 2014-2023 elementary, Inc.
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
    private Gtk.Box box;
    private Gtk.Stack stack;
    private DisplaysView displays_view;

    public Plug () {
        GLib.Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        GLib.Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");

        var settings = new Gee.TreeMap<string, string?> (null, null);
        settings.set ("display", "displays");
        settings.set ("display/night-light", "night-light");
        settings.set ("display/filters", "filters");
        Object (category: Category.HARDWARE,
                code_name: "io.elementary.settings.display",
                display_name: _("Displays"),
                description: _("Configure resolution and position of monitors and projectors"),
                icon: "preferences-desktop-display",
                supported_settings: settings);
        plug = this;
    }

    public override Gtk.Widget get_widget () {
        if (box == null) {
            displays_view = new DisplaysView ();

            stack = new Gtk.Stack ();
            stack.add_titled (displays_view, "displays", _("Displays"));

            var interface_settings_schema = SettingsSchemaSource.get_default ().lookup ("org.gnome.settings-daemon.plugins.color", true);
            if (interface_settings_schema != null && interface_settings_schema.has_key ("night-light-enabled")) {
                var nightlight_view = new NightLightView ();
                stack.add_titled (nightlight_view, "night-light", _("Night Light"));
            }

            var filters_settings_schema = SettingsSchemaSource.get_default ().lookup ("io.elementary.desktop.wm.accessibility", true);
            if (filters_settings_schema != null && filters_settings_schema.has_key ("colorblindness-correction-filter")) {
                var filters_view = new FiltersView ();
                stack.add_titled (filters_view, "filters", _("Filters"));
            }

            var stack_switcher = new Gtk.StackSwitcher () {
                stack = stack
            };

            var switcher_sizegroup = new Gtk.SizeGroup (HORIZONTAL);
            unowned var switcher_child =stack_switcher.get_first_child ();
            while (switcher_child != null) {
                switcher_sizegroup.add_widget (switcher_child);
                switcher_child = switcher_child.get_next_sibling ();
            }

            var headerbar = new Adw.HeaderBar () {
                title_widget = stack_switcher
            };
            headerbar.add_css_class (Granite.STYLE_CLASS_FLAT);

            box = new Gtk.Box (VERTICAL, 0);
            box.append (headerbar);
            box.append (stack);

            stack.notify["visible-child"].connect (() => {
                if (stack.visible_child == displays_view) {
                    displays_view.displays_overlay.show_windows ();
                } else {
                    displays_view.displays_overlay.hide_windows ();
                }
            });
        }

        return box;
    }

    public override void shown () {
        if (stack.visible_child == displays_view) {
            displays_view.displays_overlay.show_windows ();
        } else {
            displays_view.displays_overlay.hide_windows ();
        }
    }

    public override void hidden () {
        displays_view.displays_overlay.hide_windows ();
    }

    public override void search_callback (string location) {
        stack.visible_child_name = location;
    }

    // 'search' returns results like ("Keyboard → Behavior → Duration", "keyboard<sep>behavior")
    public override async Gee.TreeMap<string, string> search (string search) {
        var search_results = new Gee.TreeMap<string, string> ((GLib.CompareDataFunc<string>)strcmp, (Gee.EqualDataFunc<string>)str_equal);
        search_results.set ("%s → %s".printf (display_name, _("Screen Resolution")), "displays");
        search_results.set ("%s → %s".printf (display_name, _("Primary display")), "displays");
        search_results.set ("%s → %s".printf (display_name, _("Screen mirroring")), "displays");
        search_results.set ("%s → %s".printf (display_name, _("Screen Rotation")), "displays");
        search_results.set ("%s → %s".printf (display_name, _("Scaling factor")), "displays");
        search_results.set ("%s → %s".printf (display_name, _("Night Light")), "night-light");
        search_results.set ("%s → %s → %s".printf (display_name, _("Night Light"), _("Schedule")), "night-light");
        search_results.set ("%s → %s → %s".printf (display_name, _("Night Light"), _("Color temperature")), "night-light");
        search_results.set ("%s → %s → %s".printf (display_name, _("Filters"), _("Color Blindness")), "filters");
        search_results.set ("%s → %s → %s".printf (display_name, _("Filters"), _("Color Vision Deficiency")), "filters");
        search_results.set ("%s → %s → %s".printf (display_name, _("Filters"), _("Grayscale")), "filters");
        search_results.set ("%s → %s → %s".printf (display_name, _("Filters"), _("Monochrome")), "filters");

        if (SensorManager.get_default ().has_accelerometer) {
            search_results.set ("%s → %s".printf (display_name, _("Rotation lock")), "displays");
        }

        return search_results;
    }
}

public Switchboard.Plug get_plug (Module module) {
    debug ("Activating Display plug");
    var plug = new Display.Plug ();
    return plug;
}

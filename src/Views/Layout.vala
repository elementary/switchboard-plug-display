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

public class Display.Views.Layout : Granite.SettingsPage {
    public Layout () {
        Object (header: _("Behavior"), title: _("Layout"), icon_name: "multitasking-view");
    }

    construct {
        var stack = new Gtk.Stack ();
        stack.expand = true;

        var mirror_label = new Gtk.Label (_("Mirror Display:"));
        var mirror_switch = new Gtk.Switch ();

        var action_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        action_box.hexpand = true;
        action_box.margin = 12;
        action_box.add (mirror_label);
        action_box.add (mirror_switch);

        var action_bar = new Gtk.ActionBar ();
        action_bar.get_style_context ().add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);
        action_bar.add (action_box);

        if (Utils.has_touchscreen ()) {
            var schema_source = GLib.SettingsSchemaSource.get_default ();
            var rotation_lock_schema = schema_source.lookup ("org.gnome.settings-daemon.peripherals.touchscreen", true);
            if (rotation_lock_schema != null) {
                var touchscreen_settings = new GLib.Settings.full (rotation_lock_schema, null, null);

                var rotation_lock_label = new Gtk.Label (_("Rotation Lock:"));
                var rotation_lock_switch = new Gtk.Switch ();

                action_box.add (rotation_lock_label);
                action_box.add (rotation_lock_switch);

                touchscreen_settings.bind ("orientation-lock", rotation_lock_switch, "state", SettingsBindFlags.DEFAULT);
            } else {
                info ("Schema \"org.gnome.settings-daemon.peripherals.touchscreen\" is not installed on your system.");
            }
        }

        var apply_button = new Gtk.Button.with_label (_("Apply"));
        apply_button.halign = Gtk.Align.END;
        apply_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        apply_button.sensitive = false;

        action_box.pack_end (apply_button);

        var main_grid = new Gtk.Grid ();
        main_grid.orientation = Gtk.Orientation.VERTICAL;
        main_grid.add (stack);
        main_grid.add (action_bar);
        main_grid.show_all ();

        add (main_grid);
    }
}

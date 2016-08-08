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
 */

public class Display.MirrorDisplay : Gtk.Grid {
    public signal void configuration_changed (bool changed);
    private Gnome.RRConfig rr_config;
    private Gnome.RRScreen rr_screen;
    private Gtk.ListStore resolution_list_store;
    private Gtk.ComboBox resolution_combobox;
    public MirrorDisplay () {
        column_spacing = 12;
        orientation = Gtk.Orientation.HORIZONTAL;
        var resolution_label = new Gtk.Label (_("Resolution:"));
        resolution_label.halign = Gtk.Align.END;
        resolution_label.valign = Gtk.Align.CENTER;
        resolution_label.expand = true;

        resolution_list_store = new Gtk.ListStore (2, typeof (string), typeof (Gnome.RRMode));
        resolution_combobox = new Gtk.ComboBox.with_model (resolution_list_store);
        resolution_combobox.halign = Gtk.Align.START;
        resolution_combobox.valign = Gtk.Align.CENTER;
        var text_renderer = new Gtk.CellRendererText ();
        resolution_combobox.pack_start (text_renderer, true);
        resolution_combobox.add_attribute (text_renderer, "text", 0);
        resolution_combobox.expand = true;

        add (resolution_label);
        add (resolution_combobox);

        resolution_combobox.changed.connect (() => {
            Value val;
            Gtk.TreeIter iter;
            resolution_combobox.get_active_iter (out iter);
            resolution_list_store.get_value (iter, 1, out val);
            foreach (unowned Gnome.RROutputInfo output_info in rr_config.get_outputs ()) {
                output_info.set_geometry (0, 0, (int)((Gnome.RRMode) val).get_width (), (int)((Gnome.RRMode) val).get_height ());
            }

            check_configuration_changed ();
        });

        populate_clone_mode ();
        rr_screen.output_connected.connect (() => populate_clone_mode ());
        rr_screen.output_disconnected.connect (() => populate_clone_mode ());
        rr_screen.changed.connect (() => populate_clone_mode ());
    }

    public void populate_clone_mode () {
        rr_screen = new Gnome.RRScreen (Gdk.Screen.get_default ());
        rr_config = new Gnome.RRConfig.current (rr_screen);
        unowned Gnome.RRMode current_mode = null;
        foreach (unowned Gnome.RROutputInfo output_info in rr_config.get_outputs ()) {
            if (output_info.get_primary ()) {
                current_mode = rr_screen.get_output_by_name (output_info.get_name ()).get_current_mode ();
            }
        }

        resolution_list_store.clear ();
        foreach (unowned Gnome.RRMode mode in rr_screen.list_clone_modes ()) {
            var mode_width = mode.get_width ();
            var mode_height = mode.get_height ();
            var aspect = DisplayWidget.make_aspect_string (mode_width, mode_height);

            string text;
            if (aspect != null) {
                text = "%u × %u (%s)".printf (mode_width, mode_height, aspect);
            } else {
                text = "%u × %u".printf (mode_width, mode_height);
            }

            Gtk.TreeIter iter;
            resolution_list_store.append (out iter);
            resolution_list_store.set (iter, 0, text, 1, mode);
            if (current_mode == mode) {
                resolution_combobox.set_active_iter (iter);
            }
        }
    }

    public void apply_configuration () {
        try {
            rr_config.sanitize ();
            rr_config.apply_persistent (rr_screen);
        } catch (Error e) {
            critical (e.message);
        }
    }

    private void check_configuration_changed () {
        try {
            configuration_changed (rr_config.applicable (rr_screen));
        } catch (Error e) {
            // Nothing to show here
        }
    }
}

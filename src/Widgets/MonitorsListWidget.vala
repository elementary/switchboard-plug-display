/*-
 * Copyright 2021 elementary, Inc. (https://elementary.io)
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
 *              Jeremy Wootten <jeremywootten@gmail.com>
 */

public class Display.MonitorsListWidget : Gtk.Grid {
    private enum ResolutionColumns {
        NAME,
        MODE,
        TOTAL
    }

    private enum RotationColumns {
        NAME,
        VALUE,
        TOTAL
    }

    private enum RefreshColumns {
        NAME,
        VALUE,
        TOTAL
    }

    public Display.VirtualMonitor monitor { get; construct; }
    private Gtk.MenuButton toggle_settings { get; private set; }

    private Gtk.ComboBox resolution_combobox;
    private Gtk.ListStore resolution_list_store;

    private Gtk.ComboBox rotation_combobox;
    private Gtk.ListStore rotation_list_store;

    private Gtk.ComboBox refresh_combobox;
    private Gtk.ListStore refresh_list_store;
    unowned MonitorsList monitors_list;
    public MonitorsListWidget (Display.VirtualMonitor _monitor, MonitorsList _monitors_list) {
        Object (
            monitor: _monitor
        );

        monitors_list = _monitors_list;
    }

    construct {
        margin_start = 6;
        margin_top = 12;
        row_spacing = 3;
        column_spacing = 3;

        var name_label = new Gtk.Label (monitor.get_display_name ()) {
            hexpand = true,
            halign = Gtk.Align.START,
            valign = Gtk.Align.CENTER
        };
        name_label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);
        var use_switch = new Gtk.Switch () {
            active = monitor.is_active,
            halign = Gtk.Align.END,
            valign = Gtk.Align.CENTER,
            sensitive = monitors_list.active_displays > 1
        };

        var resolution_label = new Gtk.Label (_("Resolution:")) {
            halign = Gtk.Align.START
        };

        resolution_list_store = new Gtk.ListStore (ResolutionColumns.TOTAL, typeof (string), typeof (Display.MonitorMode));
        resolution_combobox = new Gtk.ComboBox.with_model (resolution_list_store);
        resolution_combobox.sensitive = use_switch.active;
        var text_renderer = new Gtk.CellRendererText ();
        resolution_combobox.pack_start (text_renderer, true);
        resolution_combobox.add_attribute (text_renderer, "text", ResolutionColumns.NAME);

        var rotation_label = new Gtk.Label (_("Screen Rotation:")) {
            halign = Gtk.Align.START
        };
        rotation_list_store = new Gtk.ListStore (RotationColumns.TOTAL, typeof (string), typeof (int));
        for (int i = 0; i <= DisplayTransform.FLIPPED_ROTATION_270; i++) {
            Gtk.TreeIter iter;
            rotation_list_store.append (out iter);
            rotation_list_store.set (iter, RotationColumns.NAME, ((DisplayTransform) i).to_string (), RotationColumns.VALUE, i);
        }
        rotation_combobox = new Gtk.ComboBox.with_model (rotation_list_store);
        rotation_combobox.sensitive = use_switch.active;
        text_renderer = new Gtk.CellRendererText ();
        rotation_combobox.pack_start (text_renderer, true);
        rotation_combobox.add_attribute (text_renderer, "text", RotationColumns.NAME);
        rotation_combobox.set_active ((int) monitor.transform);
        // on_vm_transform_changed ();

        var refresh_label = new Gtk.Label (_("Refresh Rate:")) {
            halign = Gtk.Align.START
        };

        refresh_list_store = new Gtk.ListStore (RefreshColumns.TOTAL, typeof (string), typeof (Display.MonitorMode));
        refresh_combobox = new Gtk.ComboBox.with_model (refresh_list_store);
        refresh_combobox.sensitive = use_switch.active;
        text_renderer = new Gtk.CellRendererText ();
        refresh_combobox.pack_start (text_renderer, true);
        refresh_combobox.add_attribute (text_renderer, "text", RefreshColumns.NAME);



        Resolution[] resolutions = {};
        bool resolution_set = false;
        foreach (var mode in monitor.get_available_modes ()) {
            var mode_width = mode.width;
            var mode_height = mode.height;

            Resolution res = {mode_width, mode_height};
            if (res in resolutions) {
                continue;
            }

            resolutions += res;

            Gtk.TreeIter iter;
            resolution_list_store.append (out iter);
            resolution_list_store.set (iter, ResolutionColumns.NAME, mode.get_resolution (), ResolutionColumns.MODE, mode);
            if (mode.is_current) {
                resolution_combobox.set_active_iter (iter);
                resolution_set = true;
            }
        }

        if (!resolution_set) {
            resolution_combobox.set_active (0);
        }

        populate_refresh_rates ();

        attach (name_label, 0, 0);
        attach (use_switch, 1, 0);
        attach (resolution_label, 0, 1);
        attach (resolution_combobox, 1, 1);
        attach (rotation_label, 0, 2);
        attach (rotation_combobox, 1, 2);
        attach (refresh_label, 0, 3);
        attach (refresh_combobox, 1, 3);

        use_switch.notify ["active"].connect (() => {
            monitor.is_active = use_switch.active;
            monitors_list.active_displays += use_switch.active ? 1 : -1;
        });

        monitors_list.notify ["active-displays"].connect (() => {
            use_switch.sensitive = monitors_list.active_displays > 1;
        });
    }

    private void populate_refresh_rates () {
        refresh_list_store.clear ();

        Gtk.TreeIter iter;
        int added = 0;
        if (resolution_combobox.get_active_iter (out iter)) {
            Value val;
            resolution_list_store.get_value (iter, ResolutionColumns.MODE, out val);
            var width = ((Display.MonitorMode)val).width;
            var height = ((Display.MonitorMode)val).height;

            double[] frequencies = {};
            bool refresh_set = false;
            foreach (var mode in monitor.get_available_modes ()) {
                if (mode.width != width || mode.height != height) {
                    continue;
                }

                if (mode.frequency in frequencies) {
                    continue;
                }

                bool freq_already_added = false;
                foreach (var freq in frequencies) {
                    if ((mode.frequency - freq).abs () < 1) {
                        freq_already_added = true;
                        break;
                    }
                }

                if (freq_already_added) {
                    continue;
                }

                frequencies += mode.frequency;

                var freq_name = _("%g Hz").printf (Math.roundf ((float)mode.frequency));
                refresh_list_store.append (out iter);
                refresh_list_store.set (iter, ResolutionColumns.NAME, freq_name, ResolutionColumns.MODE, mode);
                added++;
                if (mode.is_current) {
                    refresh_combobox.set_active_iter (iter);
                    refresh_set = true;
                }
            }
        }

        refresh_combobox.sensitive = added > 1;
    }

    private void on_vm_transform_changed () {
        var transform = monitor.transform;
        rotation_list_store.@foreach ((model, path, iter) => {
            Value val;
            rotation_list_store.get_value (iter, RotationColumns.VALUE, out val);

            var iter_transform = (DisplayTransform)((int)val);
            if (iter_transform == transform) {
                rotation_combobox.set_active_iter (iter);
                return true;
            }

            return false;
        });
    }
}

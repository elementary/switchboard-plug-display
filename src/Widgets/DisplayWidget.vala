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
 */

public class Display.DisplayWidget : Gtk.EventBox {
    public signal void set_as_primary ();
    public signal void move_display (double diff_x, double diff_y);
    public signal void end_grab (int delta_x, int delta_y);
    public signal void check_position ();
    public signal void configuration_changed ();
    public signal void active_changed ();

    public Display.VirtualMonitor virtual_monitor;
    public DisplayWindow display_window;
    public double window_ratio = 1.0;
    public int delta_x { get; set; default = 0; }
    public int delta_y { get; set; default = 0; }
    public bool only_display { get; set; default = false; }
    private double start_x = 0;
    private double start_y = 0;
    private bool holding = false;

    public Gtk.Button primary_image { get; private set; }
    public Gtk.MenuButton toggle_settings { get; private set; }

    private Gtk.ComboBox resolution_combobox;
    private Gtk.ListStore resolution_list_store;

    private Gtk.ComboBox rotation_combobox;
    private Gtk.ListStore rotation_list_store;

    private Gtk.ComboBox refresh_combobox;
    private Gtk.ListStore refresh_list_store;

    public int real_width = 0;
    public int real_height = 0;

    struct Resolution {
        uint width;
        uint height;
    }

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

    public DisplayWidget (Display.VirtualMonitor virtual_monitor) {
        this.virtual_monitor = virtual_monitor;
        display_window = new DisplayWindow (virtual_monitor);
        events |= Gdk.EventMask.BUTTON_PRESS_MASK;
        events |= Gdk.EventMask.BUTTON_RELEASE_MASK;
        events |= Gdk.EventMask.POINTER_MOTION_MASK;
        virtual_monitor.get_current_mode_size (out real_width, out real_height);

        primary_image = new Gtk.Button.from_icon_name ("non-starred-symbolic", Gtk.IconSize.MENU);
        primary_image.margin = 6;
        primary_image.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        primary_image.halign = Gtk.Align.START;
        primary_image.valign = Gtk.Align.START;
        primary_image.clicked.connect (() => set_as_primary ());
        set_primary (virtual_monitor.primary);

        var virtual_monitor_name = virtual_monitor.get_display_name ();
        var label = new Gtk.Label (virtual_monitor_name);
        label.halign = Gtk.Align.CENTER;
        label.valign = Gtk.Align.CENTER;
        label.expand = true;

        var use_label = new Gtk.Label (_("Use This Display:"));
        use_label.halign = Gtk.Align.END;
        var use_switch = new Gtk.Switch ();
        use_switch.halign = Gtk.Align.START;
        use_switch.active = virtual_monitor.is_active;
        this.bind_property ("only-display", use_switch, "sensitive", GLib.BindingFlags.INVERT_BOOLEAN);

        var resolution_label = new Gtk.Label (_("Resolution:"));
        resolution_label.halign = Gtk.Align.END;

        resolution_list_store = new Gtk.ListStore (ResolutionColumns.TOTAL, typeof (string), typeof (Display.MonitorMode));
        resolution_combobox = new Gtk.ComboBox.with_model (resolution_list_store);
        resolution_combobox.sensitive = use_switch.active;
        var text_renderer = new Gtk.CellRendererText ();
        resolution_combobox.pack_start (text_renderer, true);
        resolution_combobox.add_attribute (text_renderer, "text", ResolutionColumns.NAME);

        var rotation_label = new Gtk.Label (_("Screen Rotation:"));
        rotation_label.halign = Gtk.Align.END;
        rotation_list_store = new Gtk.ListStore (RotationColumns.TOTAL, typeof (string), typeof (int));
        rotation_combobox = new Gtk.ComboBox.with_model (rotation_list_store);
        rotation_combobox.sensitive = use_switch.active;
        text_renderer = new Gtk.CellRendererText ();
        rotation_combobox.pack_start (text_renderer, true);
        rotation_combobox.add_attribute (text_renderer, "text", RotationColumns.NAME);

        var refresh_label = new Gtk.Label (_("Refresh Rate:"));
        refresh_label.halign = Gtk.Align.END;
        refresh_list_store = new Gtk.ListStore (RefreshColumns.TOTAL, typeof (string), typeof (Display.MonitorMode));
        refresh_combobox = new Gtk.ComboBox.with_model (refresh_list_store);
        refresh_combobox.sensitive = use_switch.active;
        text_renderer = new Gtk.CellRendererText ();
        refresh_combobox.pack_start (text_renderer, true);
        refresh_combobox.add_attribute (text_renderer, "text", RefreshColumns.NAME);

        for (int i = 0; i <= DisplayTransform.FLIPPED_ROTATION_270; i++) {
            Gtk.TreeIter iter;
            rotation_list_store.append (out iter);
            rotation_list_store.set (iter, RotationColumns.NAME, ((DisplayTransform) i).to_string (), RotationColumns.VALUE, i);
        }

        Resolution[] resolutions = {};
        bool resolution_set = false;
        foreach (var mode in virtual_monitor.get_available_modes ()) {
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

        var popover_grid = new Gtk.Grid ();
        popover_grid.column_spacing = 12;
        popover_grid.row_spacing = 6;
        popover_grid.margin = 12;
        popover_grid.attach (use_label, 0, 0);
        popover_grid.attach (use_switch, 1, 0);
        popover_grid.attach (resolution_label, 0, 1);
        popover_grid.attach (resolution_combobox, 1, 1);
        popover_grid.attach (rotation_label, 0, 2);
        popover_grid.attach (rotation_combobox, 1, 2);
        popover_grid.attach (refresh_label, 0, 3);
        popover_grid.attach (refresh_combobox, 1, 3);
        popover_grid.show_all ();

        var popover = new Gtk.Popover (toggle_settings);
        popover.position = Gtk.PositionType.BOTTOM;
        popover.add (popover_grid);

        toggle_settings = new Gtk.MenuButton ();
        toggle_settings.image = new Gtk.Image.from_icon_name ("open-menu-symbolic", Gtk.IconSize.MENU);
        toggle_settings.halign = Gtk.Align.END;
        toggle_settings.valign = Gtk.Align.START;
        toggle_settings.margin = 6;
        toggle_settings.popover = popover;
        toggle_settings.tooltip_text = _("Configure display");
        toggle_settings.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        var grid = new Gtk.Grid ();
        grid.attach (primary_image, 0, 0);
        grid.attach (toggle_settings, 2, 0);
        grid.attach (label, 0, 0, 3, 2);

        add (grid);

        display_window.attached_to = this;

        destroy.connect (() => display_window.destroy ());

        use_switch.notify["active"].connect (() => {
            //output_info.set_active (use_switch.active);
            resolution_combobox.sensitive = use_switch.active;
            rotation_combobox.sensitive = use_switch.active;
            refresh_combobox.sensitive = use_switch.active;

            if (rotation_combobox.active == -1) rotation_combobox.set_active (0);
            if (resolution_combobox.active == -1) resolution_combobox.set_active (0);
            if (refresh_combobox.active == -1) refresh_combobox.set_active (0);

            if (use_switch.active) {
                get_style_context ().remove_class ("disabled");
            } else {
                get_style_context ().add_class ("disabled");
            }

            configuration_changed ();
            active_changed ();
        });

        if (!virtual_monitor.is_active) {
            get_style_context ().add_class ("disabled");
        }

        resolution_combobox.changed.connect (() => {
            Value val;
            Gtk.TreeIter iter;
            resolution_combobox.get_active_iter (out iter);
            resolution_list_store.get_value (iter, ResolutionColumns.MODE, out val);
            Display.MonitorMode new_mode = (Display.MonitorMode) val;
            set_geometry (virtual_monitor.x, virtual_monitor.y, (int)new_mode.width, (int)new_mode.height);
            virtual_monitor.set_current_mode (new_mode);
            rotation_combobox.set_active (0);
            populate_refresh_rates ();
            configuration_changed ();
            check_position ();
        });

        rotation_combobox.changed.connect (() => {
            Value val;
            Gtk.TreeIter iter;
            rotation_combobox.get_active_iter (out iter);
            rotation_list_store.get_value (iter, RotationColumns.VALUE, out val);

            var transform = (DisplayTransform)((int)val);
            virtual_monitor.transform = transform;

            switch (transform) {
                case DisplayTransform.NORMAL:
                    virtual_monitor.get_current_mode_size (out real_width, out real_height);
                    label.angle = 0;
                    label.label = virtual_monitor_name;
                    break;
                case DisplayTransform.ROTATION_90:
                    virtual_monitor.get_current_mode_size (out real_height, out real_width);
                    label.angle = 270;
                    label.label = virtual_monitor_name;
                    break;
                case DisplayTransform.ROTATION_180:
                    virtual_monitor.get_current_mode_size (out real_width, out real_height);
                    label.angle = 180;
                    label.label = virtual_monitor_name;
                    break;
                case DisplayTransform.ROTATION_270:
                    virtual_monitor.get_current_mode_size (out real_height, out real_width);
                    label.angle = 90;
                    label.label = virtual_monitor_name;
                    break;
                case DisplayTransform.FLIPPED:
                    virtual_monitor.get_current_mode_size (out real_width, out real_height);
                    label.angle = 0;
                    label.label = virtual_monitor_name.reverse (); //mirroring simulation, because we can't really mirror the text
                    break;
                case DisplayTransform.FLIPPED_ROTATION_90:
                    virtual_monitor.get_current_mode_size (out real_height, out real_width);
                    label.angle = 270;
                    label.label = virtual_monitor_name.reverse ();
                    break;
                case DisplayTransform.FLIPPED_ROTATION_180:
                    virtual_monitor.get_current_mode_size (out real_width, out real_height);
                    label.angle = 180;
                    label.label = virtual_monitor_name.reverse ();
                    break;
                case DisplayTransform.FLIPPED_ROTATION_270:
                    virtual_monitor.get_current_mode_size (out real_height, out real_width);
                    label.angle = 90;
                    label.label = virtual_monitor_name.reverse ();
                    break;
            }

            configuration_changed ();
            check_position ();
        });

        refresh_combobox.changed.connect (() => {
            Value val;
            Gtk.TreeIter iter;
            refresh_combobox.get_active_iter (out iter);
            refresh_list_store.get_value (iter, ResolutionColumns.MODE, out val);
            Display.MonitorMode new_mode = (Display.MonitorMode) val;
            virtual_monitor.set_current_mode (new_mode);
            rotation_combobox.set_active (0);
            configuration_changed ();
            check_position ();
        });

        rotation_combobox.set_active ((int) virtual_monitor.transform);
        on_vm_transform_changed ();

        virtual_monitor.modes_changed.connect (on_monitor_modes_changed);
        virtual_monitor.notify["transform"].connect (on_vm_transform_changed);

        configuration_changed ();
        check_position ();
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
            foreach (var mode in virtual_monitor.get_available_modes ()) {
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

    private void on_monitor_modes_changed () {
        foreach (var mode in virtual_monitor.get_available_modes ()) {
            if (!mode.is_current) {
                continue;
            }

            resolution_list_store.@foreach ((model, path, iter) => {
                Value val;
                resolution_list_store.get_value (iter, ResolutionColumns.MODE, out val);
                if (((Display.MonitorMode)val).id == mode.id) {
                    resolution_combobox.set_active_iter (iter);
                    return true;
                }

                return false;
            });
        }
    }

    private void on_vm_transform_changed () {
        var transform = virtual_monitor.transform;
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

    public override bool button_press_event (Gdk.EventButton event) {
        if (only_display) {
            return false;
        }

        start_x = event.x_root;
        start_y = event.y_root;
        holding = true;
        return false;
    }

    public override bool button_release_event (Gdk.EventButton event) {
        holding = false;
        if ((delta_x == 0 && delta_y == 0) || only_display) {
            return false;
        }

        var old_delta_x = delta_x;
        var old_delta_y = delta_y;
        delta_x = 0;
        delta_y = 0;
        end_grab (old_delta_x, old_delta_y);
        return false;
    }

    public override bool motion_notify_event (Gdk.EventMotion event) {
        if (holding && !only_display) {
            move_display (event.x_root - start_x, event.y_root - start_y);
        }

        return false;
    }

    public void set_primary (bool is_primary) {
        if (is_primary) {
            ((Gtk.Image) primary_image.image).icon_name = "starred-symbolic";
            primary_image.tooltip_text = _("Is the primary display");
        } else {
            ((Gtk.Image) primary_image.image).icon_name = "non-starred-symbolic";
            primary_image.tooltip_text = _("Set as primary display");
        }
    }

    public override void get_preferred_width (out int minimum_width, out int natural_width) {
        minimum_width = (int)(real_width * window_ratio);
        natural_width = minimum_width;
    }

    public override void get_preferred_height (out int minimum_height, out int natural_height) {
        minimum_height = (int)(real_height * window_ratio);
        natural_height = minimum_height;
    }

    public void get_geometry (out int x, out int y, out int width, out int height) {
        x = virtual_monitor.x;
        y = virtual_monitor.y;
        width = real_width;
        height = real_height;
    }

    public void set_geometry (int x, int y, int width, int height) {
        virtual_monitor.x = x;
        virtual_monitor.y = y;
        real_width = width;
        real_height = height;
    }

    public bool equals (DisplayWidget sibling) {
        return virtual_monitor.id == sibling.virtual_monitor.id;
    }
}

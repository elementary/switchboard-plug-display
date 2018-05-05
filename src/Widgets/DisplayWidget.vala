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
    public signal void move_display (int delta_x, int delta_y);
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
    private Gtk.Button primary_image;

    private Gtk.ComboBox resolution_combobox;
    private Gtk.ListStore resolution_list_store;
    
    private Gtk.ComboBox rotation_combobox;
    private Gtk.ListStore rotation_list_store;

    private int real_width = 0;
    private int real_height = 0;
    private int real_x = 0;
    private int real_y = 0;

    struct Resolution {
        uint width;
        uint height;
    }

    public DisplayWidget (Display.VirtualMonitor virtual_monitor) {
        this.virtual_monitor = virtual_monitor;
        display_window = new DisplayWindow (virtual_monitor);
        events |= Gdk.EventMask.BUTTON_PRESS_MASK;
        events |= Gdk.EventMask.BUTTON_RELEASE_MASK;
        events |= Gdk.EventMask.POINTER_MOTION_MASK;
        real_x = virtual_monitor.x;
        real_y = virtual_monitor.y;
        virtual_monitor.get_current_mode_size (out real_width, out real_height);

        primary_image = new Gtk.Button.from_icon_name ("non-starred-symbolic", Gtk.IconSize.MENU);
        primary_image.margin = 6;
        primary_image.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        primary_image.halign = Gtk.Align.START;
        primary_image.valign = Gtk.Align.START;
        primary_image.clicked.connect (() => set_as_primary ());
        set_primary (virtual_monitor.primary);

        var toggle_settings = new Gtk.ToggleButton ();
        toggle_settings.margin = 6;
        toggle_settings.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        toggle_settings.halign = Gtk.Align.END;
        toggle_settings.valign = Gtk.Align.START;
        toggle_settings.image = new Gtk.Image.from_icon_name ("open-menu-symbolic", Gtk.IconSize.MENU);
        toggle_settings.tooltip_text = _("Configure display");

        var label = new Gtk.Label (virtual_monitor.monitor.display_name);
        label.halign = Gtk.Align.CENTER;
        label.valign = Gtk.Align.CENTER;
        label.expand = true;

        var grid = new Gtk.Grid ();
        grid.attach (primary_image, 0, 0, 1, 1);
        grid.attach (toggle_settings, 2, 0, 1, 1);
        grid.attach (label, 0, 0, 3, 2);
        add (grid);

        var popover_grid = new Gtk.Grid ();
        popover_grid.column_spacing = 12;
        popover_grid.row_spacing = 6;
        popover_grid.margin = 12;
        var popover = new Gtk.Popover (toggle_settings);
        popover.position = Gtk.PositionType.BOTTOM;
        popover.bind_property ("visible", toggle_settings, "active", GLib.BindingFlags.BIDIRECTIONAL);
        popover.add (popover_grid);

        var use_label = new Gtk.Label (_("Use This Display:"));
        use_label.halign = Gtk.Align.END;
        var use_switch = new Gtk.Switch ();
        use_switch.halign = Gtk.Align.START;
        use_switch.active = virtual_monitor.is_active;
        this.bind_property ("only-display", use_switch, "sensitive", GLib.BindingFlags.INVERT_BOOLEAN);

        var resolution_label = new Gtk.Label (_("Resolution:"));
        resolution_label.halign = Gtk.Align.END;

        resolution_list_store = new Gtk.ListStore (2, typeof (string), typeof (Display.MonitorMode));
        resolution_combobox = new Gtk.ComboBox.with_model (resolution_list_store);
        resolution_combobox.sensitive = use_switch.active;
        var text_renderer = new Gtk.CellRendererText ();
        resolution_combobox.pack_start (text_renderer, true);
        resolution_combobox.add_attribute (text_renderer, "text", 0);

        var rotation_label = new Gtk.Label (_("Rotation:"));
        rotation_label.halign = Gtk.Align.END;
        rotation_list_store = new Gtk.ListStore (2, typeof (string), typeof (int));
        rotation_combobox = new Gtk.ComboBox.with_model (rotation_list_store);
        rotation_combobox.sensitive = use_switch.active;
        text_renderer = new Gtk.CellRendererText ();
        rotation_combobox.pack_start (text_renderer, true);
        rotation_combobox.add_attribute (text_renderer, "text", 0);

        for (int i = 0; i <= DisplayTransform.FLIPPED_ROTATION_270; i++) {
            Gtk.TreeIter iter;
            rotation_list_store.append (out iter);
            rotation_list_store.set (iter, 0, ((DisplayTransform) i).to_string (), 1, i);
        }

        Resolution[] resolutions = {};
        bool resolution_set = false;
        foreach (var mode in virtual_monitor.monitor.modes) {
            var mode_width = mode.width;
            var mode_height = mode.height;

            Resolution res = {mode_width, mode_height};
            if (res in resolutions) {
                continue;
            }

            resolutions += res;

            Gtk.TreeIter iter;
            resolution_list_store.append (out iter);
            resolution_list_store.set (iter, 0, mode.get_resolution (), 1, mode);
            if (mode.is_current) {
                resolution_combobox.set_active_iter (iter);
                resolution_set = true;
            }
        }

        if (!resolution_set) {
            resolution_combobox.set_active (0);
        }

        popover_grid.attach (use_label, 0, 0, 1, 1);
        popover_grid.attach (use_switch, 1, 0, 1, 1);
        popover_grid.attach (resolution_label, 0, 1, 1, 1);
        popover_grid.attach (resolution_combobox, 1, 1, 1, 1);
        popover_grid.attach (rotation_label, 0, 2, 1, 1);
        popover_grid.attach (rotation_combobox, 1, 2, 1, 1);
        popover_grid.show_all ();
        display_window.attached_to = this;
        destroy.connect (() => display_window.destroy ());
        use_switch.notify["active"].connect (() => {
            //output_info.set_active (use_switch.active);
            resolution_combobox.sensitive = use_switch.active;
            rotation_combobox.sensitive = use_switch.active;

            if (rotation_combobox.active == -1) rotation_combobox.set_active (0);
            if (resolution_combobox.active == -1) resolution_combobox.set_active (0);

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

        bool rotation_set = false;
        resolution_combobox.changed.connect (() => {
            Value val;
            Gtk.TreeIter iter;
            resolution_combobox.get_active_iter (out iter);
            resolution_list_store.get_value (iter, 1, out val);
            set_geometry (real_x, real_y, (int)((Display.MonitorMode) val).width, (int)((Display.MonitorMode) val).height);
            virtual_monitor.monitor.current_mode.is_current = false;
            ((Display.MonitorMode)val).is_current = true;
            rotation_set = false;
            rotation_combobox.set_active (0);
            rotation_set = true;
            configuration_changed ();
            check_position ();
        });

        rotation_combobox.changed.connect (() => {
            Value val;
            Gtk.TreeIter iter;
            rotation_combobox.get_active_iter (out iter);
            rotation_list_store.get_value (iter, 1, out val);

            var transform = (DisplayTransform)((int)val);
            virtual_monitor.transform = transform;

            switch (transform) {
                case DisplayTransform.ROTATION_90:
                    virtual_monitor.get_current_mode_size (out real_height, out real_width);
                    label.angle = 270;
                    break;
                case DisplayTransform.ROTATION_180:
                    virtual_monitor.get_current_mode_size (out real_width, out real_height);
                    label.angle = 180;
                    break;
                case DisplayTransform.ROTATION_270:
                    virtual_monitor.get_current_mode_size (out real_height, out real_width);
                    label.angle = 90;
                    break;
                default:
                    virtual_monitor.get_current_mode_size (out real_width, out real_height);
                    label.angle = 0;
                    break;
            }

            rotation_set = true;
            configuration_changed ();
            check_position ();
        });

        //  Gtk.TreeIter iter;

        //  rotation_list_store.append (out iter);
        //  rotation_list_store.set (iter, 0, _("None"), 1, DisplayTransform.ROTATION_0);

        //  if (output_info.supports_rotation (DisplayTransform.ROTATION_90)) {
        //      rotation_list_store.append (out iter);
        //      rotation_list_store.set (iter, 0, _("Clockwise"), 1, DisplayTransform.ROTATION_90);
        //      if (output_info.get_rotation () == DisplayTransform.ROTATION_90) {
        //          rotation_combobox.set_active_iter (iter);
        //          label.angle = 270;
        //          rotation_set = true;
        //      }
        //  }

        //  if (output_info.supports_rotation (DisplayTransform.ROTATION_180)) {
        //      rotation_list_store.append (out iter);
        //      rotation_list_store.set (iter, 0, _("Flipped"), 1, DisplayTransform.ROTATION_180);
        //      if (output_info.get_rotation () == DisplayTransform.ROTATION_180) {
        //          rotation_combobox.set_active_iter (iter);
        //          label.angle = 180;
        //          rotation_set = true;
        //      }
        //  }

        //  if (output_info.supports_rotation (DisplayTransform.ROTATION_270)) {
        //      rotation_list_store.append (out iter);
        //      rotation_list_store.set (iter, 0, _("Counterclockwise"), 1, DisplayTransform.ROTATION_270);
        //      if (output_info.get_rotation () == DisplayTransform.ROTATION_270) {
        //          rotation_combobox.set_active_iter (iter);
        //          label.angle = 90;
        //          rotation_set = true;
        //      }
        //  }

        rotation_combobox.set_active (0);
        on_vm_transform_changed ();

        virtual_monitor.monitor.modes_changed.connect (on_monitor_modes_changed);
        virtual_monitor.notify["transform"].connect (on_vm_transform_changed);

        configuration_changed ();
        check_position ();
    }

    private void on_monitor_modes_changed () {
        foreach (var mode in virtual_monitor.monitor.modes) {
            if (!mode.is_current) {
                continue;
            }

            resolution_list_store.@foreach ((model, path, iter) => {
                Value val;
                resolution_list_store.get_value (iter, 1, out val);
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
            rotation_list_store.get_value (iter, 1, out val);

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
        if ((delta_x == 0 && delta_y == 0) || only_display) {
            return false;
        }

        var old_delta_x = delta_x;
        var old_delta_y = delta_y;
        delta_x = 0;
        delta_y = 0;
        move_display (old_delta_x, old_delta_y);
        holding = false;
        return false;
    }

    public override bool motion_notify_event (Gdk.EventMotion event) {
        if (holding && !only_display) {
            delta_x = (int)(event.x_root - start_x);
            delta_y = (int)(event.y_root - start_y);
            check_position ();
        }

        return false;
    }

    public void set_primary (bool is_primary) {
        //output_info.set_primary (is_primary);
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
        x = real_x;
        y = real_y;
        width = real_width;
        height = real_height;
    }

    public void set_geometry (int x, int y, int width, int height) {
        real_x = x;
        real_y = y;
        real_width = width;
        real_height = height;
    }

    public bool equals (DisplayWidget sibling) {
        return virtual_monitor.monitor.serial == sibling.virtual_monitor.monitor.serial;
    }
}

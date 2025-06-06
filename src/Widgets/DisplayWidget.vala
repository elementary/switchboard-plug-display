/*-
 * Copyright 2014–2024 elementary, Inc.
 *           2014–2018 Corentin Noël <corentin@elementary.io>
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
 */

public class Display.DisplayWidget : Gtk.Box {
    public signal void set_as_primary ();
    public signal void check_position ();
    public signal void configuration_changed ();
    public signal void active_changed ();

    public Display.VirtualMonitor virtual_monitor { get; construct; }
    public string bg_color { get; construct; }
    public string text_color { get; construct; }
    public string display_name { get {return virtual_monitor.get_display_name (); }}

    public double window_ratio { get; private set; default = 1.0; }
    public bool connected { get; set; }

    private Gtk.Button primary_image;
    private Granite.SwitchModelButton use_switch;

    private Display.ResolutionDropDown resolution_drop_down;
    private Display.RotationDropDown rotation_drop_down;
    private Display.RefreshRateDropDown refresh_rate_drop_down;

    private Gtk.DropDown scale_drop_down;

    private int real_width = 0;
    private int real_height = 0;

    public DisplayWidget (Display.VirtualMonitor virtual_monitor, string bg_color, string text_color) {
        Object (
            virtual_monitor: virtual_monitor,
            bg_color: bg_color,
            text_color: text_color
        );
    }

    class construct {
        set_css_name ("display-widget");
    }

    construct {
        virtual_monitor.get_current_mode_size (out real_width, out real_height);

        primary_image = new Gtk.Button.from_icon_name ("non-starred-symbolic") {
            has_frame = false,
            halign = START,
            valign = START
        };
        primary_image.clicked.connect (() => set_as_primary ());

        var virtual_monitor_name = virtual_monitor.get_display_name ();
        var label = new Gtk.Label (virtual_monitor_name) {
            halign = CENTER,
            valign = CENTER,
            hexpand = true,
            vexpand = true
        };

        rotation_drop_down = new Display.RotationDropDown (virtual_monitor);
        var rotation_label = new Granite.HeaderLabel (_("Screen Rotation")) {
            mnemonic_widget = rotation_drop_down
        };

        refresh_rate_drop_down = new Display.RefreshRateDropDown (virtual_monitor);
        var refresh_label = new Granite.HeaderLabel (_("Refresh Rate")) {
            mnemonic_widget = refresh_rate_drop_down
        };

        resolution_drop_down = new Display.ResolutionDropDown (virtual_monitor);
        var resolution_label = new Granite.HeaderLabel (_("Resolution")) {
            mnemonic_widget = resolution_drop_down
        };

        var scale_drop_down_factory = new Gtk.SignalListItemFactory ();
        scale_drop_down_factory.setup.connect ((obj) => {
            var list_item = (Gtk.ListItem) obj;
            list_item.child = new Gtk.Label (null) { xalign = 0 };
        });
        scale_drop_down_factory.bind.connect ((obj) => {
            var list_item = (Gtk.ListItem) obj;
            var item = (VirtualMonitor.Scale) list_item.item;
            var scale_label = (Gtk.Label) list_item.child;
            scale_label.label = item.string_representation;
        });

        scale_drop_down = new Gtk.DropDown (virtual_monitor.available_scales, null) {
            margin_start = 12,
            margin_end = 12,
            factory = scale_drop_down_factory
        };
        virtual_monitor.available_scales.bind_property (
            "selected",
            scale_drop_down,
            "selected", BIDIRECTIONAL | SYNC_CREATE
        );

        var scale_label = new Granite.HeaderLabel (_("Scaling factor")) {
            mnemonic_widget = scale_drop_down
        };

        use_switch = new Granite.SwitchModelButton (_("Use This Display"));
        use_switch.bind_property ("active", resolution_drop_down, "sensitive");
        use_switch.bind_property ("active", rotation_drop_down, "sensitive");
        use_switch.bind_property ("active", refresh_rate_drop_down, "sensitive");
        use_switch.bind_property ("active", scale_drop_down, "sensitive");

        virtual_monitor.bind_property (
            "is-active",
            use_switch,
            "active",
            GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.BIDIRECTIONAL
        );

        var popover_box = new Gtk.Box (VERTICAL, 0) {
            margin_top = 6,
            margin_bottom = 12
        };
        popover_box.append (use_switch);
        popover_box.append (resolution_label);
        popover_box.append (resolution_drop_down);
        popover_box.append (rotation_label);
        popover_box.append (rotation_drop_down);
        popover_box.append (refresh_label);
        popover_box.append (refresh_rate_drop_down);

        if (!MonitorManager.get_default ().global_scale_required) {
            popover_box.append (scale_label);
            popover_box.append (scale_drop_down);
        }

        var popover = new Gtk.Popover () {
            child = popover_box,
            position = BOTTOM
        };

        var toggle_settings = new Gtk.MenuButton () {
            has_frame = false,
            halign = END,
            valign = START,
            icon_name = "open-menu-symbolic",
            popover = popover,
            tooltip_text = _("Configure display")
        };

        var grid = new Gtk.Grid ();
        grid.attach (primary_image, 0, 0);
        grid.attach (toggle_settings, 2, 0);
        grid.attach (label, 0, 0, 3, 2);

        append (grid);

        set_primary (virtual_monitor.primary);

        use_switch.notify["active"].connect (() => {
            if (rotation_drop_down.selected == -1) rotation_drop_down.set_selected_rotation (0);
            if (resolution_drop_down.selected == -1) resolution_drop_down.set_selected_resolution (0);
            if (refresh_rate_drop_down.selected == -1) refresh_rate_drop_down.set_selected_refresh_rate (0);

            if (use_switch.active) {
                remove_css_class ("disabled");
            } else {
                add_css_class ("disabled");
            }

            configuration_changed ();
            active_changed ();
        });

        if (!virtual_monitor.is_active) {
            add_css_class ("disabled");
        }

        resolution_drop_down.resolution_changed.connect ((selected_option) => {
            // Prevent breaking autohide by closing popover
            popover.popdown ();

            set_virtual_monitor_geometry (
                virtual_monitor.x,
                virtual_monitor.y,
                selected_option.width,
                selected_option.height
            );
            var new_mode = virtual_monitor.get_modes_for_resolution (selected_option.width, selected_option.height);
            if (new_mode == null) {
                return;
            }

            virtual_monitor.set_current_mode (new_mode.get (0));
            rotation_drop_down.set_selected_rotation (0);
            refresh_rate_drop_down.update_refresh_rates (selected_option.width, selected_option.height);
            configuration_changed ();
            check_position ();
        });

        rotation_drop_down.rotation_selected.connect ((obj) => {
            // Prevent breaking autohide by closing popover
            popover.popdown ();

            var transform = (DisplayTransform)obj.value;

            label.css_classes = {""};

            switch (transform) {
                case DisplayTransform.NORMAL:
                    virtual_monitor.get_current_mode_size (out real_width, out real_height);
                    label.label = virtual_monitor_name;
                    break;
                case DisplayTransform.ROTATION_90:
                    virtual_monitor.get_current_mode_size (out real_height, out real_width);
                    label.add_css_class ("rotate-270");
                    label.label = virtual_monitor_name;
                    break;
                case DisplayTransform.ROTATION_180:
                    virtual_monitor.get_current_mode_size (out real_width, out real_height);
                    label.add_css_class ("rotate-180");
                    label.label = virtual_monitor_name;
                    break;
                case DisplayTransform.ROTATION_270:
                    virtual_monitor.get_current_mode_size (out real_height, out real_width);
                    label.add_css_class ("rotate-90");
                    label.label = virtual_monitor_name;
                    break;
                case DisplayTransform.FLIPPED:
                    virtual_monitor.get_current_mode_size (out real_width, out real_height);
                    label.label = virtual_monitor_name.reverse (); //mirroring simulation, because we can't really mirror the text
                    break;
                case DisplayTransform.FLIPPED_ROTATION_90:
                    virtual_monitor.get_current_mode_size (out real_height, out real_width);
                    label.add_css_class ("rotate-270");
                    label.label = virtual_monitor_name.reverse ();
                    break;
                case DisplayTransform.FLIPPED_ROTATION_180:
                    virtual_monitor.get_current_mode_size (out real_width, out real_height);
                    label.add_css_class ("rotate-180");
                    label.label = virtual_monitor_name.reverse ();
                    break;
                case DisplayTransform.FLIPPED_ROTATION_270:
                    virtual_monitor.get_current_mode_size (out real_height, out real_width);
                    label.add_css_class ("rotate-90");
                    label.label = virtual_monitor_name.reverse ();
                    break;
            }

            configuration_changed ();
            check_position ();
        });

        refresh_rate_drop_down.refresh_rate_selected.connect ((obj) => {
            // Prevent breaking autohide by closing popover
            popover.popdown ();
 
            virtual_monitor.set_current_mode (obj.mode);
            rotation_drop_down.set_selected_rotation (0);
            configuration_changed ();
            check_position ();
        });

        scale_drop_down.notify["selected-item"].connect (() => {
            // Prevent breaking autohide by closing popover
            popover.popdown ();

            configuration_changed ();
        });

        rotation_drop_down.set_selected_rotation ((int) virtual_monitor.transform);
        on_vm_transform_changed ();

        virtual_monitor.modes_changed.connect (on_monitor_modes_changed);
        virtual_monitor.notify["transform"].connect (on_vm_transform_changed);

        configuration_changed ();
        check_position ();
    }

    private void on_monitor_modes_changed () {
        resolution_drop_down.set_active_resolution_from_current_mode ();
    }

    private void on_vm_transform_changed () {
        rotation_drop_down.set_selected_rotation ((int) virtual_monitor.transform);
    }

    public void set_primary (bool is_primary) {
        if (is_primary) {
            primary_image.icon_name = "starred-symbolic";
            primary_image.tooltip_text = _("Is the primary display");
        } else {
            primary_image.icon_name = "non-starred-symbolic";
            primary_image.tooltip_text = _("Set as primary display");
        }

        use_switch.sensitive = !is_primary;
    }

    public new void get_preferred_size (out Gtk.Requisition minimum_size, out Gtk.Requisition natural_size) {
        minimum_size = Gtk.Requisition () {
            height = (int)(real_height * window_ratio),
            width = (int)(real_width * window_ratio)
        };

        natural_size = minimum_size;
    }

    public void get_virtual_monitor_geometry (out int x, out int y, out int width, out int height) {
        x = virtual_monitor.x;
        y = virtual_monitor.y;
        width = real_width;
        height = real_height;
    }

    public void set_virtual_monitor_geometry (int x, int y, int width, int height) {
        virtual_monitor.x = x;
        virtual_monitor.y = y;
        real_width = width;
        real_height = height;

        queue_resize ();
    }

    public void move_x (int dx) {
        virtual_monitor.x += dx;
        queue_resize ();
    }

    public void move_y (int dy) {
        virtual_monitor.y += dy;
        queue_resize ();
    }

    public bool equals (DisplayWidget sibling) {
        return virtual_monitor.id == sibling.virtual_monitor.id;
    }
}

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

public struct Display.Resolution {
    int width;
    int height;
    int aspect;
    bool is_preferred;
    bool is_current;
}

public class Display.DisplayWidget : Gtk.Box {
    private static double[] scales;
    private static string[] string_scales;

    static construct {
        unowned var monitor_manager = MonitorManager.get_default ();

        if (monitor_manager.fractional_scale_enabled) {
            scales = { 0.75, 1.00, 1.25, 1.50, 1.75, 2.00 };
        } else {
            scales = { 1.00, 2.00 };
        }

        foreach (var scale in scales) {
            string_scales += "%d %%".printf ((int) (scale * 100));
        }
    }

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

    private Gtk.Label label;

    private Gtk.Button primary_image;
    private Granite.SwitchModelButton use_switch;

    private Gtk.ComboBox resolution_combobox;
    private Gtk.TreeStore resolution_tree_store;

    private Gtk.DropDown refresh_drop_down;
    private Gtk.DropDown scale_drop_down;

    private int real_width = 0;
    private int real_height = 0;

    private enum ResolutionColumns {
        NAME,
        WIDTH,
        HEIGHT,
        TOTAL
    }

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
        label = new Gtk.Label (virtual_monitor_name) {
            halign = CENTER,
            valign = CENTER,
            hexpand = true,
            vexpand = true
        };

        use_switch = new Granite.SwitchModelButton (_("Use This Display"));

        virtual_monitor.bind_property ("is-active", use_switch, "active", GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.BIDIRECTIONAL);

        resolution_tree_store = new Gtk.TreeStore (ResolutionColumns.TOTAL, typeof (string), typeof (int), typeof (int));
        resolution_combobox = new Gtk.ComboBox.with_model (resolution_tree_store) {
            margin_start = 12,
            margin_end = 12
        };

        var resolution_label = new Granite.HeaderLabel (_("Resolution")) {
            mnemonic_widget = resolution_combobox
        };

        var text_renderer = new Gtk.CellRendererText ();
        resolution_combobox.pack_start (text_renderer, true);
        resolution_combobox.add_attribute (text_renderer, "text", ResolutionColumns.NAME);

        var rotation_drop_down = new Gtk.DropDown (virtual_monitor.available_transforms, null) {
            margin_start = 12,
            margin_end = 12,
            factory = Utils.create_string_list_item_factory ()
        };
        virtual_monitor.available_transforms.bind_property ("selected", rotation_drop_down, "selected", BIDIRECTIONAL | SYNC_CREATE);

        var rotation_label = new Granite.HeaderLabel (_("Screen Rotation")) {
            mnemonic_widget = rotation_drop_down
        };

        refresh_drop_down = new Gtk.DropDown (virtual_monitor.available_refresh_rates, null) {
            margin_start = 12,
            margin_end = 12,
            factory = Utils.create_string_list_item_factory ()
        };
        virtual_monitor.available_refresh_rates.bind_property ("selected", refresh_drop_down, "selected", BIDIRECTIONAL | SYNC_CREATE);
        virtual_monitor.available_refresh_rates.items_changed.connect (() => refresh_drop_down.sensitive = virtual_monitor.available_refresh_rates.n_items > 1);

        var refresh_label = new Granite.HeaderLabel (_("Refresh Rate")) {
            mnemonic_widget = refresh_drop_down
        };

        // Build resolution menu
        // First, get list of unique resolutions from available modes.
        Resolution[] resolutions = {};
        Resolution[] recommended_resolutions = {};
        Resolution[] other_resolutions = {};
        int max_width = -1;
        int max_height = -1;
        uint usable_resolutions = 0;
        int current_width, current_height;
        virtual_monitor.get_current_mode_size (out current_width, out current_height);
        var resolution_set = new Gee.TreeSet<Display.MonitorMode> (Display.MonitorMode.resolution_compare_func);
        foreach (var mode in virtual_monitor.get_available_modes ()) {
            resolution_set.add (mode); // Ensures resolutions unique and sorted
        }

        foreach (var mode in resolution_set) {
            var mode_width = mode.width;
            var mode_height = mode.height;
            if (mode.is_preferred) {
                max_width = int.max (max_width, mode_width);
                max_height = int.max (max_height, mode_height);
            }

            Resolution res = {mode_width, mode_height, mode_width * 10 / mode_height, mode.is_preferred, mode.is_current};
            resolutions += res;
        }

        var native_ratio = max_width * 10 / max_height;
         // Split resolutions into recommended and other
         foreach (var resolution in resolutions) {
             // Reject all resolutions incompatible with elementary desktop
             if (resolution.width < 1024 || resolution.height < 768) {
                continue;
            }

            if (resolution.is_preferred || resolution.is_current || resolution.aspect == native_ratio) {
                recommended_resolutions += resolution;
            } else {
                other_resolutions += resolution;
            }

            usable_resolutions++;
        }

        foreach (var resolution in recommended_resolutions) {
            Gtk.TreeIter iter;
            resolution_tree_store.append (out iter, null);
            resolution_tree_store.set (iter,
                ResolutionColumns.NAME, MonitorMode.get_resolution_string (resolution.width, resolution.height, false),
                ResolutionColumns.WIDTH, resolution.width,
                ResolutionColumns.HEIGHT, resolution.height
            );
        }

        if (other_resolutions.length > 0) {
            Gtk.TreeIter iter;
            Gtk.TreeIter parent_iter;
            resolution_tree_store.append (out parent_iter, null);
            resolution_tree_store.set (parent_iter, ResolutionColumns.NAME, _("Other…"),
                ResolutionColumns.WIDTH, -1,
                ResolutionColumns.HEIGHT, -1
            );

            foreach (var resolution in other_resolutions) {
                resolution_tree_store.append (out iter, parent_iter);
                resolution_tree_store.set (iter,
                    ResolutionColumns.NAME, Display.MonitorMode.get_resolution_string (resolution.width, resolution.height, true),
                    ResolutionColumns.WIDTH, resolution.width,
                    ResolutionColumns.HEIGHT, resolution.height
                );
            }
        }

        if (!set_active_resolution_from_current_mode ()) {
            resolution_combobox.set_active (0);
        }

        resolution_combobox.sensitive = usable_resolutions > 1;

        scale_drop_down = new Gtk.DropDown.from_strings (string_scales) {
            margin_start = 12,
            margin_end = 12
        };

        var scale_label = new Granite.HeaderLabel (_("Scaling factor")) {
            mnemonic_widget = scale_drop_down
        };

        var popover_box = new Gtk.Box (VERTICAL, 0) {
            margin_top = 6,
            margin_bottom = 12
        };
        popover_box.append (use_switch);
        popover_box.append (resolution_label);
        popover_box.append (resolution_combobox);
        popover_box.append (rotation_label);
        popover_box.append (rotation_drop_down);
        popover_box.append (refresh_label);
        popover_box.append (refresh_drop_down);

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

        use_switch.bind_property ("active", resolution_combobox, "sensitive");
        use_switch.bind_property ("active", rotation_drop_down, "sensitive");
        use_switch.bind_property ("active", refresh_drop_down, "sensitive");
        use_switch.bind_property ("active", scale_drop_down, "sensitive");

        use_switch.notify["active"].connect (() => {
            if (resolution_combobox.active == -1) resolution_combobox.set_active (0);

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

        resolution_combobox.changed.connect (() => {
            // Prevent breaking autohide by closing popover
            popover.popdown ();

            int active_width, active_height;
            Gtk.TreeIter iter;
            if (resolution_combobox.get_active_iter (out iter)) {
                resolution_tree_store.get (iter,
                    ResolutionColumns.WIDTH, out active_width,
                    ResolutionColumns.HEIGHT, out active_height
                );
            } else {
                return;
            }

            set_virtual_monitor_geometry (virtual_monitor.x, virtual_monitor.y, active_width, active_height);
            var new_mode = virtual_monitor.get_mode_for_resolution (active_width, active_height);
            if (new_mode == null) {
                return;
            }

            virtual_monitor.set_current_mode (new_mode);
            configuration_changed ();
            check_position ();
        });

        rotation_drop_down.notify["selected"].connect (() => {
            // Prevent breaking autohide by closing popover
            popover.popdown ();

            update_transformed_style ();

            configuration_changed ();
        });

        refresh_drop_down.notify["selected"].connect (() => {
            // Prevent breaking autohide by closing popover
            popover.popdown ();

            configuration_changed ();
        });

        virtual_monitor.notify["scale"].connect (update_selected_scale);
        update_selected_scale ();
        scale_drop_down.notify["selected-item"].connect ((drop_down, param_spec) => {
            // Prevent breaking autohide by closing popover
            popover.popdown ();

            var i = ((Gtk.DropDown) drop_down).selected;

            if (i < 0 || i > scales.length) {
                warning ("Invalid scale selected.");
                return;
            }

            virtual_monitor.scale = scales[i];

            configuration_changed ();
        });

        virtual_monitor.modes_changed.connect (on_monitor_modes_changed);

        update_transformed_style ();

        configuration_changed ();
        check_position ();
    }

    private void update_selected_scale () {
        for (uint i = 0; i < scales.length; i++) {
            if (scales[i] == virtual_monitor.scale) {
                scale_drop_down.selected = i;
            }
        }
    }

    private void on_monitor_modes_changed () {
        set_active_resolution_from_current_mode ();
    }

    private bool set_active_resolution_from_current_mode () {
        bool result = false;
        foreach (var mode in virtual_monitor.get_available_modes ()) {
            if (!mode.is_current) {
                continue;
            }

            resolution_tree_store.@foreach ((model, path, iter) => {
                int width, height;
                resolution_tree_store.get (iter,
                    ResolutionColumns.WIDTH, out width,
                    ResolutionColumns.HEIGHT, out height
                );
                if (mode.width == width && mode.height == height) {
                    resolution_combobox.set_active_iter (iter);
                    result = true;
                    return true;
                }

                return false;
            });
        }

        return result;
    }

    private void update_transformed_style () {
        label.css_classes = {""};

        switch (virtual_monitor.transform) {
            case DisplayTransform.NORMAL:
                virtual_monitor.get_current_mode_size (out real_width, out real_height);
                label.label = virtual_monitor.get_display_name ();
                break;
            case DisplayTransform.ROTATION_90:
                virtual_monitor.get_current_mode_size (out real_height, out real_width);
                label.add_css_class ("rotate-270");
                label.label = virtual_monitor.get_display_name ();
                break;
            case DisplayTransform.ROTATION_180:
                virtual_monitor.get_current_mode_size (out real_width, out real_height);
                label.add_css_class ("rotate-180");
                label.label = virtual_monitor.get_display_name ();
                break;
            case DisplayTransform.ROTATION_270:
                virtual_monitor.get_current_mode_size (out real_height, out real_width);
                label.add_css_class ("rotate-90");
                label.label = virtual_monitor.get_display_name ();
                break;
            case DisplayTransform.FLIPPED:
                virtual_monitor.get_current_mode_size (out real_width, out real_height);
                label.label = virtual_monitor.get_display_name ().reverse (); //mirroring simulation, because we can't really mirror the text
                break;
            case DisplayTransform.FLIPPED_ROTATION_90:
                virtual_monitor.get_current_mode_size (out real_height, out real_width);
                label.add_css_class ("rotate-270");
                label.label = virtual_monitor.get_display_name ().reverse ();
                break;
            case DisplayTransform.FLIPPED_ROTATION_180:
                virtual_monitor.get_current_mode_size (out real_width, out real_height);
                label.add_css_class ("rotate-180");
                label.label = virtual_monitor.get_display_name ().reverse ();
                break;
            case DisplayTransform.FLIPPED_ROTATION_270:
                virtual_monitor.get_current_mode_size (out real_height, out real_width);
                label.add_css_class ("rotate-90");
                label.label = virtual_monitor.get_display_name ().reverse ();
                break;
        }

        check_position ();
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

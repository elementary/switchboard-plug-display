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

    public Gtk.Button primary_image { get; private set; }
    public Gtk.MenuButton toggle_settings { get; private set; }

    private static Gtk.CssProvider display_provider;

    private Granite.SwitchModelButton use_switch;

    private Gtk.ComboBox resolution_combobox;
    private Gtk.TreeStore resolution_tree_store;

    private Gtk.ComboBox rotation_combobox;
    private Gtk.ListStore rotation_list_store;

    private Gtk.ComboBox refresh_combobox;
    private Gtk.ListStore refresh_list_store;

    private int real_width = 0;
    private int real_height = 0;

    private enum ResolutionColumns {
        NAME,
        WIDTH,
        HEIGHT,
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

    public DisplayWidget (Display.VirtualMonitor virtual_monitor, string bg_color, string text_color) {
        Object (
            virtual_monitor: virtual_monitor,
            bg_color: bg_color,
            text_color: text_color
        );
    }

    static construct {
        display_provider = new Gtk.CssProvider ();
        display_provider.load_from_resource ("io/elementary/settings/display/Display.css");
    }

    class construct {
        set_css_name ("display-widget");
    }

    construct {
        virtual_monitor.get_current_mode_size (out real_width, out real_height);

        primary_image = new Gtk.Button.from_icon_name ("non-starred-symbolic") {
            halign = START,
            valign = START,
            margin_top = 6,
            margin_end = 6,
            margin_bottom = 6,
            margin_start = 6
        };
        primary_image.add_css_class (Granite.STYLE_CLASS_FLAT);
        primary_image.clicked.connect (() => set_as_primary ());

        var virtual_monitor_name = virtual_monitor.get_display_name ();
        var label = new Gtk.Label (virtual_monitor_name) {
            halign = CENTER,
            valign = CENTER,
            hexpand = true,
            vexpand = true
        };
        label.get_style_context ().add_provider (display_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        use_switch = new Granite.SwitchModelButton ("Use This Display");

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

        rotation_list_store = new Gtk.ListStore (RotationColumns.TOTAL, typeof (string), typeof (int));
        rotation_combobox = new Gtk.ComboBox.with_model (rotation_list_store) {
            margin_start = 12,
            margin_end = 12
        };

        var rotation_label = new Granite.HeaderLabel (_("Screen Rotation")) {
            mnemonic_widget = rotation_combobox
        };

        text_renderer = new Gtk.CellRendererText ();
        rotation_combobox.pack_start (text_renderer, true);
        rotation_combobox.add_attribute (text_renderer, "text", RotationColumns.NAME);

        refresh_list_store = new Gtk.ListStore (RefreshColumns.TOTAL, typeof (string), typeof (Display.MonitorMode));
        refresh_combobox = new Gtk.ComboBox.with_model (refresh_list_store) {
            margin_start = 12,
            margin_end = 12
        };

        var refresh_label = new Granite.HeaderLabel (_("Refresh Rate")) {
            mnemonic_widget = refresh_combobox
        };

        text_renderer = new Gtk.CellRendererText ();
        refresh_combobox.pack_start (text_renderer, true);
        refresh_combobox.add_attribute (text_renderer, "text", RefreshColumns.NAME);

        for (int i = 0; i <= DisplayTransform.FLIPPED_ROTATION_270; i++) {
            Gtk.TreeIter iter;
            rotation_list_store.append (out iter);
            rotation_list_store.set (iter, RotationColumns.NAME, ((DisplayTransform) i).to_string (), RotationColumns.VALUE, i);
        }

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

        populate_refresh_rates ();

        var popover_box = new Gtk.Box (VERTICAL, 0) {
            margin_top = 6,
            margin_bottom = 12
        };
        popover_box.append (use_switch);
        popover_box.append (resolution_label);
        popover_box.append (resolution_combobox);
        popover_box.append (rotation_label);
        popover_box.append (rotation_combobox);
        popover_box.append (refresh_label);
        popover_box.append (refresh_combobox);

        var popover = new Gtk.Popover () {
            child = popover_box,
            position = BOTTOM
        };

        toggle_settings = new Gtk.MenuButton () {
            halign = END,
            valign = START,
            icon_name = "open-menu-symbolic",
            margin_top = 6,
            margin_end = 6,
            margin_bottom = 6,
            margin_start = 6,
            popover = popover,
            tooltip_text = _("Configure display")
        };
        toggle_settings.add_css_class (Granite.STYLE_CLASS_FLAT);

        var grid = new Gtk.Grid ();
        grid.attach (primary_image, 0, 0);
        grid.attach (toggle_settings, 2, 0);
        grid.attach (label, 0, 0, 3, 2);

        append (grid);

        set_primary (virtual_monitor.primary);

        use_switch.bind_property ("active", resolution_combobox, "sensitive");
        use_switch.bind_property ("active", rotation_combobox, "sensitive");
        use_switch.bind_property ("active", refresh_combobox, "sensitive");

        use_switch.notify["active"].connect (() => {
            if (rotation_combobox.active == -1) rotation_combobox.set_active (0);
            if (resolution_combobox.active == -1) resolution_combobox.set_active (0);
            if (refresh_combobox.active == -1) refresh_combobox.set_active (0);

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

        refresh_combobox.changed.connect (() => {
            Value val;
            Gtk.TreeIter iter;
            if (refresh_combobox.get_active_iter (out iter)) {
                refresh_list_store.get_value (iter, RefreshColumns.VALUE, out val);
                Display.MonitorMode new_mode = (Display.MonitorMode) val;
                virtual_monitor.set_current_mode (new_mode);
                rotation_combobox.set_active (0);
                configuration_changed ();
                check_position ();
            }
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
            int active_width, active_height;
            if (resolution_combobox.get_active_iter (out iter)) {
                resolution_tree_store.get (iter,
                    ResolutionColumns.WIDTH, out active_width,
                    ResolutionColumns.HEIGHT, out active_height
                );
            } else {
                return;
            }

            double[] frequencies = {};
            bool refresh_set = false;
            foreach (var mode in virtual_monitor.get_available_modes ()) {
                if (mode.width != active_width || mode.height != active_height) {
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
                refresh_list_store.set (iter, ResolutionColumns.NAME, freq_name, RefreshColumns.VALUE, mode);
                added++;
                if (mode.is_current) {
                    refresh_combobox.set_active_iter (iter);
                    refresh_set = true;
                }
            }

            if (!refresh_set) {
                refresh_combobox.set_active (0);
            }
        }

        refresh_combobox.sensitive = added > 1;
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

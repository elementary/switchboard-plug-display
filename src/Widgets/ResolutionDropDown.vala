/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. <https://elementary.io>
 *
 * Authored by: Leonardo Lemos <leonardolemos@live.com>
 */

public class Display.ResolutionDropDown : Granite.Bin {
    public class ResolutionOption : Object {
        public string label { get; set; }
        public int width { get; set; }
        public int height { get; set; }

        public ResolutionOption () {
            Object ();
        }
    }

    public Display.VirtualMonitor virtual_monitor { get; construct; }
    public uint selected {
        get {
            return drop_down.get_selected ();
        }
    }

    public signal void resolution_selected (ResolutionOption resolution);

    private Gtk.DropDown drop_down;
    private ListStore resolutions;

    public ResolutionDropDown (Display.VirtualMonitor _virtual_monitor) {
        Object (
            virtual_monitor: _virtual_monitor
        );
    }

    construct {
        resolutions = new ListStore (typeof (ResolutionOption));

        populate_resolutions ();

        var resolution_factory = new Gtk.SignalListItemFactory ();
        resolution_factory.setup.connect ((obj) => {
            var item = obj as Gtk.ListItem;
            item.child = new Gtk.Label (null) { xalign = 0 };
        });
        resolution_factory.bind.connect ((obj) => {
            var item = obj as Gtk.ListItem;
            var resolution = item.get_item () as ResolutionOption;
            var item_child = item.child as Gtk.Label;
            item_child.label = resolution.label;
        });
 
        drop_down = new Gtk.DropDown (resolutions, null) {
            factory = resolution_factory,
            margin_start = 12,
            margin_end = 12
        };

        drop_down.sensitive = resolutions.get_n_items () > 0;

        if (!set_active_resolution_from_current_mode ()) {
            drop_down.set_selected (0);
        }

        drop_down.notify["selected-item"].connect (() => {
            var selected_resolution = get_selected_resolution ();
            if (selected_resolution != null) {
                resolution_selected (selected_resolution);
            }
        });

        child = drop_down;
    }

    public void set_selected_resolution (int index) {
        drop_down.set_selected (index);
    }

    public ResolutionOption? get_selected_resolution () {
        var selected_item = drop_down.get_selected_item ();
        if (selected_item == null) {
            return null;
        }
        return selected_item as ResolutionOption;
    }

    public uint get_selected_resolution_index () {
        return drop_down.get_selected ();
    }

    public bool set_active_resolution_from_current_mode () {
        bool result = false;

        int current_width, current_height;
        virtual_monitor.get_current_mode_size (out current_width, out current_height);

        for (uint i = 0; i < resolutions.get_n_items (); i++) {
            var option = resolutions.get_item (i) as ResolutionOption?;
            if (option == null) {
                continue;
            }

            if (option.width == current_width && option.height == current_height) {
                drop_down.selected = (int)i;
                result = true;
                break;
            }
        }

        return result;
    }

    private void populate_resolutions () {
        // Build resolution menu
        // First, get list of unique resolutions from available modes.
        int max_width = -1;
        int max_height = -1;
        // Ensures resolutions unique and sorted
        var resolution_set = new Gee.TreeSet<Display.MonitorMode> (Display.MonitorMode.resolution_compare_func);
        resolution_set.add_all (virtual_monitor.get_available_modes ());
        
        foreach (var mode in resolution_set) {
            var mode_width = mode.width;
            var mode_height = mode.height;
            
            if (mode.is_preferred) {
                max_width = int.max (max_width, mode_width);
                max_height = int.max (max_height, mode_height);
            }

            if (mode_width < 1024 || mode_height < 768) {
                continue;
            }

            var res = new ResolutionOption () {
                label = MonitorMode.get_resolution_string (mode_width, mode_height, false),
                width = mode_width,
                height = mode_height
            };

            resolutions.append (res);
        }
    }
}

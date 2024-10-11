/*-
 * Copyright (c) 2018 elementary LLC.
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

public class Display.VirtualMonitor : GLib.Object {
    public class Transform : Object, Utils.StringRepresentable {
        public string string_representation { get; construct; }
        public DisplayTransform transform { get; construct; }

        public Transform (DisplayTransform transform) {
            Object (transform: transform, string_representation: transform.to_string ());
        }
    }

    public class RefreshRate : Object, Utils.StringRepresentable {
        public string string_representation { get; construct; }
        public MonitorMode mode { get; construct; }

        public RefreshRate (MonitorMode mode) {
            Object (mode: mode, string_representation: _("%g Hz").printf (Math.round (mode.frequency)));
        }
    }

    public int x { get; set; }
    public int y { get; set; }
    public int current_x { get; set; }
    public int current_y { get; set; }
    public double scale { get; set; }
    public Gtk.SingleSelection available_transforms { get; construct; }
    public Gtk.SingleSelection available_refresh_rates { get; construct; }
    public bool primary { get; set; }
    public Gee.LinkedList<Display.Monitor> monitors { get; construct; }

    public signal void modes_changed ();

    /*
     * Used to distinguish two VirtualMonitors from each other.
     * We make up and ID by sum all hashes of
     * monitors that a VirtualMonitor has.
     */
    public string id {
        owned get {
            uint val = 0;
            foreach (var monitor in monitors) {
                val += monitor.hash;
            }

            return val.to_string ();
        }
    }

    public bool is_mirror {
        get {
            return monitors.size > 1;
        }
    }

    public bool is_active { get; set; default = true; }

    public DisplayTransform transform {
        get {
            return (DisplayTransform) available_transforms.selected;
        }
        set {
            available_transforms.selected = value;
        }
    }

    /*
     * Get the first monitor of the list, handy in non-mirror context.
     */
    public Display.Monitor monitor {
        owned get {
            if (is_mirror) {
                critical ("Do not use Display.VirtualMonitor.monitor in a mirror context!");
            }

            return monitors[0];
        }
    }

    private ListStore available_transforms_store;
    private ListStore available_refresh_rates_store;

    construct {
        monitors = new Gee.LinkedList<Display.Monitor> ();

        available_transforms_store = new ListStore (typeof (Transform));
        available_transforms = new Gtk.SingleSelection (available_transforms_store) {
            autoselect = true
        };

        for (int i = 0; i <= DisplayTransform.FLIPPED_ROTATION_270; i++) {
            available_transforms_store.append (new Transform ((DisplayTransform) i));
        }

        available_refresh_rates_store = new ListStore (typeof (RefreshRate));
        available_refresh_rates = new Gtk.SingleSelection (available_refresh_rates_store) {
            autoselect = true
        };

        available_refresh_rates.selection_changed.connect (() =>
            set_current_mode (((RefreshRate) available_refresh_rates.get_item (available_refresh_rates.selected)).mode));

        Idle.add_once (update_available_refresh_rates);
    }

    public unowned string get_display_name () {
        if (is_mirror) {
            return _("Mirrored Display");
        } else {
            return monitor.display_name;
        }
    }

    public void get_current_mode_size (out int width, out int height) {
        if (!is_active) {
            // If the monitor isn't active, return the preferred mode as this will be the default
            // mode when the monitor is re-activated
            foreach (var mode in monitor.modes) {
                if (mode.is_preferred) {
                    width = mode.width;
                    height = mode.height;
                    return;
                }
            }

            // Last resort fallback if no preferred mode
            width = 1280;
            height = 720;
        } else if (is_mirror) {
            var current_mode = monitors[0].current_mode;
            width = current_mode.width;
            height = current_mode.height;
        } else {
            var current_mode = monitor.current_mode;
            width = current_mode.width;
            height = current_mode.height;
        }
    }

    public Gee.LinkedList<Display.MonitorMode> get_available_modes () {
        if (is_mirror) {
            return Utils.get_common_monitor_modes (monitors);
        } else {
            return monitor.modes;
        }
    }

    public Display.MonitorMode? get_mode_for_resolution (int width, int height) {
        foreach (var mode in get_available_modes ()) {
            if (mode.width == width && mode.height == height) {
                return mode;
            }
        }

        return null;
    }

    public void set_current_mode (Display.MonitorMode current_mode) {
        var old_current_mode = monitors[0].current_mode;

        if (old_current_mode == current_mode) {
            return;
        }

        if (is_mirror) {
            monitors.foreach ((_monitor) => {
                bool mode_found = false;
                foreach (var mode in _monitor.modes) {
                    if (mode_found) {
                        mode.is_current = false;
                        continue;
                    }

                    if (mode.width == current_mode.width && mode.height == current_mode.height) {
                        mode_found = true;
                        mode.is_current = true;
                    } else {
                        mode.is_current = false;
                    }
                }

                return true;
            });
        } else {
            foreach (var mode in monitor.modes) {
                mode.is_current = mode == current_mode;
            }
        }

        update_available_refresh_rates ();
    }

    private void update_available_refresh_rates () {
        int active_width, active_height;
        get_current_mode_size (out active_width, out active_height);

        double[] frequencies = {};
        RefreshRate[] refresh_rates = {};
        uint to_select = 0;
        foreach (var mode in get_available_modes ()) {
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

            refresh_rates += new RefreshRate (mode);

            if (mode.is_current) {
                to_select = refresh_rates.length - 1;
            }
        }

        available_refresh_rates_store.splice (0, available_refresh_rates_store.get_n_items (), refresh_rates);
        available_refresh_rates.selected = to_select;
    }

    public static string generate_id_from_monitors (MutterReadMonitorInfo[] infos) {
        uint val = 0;
        foreach (var info in infos) {
            val += info.hash;
        }

        return val.to_string ();
    }
}

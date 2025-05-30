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
    public class Scale : GLib.Object {
        public double scale { get; construct; }
        public string string_representation { get; construct; }

        public Scale (double scale) {
            Object (
                scale: scale,
                string_representation: "%d %%".printf ((int) Math.round (scale * 100))
            );
        }
    }

    public int x { get; set; }
    public int y { get; set; }
    public int current_x { get; set; }
    public int current_y { get; set; }
    public Gtk.SingleSelection available_scales { get; construct; }
    public DisplayTransform transform { get; set; }
    public bool primary { get; set; }
    public Gee.LinkedList<Display.Monitor> monitors { get; construct; }

    public signal void modes_changed ();

    public double scale {
        get {
            return ((Scale) available_scales.selected_item).scale;
        }
        set {
            update_available_scales ();
            for (int i = 0; i < available_scales.get_n_items (); i++) {
                if (value == ((Scale) available_scales.get_item (i)).scale) {
                    available_scales.selected = i;
                    return;
                }
            }
            critical ("Unsupported scale %f for current mode", value);
        }
    }

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

    private ListStore available_scales_store;

    construct {
        monitors = new Gee.LinkedList<Display.Monitor> ();

        available_scales_store = new ListStore (typeof (Scale));
        available_scales = new Gtk.SingleSelection (available_scales_store);
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

    private void update_available_scales () {
        Scale[] scales = {};
        foreach (var mode in get_available_modes ()) {
            if (!mode.is_current && !mode.is_preferred) {
                continue;
            }

            foreach (var scale in mode.supported_scales) {
                scales += new Scale (scale);
            }

            break;
        }

        available_scales_store.splice (0, available_scales_store.get_n_items (), scales);
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

        scale = current_mode.preferred_scale;
    }

    public static string generate_id_from_monitors (MutterReadMonitorInfo[] infos) {
        uint val = 0;
        foreach (var info in infos) {
            val += info.hash;
        }

        return val.to_string ();
    }
}

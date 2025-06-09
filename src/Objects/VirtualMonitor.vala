/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2018-2025 elementary, Inc. <https://elementary.io>
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Display.VirtualMonitor : GLib.Object {
    public int x { get; set; }
    public int y { get; set; }
    public int current_x { get; set; }
    public int current_y { get; set; }
    public double scale { get; set; }
    public DisplayTransform transform { get; set; }
    public bool primary { get; set; }
    public Gee.LinkedList<Display.Monitor> monitors { get; construct; }
    public Display.MonitorMode current_mode {
        owned get {
            return monitors[0].current_mode;
        }
    }

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

    construct {
        monitors = new Gee.LinkedList<Display.Monitor> ();
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

    public double[] get_frequencies_from_current_mode () {
        double[] frequencies = {};
        int current_width, current_height;

        get_current_mode_size (out current_width, out current_height);

        foreach (var mode in get_available_modes ()) {
            if (mode.width == current_width && mode.height == current_height) {
                frequencies += mode.frequency;
            }
        }

        return frequencies;
    }

    public Gee.LinkedList<Display.MonitorMode> get_modes_for_resolution (int width, int height) {
        var mode_list = new Gee.LinkedList<Display.MonitorMode> ();

        foreach (var mode in get_available_modes ()) {
            if (mode.width == width && mode.height == height) {
                mode_list.add (mode);
            }
        }

        return mode_list;
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
    }

    public static string generate_id_from_monitors (MutterReadMonitorInfo[] infos) {
        uint val = 0;
        foreach (var info in infos) {
            val += info.hash;
        }

        return val.to_string ();
    }
}

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

public class Display.Monitor : GLib.Object {
    public string connector { get; set; }
    public string vendor { get; set; }
    public string product { get; set; }
    public string serial { get; set; }
    public string display_name { get; set; }
    public bool is_builtin { get; set; }
    public Gee.LinkedList<Display.MonitorMode> modes { get; construct; }

    public Display.MonitorMode current_mode {
        owned get {
            foreach (var mode in modes) {
                if (mode.is_current) {
                    return mode;
                }
            }

            return modes[0];
        }
    }

    public Display.MonitorMode preferred_mode {
        owned get {
            foreach (var mode in modes) {
                if (mode.is_preferred) {
                    return mode;
                }
            }

            return modes[0];
        }
    }

    public double get_max_scale () {
        double max_scale = 1.0;
        foreach (var mode in modes) {
            max_scale = double.max (max_scale, mode.preferred_scale);
        }

        return max_scale;
    }

    construct {
        modes = new Gee.LinkedList<Display.MonitorMode> ();
    }

    public Display.MonitorMode? get_mode_by_id (string id) {
        foreach (var mode in modes) {
            if (mode.id == id) {
                return mode;
            }
        }

        return null;
    }
}

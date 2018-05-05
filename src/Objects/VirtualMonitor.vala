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
    public int x { get; set; }
    public int y { get; set; }
    public double scale { get; set; }
    public DisplayTransform transform { get; set; }
    public bool primary { get; set; }
    public Gee.LinkedList<Display.Monitor> monitors { get; construct; }

<<<<<<< HEAD
    // Used to distinguish two VirtualMonitors from each other.
    // We make up and ID by concatenating all serials of
    // monitors that a VirtualMonitor has.
    public string id {
        owned get {
            string val = "";
            foreach (var monitor in monitors) {
                val += monitor.serial;
            }

            return val;
        }
    }

=======
>>>>>>> 3a2285bc2024dfe56f303050c1a84ecbf65dd585
    public bool is_mirror {
        get {
            return monitors.size > 1;
        }
    }

    public bool is_active {
        get {
            return true;
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

            return monitors.get (0);
        }
    }

    public VirtualMonitor () {
        
    }

    construct {
        monitors = new Gee.LinkedList<Display.Monitor> ();
    } 

    public void get_current_mode_size (out int width, out int height) {
        if (!is_active) {
            width = 1280;
            height = 720;
        } else {
            width = monitor.current_mode.width;
            height = monitor.current_mode.height;
        }
    }
}

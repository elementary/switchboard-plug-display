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

public class Display.MonitorObject : GLib.Object {
    public enum Rotation {
        NONE,
        90_DEGREES,
        180_DEGREES,
        270_DEGREES,
        FLIPPED,
        90_DEGREES_FLIPPED,
        180_DEGREES_FLIPPED,
        270_DEGREES_FLIPPED,
    }

    public uint id { get; set; }
    public string display_name { get; set; }
    public string connector_name { get; set; }
    public bool is_builtin { get; set; }
    public bool primary { get; set; }
    public bool active { get; set; }
    public bool supports_rotation { get; set; }
    public double scale { get; set; }
    public Rotation rotation { get; set; }

    public void get_physical_size (out int width, out int height) {
        width = 0;
        height = 0;
    }

    public void get_geometry (out int x, out int y, out int width, out int height) {
        x = 0;
        y = 0;
        width = 0;
        height = 0;
    }

    public void set_position (int x, int y) {
        
    }
}

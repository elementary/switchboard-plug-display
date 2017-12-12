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

public class Display.MutterDisplayConfig : GLib.Object {
    private static MutterDisplayConfig instance;
    public static unowned MutterDisplayConfig get_instance () {
        if (instance == null) {
            instance = new MutterDisplayConfig ();
        }

        return instance;
    }

    MutterDisplayConfigInterface intface;
    construct {
        try {
            intface = Bus.get_proxy_sync (BusType.SESSION, "org.gnome.Mutter.DisplayConfig", "/org/gnome/Mutter/DisplayConfig");
        } catch (Error e) {
            critical (e.message);
        }
    }

    public DisplayObject get_display () throws GLib.Error {
        try {
            uint serial;
            MutterReadDisplayCrtc[] crtcs;
            MutterReadDisplayOutput[] outputs;
            MutterReadDisplayMode[] modes;
            int max_screen_width;
            int max_screen_height;

            intface.get_resources (out serial, out crtcs, out outputs, out modes, out max_screen_width, out max_screen_height);
            var display = new DisplayObject ();
            return display;
        } catch (Error e) {
            throw e;
        }
    }
}

[DBus (name = "org.gnome.Mutter.DisplayConfig")]
public interface MutterDisplayConfigInterface : Object {
    public abstract void get_resources (out uint serial, out MutterReadDisplayCrtc[] crtcs, out MutterReadDisplayOutput[] outputs, out MutterReadDisplayMode[] modes, out int max_screen_width, out int max_screen_height) throws IOError;
    public abstract void apply_configuration (uint serial, bool persistent, MutterWriteDisplayCrtc[] crtcs, MutterWriteDisplayOutput[] outputs) throws IOError;
    public abstract int change_backlight (uint serial, uint output, int value) throws IOError;
    public abstract void get_crtc_gamma (uint serial, uint crtc, out uint[] red, out uint[] green, out uint[] blue) throws IOError;
    public abstract void set_crtc_gamma (uint serial, uint crtc, uint[] red, uint[] green, uint[] blue) throws IOError;
    public abstract int power_save_mode { get; set; }
    public signal void monitors_changed ();
    public abstract void get_current_state (out uint serial, out MutterReadMonitor[] monitors, out MutterReadLogicalMonitor[] logical_monitors, out GLib.HashTable<string, GLib.Variant> properties) throws IOError;
    public abstract void apply_monitors_config (uint serial, uint method, MutterWriteLogicalMonitor[] logical_monitors, GLib.HashTable<string, GLib.Variant> properties) throws IOError;
}

public struct MutterReadMonitorInfo {
    public string connector;
    public string vendor;
    public string product;
    public string serial;
}

public struct MutterReadMonitorMode {
    public string id;
    public int width;
    public int height;
    public double frequency;
    public double preferred_scale;
    public double[] supported_scales;
    public GLib.HashTable<string, GLib.Variant> properties;
}

public struct MutterReadMonitor {
    public MutterReadMonitorInfo monitors;
    public MutterReadMonitorMode[] modes;
    public GLib.HashTable<string, GLib.Variant> properties;
}

public struct MutterReadLogicalMonitor {
    public int x;
    public int y;
    public double scale;
    public uint transform;
    public bool primary;
    public MutterReadMonitorInfo[] monitors;
    public GLib.HashTable<string, GLib.Variant> properties;
}

public struct MutterWriteMonitor {
    public string connector;
    public string monitor_mode;
    public GLib.HashTable<string, GLib.Variant> properties;
}

public struct MutterWriteLogicalMonitor {
    public int x;
    public int y;
    public double scale;
    public uint transform;
    public bool primary;
    public MutterWriteMonitor[] monitors;
}

public struct MutterReadDisplayCrtc {
    public uint id;
    public int64 winsys_id;
    public int x;
    public int y;
    public int width;
    public int height;
    public int current_mode;
    public uint current_transform;
    public uint[] transforms;
    public GLib.HashTable<string, GLib.Variant> properties;
}

public struct MutterWriteDisplayCrtc {
    public uint id;
    public int new_mode;
    public int x;
    public int y;
    public uint transform;
    public uint[] outputs;
    public GLib.HashTable<string, GLib.Variant> properties;
}

public struct MutterReadDisplayOutput {
    public uint id;
    public int64 winsys_id;
    public int current_crtc;
    public uint[] possible_crtcs;
    public string connector_name;
    public uint[] modes;
    public uint[] clones;
    public GLib.HashTable<string, GLib.Variant> properties;
}

public struct MutterWriteDisplayOutput {
    public uint id;
    public GLib.HashTable<string, GLib.Variant> properties;
}

public struct MutterReadDisplayMode {
    public uint id;
    public int64 winsys_id;
    public uint width;
    public uint height;
    public double frequency;
    public uint flags;
}


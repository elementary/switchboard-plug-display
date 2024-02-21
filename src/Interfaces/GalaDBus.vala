/*
 * SPDX-License-Identifier: LGPL-2.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

[DBus (name = "org.pantheon.gala.daemon")]
public interface GalaDBus : Object {
    public abstract void show_monitor_labels (MonitorLabelInfo[] label_infos) throws GLib.DBusError, GLib.IOError;
    public abstract void hide_monitor_labels () throws GLib.DBusError, GLib.IOError;
}

public struct MonitorLabelInfo {
    public int monitor;
    public string label;
    public string background_color;
    public string text_color;
    public int x;
    public int y;
}

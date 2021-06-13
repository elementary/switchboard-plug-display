/*-
 * Copyright 2021 elementary, Inc. (https://elementary.io)
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
 * Authored by: Jeremy Wootten <jeremywootten@gmail.com>
 */

public class Display.MonitorsList : Gtk.ListBox {
    private Display.MonitorManager monitor_manager;
    private GLib.ListStore monitor_store;
    public int active_displays { get; set; }

    construct {
        monitor_manager = Display.MonitorManager.get_default ();
        monitor_store = new GLib.ListStore (typeof (Display.VirtualMonitor));

        this.bind_model (monitor_store, widget_from_monitor);
        monitor_manager.notify["monitor-number"].connect (() => rescan_monitors ());
        rescan_monitors ();
    }

    private Gtk.Widget widget_from_monitor (Object object) {
        if (object is Display.VirtualMonitor) {
            var monitor = (Display.VirtualMonitor)object;
            return new Display.MonitorsListWidget (monitor, this);
        } else {
            return new Gtk.Label (_("Unknown monitor type"));
        }
    }

    public void rescan_monitors () {
        active_displays = 0;
        monitor_store.remove_all ();
        foreach (VirtualMonitor monitor in monitor_manager.virtual_monitors) {
            monitor_store.append (monitor);
        }
    }
}

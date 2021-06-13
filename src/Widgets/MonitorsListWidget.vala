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

public class Display.MonitorsListWidget : Gtk.Grid {
    public Display.VirtualMonitor monitor { get; construct; }
    unowned MonitorsList monitors_list;
    public MonitorsListWidget (Display.VirtualMonitor _monitor, MonitorsList _monitors_list) {
        Object (
            monitor: _monitor
        );

        monitors_list = _monitors_list;
    }

    construct {
        margin = 6;
        var name_label = new Gtk.Label (monitor.get_display_name ()) {
            hexpand = true,
            halign = Gtk.Align.START
        };
        var active_switch = new Gtk.Switch () {
            active = monitor.is_active,
            halign = Gtk.Align.END,
            sensitive = monitors_list.active_displays > 1
        };

        attach (name_label, 0, 0, 1, 1);
        attach (active_switch, 1, 0, 1, 1);

        active_switch.notify ["active"].connect (() => {
            monitor.is_active = active_switch.active;
            monitors_list.active_displays += active_switch.active ? 1 : -1;
        });

        monitors_list.notify ["active-displays"].connect (() => {
            active_switch.sensitive = monitors_list.active_displays > 1;
        });
    }
}

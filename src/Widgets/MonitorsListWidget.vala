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
 * Authored by: Corentin Noël <corentin@elementary.io>
 *              Jeremy Wootten <jeremywootten@gmail.com>
 */

public class Display.MonitorsListWidget : Gtk.Grid {
    private Gtk.Switch use_switch;
    public weak MonitorsList? monitors_list { get; construct; }
    public weak Display.VirtualMonitor? monitor { get; construct; }

    public MonitorsListWidget (Display.VirtualMonitor _monitor, MonitorsList _monitors_list) {
        Object (
            monitor: _monitor,
            monitors_list: _monitors_list
        );
    }

    ~MonitorsListWidget () {
        debug ("DESTRUCT MonitorsListWidget %s", monitor.get_display_name ());
    }

    construct {
        margin_start = 6;
        margin_top = 12;
        margin_end = 6;
        row_spacing = 3;
        column_spacing = 3;

        var name_label = new Gtk.Label (monitor.get_display_name ()) {
            hexpand = true,
            halign = Gtk.Align.START,
            valign = Gtk.Align.CENTER
        };
        name_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);
        use_switch = new Gtk.Switch () {
            active = monitor.is_active,
            halign = Gtk.Align.END,
            valign = Gtk.Align.CENTER,
            sensitive = monitors_list.active_displays > 1
        };

        attach (name_label, 0, 0);
        attach (use_switch, 1, 0);

        // Make a weak signal connection else it is not disconnected when widget is destroyed.
        weak MonitorsListWidget weak_this = this;
        monitors_list.notify ["active-displays"].connect (weak_this.set_use_switch_sensitive);

        use_switch.notify ["active"].connect (() => {
            monitor.is_active = use_switch.active;
            monitors_list.active_displays += use_switch.active ? 1 : -1;
            monitors_list.active_changed (monitor);
        });

        show_all ();
    }

    private void set_use_switch_sensitive () {
        use_switch.sensitive = monitors_list.active_displays > 1 || !use_switch.active;
    }
}

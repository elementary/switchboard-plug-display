/*
* Copyright (c) 2017 elementary LLC (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

public class Displays.NightLightView : Granite.SimpleSettingsPage {
    public NightLightView () {
        Object (
            activatable: true,
            description: _("Night Light makes the colors of your display warmer. This may help prevent eye strain and sleeplessness."),
            icon_name: "night-light",
            title: _("Night Light")
        );
    }

    construct {
        var temp_label = new Gtk.Label (_("Color temperature:"));
        temp_label.halign = Gtk.Align.END;

        var temp_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 3500, 6000, 10);
        temp_scale.draw_value = false;
        temp_scale.inverted = true;
        temp_scale.add_mark (3500, Gtk.PositionType.BOTTOM, "More Warm");
        temp_scale.add_mark (6000, Gtk.PositionType.BOTTOM, "Less Warm");

        var schedule_label = new Gtk.Label (_("Schedule:"));
        schedule_label.halign = Gtk.Align.END;

        var schedule_button = new Granite.Widgets.ModeButton ();
        schedule_button.append_text (_("Sunset to Sunrise"));
        schedule_button.append_text (_("Manual"));

        var from_label = new Gtk.Label (_("From:"));
        var from_time = new Granite.Widgets.TimePicker ();
        var to_label = new Gtk.Label (_("To:"));
        var to_time = new Granite.Widgets.TimePicker ();

        content_area.attach (temp_label, 0, 0, 1, 1);
        content_area.attach (temp_scale, 1, 0, 4, 1);
        content_area.attach (schedule_label, 0, 1, 1, 1);
        content_area.attach (schedule_button, 1, 1, 4, 1);
        content_area.attach (from_label, 1, 2, 1, 1);
        content_area.attach (from_time, 2, 2, 1, 1);
        content_area.attach (to_label, 3, 2, 1, 1);
        content_area.attach (to_time, 4, 2, 1, 1);

        var settings = new GLib.Settings ("org.gnome.settings-daemon.plugins.color");
        settings.bind ("night-light-enabled", status_switch, "active", GLib.SettingsBindFlags.DEFAULT);
        settings.bind ("night-light-temperature", temp_scale, "value", GLib.SettingsBindFlags.DEFAULT);

        var automatic_schedule = settings.get_boolean ("night-light-schedule-automatic");
        if (automatic_schedule) {
            schedule_button.selected = 0;
        } else {
            schedule_button.selected = 1;
        }

        schedule_button.mode_changed.connect (() => {
            if (schedule_button.selected == 0) {
                settings.set_boolean ("night-light-schedule-automatic", true);
                from_label.sensitive = false;
                from_time.sensitive = false;
                to_label.sensitive = false;
                to_time.sensitive = false;
            } else {
                settings.set_boolean ("night-light-schedule-automatic", false);
                from_label.sensitive = true;
                from_time.sensitive = true;
                to_label.sensitive = true;
                to_time.sensitive = true;
            }
        });

        from_time.time_changed.connect (() => {
            settings.set_double ("night-light-schedule-from", date_time_double (from_time.time));
        });

        to_time.time_changed.connect (() => {
            settings.set_double ("night-light-schedule-to", date_time_double (to_time.time));
        });
    }

    private double date_time_double (DateTime date_time) {
        double time_double = 0;
        time_double += date_time.get_hour ();
        time_double += date_time.get_minute () / 100;

        return time_double;
    }
}

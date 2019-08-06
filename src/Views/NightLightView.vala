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

public class Display.NightLightView : Gtk.Grid {
    private Gtk.Scale temp_scale;

    public int temperature {
        set {
            temp_scale.set_value (value);
        }
    }

    construct {
        var settings = new GLib.Settings ("org.gnome.settings-daemon.plugins.color");

        var status_label = new Gtk.Label (_("Night Light:"));
        status_label.halign = Gtk.Align.END;
        status_label.xalign = 1;

        var status_switch = new Gtk.Switch ();
        status_switch.halign = Gtk.Align.START;
        status_switch.hexpand = true;

        var description_label = new Gtk.Label (
            _("Night Light makes the colors of your display warmer. This may help prevent eye strain and sleeplessness.")
        );
        description_label.max_width_chars = 60;
        description_label.wrap = true;
        description_label.xalign = 0;
        description_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var schedule_label = new Gtk.Label (_("Schedule:"));
        schedule_label.halign = Gtk.Align.END;
        schedule_label.xalign = 1;

        var schedule_button = new Granite.Widgets.ModeButton ();
        schedule_button.append_text (_("Sunset to Sunrise"));
        schedule_button.append_text (_("Manual"));

        var from_label = new Gtk.Label (_("From:"));

        var from_time = new Granite.Widgets.TimePicker ();
        from_time.time = double_date_time (settings.get_double ("night-light-schedule-from"));

        var to_label = new Gtk.Label (_("To:"));

        var to_time = new Granite.Widgets.TimePicker ();
        to_time.time = double_date_time (settings.get_double ("night-light-schedule-to"));

        var temp_label = new Gtk.Label (_("Color temperature:"));
        temp_label.halign = Gtk.Align.END;
        temp_label.valign = Gtk.Align.START;
        temp_label.margin_top = 24;
        temp_label.xalign = 1;

        temp_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 3500, 6000, 10);
        temp_scale.draw_value = false;
        temp_scale.has_origin = false;
        temp_scale.inverted = true;
        temp_scale.margin_top = 24;
        temp_scale.add_mark (3500, Gtk.PositionType.BOTTOM, _("More Warm"));
        temp_scale.add_mark (4500, Gtk.PositionType.BOTTOM, null);
        temp_scale.add_mark (6000, Gtk.PositionType.BOTTOM, _("Less Warm"));
        temp_scale.get_style_context ().add_class ("warmth");
        temp_scale.set_value (settings.get_uint ("night-light-temperature"));

        var content_grid = new Gtk.Grid ();
        content_grid.column_spacing = 12;
        content_grid.row_spacing = 12;
        content_grid.margin_top = 24;
        content_grid.attach (schedule_label, 0, 0, 1, 1);
        content_grid.attach (schedule_button, 1, 0, 4, 1);
        content_grid.attach (from_label, 1, 1, 1, 1);
        content_grid.attach (from_time, 2, 1, 1, 1);
        content_grid.attach (to_label, 3, 1, 1, 1);
        content_grid.attach (to_time, 4, 1, 1, 1);
        content_grid.attach (temp_label, 0, 2, 1, 1);
        content_grid.attach (temp_scale, 1, 2, 4, 1);

        halign = Gtk.Align.CENTER;
        column_spacing = 12;
        row_spacing = 12;
        margin = 12;
        attach (status_label, 0, 0, 1, 1);
        attach (status_switch, 1, 0, 1, 1);
        attach (description_label, 1, 1, 1, 1);
        attach (content_grid, 0, 2, 2, 1);
        show_all ();

        var size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
        size_group.add_widget (status_label);
        size_group.add_widget (schedule_label);
        size_group.add_widget (temp_label);

        settings.bind ("night-light-enabled", status_switch, "active", GLib.SettingsBindFlags.DEFAULT);
        settings.bind ("night-light-enabled", content_grid, "sensitive", GLib.SettingsBindFlags.GET);
        settings.bind ("night-light-temperature", this, "temperature", GLib.SettingsBindFlags.GET);

        var automatic_schedule = settings.get_boolean ("night-light-schedule-automatic");
        if (automatic_schedule) {
            schedule_button.selected = 0;
            from_label.sensitive = false;
            from_time.sensitive = false;
            to_label.sensitive = false;
            to_time.sensitive = false;
        } else {
            schedule_button.selected = 1;
            from_label.sensitive = true;
            from_time.sensitive = true;
            to_label.sensitive = true;
            to_time.sensitive = true;
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

            clear_snooze ();
        });

        temp_scale.value_changed.connect (() => {
            settings.set_uint ("night-light-temperature", (uint) temp_scale.get_value ());
            clear_snooze ();
        });

        from_time.time_changed.connect (() => {
            settings.set_double ("night-light-schedule-from", date_time_double (from_time.time));
            clear_snooze ();
        });

        to_time.time_changed.connect (() => {
            settings.set_double ("night-light-schedule-to", date_time_double (to_time.time));
            clear_snooze ();
        });

        status_switch.state_set.connect ((state) => {
            if (state) {
                clear_snooze ();
            }

            return false;
        });
    }

    private void clear_snooze () {
        NightLightManager.get_instance ().snoozed = false;
    }

    private static double date_time_double (DateTime date_time) {
        double time_double = 0;
        time_double += date_time.get_hour ();
        time_double += (double) date_time.get_minute () / 60;

        return time_double;
    }

    private static DateTime double_date_time (double dbl) {
        var hours = (int) dbl;
        var minutes = (int) Math.round ((dbl - hours) * 60);

        var date_time = new DateTime.local (1, 1, 1, hours, minutes, 0.0);

        return date_time;
    }
}


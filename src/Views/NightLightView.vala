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

public class Display.NightLightView : Granite.SimpleSettingsPage {
    private const string SCALE_CSS = """
        scale trough {
            background-image:
                linear-gradient(
                    to right,
                #3689e6,
                    #f37329
                );
             border: none;
            box-shadow:
                inset 0 0 0 1px alpha (#000, 0.3),
                inset 0 0 0 2px alpha (#000, 0.03),
                0 1px 0 0 alpha (@bg_highlight_color, 0.3);
            min-height: 5px;
            min-width: 5px;
        }
    """;

    public NightLightView () {
        Object (
            activatable: true,
            description: _("Night Light makes the colors of your display warmer. This may help prevent eye strain and sleeplessness."),
            icon_name: "night-light",
            title: _("Night Light")
        );
    }

    construct {
        var settings = new GLib.Settings ("org.gnome.settings-daemon.plugins.color");

        var schedule_label = new Gtk.Label (_("Schedule:"));
        schedule_label.halign = Gtk.Align.END;

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

        var temp_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 3500, 6000, 10);
        temp_scale.draw_value = false;
        temp_scale.has_origin = false;
        temp_scale.inverted = true;
        temp_scale.margin_top = 24;
        temp_scale.add_mark (3500, Gtk.PositionType.BOTTOM, "More Warm");
        temp_scale.add_mark (6000, Gtk.PositionType.BOTTOM, "Less Warm");
        temp_scale.set_value (settings.get_uint ("night-light-temperature")); 

        content_area.halign = Gtk.Align.CENTER;
        content_area.margin_top = 24;
        content_area.attach (schedule_label, 0, 0, 1, 1);
        content_area.attach (schedule_button, 1, 0, 4, 1);
        content_area.attach (from_label, 1, 1, 1, 1);
        content_area.attach (from_time, 2, 1, 1, 1);
        content_area.attach (to_label, 3, 1, 1, 1);
        content_area.attach (to_time, 4, 1, 1, 1);
        content_area.attach (temp_label, 0, 2, 1, 1);
        content_area.attach (temp_scale, 1, 2, 4, 1);

        var provider = new Gtk.CssProvider ();

        try {
            provider.load_from_data (SCALE_CSS, SCALE_CSS.length);
            Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        } catch (Error e) {
            critical (e.message);
        }

        margin = 12;
        margin_top = 0;
        show_all ();

        status_switch.bind_property ("active", content_area, "sensitive", GLib.BindingFlags.DEFAULT);

        settings.bind ("night-light-enabled", status_switch, "active", GLib.SettingsBindFlags.DEFAULT);

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
        });

        temp_scale.value_changed.connect (() => {
            settings.set_uint ("night-light-temperature", (uint) temp_scale.get_value ());
        });

        from_time.time_changed.connect (() => {
            settings.set_double ("night-light-schedule-from", date_time_double (from_time.time));
        });

        to_time.time_changed.connect (() => {
            settings.set_double ("night-light-schedule-to", date_time_double (to_time.time));
        });
    }

    private static double date_time_double (DateTime date_time) {
        double time_double = 0;
        time_double += date_time.get_hour ();
        time_double += (double) date_time.get_minute () / 100;

        return time_double;
    }

    private static DateTime double_date_time (double dbl) {
        var hours = (int) dbl;
        var minutes = (int) (dbl - hours) * 100;

        var date_time = new DateTime.local (1, 1, 1, hours, minutes, 0.0);

        if (date_time == null) {
            warning ("wtf why");
        }

        return date_time;
    }
}

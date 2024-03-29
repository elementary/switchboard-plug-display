/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2017-2023 elementary, Inc. (https://elementary.io)
 */

public class Display.NightLightView : Gtk.Box {
    construct {
        var nightlight_header = new Granite.HeaderLabel (_("Night Light")) {
            secondary_text = _("Making the colors of your display warmer may help prevent eye strain and sleeplessness")
        };

        var nightlight_switch = new Gtk.Switch () {
            halign = END,
            hexpand = true,
            valign = CENTER
        };

        var temp_adjustment = new Gtk.Adjustment (0, 1500, 6000, 10, 0, 0);

        var temp_scale = new Gtk.Scale (HORIZONTAL, temp_adjustment) {
            draw_value = false,
            has_origin = false,
            inverted = true,
            margin_top = 12
        };
        temp_scale.add_mark (1500, Gtk.PositionType.BOTTOM, _("More Warm"));
        temp_scale.add_mark (4500, Gtk.PositionType.BOTTOM, null);
        temp_scale.add_mark (6000, Gtk.PositionType.BOTTOM, _("Less Warm"));
        temp_scale.add_css_class ("warmth");

        var nightlight_grid = new Gtk.Grid () {
            column_spacing = 12
        };
        nightlight_grid.attach (nightlight_header, 0, 0);
        nightlight_grid.attach (nightlight_switch, 1, 0);
        nightlight_grid.attach (temp_scale, 0, 1, 2);

        var schedule_header = new Granite.HeaderLabel (_("Schedule"));

        var schedule_sunset_radio = new Gtk.CheckButton.with_label (_("Sunset to Sunrise"));

        var from_label = new Gtk.Label (_("From:"));

        var from_time = new Granite.TimePicker () {
            hexpand = true,
            margin_end = 6
        };

        var to_label = new Gtk.Label (_("To:"));

        var to_time = new Granite.TimePicker () {
            hexpand = true
        };

        var schedule_manual_box = new Gtk.Box (HORIZONTAL, 6);
        schedule_manual_box.append (from_label);
        schedule_manual_box.append (from_time);
        schedule_manual_box.append (to_label);
        schedule_manual_box.append (to_time);

        var schedule_manual_radio = new Gtk.CheckButton () {
            group = schedule_sunset_radio
        };
        schedule_manual_box.set_parent (schedule_manual_radio);

        var schedule_grid = new Gtk.Grid () {
            column_spacing = 6,
            row_spacing = 6
        };
        schedule_grid.attach (schedule_header, 0, 3);
        schedule_grid.attach (schedule_sunset_radio, 0, 5);
        schedule_grid.attach (schedule_manual_radio, 0, 6);

        var box = new Gtk.Box (VERTICAL, 24);
        box.append (nightlight_grid);
        box.append (schedule_grid);

        var clamp = new Adw.Clamp () {
            child = box
        };

        append (clamp);
        margin_start = 12;
        margin_end = 12;
        margin_bottom = 12;

        var settings = new Settings ("org.gnome.settings-daemon.plugins.color");
        settings.bind ("night-light-enabled", nightlight_switch, "active", DEFAULT);
        settings.bind ("night-light-enabled", schedule_grid, "sensitive", GET);
        settings.bind ("night-light-enabled", temp_scale, "sensitive", GET);
        settings.bind ("night-light-schedule-automatic", schedule_sunset_radio, "active", DEFAULT);
        settings.bind ("night-light-schedule-automatic", schedule_manual_radio, "active", INVERT_BOOLEAN);
        settings.bind ("night-light-schedule-automatic", schedule_manual_box, "sensitive", GET | INVERT_BOOLEAN);
        settings.bind ("night-light-temperature", temp_adjustment, "value", DEFAULT);

        schedule_sunset_radio.toggled.connect (() => {
            clear_snooze ();
        });

        temp_adjustment.value_changed.connect (() => {
            clear_snooze ();
        });

        from_time.time = double_date_time (settings.get_double ("night-light-schedule-from"));
        from_time.time_changed.connect (() => {
            settings.set_double ("night-light-schedule-from", date_time_double (from_time.time));
            clear_snooze ();
        });

        to_time.time = double_date_time (settings.get_double ("night-light-schedule-to"));
        to_time.time_changed.connect (() => {
            settings.set_double ("night-light-schedule-to", date_time_double (to_time.time));
            clear_snooze ();
        });

        nightlight_switch.state_set.connect ((state) => {
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

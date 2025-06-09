/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. <https://elementary.io>
 *
 * Authored by: Leonardo Lemos <leonardolemos@live.com>
 */

public class Display.RefreshRateDropDown : Granite.Bin {
    public class RefreshRateOption : Object {
        public string label { get; set; }
        public Display.MonitorMode mode { get; set; }

        public RefreshRateOption () {
            Object ();
        }
    }

    public signal void refresh_rate_selected (RefreshRateOption refresh_rate);

    public Display.VirtualMonitor virtual_monitor { get; construct; }
    public uint selected { get { return drop_down.get_selected (); } }

    private Gtk.DropDown drop_down;
    private ListStore refresh_rates;

    public RefreshRateDropDown (Display.VirtualMonitor _virtual_monitor) {
        Object (
            virtual_monitor: _virtual_monitor
        );
    }

    construct {
        refresh_rates = new ListStore (typeof (RefreshRateOption));

        populate_refresh_rates ();

        var refresh_rate_factory = new Gtk.SignalListItemFactory ();
        refresh_rate_factory.setup.connect ((obj) => {
            var item = obj as Gtk.ListItem;
            item.child = new Gtk.Label (null) { xalign = 0 };
        });
        refresh_rate_factory.bind.connect ((obj) => {
            var item = obj as Gtk.ListItem;
            var refresh_rate = item.get_item () as RefreshRateOption;
            var item_child = item.child as Gtk.Label;
            item_child.label = refresh_rate.label;
        });

        drop_down = new Gtk.DropDown (refresh_rates, null) {
            factory = refresh_rate_factory,
            margin_start = 12,
            margin_end = 12
        };

        drop_down.sensitive = refresh_rates.get_n_items () > 0;

        set_current_refresh_rate ();

        drop_down.notify["selected"].connect (() => {
            var selected_refresh_rate = get_selected_refresh_rate ();
            if (selected_refresh_rate != null) {
                refresh_rate_selected (selected_refresh_rate);
            }
        });

        child = drop_down;
    }

    public RefreshRateOption get_selected_refresh_rate () {
        return drop_down.get_selected_item () as RefreshRateOption;
    }

    public void set_selected_refresh_rate (int refresh_rate) {
        drop_down.set_selected (refresh_rate);
    }

    public void update_refresh_rates (int width, int height) {
        refresh_rates.remove_all ();

        populate_refresh_rates ();

        drop_down.set_selected (0);

        drop_down.sensitive = refresh_rates.get_n_items () > 0;
    }

    private void set_current_refresh_rate () {
        var current_refresh_rate = virtual_monitor.current_mode.frequency;

        for (int i = 0; i < refresh_rates.get_n_items (); i++) {
            var item = refresh_rates.get_item (i) as RefreshRateOption;

            if (item.mode.frequency == current_refresh_rate) {
                drop_down.set_selected (i);
                return;
            }
        }
    }

    private void populate_refresh_rates () {
        var current_mode = virtual_monitor.current_mode;
        var modes = virtual_monitor.get_modes_for_resolution (current_mode.width, current_mode.height);

        var used_freqs = new Gee.HashSet<int> ();
        var options = new Gee.ArrayList<RefreshRateOption> ();

        // Prefer a frequency that is already rounded (e.g. 60.0)
        // over a different frequency rounded to the same value
        // (e.g. 59.76 rounded to 60.0).
        foreach (var mode in modes) {
            int freq_int = (int) Math.roundf ((float) mode.frequency);
            if (!used_freqs.contains (freq_int)) {
                var freq_display = mode.frequency % 1.0 == 0
                    ? mode.frequency
                    : Math.roundf ((float) mode.frequency);
                var label = _("%g Hz").printf (freq_display);
                options.add (new RefreshRateOption () {
                    label = label,
                    mode = mode
                });
                used_freqs.add (freq_int);
            }
        }

        options.sort ((a, b) => {
            if (a.mode.frequency < b.mode.frequency) {
                return -1;
            } else if (a.mode.frequency > b.mode.frequency) {
                return 1;
            }
            return 0;
        });

        foreach (var option in options) {
            refresh_rates.append (option);
        }
    }
}

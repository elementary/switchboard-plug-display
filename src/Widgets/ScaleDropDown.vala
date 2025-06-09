/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. <https://elementary.io>
 *
 * Authored by: Leonardo Lemos <leonardolemos@live.com>
 */

public class Display.ScaleDropDown : Granite.Bin {
    public class ScaleOption : Object {
        public string label { get; set; }
        public double value { get; set; }

        public ScaleOption (double _value) {
            Object (value: _value);

            label = "%d %%".printf ((int) Math.round (_value * 100));
        }
    }

    public Display.VirtualMonitor virtual_monitor { get; construct; }

    private Gtk.DropDown drop_down;
    private ListStore scales;

    public signal void scale_selected (ScaleOption scale);

    public ScaleDropDown (Display.VirtualMonitor _virtual_monitor) {
        Object (
            virtual_monitor: _virtual_monitor
        );
    }

    construct {
        scales = new ListStore (typeof (ScaleOption));

        populate_scales ();

        var scale_drop_down_factory = new Gtk.SignalListItemFactory ();
        scale_drop_down_factory.setup.connect ((obj) => {
            var list_item = obj as Gtk.ListItem;
            list_item.child = new Gtk.Label (null) { xalign = 0 };
        });
        scale_drop_down_factory.bind.connect ((obj) => {
            var list_item = obj as Gtk.ListItem;
            var item = list_item.item as ScaleOption;
            var scale_label = list_item.child as Gtk.Label;
            scale_label.label = item.label;
        });

        drop_down = new Gtk.DropDown (scales, null) {
            factory = scale_drop_down_factory,
            margin_start = 12,
            margin_end = 12
        };

        drop_down.notify["selected-item"].connect (() => {
            scale_selected (get_selected_scale ());
        });

        child = drop_down;
    }

    public void update_available_scales (Display.MonitorMode mode) {
        var scales_to_replace = new ScaleOption[] {};

        foreach (var scale in mode.supported_scales) {
            scales_to_replace += new ScaleOption (scale);
        }

        scales.splice (0, scales.get_n_items (), scales_to_replace);
    }

    public ScaleOption get_selected_scale () {
        return drop_down.get_selected_item () as ScaleOption;
    }

    private void populate_scales () {
        var current_mode = virtual_monitor.current_mode;

        foreach (var scale in current_mode.supported_scales) {
            var option = new ScaleOption (scale);

            scales.append (option);
        }
    }
}
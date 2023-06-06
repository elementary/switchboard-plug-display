/*
 * SPDX-License-Identifier: LGPL-2.0-or-later
 * SPDX-FileCopyrightText: 2023 elementary, Inc. (https://elementary.io)
 */

public class Display.FiltersView : Gtk.Box {
    construct {
        var colorblindness_header = new Granite.HeaderLabel (_("Color Deficiency Assistance"));

        var colorblindness_subtitle = new Gtk.Label (
            _("A filter can be applied to the entire display to help differentiate between colors")
        ) {
            wrap = true,
            xalign = 0
        };
        colorblindness_subtitle.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        // FIXME: Replace with Granite.HeaderLabel secondary_text in Gtk4
        var colorblindness_headerbox = new Gtk.Box (VERTICAL, 0) {
            margin_bottom = 3
        };
        colorblindness_headerbox.add (colorblindness_header);
        colorblindness_headerbox.add (colorblindness_subtitle);

        var none_radio = new Gtk.RadioButton.with_label (null, _("None"));

        var protanopia_label = new Gtk.Label (
            _("Red/Green") + "\n" + Granite.TOOLTIP_SECONDARY_TEXT_MARKUP.printf (_("Protanopia"))
        ) {
            halign = START,
            hexpand = true,
            selectable = true,
            use_markup = true
        };

        var protanopia_box = new Gtk.Box (HORIZONTAL, 0);
        protanopia_box.add (protanopia_label);
        protanopia_box.add (new ColorSwatch ("green") { valign = Gtk.Align.CENTER });
        protanopia_box.add (new ColorSwatch ("red") { valign = Gtk.Align.CENTER });

        var protanopia_radio = new Gtk.RadioButton.from_widget (none_radio) {
            child = protanopia_box
        };

        var protanopia_hc_label = new Gtk.Label (
            _("Red/Green — High Contrast") + "\n" + Granite.TOOLTIP_SECONDARY_TEXT_MARKUP.printf (_("Protanopia"))
        ) {
            halign = START,
            hexpand = true,
            selectable = true,
            use_markup = true
        };

        var protanopia_hc_box = new Gtk.Box (HORIZONTAL, 0);
        protanopia_hc_box.add (protanopia_hc_label);
        protanopia_hc_box.add (new ColorSwatch ("orange") { valign = Gtk.Align.CENTER });

        var protanopia_hc_radio = new Gtk.RadioButton.from_widget (none_radio) {
            child = protanopia_hc_box
        };

        var deuteranopia_label = new Gtk.Label (
            _("Green/Red") + "\n" + Granite.TOOLTIP_SECONDARY_TEXT_MARKUP.printf (_("Deuteranopia"))
        ) {
            halign = START,
            hexpand = true,
            selectable = true,
            use_markup = true
        };

        var deuteranopia_box = new Gtk.Box (HORIZONTAL, 0);
        deuteranopia_box.add (deuteranopia_label);
        deuteranopia_box.add (new ColorSwatch ("teal") { valign = Gtk.Align.CENTER });
        deuteranopia_box.add (new ColorSwatch ("pink") { valign = Gtk.Align.CENTER });

        var deuteranopia_radio = new Gtk.RadioButton.from_widget (none_radio) {
            child = deuteranopia_box
        };

        var deuteranopia_hc_label = new Gtk.Label (
            _("Green/Red — High Contrast") + "\n" + Granite.TOOLTIP_SECONDARY_TEXT_MARKUP.printf (_("Deuteranopia"))
        ) {
            halign = START,
            hexpand = true,
            selectable = true,
            use_markup = true
        };

        var deuteranopia_hc_box = new Gtk.Box (HORIZONTAL, 0);
        deuteranopia_hc_box.add (deuteranopia_hc_label);
        deuteranopia_hc_box.add (new ColorSwatch ("purple") { valign = Gtk.Align.CENTER });

        var deuteranopia_hc_radio = new Gtk.RadioButton.from_widget (none_radio) {
            child = deuteranopia_hc_box
        };

        var tritanopia_label = new Gtk.Label (
            _("Blue/Yellow") + "\n" + Granite.TOOLTIP_SECONDARY_TEXT_MARKUP.printf (_("Tritanopia"))
        ) {
            halign = START,
            hexpand = true,
            selectable = true,
            use_markup = true
        };

        var tritanopia_box = new Gtk.Box (HORIZONTAL, 0);
        tritanopia_box.add (tritanopia_label);
        tritanopia_box.add (new ColorSwatch ("yellow") { valign = Gtk.Align.CENTER });
        tritanopia_box.add (new ColorSwatch ("blue") { valign = Gtk.Align.CENTER });

        var tritanopia_radio = new Gtk.RadioButton.from_widget (none_radio) {
            child = tritanopia_box
        };

        var colorblindness_adjustment = new Gtk.Adjustment (0, 0.15, 1, 0.01, 0, 0);

        var colorblindness_scale = new Gtk.Scale (HORIZONTAL, colorblindness_adjustment) {
            draw_value = false,
            hexpand = true,
            margin_top = 3
        };
        colorblindness_scale.add_mark (0.15, Gtk.PositionType.BOTTOM, _("Less Assistance"));
        colorblindness_scale.add_mark (1, Gtk.PositionType.BOTTOM, _("More Assistance"));

        var colorblindness_box = new Gtk.Box (VERTICAL, 6);
        colorblindness_box.add (colorblindness_headerbox);
        colorblindness_box.add (none_radio);
        colorblindness_box.add (protanopia_radio);
        colorblindness_box.add (protanopia_hc_radio);
        colorblindness_box.add (deuteranopia_radio);
        colorblindness_box.add (deuteranopia_hc_radio);
        colorblindness_box.add (tritanopia_radio);
        colorblindness_box.add (colorblindness_scale);

        var grayscale_header = new Granite.HeaderLabel (_("Grayscale"));

        var grayscale_switch = new Gtk.Switch () {
            halign = END,
            valign = CENTER
        };

        var grayscale_subtitle = new Gtk.Label (
            _("Reducing color can help avoid distractions and alleviate screen addiction")
        ) {
            wrap = true,
            xalign = 0
        };
        grayscale_subtitle.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var grayscale_adjustment = new Gtk.Adjustment (0, 0.15, 1, 0.01, 0, 0);

        var grayscale_scale = new Gtk.Scale (HORIZONTAL, grayscale_adjustment) {
            draw_value = false,
            hexpand = true,
            margin_top = 6
        };
        grayscale_scale.add_mark (0.15, Gtk.PositionType.BOTTOM, _("More Color"));
        grayscale_scale.add_mark (1, Gtk.PositionType.BOTTOM, _("Less Color"));

        var grayscale_grid = new Gtk.Grid () {
            column_spacing = 12
        };
        grayscale_grid.attach (grayscale_header, 0, 0);
        grayscale_grid.attach (grayscale_subtitle, 0, 1);
        grayscale_grid.attach (grayscale_switch, 1, 0, 1, 2);
        grayscale_grid.attach (grayscale_scale, 0, 2, 2);

        var box = new Gtk.Box (VERTICAL, 24);
        box.add (colorblindness_box);
        box.add (grayscale_grid);

        var clamp = new Hdy.Clamp ();
        clamp.add (box);

        add (clamp);
        halign = CENTER;
        margin_start = 12;
        margin_end = 12;
        margin_bottom = 12;

        var a11y_settings = new Settings ("io.elementary.desktop.wm.accessibility");
        a11y_settings.bind ("colorblindness-correction-filter-strength", colorblindness_adjustment, "value", DEFAULT);
        a11y_settings.bind ("enable-monochrome-filter", grayscale_switch, "active", DEFAULT);
        a11y_settings.bind ("enable-monochrome-filter", grayscale_scale, "sensitive", DEFAULT);
        a11y_settings.bind ("monochrome-filter-strength", grayscale_adjustment, "value", DEFAULT);

        a11y_settings.bind_with_mapping (
            "colorblindness-correction-filter", none_radio, "active", DEFAULT,
            (value, variant, user_data) => {
                value.set_boolean (variant.get_string () == "none");
                return true;
            },
            (value, expected_type, user_data) => {
                if (value.get_boolean ()) {
                    return new Variant ("s", "none");
                }

                return null;
            },
            null, null
        );

        a11y_settings.bind_with_mapping (
            "colorblindness-correction-filter", protanopia_radio, "active", DEFAULT,
            (value, variant, user_data) => {
                value.set_boolean (variant.get_string () == "protanopia");
                return true;
            },
            (value, expected_type, user_data) => {
                if (value.get_boolean ()) {
                    return new Variant ("s", "protanopia");
                }

                return null;
            },
            null, null
        );

        a11y_settings.bind_with_mapping (
            "colorblindness-correction-filter", protanopia_hc_radio, "active", DEFAULT,
            (value, variant, user_data) => {
                value.set_boolean (variant.get_string () == "protanopia-high-contrast");
                return true;
            },
            (value, expected_type, user_data) => {
                if (value.get_boolean ()) {
                    return new Variant ("s", "protanopia-high-contrast");
                }

                return null;
            },
            null, null
        );

        a11y_settings.bind_with_mapping (
            "colorblindness-correction-filter", deuteranopia_radio, "active", DEFAULT,
            (value, variant, user_data) => {
                value.set_boolean (variant.get_string () == "deuteranopia");
                return true;
            },
            (value, expected_type, user_data) => {
                if (value.get_boolean ()) {
                    return new Variant ("s", "deuteranopia");
                }

                return null;
            },
            null, null
        );

        a11y_settings.bind_with_mapping (
            "colorblindness-correction-filter", deuteranopia_hc_radio, "active", DEFAULT,
            (value, variant, user_data) => {
                value.set_boolean (variant.get_string () == "deuteranopia-high-contrast");
                return true;
            },
            (value, expected_type, user_data) => {
                if (value.get_boolean ()) {
                    return new Variant ("s", "deuteranopia-high-contrast");
                }

                return null;
            },
            null, null
        );

        a11y_settings.bind_with_mapping (
            "colorblindness-correction-filter", tritanopia_radio, "active", DEFAULT,
            (value, variant, user_data) => {
                value.set_boolean (variant.get_string () == "tritanopia");
                return true;
            },
            (value, expected_type, user_data) => {
                if (value.get_boolean ()) {
                    return new Variant ("s", "tritanopia");
                }

                return null;
            },
            null, null
        );

        a11y_settings.bind_with_mapping (
            "colorblindness-correction-filter", colorblindness_scale, "sensitive", GET,
            (value, variant, user_data) => {
                value.set_boolean (variant.get_string () != "none");
                return true;
            },
            (value, expected_type, user_data) => {
                if (value.get_boolean ()) {
                    return new Variant ("s", "none");
                }

                return null;
            },
            null, null
        );
    }

    private class ColorSwatch : Gtk.Grid {
        public string color { get; construct; }
        private static Gtk.CssProvider provider;

        public ColorSwatch (string color) {
            Object (color: color);
        }

        class construct {
            set_css_name ("colorswatch");
        }

        static construct {
            provider = new Gtk.CssProvider ();
            provider.load_from_resource ("io/elementary/switchboard/display/Filters.css");
        }

        construct {
            var context = get_style_context ();
            context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            context.add_class (color);
        }
    }
}

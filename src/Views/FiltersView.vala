/*
 * SPDX-License-Identifier: LGPL-2.0-or-later
 * SPDX-FileCopyrightText: 2023 elementary, Inc. (https://elementary.io)
 */

public class Display.FiltersView : Gtk.Box {
    private const string TEXT_MARKUP = "%s\n<span size='smaller' alpha='75%'>%s</span>";

    construct {
        var colorblindness_header = new Granite.HeaderLabel (_("Color Deficiency Assistance")) {
            secondary_text = _("Each of the circles below should appear as a different color. A filter can be applied to the entire display to help differentiate between colors.")
        };

        var none_radio = new Gtk.CheckButton.with_label (_("None"));

        var protanopia_label = new Gtk.Label (
            TEXT_MARKUP.printf (_("Red/Green"), _("Protanopia"))
        ) {
            halign = START,
            hexpand = true,
            selectable = true,
            use_markup = true
        };

        var protanopia_box = new Gtk.Box (HORIZONTAL, 0);
        protanopia_box.append (protanopia_label);
        protanopia_box.append (new ColorSwatch ("green"));
        protanopia_box.append (new ColorSwatch ("orange"));
        protanopia_box.append (new ColorSwatch ("red"));

        var protanopia_radio = new Gtk.CheckButton () {
            group = none_radio
        };
        protanopia_box.set_parent (protanopia_radio);

        var protanopia_hc_label = new Gtk.Label (
            TEXT_MARKUP.printf (_("Red/Green — High Contrast"), _("Protanopia"))
        ) {
            halign = START,
            hexpand = true,
            selectable = true,
            use_markup = true
        };

        var protanopia_hc_box = new Gtk.Box (HORIZONTAL, 0);
        protanopia_hc_box.append (protanopia_hc_label);

        var protanopia_hc_radio = new Gtk.CheckButton () {
            group = none_radio
        };
        protanopia_hc_box.set_parent (protanopia_hc_radio);

        var deuteranopia_label = new Gtk.Label (
            TEXT_MARKUP.printf (_("Green/Red"), _("Deuteranopia"))
        ) {
            halign = START,
            hexpand = true,
            selectable = true,
            use_markup = true
        };

        var deuteranopia_box = new Gtk.Box (HORIZONTAL, 0);
        deuteranopia_box.append (deuteranopia_label);
        deuteranopia_box.append (new ColorSwatch ("teal"));
        deuteranopia_box.append (new ColorSwatch ("purple"));
        deuteranopia_box.append (new ColorSwatch ("pink"));

        var deuteranopia_radio = new Gtk.CheckButton () {
            group = none_radio
        };
        deuteranopia_box.set_parent (deuteranopia_radio);

        var deuteranopia_hc_label = new Gtk.Label (
            TEXT_MARKUP.printf (_("Green/Red — High Contrast"), _("Deuteranopia"))
        ) {
            halign = START,
            hexpand = true,
            selectable = true,
            use_markup = true
        };

        var deuteranopia_hc_box = new Gtk.Box (HORIZONTAL, 0);
        deuteranopia_hc_box.append (deuteranopia_hc_label);

        var deuteranopia_hc_radio = new Gtk.CheckButton () {
            group = none_radio
        };
        deuteranopia_hc_box.set_parent (deuteranopia_hc_radio);

        var tritanopia_label = new Gtk.Label (
            TEXT_MARKUP.printf (_("Blue/Yellow"), _("Tritanopia"))
        ) {
            halign = START,
            hexpand = true,
            selectable = true,
            use_markup = true
        };

        var tritanopia_box = new Gtk.Box (HORIZONTAL, 0);
        tritanopia_box.append (tritanopia_label);
        tritanopia_box.append (new ColorSwatch ("yellow"));
        tritanopia_box.append (new ColorSwatch ("blue"));

        var tritanopia_radio = new Gtk.CheckButton () {
            group = none_radio
        };
        tritanopia_box.set_parent (tritanopia_radio);

        var colorblindness_adjustment = new Gtk.Adjustment (0, 0.15, 1, 0.01, 0, 0);

        var colorblindness_scale = new Gtk.Scale (HORIZONTAL, colorblindness_adjustment) {
            draw_value = false,
            hexpand = true,
            margin_top = 3
        };
        colorblindness_scale.add_mark (0.15, BOTTOM, _("Less Assistance"));
        colorblindness_scale.add_mark (1, BOTTOM, _("More Assistance"));

        var colorblindness_box = new Gtk.Box (VERTICAL, 6);
        colorblindness_box.append (colorblindness_header);
        colorblindness_box.append (none_radio);
        colorblindness_box.append (protanopia_radio);
        colorblindness_box.append (protanopia_hc_radio);
        colorblindness_box.append (deuteranopia_radio);
        colorblindness_box.append (deuteranopia_hc_radio);
        colorblindness_box.append (tritanopia_radio);
        colorblindness_box.append (colorblindness_scale);

        var grayscale_header = new Granite.HeaderLabel (_("Grayscale")) {
            secondary_text = _("Reducing color can help avoid distractions and alleviate screen addiction")
        };

        var grayscale_switch = new Gtk.Switch () {
            halign = END,
            valign = CENTER
        };

        var grayscale_adjustment = new Gtk.Adjustment (0, 0.15, 1, 0.01, 0, 0);

        var grayscale_scale = new Gtk.Scale (HORIZONTAL, grayscale_adjustment) {
            draw_value = false,
            hexpand = true,
            margin_top = 6
        };
        grayscale_scale.add_mark (0.15, BOTTOM, _("More Color"));
        grayscale_scale.add_mark (1, BOTTOM, _("Less Color"));

        var grayscale_grid = new Gtk.Grid () {
            column_spacing = 12
        };
        grayscale_grid.attach (grayscale_header, 0, 0);
        grayscale_grid.attach (grayscale_switch, 1, 0);
        grayscale_grid.attach (grayscale_scale, 0, 1, 2);

        var box = new Gtk.Box (VERTICAL, 24);
        box.append (colorblindness_box);
        box.append (grayscale_grid);

        var clamp = new Adw.Clamp () {
            child = box
        };

        append (clamp);
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

                return new Variant.maybe (VariantType.STRING, null);
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

                return new Variant.maybe (VariantType.STRING, null);
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

                return new Variant.maybe (VariantType.STRING, null);
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

                return new Variant.maybe (VariantType.STRING, null);
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

                return new Variant.maybe (VariantType.STRING, null);
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

                return new Variant.maybe (VariantType.STRING, null);
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

                return new Variant.maybe (VariantType.STRING, null);
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
            provider.load_from_resource ("io/elementary/settings/display/Filters.css");
        }

        construct {
            get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            add_css_class (color);

            valign = CENTER;
        }
    }
}

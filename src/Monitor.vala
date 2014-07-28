
class Monitor : Clutter.Actor {
    const int MARGIN = 6;

    public signal void show_settings (Gnome.RROutputInfo output, Gdk.Rectangle position);

    public unowned Gnome.RROutputInfo output { get; construct; }
    Gdk.RGBA rgba;
    Gtk.Image primary_image;
    Gtk.Image settings_image;
    Gtk.Label label;

    public Monitor (Gnome.RROutputInfo output) {
        Object (output: output);

        layout_manager = new Clutter.BinLayout ();
        primary_image = new Gtk.Image.from_icon_name ("non-starred-symbolic", Gtk.IconSize.MENU);
        primary_image.margin = MARGIN;
        var primary = new GtkClutter.Actor.with_contents (primary_image);

        settings_image = new Gtk.Image.from_icon_name ("document-properties-symbolic", Gtk.IconSize.MENU);
        settings_image.margin = MARGIN;
        var settings = new GtkClutter.Actor.with_contents (settings_image);
        settings.reactive = true;
        settings.button_release_event.connect (() => {
            float x, y;
            settings.get_transformed_position (out x, out y);

            show_settings (output, { (int) x, (int) y, (int) settings.width, (int) settings.height });

            return false;
        });

        label = new Gtk.Label (output.get_display_name ());
        var label_actor = new GtkClutter.Actor.with_contents (label);

        var canvas = new Clutter.Canvas ();
        canvas.draw.connect (draw_background);
        notify["allocation"].connect (() => {
            canvas.set_size ((int) width, (int) height);
        });

        content = canvas;

        add_child (primary);
        add_child (settings);
        add_child (label_actor);

        settings.x_align = Clutter.ActorAlign.END;
        settings.x_expand = true;
        settings.y_align = Clutter.ActorAlign.START;
        label_actor.x_align = Clutter.ActorAlign.CENTER;
        label_actor.x_expand = true;
        label_actor.y_align = Clutter.ActorAlign.CENTER;
        label_actor.y_expand = true;
    }

    public void update_position (float scale_factor, float offset_x, float offset_y) {
        int monitor_x, monitor_y, monitor_width, monitor_height;
        output.get_geometry (out monitor_x, out monitor_y, out monitor_width, out monitor_height);

        var rotation = output.get_rotation ();
        switch (rotation) {
            case Gnome.RRRotation.ROTATION_90:
                var tmp = monitor_width;
                monitor_width = monitor_height;
                monitor_height = tmp;
                label.angle = 270;
                break;
            case Gnome.RRRotation.ROTATION_180:
                label.angle = 180;
                break;
            case Gnome.RRRotation.ROTATION_270:
                var tmp = monitor_width;
                monitor_width = monitor_height;
                monitor_height = tmp;
                label.angle = 90;
                break;
            default:
                break;
        }

        set_position (Math.floorf (offset_x + monitor_x * scale_factor),
                      Math.floorf (offset_y + monitor_y * scale_factor));

        set_size (Math.floorf (monitor_width * scale_factor),
                  Math.floorf (monitor_height * scale_factor));
    }

    public void set_rgba (Gdk.RGBA new_rgba) {
        rgba = new_rgba;
        primary_image.override_background_color (Gtk.StateFlags.NORMAL, rgba);
        settings_image.override_background_color (Gtk.StateFlags.NORMAL, rgba);
        if (use_white_text (rgba) == true) {
            var white = Gdk.RGBA ();
            white.parse ("#FFFFFF");
            white.alpha = 1;
            primary_image.override_color (Gtk.StateFlags.NORMAL, white);
            settings_image.override_color (Gtk.StateFlags.NORMAL, white);
            label.override_color (Gtk.StateFlags.NORMAL, white);
        } else {
            var black = Gdk.RGBA ();
            black.parse ("#000000");
            black.alpha = 1;
            primary_image.override_color (Gtk.StateFlags.NORMAL, black);
            settings_image.override_color (Gtk.StateFlags.NORMAL, black);
            label.override_color (Gtk.StateFlags.NORMAL, black);
        }
    }

    private bool draw_background (Cairo.Context cr) {
        // TODO draw shadow and inner highlight
        cr.rectangle (0, 0, (int) width, (int) height);
        cr.set_source_rgb (rgba.red, rgba.green, rgba.blue);
        cr.fill ();
        cr.rectangle (0, 0, (int) width, (int) height);
        cr.set_source_rgba (1, 1, 1, 0.5);
        cr.set_line_width (1);
        cr.stroke ();

        return false;
    }

    // Help function, from: http://www.w3.org/TR/WCAG20/
    private bool use_white_text (Gdk.RGBA rgba) {
        double R;
        if (rgba.red <= 0.03928) {
            R = rgba.red/12.92;
        } else {
            R = Math.pow((rgba.red+0.055)/1.055, 2.4);
        }
        double G;
        if (rgba.green <= 0.03928) {
            G = rgba.green/12.92;
        } else {
            G = Math.pow((rgba.green+0.055)/1.055, 2.4);
        }
        double B;
        if (rgba.blue <= 0.03928) {
            B = rgba.blue/12.92;
        } else {
            B = Math.pow((rgba.blue+0.055)/1.055, 2.4);
        }
        var L = 0.2126 * R + 0.7152 * G + 0.0722 * B;
        if (L > 0.5) {
            return false;
        } else {
            return true;
        }
    }
}
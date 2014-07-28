
class Monitor : Clutter.Actor {
    const int MARGIN = 6;

    public signal void show_settings (Gnome.RROutputInfo output, Gdk.Rectangle position);

    public unowned Gnome.RROutputInfo output { get; construct; }
    public Gdk.RGBA rgba;

    public Monitor (Gnome.RROutputInfo output) {
        Object (output: output);

        var align = new Clutter.BinLayout ();
        layout_manager = align;

        var primary = new GtkClutter.Texture ();
        primary.margin_left = primary.margin_top = MARGIN;
        primary.set_from_pixbuf (Gtk.IconTheme.get_default ()
            .lookup_icon ("gtk-about-symbolic", 16, 0).load_symbolic ({ 0, 0, 0, 1 }));

        var settings = new GtkClutter.Texture ();
        settings.reactive = true;
        settings.button_release_event.connect (() => {
            float x, y;
            settings.get_transformed_position (out x, out y);

            show_settings (output, { (int) x, (int) y, (int) settings.width, (int) settings.height });

            return false;
        });
        settings.margin_right = settings.margin_top = MARGIN;
        settings.set_from_pixbuf (Gtk.IconTheme.get_default ()
            .lookup_icon ("document-properties-symbolic", 16, 0).load_symbolic ({ 1, 1, 1, 1 }));

        var label = new Clutter.Text.with_text (null, output.get_display_name ());
        label.color = { 255, 255, 255, 255 };

        var canvas = new Clutter.Canvas ();
        canvas.draw.connect (draw_background);
        notify["allocation"].connect (() => {
            canvas.set_size ((int) width, (int) height);
        });

        content = canvas;

        add_child (primary);
        add_child (settings);
        add_child (label);

        align.set_alignment (settings, Clutter.BinAlignment.END, Clutter.BinAlignment.START);
        align.set_alignment (label, Clutter.BinAlignment.CENTER, Clutter.BinAlignment.CENTER);
    }

    public void update_position (float scale_factor, float offset_x, float offset_y) {
        int monitor_x, monitor_y, monitor_width, monitor_height;
        output.get_geometry (out monitor_x, out monitor_y, out monitor_width, out monitor_height);

        var rotation = output.get_rotation ();
        if (rotation == Gnome.RRRotation.ROTATION_90
            || rotation == Gnome.RRRotation.ROTATION_270) {
            var tmp = monitor_width;
            monitor_width = monitor_height;
            monitor_height = tmp;
        }

        set_position (Math.floorf (offset_x + monitor_x * scale_factor),
                      Math.floorf (offset_y + monitor_y * scale_factor));

        set_size (Math.floorf (monitor_width * scale_factor),
                  Math.floorf (monitor_height * scale_factor));
    }

    bool draw_background (Cairo.Context cr) {
        // TODO draw shadow, inner highlight and use correct color
        cr.rectangle (0, 0, (int) width, (int) height);
        cr.set_source_rgb (rgba.red, rgba.green, rgba.blue);
        cr.fill ();

        return false;
    }
}
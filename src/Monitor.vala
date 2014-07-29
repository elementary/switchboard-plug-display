
class Monitor : Clutter.Actor {
    const int MARGIN = 6;

    public signal void is_primary ();
    public signal void reposition ();

    public unowned Gnome.RROutputInfo output { get; construct; }
    Gdk.RGBA rgba;
    Gtk.Image primary_image;
    Gtk.Image settings_image;
    Gtk.Label label;
    DisplayPopover display_popover;
    Gtk.Dialog monitor_revealer;
    Gtk.Label monitor_revealer_label;
    public Clutter.DragAction drag_action { get; private set; }
    public bool is_main_clone { get; private set; default=false; }

    public Monitor (Gnome.RROutputInfo output) {
        Object (output: output);
        reactive = true;

        drag_action = new Clutter.DragAction ();
        add_action (drag_action);

        layout_manager = new Clutter.BinLayout ();
        primary_image = new Gtk.Image.from_icon_name ("non-starred-symbolic", Gtk.IconSize.MENU);
        primary_image.margin = MARGIN;
        if (output.get_primary () == true) {
            primary_image.icon_name = "starred-symbolic";
        }

        var primary = new GtkClutter.Actor.with_contents (primary_image);
        primary.reactive = true;
        primary.button_release_event.connect ((event) => {
            if (primary_image.icon_name == "non-starred-symbolic" && event.button == 1) {
                primary_image.icon_name = "starred-symbolic";
                output.set_primary (true);
                is_primary ();
                return true;
            }

            return false;
        });

        settings_image = new Gtk.Image.from_icon_name ("document-properties-symbolic", Gtk.IconSize.MENU);
        settings_image.margin = MARGIN;
        var settings = new GtkClutter.Actor.with_contents (settings_image);
        settings.reactive = true;
        settings.button_release_event.connect ((event) => {
            if (event.button == 1) {
                display_popover.show_all ();
                return true;
            }
    
            return false;
        });

        // Reposition the Popover if the window is resized.
        settings.allocation_changed.connect (() => {
            settings_image.queue_resize ();
        });

        // Reposition the Popover if the screen resolution has changed.
        allocation_changed.connect (() => {
            settings_image.queue_resize ();
        });

        display_popover = Configuration.get_default ().get_popover (output);
        display_popover.relative_to = settings_image;
        display_popover.update_settings ();
        display_popover.update_config.connect (() => {
            reposition ();
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

        monitor_revealer = new Gtk.Dialog ();
        monitor_revealer_label = new Gtk.Label (output.get_display_name ());
        if (output.is_active ()) {
            monitor_revealer.accept_focus = false;
            monitor_revealer.decorated = false;
            monitor_revealer.resizable = false;
            monitor_revealer.type_hint = Gdk.WindowTypeHint.TOOLTIP;
            monitor_revealer.set_keep_above (true);
            monitor_revealer.opacity = 0.75;
            monitor_revealer.get_content_area ().add (monitor_revealer_label);
            monitor_revealer.get_action_area ().destroy ();
            monitor_revealer_label.margin = 12;

            int monitor_x, monitor_y;
            output.get_geometry (out monitor_x, out monitor_y, null, null);
            monitor_revealer.move (monitor_x, monitor_y);

            show.connect (() => {
                monitor_revealer.show_all ();
            });

            hide.connect (() => {
                monitor_revealer.hide ();
            });
            
            destroy.connect (() => {
                monitor_revealer.destroy ();
            });
        }
    }

    public void set_main_clone () {
        is_main_clone = true;
        label.label = _("Mirrored Displays");
        monitor_revealer.no_show_all = true;
    }

    public void unset_primary () {
        if (primary_image.icon_name == "starred-symbolic") {
            primary_image.icon_name = "non-starred-symbolic";
            output.set_primary (false);
        }
    }

    public void update_position (float scale_factor, float offset_x, float offset_y) {
        int monitor_x, monitor_y;
        output.get_geometry (out monitor_x, out monitor_y, null, null);
        int monitor_width = get_real_width ();
        int monitor_height = get_real_height ();

        var rotation = output.get_rotation ();
        switch (rotation) {
            case Gnome.RRRotation.ROTATION_90:
                label.angle = 270;
                break;
            case Gnome.RRRotation.ROTATION_180:
                label.angle = 180;
                break;
            case Gnome.RRRotation.ROTATION_270:
                label.angle = 90;
                break;
            default:
                label.angle = 0;
                break;
        }

        set_position (Math.floorf (offset_x + monitor_x * scale_factor),
                      Math.floorf (offset_y + monitor_y * scale_factor));
        set_size (Math.floorf (monitor_width * scale_factor),
                  Math.floorf (monitor_height * scale_factor));
    }

    public int get_real_width () {
        int monitor_width, monitor_height;
        output.get_geometry (null, null, out monitor_width, out monitor_height);
        if (monitor_width == 0) {
            monitor_width = output.get_preferred_width ();
        }

        if (monitor_height == 0) {
            monitor_height = output.get_preferred_height ();
        }

        var rotation = output.get_rotation ();
        switch (rotation) {
            case Gnome.RRRotation.ROTATION_90:
            case Gnome.RRRotation.ROTATION_270:
                return monitor_height;
            default:
                return monitor_width;
        }
    }

    public int get_real_height () {
        int monitor_width, monitor_height;
        output.get_geometry (null, null, out monitor_width, out monitor_height);
        if (monitor_width == 0) {
            monitor_width = output.get_preferred_width ();
        }

        if (monitor_height == 0) {
            monitor_height = output.get_preferred_height ();
        }

        var rotation = output.get_rotation ();
        switch (rotation) {
            case Gnome.RRRotation.ROTATION_90:
            case Gnome.RRRotation.ROTATION_270:
                return monitor_width;
            default:
                return monitor_height;
        }
    }

    public void set_rgba (Gdk.RGBA new_rgba) {
        rgba = new_rgba;
        primary_image.override_background_color (Gtk.StateFlags.NORMAL, rgba);
        settings_image.override_background_color (Gtk.StateFlags.NORMAL, rgba);
        monitor_revealer.override_background_color (Gtk.StateFlags.NORMAL, rgba);
        if (use_white_text (rgba) == true) {
            var white = Gdk.RGBA ();
            white.parse ("#FFFFFF");
            white.alpha = 1;
            primary_image.override_color (Gtk.StateFlags.NORMAL, white);
            settings_image.override_color (Gtk.StateFlags.NORMAL, white);
            label.override_color (Gtk.StateFlags.NORMAL, white);
            monitor_revealer_label.override_color (Gtk.StateFlags.NORMAL, white);
        } else {
            var black = Gdk.RGBA ();
            black.parse ("#000000");
            black.alpha = 1;
            primary_image.override_color (Gtk.StateFlags.NORMAL, black);
            settings_image.override_color (Gtk.StateFlags.NORMAL, black);
            label.override_color (Gtk.StateFlags.NORMAL, black);
            monitor_revealer_label.override_color (Gtk.StateFlags.NORMAL, black);
        }
    }

    public void disable () {
        rgba = Gdk.RGBA ();
        rgba.parse ("#000000");
        rgba.alpha = 1;
        var white = Gdk.RGBA ();
        white.parse ("#FFFFFF");
        white.alpha = 1;
        primary_image.override_color (Gtk.StateFlags.NORMAL, white);
        settings_image.override_color (Gtk.StateFlags.NORMAL, white);
        label.sensitive = false;
        primary_image.hide ();
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
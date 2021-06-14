/*-
 * Copyright (c) 2014-2018 elementary LLC.
 *
 * This software is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this software; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public struct Display.Resolution {
    uint width;
    uint height;
}

public class Display.DisplayWidget : Gtk.EventBox {
    public signal void set_as_primary ();
    public signal void move_display (double diff_x, double diff_y);
    public signal void end_grab (int delta_x, int delta_y);
    public signal void check_position ();

    public Display.VirtualMonitor virtual_monitor;
    public DisplayWindow display_window;
    public double window_ratio = 1.0;
    public int delta_x { get; set; default = 0; }
    public int delta_y { get; set; default = 0; }
    public bool only_display { get; set; default = false; }
    public Gtk.Label monitor_name_label;
    private double start_x = 0;
    private double start_y = 0;
    private bool holding = false;

    public Gtk.Button primary_image { get; private set; }

    private int real_width = 0;
    private int real_height = 0;

    public DisplayWidget (Display.VirtualMonitor virtual_monitor) {
        this.virtual_monitor = virtual_monitor;
        display_window = new DisplayWindow (virtual_monitor);
        events |= Gdk.EventMask.BUTTON_PRESS_MASK;
        events |= Gdk.EventMask.BUTTON_RELEASE_MASK;
        events |= Gdk.EventMask.POINTER_MOTION_MASK;
        virtual_monitor.get_current_mode_size (out real_width, out real_height);

        primary_image = new Gtk.Button.from_icon_name ("non-starred-symbolic", Gtk.IconSize.MENU);
        primary_image.margin = 6;
        primary_image.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        primary_image.halign = Gtk.Align.START;
        primary_image.valign = Gtk.Align.START;
        primary_image.clicked.connect (() => set_as_primary ());
        set_primary (virtual_monitor.primary);

        monitor_name_label = new Gtk.Label (virtual_monitor.get_display_name ()) {
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER,
            expand = true
        };

        var grid = new Gtk.Grid ();
        grid.attach (primary_image, 0, 0);
        grid.attach (monitor_name_label, 0, 0, 3, 2);

        add (grid);

        display_window.attached_to = this;

        destroy.connect (() => display_window.destroy ());
    }

    ~DisplayWidget () {
        debug ("DESTRUCT display widget");
    }

    public override bool button_press_event (Gdk.EventButton event) {
        if (only_display) {
            return false;
        }

        start_x = event.x_root;
        start_y = event.y_root;
        holding = true;
        return false;
    }

    public override bool button_release_event (Gdk.EventButton event) {
        holding = false;
        if ((delta_x == 0 && delta_y == 0) || only_display) {
            return false;
        }

        var old_delta_x = delta_x;
        var old_delta_y = delta_y;
        delta_x = 0;
        delta_y = 0;
        end_grab (old_delta_x, old_delta_y);
        return false;
    }

    public override bool motion_notify_event (Gdk.EventMotion event) {
        if (holding && !only_display) {
            move_display (event.x_root - start_x, event.y_root - start_y);
        }

        return false;
    }

    public void set_primary (bool is_primary) {
        if (is_primary) {
            ((Gtk.Image) primary_image.image).icon_name = "starred-symbolic";
            primary_image.tooltip_text = _("Is the primary display");
        } else {
            ((Gtk.Image) primary_image.image).icon_name = "non-starred-symbolic";
            primary_image.tooltip_text = _("Set as primary display");
        }
    }

    public override void get_preferred_height_for_width (int width, out int minimum_height, out int natural_height) {
        natural_height = (int)((double)width * (double)real_height / (double)real_width);
        minimum_height = natural_height;
    }

    public void get_geometry (out int x, out int y, out int width, out int height) {
        x = virtual_monitor.x;
        y = virtual_monitor.y;
        width = real_width;
        height = real_height;
    }

    public void set_geometry (int x, int y, int width, int height) {
        virtual_monitor.x = x;
        virtual_monitor.y = y;
        real_width = width;
        real_height = height;
        // This ensures the widget resizes immediately - is there a better way? Queue_draw () does not work.
        set_rotation (virtual_monitor.transform);
    }

    public void set_rotation (DisplayTransform transform) {
        switch (transform) {
            case DisplayTransform.NORMAL:
                virtual_monitor.get_current_mode_size (out real_width, out real_height);
                monitor_name_label.angle = 0;
                monitor_name_label.label = virtual_monitor.get_display_name ();
                break;
            case DisplayTransform.ROTATION_90:
                virtual_monitor.get_current_mode_size (out real_height, out real_width);
                monitor_name_label.angle = 270;
                monitor_name_label.label = virtual_monitor.get_display_name ();
                break;
            case DisplayTransform.ROTATION_180:
                virtual_monitor.get_current_mode_size (out real_width, out real_height);
                monitor_name_label.angle = 180;
                monitor_name_label.label = virtual_monitor.get_display_name ();
                break;
            case DisplayTransform.ROTATION_270:
                virtual_monitor.get_current_mode_size (out real_height, out real_width);
                monitor_name_label.angle = 90;
                monitor_name_label.label = virtual_monitor.get_display_name ();
                break;
            case DisplayTransform.FLIPPED:
                virtual_monitor.get_current_mode_size (out real_width, out real_height);
                monitor_name_label.angle = 0;
                monitor_name_label.label = virtual_monitor.get_display_name ().reverse (); //mirroring simulation, because we can't really mirror the text
                break;
            case DisplayTransform.FLIPPED_ROTATION_90:
                virtual_monitor.get_current_mode_size (out real_height, out real_width);
                monitor_name_label.angle = 270;
                monitor_name_label.label = virtual_monitor.get_display_name ().reverse ();
                break;
            case DisplayTransform.FLIPPED_ROTATION_180:
                virtual_monitor.get_current_mode_size (out real_width, out real_height);
                monitor_name_label.angle = 180;
                monitor_name_label.label = virtual_monitor.get_display_name ().reverse ();
                break;
            case DisplayTransform.FLIPPED_ROTATION_270:
                virtual_monitor.get_current_mode_size (out real_height, out real_width);
                monitor_name_label.angle = 90;
                monitor_name_label.label = virtual_monitor.get_display_name ().reverse ();
                break;
        }
    }

    public bool equals (DisplayWidget sibling) {
        return virtual_monitor.id == sibling.virtual_monitor.id;
    }
}

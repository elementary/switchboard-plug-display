
public class DisplayPopover : Gtk.Popover {
    public signal void update_config ();

    unowned Gnome.RROutputInfo? info = null;
    unowned Gnome.RROutput? output = null;
    Gnome.RRConfig current_config;
    Gnome.RRScreen current_screen;

    Gtk.Switch use_display;
    Gtk.ComboBox resolution;
    Gtk.ComboBoxText rotation;
    Gtk.Grid grid;

    Gtk.ListStore resolution_list;

    bool ui_update = false;

    public DisplayPopover (Gnome.RRScreen screen, Gnome.RROutputInfo output_info, Gnome.RRConfig config) {
        position = Gtk.PositionType.BOTTOM;

        current_screen = screen;
        current_config = config;
        info = output_info;
        output = screen.get_output_by_name (info.get_name ());

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);

        grid = new Gtk.Grid ();
        grid.margin = 12;
        grid.margin_top = 0;
        grid.row_spacing = 6;
        grid.column_spacing = 12;

        use_display = new Gtk.Switch ();
        use_display.halign = Gtk.Align.END;
        use_display.notify["active"].connect (() => {
            if (ui_update)
                return;

            info.set_active (use_display.active);

            update_config ();
            update_settings ();
        });

        var use_display_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        use_display_box.margin = 12;
        use_display_box.margin_bottom = 0;
        use_display_box.pack_start (new Utils.RLabel.right (_("Use This Display")), false);
        use_display_box.pack_start (use_display);

        box.pack_start (use_display_box, false);
        box.pack_start (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), false);
        box.pack_start (grid);

        var text_renderer = new Gtk.CellRendererText ();
        resolution = new Gtk.ComboBoxText ();
        resolution_list = new Gtk.ListStore (2, typeof (string), typeof (Gnome.RRMode));
        resolution = new Gtk.ComboBox.with_model (resolution_list);
        resolution.pack_start (text_renderer, true);
        resolution.add_attribute (text_renderer, "text", 0);
        resolution.expand = true;
        resolution.valign = Gtk.Align.CENTER;
        resolution.notify["active"].connect (() => {
            if (ui_update)
                return;

            Gtk.TreeIter iter;
            unowned Gnome.RRMode mode;
            int x, y;

            if (!resolution.get_active_iter (out iter))
                return;

            resolution_list.@get (iter, 1, out mode);

            var width = (int) mode.get_width ();
            var height = (int) mode.get_height ();
            info.get_geometry (out x, out y, null, null);

            info.set_geometry (x, y, width, height);

            update_config ();
        });

        grid.attach (new Utils.RLabel.right (_("Resolution:")), 0, 2, 1, 1);
        grid.attach (resolution, 1, 2, 1, 1);

        rotation = new Gtk.ComboBoxText ();
        rotation.valign = Gtk.Align.CENTER;
        rotation.changed.connect (() => {
            if (ui_update)
                return;

            int rot = int.parse (rotation.active_id);
            info.set_rotation ((Gnome.RRRotation) rot);

            update_config ();
        });
        grid.attach (new Utils.RLabel.right (_("Rotation:")), 0, 4, 1, 1);
        grid.attach (rotation, 1, 4, 1, 1);

        add (box);
    }

    public void update_settings () {
        ui_update = true;

        var enabled_monitors = 0;
        foreach (unowned Gnome.RROutputInfo output in current_config.get_outputs ()) {
            if (output.is_connected ())
                enabled_monitors++;
        }

        var is_multi_monitor = enabled_monitors > 1;

        use_display.active = info.is_active ();
        use_display.sensitive = is_multi_monitor;
        grid.sensitive = info.is_active ();

        update_modes ();
        update_rotation ();

        ui_update = false;
    }

    void update_modes () {
        resolution.active_id = output.get_current_mode ().get_id ().to_string ();
        unowned Gnome.RRMode[] modes;

        if (current_config.get_clone ())
            modes = current_screen.list_clone_modes ();
        else
            modes = output.list_modes ();

        unowned Gnome.RRMode current_mode = output.get_current_mode ();
        var current_width = current_mode.get_width ();
        var current_height = current_mode.get_height ();

        foreach (unowned Gnome.RRMode mode in modes) {
            var mode_width = mode.get_width ();
            var mode_height = mode.get_height ();
            var aspect = Utils.make_aspect_string (mode_width, mode_height);

            string label;
            if (aspect != null)
                label = "%u × %u (%s)".printf (mode_width, mode_height, aspect);
            else
                label = "%u × %u".printf (mode_width, mode_height);

            Gtk.TreeIter iter;
            bool present = false;
            for (var valid = resolution_list.get_iter_first (out iter); valid;
                valid = resolution_list.iter_next (ref iter)) {

                string output_label;
                resolution_list.@get (iter, 0, out output_label);

                if (output_label == label) {
                    present = true;
                    break;
                }
            }

            if (present)
                continue;

            resolution_list.insert_with_values (out iter, -1, 0, label, 1, mode);

            if (mode_width == current_width && mode_height == current_height)
                resolution.set_active_iter (iter);
        }

        if (output.get_current_mode () == null)
            resolution.active = 0;
    }

    void update_rotation () {
        rotation.remove_all ();

        var n_rotations = 0;

        Gnome.RRRotation[] rotations = {
            Gnome.RRRotation.ROTATION_0,
            Gnome.RRRotation.ROTATION_90,
            Gnome.RRRotation.ROTATION_270,
            Gnome.RRRotation.ROTATION_180
        };

        string[] desc = {
            _("Normal"),
            _("Counterclockwise"),
            _("Clockwise"),
            _("180 Degrees")
        };

#if !HAS_GNOME312
        var current_rotation = info.get_rotation ();
#endif

        for (var i = 0; i < rotations.length; i++) {
#if HAS_GNOME312
            if (info.supports_rotation (rotations[i])) {
#else
            info.set_rotation (rotations[i]);
            try {
                if (current_config.applicable (current_screen)) {
#endif
                rotation.append (((int) rotations[i]).to_string (), desc[i]);
                n_rotations++;
#if HAS_GNOME312
            }
        }
#else
                }
            } catch (Error e) {}
        }

        info.set_rotation (current_rotation);
#endif

        rotation.sensitive = n_rotations > 0;
        rotation.active_id = ((int) info.get_rotation ()).to_string ();
    }
}

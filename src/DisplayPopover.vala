
public class DisplayPopover : Gtk.Popover
{
	public signal void update_config ();

	unowned Gnome.RROutputInfo? info = null;
	unowned Gnome.RROutput? output = null;
	Gnome.RRConfig current_config;
	Gnome.RRScreen current_screen;

	Gtk.Switch use_display;
	Gtk.Switch mirror_display;
	Gtk.ComboBoxText resolution;
	Gtk.ComboBoxText rotation;

	bool ui_update = false;

	public DisplayPopover (Gtk.Widget relative_to, Gdk.Rectangle pointing_to, Gnome.RRScreen screen,
		Gnome.RROutputInfo output_info, Gnome.RRConfig config)
	{
		Object (relative_to: relative_to);

		position = Gtk.PositionType.BOTTOM;
		set_pointing_to (pointing_to);
		width_request = 370;

		current_screen = screen;
		current_config = config;
		info = output_info;
		output = screen.get_output_by_name (info.get_name ());

		var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);

		var grid = new Gtk.Grid ();
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
		});

		var use_display_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
		use_display_box.margin = 12;
		use_display_box.margin_bottom = 0;
		use_display_box.pack_start (new RLabel.right (_("Use This Display")), false);
		use_display_box.pack_start (use_display);

		box.pack_start (use_display_box, false);
		box.pack_start (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), false);
		box.pack_start (grid);

		resolution = new Gtk.ComboBoxText ();
		resolution.expand = true;
		resolution.valign = Gtk.Align.CENTER;
		resolution.changed.connect (() => {
			if (ui_update)
				return;

			var selected_mode_id = int.parse (resolution.active_id);
			unowned Gnome.RRMode? new_mode = null;
			foreach (unowned Gnome.RRMode mode in output.list_modes ()) {
				if (mode.get_id () == selected_mode_id) {
					new_mode = mode;
					break;
				}
			}

			assert (new_mode != null);

			int x, y;
			info.get_geometry (out x, out y, null, null);
			info.set_geometry (x, y, (int) new_mode.get_width (), (int) new_mode.get_height ());

			update_config ();
		});
		grid.attach (new RLabel.right (_("Resolution:")), 0, 2, 1, 1);
		grid.attach (resolution, 1, 2, 1, 1);

		mirror_display = new Gtk.Switch ();
		mirror_display.halign = Gtk.Align.START;
		mirror_display.notify["active"].connect (() => {
			if (ui_update)
				return;

			config.set_clone (mirror_display.active);

			update_config ();
		});
		grid.attach (new RLabel.right (_("Mirror Display:")), 0, 3, 1, 1);
		grid.attach (mirror_display, 1, 3, 1, 1);

		rotation = new Gtk.ComboBoxText ();
		rotation.valign = Gtk.Align.CENTER;
		rotation.changed.connect (() => {
			if (ui_update)
				return;

			int rot = int.parse (rotation.active_id);
			info.set_rotation ((Gnome.RRRotation) rot);

			update_config ();
		});
		grid.attach (new RLabel.right (_("Rotation:")), 0, 4, 1, 1);
		grid.attach (rotation, 1, 4, 1, 1);

		add (box);

		update_settings ();
	}

	void update_settings ()
	{
		ui_update = true;

		var enabled_monitors = 0;
		foreach (unowned Gnome.RROutputInfo output in current_config.get_outputs ()) {
			if (output.is_active ())
				enabled_monitors++;
		}

		var is_multi_monitor = enabled_monitors > 1;

		mirror_display.active = current_config.get_clone ();
		mirror_display.sensitive = is_multi_monitor;

		use_display.active = info.is_active ();
		use_display.sensitive = is_multi_monitor;

		update_modes ();
		update_rotation ();

		ui_update = false;
	}

	void update_modes ()
	{
		unowned Gnome.RRMode[] modes;

		if (current_config.get_clone ())
			modes = current_screen.list_clone_modes ();
		else
			modes = output.list_modes ();

		var i = 0;

		foreach (unowned Gnome.RRMode mode in modes) {
			resolution.append (mode.get_id ().to_string (),
				"%ux%u @ %iHz".printf (mode.get_width (), mode.get_height (), mode.get_freq ()));
			i++;
		}

		resolution.active_id = output.get_current_mode ().get_id ().to_string ();
	}

	void update_rotation ()
	{
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


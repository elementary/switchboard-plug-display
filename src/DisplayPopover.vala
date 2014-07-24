
public class DisplayPopover : Gtk.Popover
{
	public signal void update_config ();

	unowned Gnome.RROutputInfo? info = null;
	unowned Gnome.RROutput? output = null;

	Gtk.Switch use_display;
	Gtk.Switch mirror_display;
	Gtk.ComboBoxText resolution;
	Gtk.ComboBoxText rotation;

	public DisplayPopover (Gtk.Widget relative_to, Gnome.RRScreen screen,
		Gnome.RROutputInfo output_info, Gnome.RRConfig config, bool is_multi_monitor)
	{
		Object (relative_to: relative_to);

		info = output_info;
		output = screen.get_output_by_name (info.get_name ());

		var grid = new Gtk.Grid ();
		//grid.margin = 12;
		grid.row_spacing = 6;
		grid.column_spacing = 12;

		use_display = new Gtk.Switch ();
		use_display.active = info.is_active ();
		use_display.sensitive = is_multi_monitor;
		use_display.halign = Gtk.Align.START;
		use_display.notify["active"].connect (() => {
			info.set_active (use_display.active);

			update_config ();
		});

		grid.attach (new RLabel.right (_("Use This Display")), 0, 0, 1, 1);
		grid.attach (use_display, 1, 0, 1, 1);

		grid.attach (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), 0, 1, 2, 1);

		resolution = new Gtk.ComboBoxText ();

		resolution.remove_all ();

		unowned Gnome.RRMode[] modes;
		if (config.get_clone ())
			modes = screen.list_clone_modes ();
		else
			modes = output.list_modes ();

		var i = 0;

		foreach (unowned Gnome.RRMode mode in modes) {
			resolution.append (mode.get_id ().to_string (),
				"%ux%u @ %iHz".printf (mode.get_width (), mode.get_height (), mode.get_freq ()));
			i++;
		}

		resolution.active_id = output.get_current_mode ().get_id ().to_string ();

		resolution.valign = Gtk.Align.CENTER;
		resolution.changed.connect (() => {
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
		grid.attach (new RLabel.right (_("Resolution:")), 0, 3, 1, 1);
		grid.attach (resolution, 1, 3, 1, 1);

		mirror_display = new Gtk.Switch ();
		mirror_display.active = config.get_clone ();
		mirror_display.sensitive = is_multi_monitor;
		mirror_display.halign = Gtk.Align.START;
		mirror_display.notify["active"].connect (() => {
			config.set_clone (mirror_display.active);

			update_config ();
		});
		grid.attach (new RLabel.right (_("Mirror display:")), 0, 2, 1, 1);
		grid.attach (mirror_display, 1, 2, 1, 1);

		rotation = new Gtk.ComboBoxText ();
		rotation.valign = Gtk.Align.CENTER;

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
		rotation.remove_all ();
		for (i = 0; i < rotations.length; i++) {
			if (info.supports_rotation (rotations[i])) {
				rotation.append (((int) rotations[i]).to_string (), desc[i]);
				n_rotations++;
			}
		}

		rotation.sensitive = n_rotations > 0;
		rotation.active_id = ((int) info.get_rotation ()).to_string ();

		rotation.changed.connect (() => {
			int rot = int.parse (rotation.active_id);
			info.set_rotation ((Gnome.RRRotation) rot);

			update_config ();
		});
		grid.attach (new RLabel.right (_("Rotation:")), 2, 4, 1, 1);
		grid.attach (rotation, 3, 4, 1, 1);
	}
}


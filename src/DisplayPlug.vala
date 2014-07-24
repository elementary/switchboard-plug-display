
public class DisplayPlug : Object
{
	Gtk.Grid main_grid;
	OutputList output_list;
	Gnome.RRScreen screen;
	Gnome.RRConfig current_config;
	Gnome.RROutputInfo? selected_info = null;
	Gnome.RROutput? selected_output = null;

	Gtk.Switch use_display;
	Gtk.Scale brightness;
	Gtk.Switch mirror_display;
	Gtk.ComboBoxText turn_off_when;
	Gtk.ComboBoxText resolution;
	Gtk.ComboBoxText color_profile;
	Gtk.ComboBoxText rotation;
	Gtk.Button apply_button;

	bool ui_update = false;

	public DisplayPlug ()
	{
		main_grid = new Gtk.Grid ();
		main_grid.margin = 12;
		main_grid.row_spacing = 6;
		main_grid.column_spacing = 12;
		main_grid.column_homogeneous = true;

		try {
			screen = new Gnome.RRScreen (Gdk.Screen.get_default ());
			screen.changed.connect (screen_changed);
		} catch (Error e) {
			report_error (e.message);
		}

		output_list = new OutputList ();
		output_list.select_output.connect (select_output);
		main_grid.attach (output_list, 0, 0, 4, 1);

		main_grid.attach (new RLabel.markup ("<b>" + _("Behavior:") + "</b>"), 0, 1, 2, 1);

		use_display = new Gtk.Switch ();
		use_display.halign = Gtk.Align.START;
		use_display.notify["active"].connect (() => {
			if (ui_update)
				return;

			selected_info.set_active (use_display.active);

			update_config ();
		});
		main_grid.attach (new RLabel.right (_("Use display:")), 0, 2, 1, 1);
		main_grid.attach (use_display, 1, 2, 1, 1);

		brightness = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 100, 1);
		brightness.draw_value = false;
		brightness.value_changed.connect (() => {
			if (ui_update)
				return;

			try {
				selected_output.set_backlight ((int) brightness.get_value ());
			} catch (Error e) {
				report_error (e.message);
			}
		});
		main_grid.attach (new RLabel.right (_("Brightness:")), 0, 3, 1, 1);
		main_grid.attach (brightness, 1, 3, 1, 1);

		mirror_display = new Gtk.Switch ();
		mirror_display.halign = Gtk.Align.START;
		main_grid.attach (new RLabel.right (_("Mirror display:")), 0, 4, 1, 1);
		main_grid.attach (mirror_display, 1, 4, 1, 1);

		turn_off_when = new Gtk.ComboBoxText ();
		main_grid.attach (new RLabel.right (_("Turn off when:")), 0, 5, 1, 1);
		main_grid.attach (turn_off_when, 1, 5, 1, 1);

		main_grid.attach (new RLabel.markup ("<b>" + _("Appearance:") + "</b>"), 2, 1, 2, 1);

		resolution = new Gtk.ComboBoxText ();
		resolution.valign = Gtk.Align.CENTER;
		resolution.changed.connect (() => {
			if (ui_update)
				return;

			var selected_mode_id = int.parse (resolution.active_id);
			Gnome.RRMode? new_mode = null;
			foreach (var mode in selected_output.list_modes ()) {
				if (mode.get_id () == selected_mode_id) {
					new_mode = mode;
					break;
				}
			}

			assert (new_mode != null);

			int x, y;
			selected_info.get_geometry (out x, out y, null, null);
			selected_info.set_geometry (x, y, (int) new_mode.get_width (), (int) new_mode.get_height ());

			update_config ();
		});
		main_grid.attach (new RLabel.right (_("Resolution:")), 2, 2, 1, 1);
		main_grid.attach (resolution, 3, 2, 1, 1);

		color_profile = new Gtk.ComboBoxText ();
		color_profile.valign = Gtk.Align.CENTER;
		main_grid.attach (new RLabel.right (_("Color Profile:")), 2, 3, 1, 1);
		main_grid.attach (color_profile, 3, 3, 1, 1);

		rotation = new Gtk.ComboBoxText ();
		rotation.valign = Gtk.Align.CENTER;
		rotation.changed.connect (() => {
			if (ui_update)
				return;

			var rotation = (Gnome.RRRotation) int.parse (rotation.active_id);
			selected_info.set_rotation (rotation);

			update_config ();
		});
		main_grid.attach (new RLabel.right (_("Rotation:")), 2, 4, 1, 1);
		main_grid.attach (rotation, 3, 4, 1, 1);

		var expander = new Gtk.EventBox ();
		expander.expand = true;
		main_grid.attach (expander, 0, 6, 4, 1);

		var buttons = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
		var detect_displays = new Gtk.Button.with_label (_("Detect Displays"));
		apply_button = new Gtk.Button.with_label (_("Apply"));
		apply_button.sensitive = false;
		apply_button.clicked.connect (apply);
		buttons.layout_style = Gtk.ButtonBoxStyle.END;
		buttons.add (detect_displays);
		buttons.add (apply_button);

		main_grid.attach (buttons, 0, 7, 4, 1);

		screen_changed ();
	}

	void select_output (Gnome.RROutputInfo? info)
	{
		var output_selected = info != null;

		brightness.sensitive = output_selected;
		resolution.sensitive = output_selected;
		rotation.sensitive = output_selected;
		use_display.sensitive = output_selected;
		mirror_display.sensitive = output_selected;
		turn_off_when.sensitive = output_selected;
		color_profile.sensitive = output_selected;

		if (!output_selected)
			return;

		unowned Gnome.RROutput output = screen.get_output_by_name (info.get_name ());

		selected_info = info;
		selected_output = output;

		ui_update = true;

		use_display.active = info.is_active ();

		var brightness_step = output.get_min_backlight_step ();
		brightness.set_increments (brightness_step, brightness_step);
		brightness.set_value (output.get_backlight ());
		// TODO Gtk.Switch mirror_display;
		//Gtk.ComboBoxText turn_off_when;

		resolution.remove_all ();
		foreach (var mode in output.list_modes ()) {
			// TODO cleanup with freqs
			resolution.append (mode.get_id ().to_string (),
				"%ux%u @ %iHz".printf (mode.get_width (), mode.get_height (), mode.get_freq ()));
		}
		resolution.active_id = output.get_current_mode ().get_id ().to_string ();

		// TODO? Gtk.ComboBoxText color_profile;
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
		for (var i = 0; i < rotations.length; i++) {
			if (info.supports_rotation (rotations[i])) {
				rotation.append (((int) rotations[i]).to_string (), desc[i]);
				n_rotations++;
			}
		}

		rotation.sensitive = n_rotations > 0;
		rotation.active_id = ((int) info.get_rotation ()).to_string ();

		ui_update = false;
	}

	void update_config ()
	{
		try {
			var existing_config = new Gnome.RRConfig.current (screen);

		// TODO check if clone or primary state changed too
			apply_button.sensitive = current_config.applicable (screen)
				&& !existing_config.equal (current_config);
		} catch (Error e) {
			report_error (e.message);
		}
	}

	void apply ()
	{
		apply_button.sensitive = false;

		current_config.sanitize ();
		current_config.ensure_primary ();

		try {
			current_config.apply_persistent (screen);
		} catch (Error e) {
			report_error (e.message);
		}

		screen_changed ();
	}

	void screen_changed ()
	{
		try {
			screen.refresh ();

			current_config = new Gnome.RRConfig.current (screen);
		} catch (Error e) {
			report_error (e.message);
		}

		output_list.remove_all ();
		foreach (var output in current_config.get_outputs ())
			output_list.add_output (output);

		output_list.select_path (new Gtk.TreePath.from_string ("0"));
	}

	void report_error (string message)
	{
		warning (message);
	}

	public Gtk.Widget get_widget ()
	{
		return main_grid;
	}
}

void main (string[] args)
{
	Gtk.init (ref args);

	var p = new DisplayPlug ();
	var w = new Gtk.Window ();
	w.set_default_size (800, 400);
	w.add (p.get_widget ());
	w.show_all ();
	w.destroy.connect (Gtk.main_quit);

	Gtk.main ();
}



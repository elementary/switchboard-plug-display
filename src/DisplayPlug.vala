
public class DisplayPlug : Object
{
	Gtk.Grid main_grid;
	OutputList output_list;
	Gnome.RRScreen screen;
	Gnome.RRConfig current_config;
	Gnome.RROutputInfo? selected_info = null;
	Gnome.RROutput? selected_output = null;

	Gtk.Switch use_display;
	Gtk.CheckButton primary_display;
	Gtk.Switch mirror_display;
	Gtk.ComboBoxText resolution;
	Gtk.ComboBoxText rotation;
	Gtk.Button apply_button;

	int enabled_monitors = 0;

	bool ui_update = false;

	public DisplayPlug ()
	{
		main_grid = new Gtk.Grid ();
		main_grid.margin = 12;
		main_grid.row_spacing = 6;
		main_grid.column_spacing = 12;

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
				enabled_monitors += (use_display.active ? 1 : -1);

			update_config ();
		});

		primary_display = new Gtk.CheckButton ();
		primary_display.notify["active"].connect (() => {
			if (ui_update)
				return;

			// TODO do we need to take care that there's always a primary one selected?
			selected_info.set_primary (primary_display.active);

			update_config ();
		});

		var display_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		display_box.pack_start (use_display, false);
		display_box.pack_start (primary_display, false);
		display_box.pack_start (new RLabel (_("Primary Display")));

		main_grid.attach (new RLabel.right (_("Use display:")), 0, 2, 1, 1);
		main_grid.attach (display_box, 1, 2, 1, 1);

		mirror_display = new Gtk.Switch ();
		mirror_display.halign = Gtk.Align.START;
		mirror_display.notify["active"].connect (() => {
			if (ui_update)
				return;

			current_config.set_clone (mirror_display.active);

			update_config ();
		});
		main_grid.attach (new RLabel.right (_("Mirror display:")), 0, 4, 1, 1);
		main_grid.attach (mirror_display, 1, 4, 1, 1);

		main_grid.attach (new RLabel.markup ("<b>" + _("Appearance:") + "</b>"), 2, 1, 2, 1);

		resolution = new Gtk.ComboBoxText ();
		resolution.valign = Gtk.Align.CENTER;
		resolution.changed.connect (() => {
			if (ui_update)
				return;

			var selected_mode_id = int.parse (resolution.active_id);
			unowned Gnome.RRMode? new_mode = null;
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

		rotation = new Gtk.ComboBoxText ();
		rotation.valign = Gtk.Align.CENTER;
		rotation.changed.connect (() => {
			if (ui_update)
				return;

			var rotation = (Gnome.RRRotation) int.parse (rotation.active_id);
			selected_info.set_rotation (rotation);

			update_config ();
			update_modes ();
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
		var is_multi_monitor = enabled_monitors > 1;

		resolution.sensitive = output_selected;
		rotation.sensitive = output_selected;
		use_display.sensitive = output_selected;
		mirror_display.sensitive = output_selected;

		if (!output_selected)
			return;

		unowned Gnome.RROutput output = screen.get_output_by_name (info.get_name ());

		selected_info = info;
		selected_output = output;

		ui_update = true;

		use_display.active = info.is_active ();
		use_display.sensitive = is_multi_monitor;

		primary_display.active = info.get_primary ();
		primary_display.sensitive = is_multi_monitor;

		mirror_display.active = current_config.get_clone ();
		mirror_display.sensitive = is_multi_monitor;

		update_modes ();

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

		enabled_monitors = 0;
		output_list.remove_all ();
		foreach (var output in current_config.get_outputs ()) {
			if (output.is_active ())
				enabled_monitors++;

			output_list.add_output (output);
		}

		output_list.select_path (new Gtk.TreePath.first ());
	}

	void update_modes ()
	{
		// FIXME crashes here when selecting a monitor
		resolution.remove_all ();

		Gnome.RRMode** modes = null;
		if (current_config.get_clone ())
			modes = (Gnome.RRMode **) screen.list_clone_modes ();
		else if (selected_output != null)
			modes = (Gnome.RRMode **) selected_output.list_modes ();
		else {
			resolution.sensitive = false;
			return;
		}

		var i = 0;

		while (modes[i] != null) {
			Gnome.RRMode* mode = modes[i];
			// TODO cleanup with freqs
			resolution.append (mode->get_id ().to_string (),
				"%ux%u @ %iHz".printf (mode->get_width (), mode->get_height (), mode->get_freq ()));
			i++;
		}

		resolution.active_id = selected_output.get_current_mode ().get_id ().to_string ();

	}

	// TODO show an infobar
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



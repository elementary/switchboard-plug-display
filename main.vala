
public class RLabel : Gtk.Label
{
	public RLabel (string label)
	{
		Object (label: label, xalign: 0.0f);
	}

	public RLabel.right (string label)
	{
		Object (label: label, xalign: 1.0f);
	}

	public RLabel.markup (string label)
	{
		Object (label: label, xalign: 0.0f, use_markup: true);
	}
}

public class OutputList : Gtk.IconView
{
	const int MONITOR_MAX_HEIGHT = 150;

	Gtk.ListStore list;
	double highest;

	public OutputList ()
	{
		set_reorderable (true);
		model = list = new Gtk.ListStore (2, typeof (Gnome.RROutputInfo), typeof (Gdk.Pixbuf));
		set_pixbuf_column (1);

		cell_area.get_cells ().data.xalign = 0.5f;
		cell_area.get_cells ().data.yalign = 0.5f;
	}

	public void add_output (Gnome.RROutputInfo output)
	{
		Gtk.TreeIter iter;
		int height;

		output.get_geometry (null, null, null, out height);

		highest = double.max (highest, height);

		list.append (out iter);
		list.@set (iter, 0, output, 1, get_monitor_pixbuf (output));
	}

	Gdk.Pixbuf get_monitor_pixbuf (Gnome.RROutputInfo output)
	{
		int monitor_width, monitor_height;
		output.get_geometry (null, null, out monitor_width, out monitor_height);

		var scale_factor = MONITOR_MAX_HEIGHT / highest;
		var width = (int) Math.floor (monitor_width * scale_factor);
		var height = (int) Math.floor (monitor_height * scale_factor);

		var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, width, height);
		var cr = new Cairo.Context (surface);

		cr.rectangle (0, 0, width, height);
		cr.set_source_rgb (1, 0, 0);
		cr.fill ();

		return Gdk.pixbuf_get_from_surface (surface, 0, 0, width, height);
	}
}

public class DisplayPlug : Object
{
	Gtk.Grid main_grid;
	OutputList output_list;
	Gnome.RRScreen screen;
	Gnome.RRConfig current_config;

	Gtk.Switch use_display;
	Gtk.Switch automatic_brightness;
	Gtk.Scale brightness;
	Gtk.Switch mirror_display;
	Gtk.ComboBoxText turn_off_when;
	Gtk.ComboBoxText resolution;
	Gtk.ComboBoxText color_profile;
	Gtk.ComboBoxText rotation;

	public DisplayPlug ()
	{
		main_grid = new Gtk.Grid ();
		main_grid.margin = 12;
		main_grid.row_spacing = 6;
		main_grid.column_spacing = 12;
		main_grid.column_homogeneous = true;

		try {
			screen = new Gnome.RRScreen (Gdk.Screen.get_default ());
			current_config = new Gnome.RRConfig.current (screen);
		} catch (Error e) { warning (e.message); }

		output_list = new OutputList ();

		foreach (var output in current_config.get_outputs ())
			output_list.add_output (output);

		main_grid.attach (output_list, 0, 0, 4, 1);

		main_grid.attach (new RLabel.markup ("<b>" + _("Behavior:") + "</b>"), 0, 1, 2, 1);

		use_display = new Gtk.Switch ();
		main_grid.attach (new RLabel.right (_("Use display:")), 0, 2, 1, 1);
		main_grid.attach (use_display, 1, 2, 1, 1);

		automatic_brightness = new Gtk.Switch ();
		brightness = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 100, 1);
		var brightness_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
		main_grid.attach (new RLabel.right (_("Automatic brightness:")), 0, 3, 1, 1);
		main_grid.attach (brightness_box, 1, 3, 1, 1);
		brightness_box.pack_start (automatic_brightness, false);
		brightness_box.pack_start (brightness);

		mirror_display = new Gtk.Switch ();
		main_grid.attach (new RLabel.right (_("Mirror display:")), 0, 4, 1, 1);
		main_grid.attach (mirror_display, 1, 4, 1, 1);

		turn_off_when = new Gtk.ComboBoxText ();
		main_grid.attach (new RLabel.right (_("Turn off when:")), 0, 5, 1, 1);
		main_grid.attach (turn_off_when, 1, 5, 1, 1);

		main_grid.attach (new RLabel.markup ("<b>" + _("Appearance:") + "</b>"), 2, 1, 2, 1);

		resolution = new Gtk.ComboBoxText ();
		resolution.valign = Gtk.Align.CENTER;
		main_grid.attach (new RLabel.right (_("Resolution:")), 2, 2, 1, 1);
		main_grid.attach (resolution, 3, 2, 1, 1);

		color_profile = new Gtk.ComboBoxText ();
		color_profile.valign = Gtk.Align.CENTER;
		main_grid.attach (new RLabel.right (_("Color Profile:")), 2, 3, 1, 1);
		main_grid.attach (color_profile, 3, 3, 1, 1);

		rotation = new Gtk.ComboBoxText ();
		rotation.valign = Gtk.Align.CENTER;
		main_grid.attach (new RLabel.right (_("Rotation:")), 2, 4, 1, 1);
		main_grid.attach (rotation, 3, 4, 1, 1);

		var expander = new Gtk.EventBox ();
		expander.expand = true;
		main_grid.attach (expander, 0, 6, 4, 1);

		var buttons = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
		var detect_displays = new Gtk.Button.with_label (_("Detect Displays"));
		var apply = new Gtk.Button.with_label (_("Apply"));
		buttons.layout_style = Gtk.ButtonBoxStyle.END;
		buttons.add (detect_displays);
		buttons.add (apply);

		main_grid.attach (buttons, 0, 7, 4, 1);
	}

	void select_output (Gnome.RROutputInfo info)
	{
		var output = screen.get_output_by_name (info.get_name ());

		use_display.active = info.is_active ();
		// TODO automatic_brightness;
		// Gtk.Scale brightness;
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
		for (var i = 0; i < rotations.length; i++) {
			if (info.supports_rotation (rotations[i])) {
				rotation.append (((int) rotations[i]).to_string (), desc[i]);
				n_rotations++;
			}
		}

		rotation.sensitive = n_rotations > 0;
		rotation.active_id = ((int) info.get_rotation ()).to_string ();
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


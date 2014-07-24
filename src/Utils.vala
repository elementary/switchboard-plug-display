
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



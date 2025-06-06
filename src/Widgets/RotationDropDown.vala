public class Display.RotationDropDown : Granite.Bin {
    public class RotationOption : Object {
        public string label { get; set; }
        public int value { get; set; }

        public RotationOption () {
            Object ();
        }
    }

    public Display.VirtualMonitor virtual_monitor { get; construct; }
    public uint selected {
        get {
            return drop_down.get_selected ();
        }
    }

    private Gtk.DropDown drop_down;
    private ListStore rotations;

    public signal void rotation_selected (RotationOption rotation);

    public RotationDropDown (Display.VirtualMonitor _virtual_monitor) {
        Object (
            virtual_monitor: _virtual_monitor
        );
    }

    construct {
        rotations = new ListStore (typeof (RotationOption));

        populate_rotations ();

        var rotation_factory = new Gtk.SignalListItemFactory ();
        rotation_factory.setup.connect ((obj) => {
            var item = obj as Gtk.ListItem;
            item.child = new Gtk.Label (null) { xalign = 0 };
        });
        rotation_factory.bind.connect ((obj) => {
            var item = obj as Gtk.ListItem;
            var rotation = item.get_item () as RotationOption;
            var item_child = item.child as Gtk.Label;
            item_child.label = rotation.label;
        });

        drop_down = new Gtk.DropDown (rotations, null) {
            factory = rotation_factory,
            margin_start = 12,
            margin_end = 12
        };

        drop_down.sensitive = rotations.get_n_items () > 0;

        child = drop_down;

        drop_down.notify["selected"].connect (() => {
            var selected_rotation = get_selected_rotation ();
            if (selected_rotation != null) {
                rotation_selected (selected_rotation);
            }
        });
    }

    public RotationOption get_selected_rotation () {
        return drop_down.get_selected_item () as RotationOption;
    }

    public void set_selected_rotation (int rotation) {
        drop_down.set_selected (rotation);
    }

    private void populate_rotations () {
        for (int i = 0; i <= DisplayTransform.FLIPPED_ROTATION_270; i++) {
            var option = new RotationOption () {
                label = ((DisplayTransform) i).to_string (),
                value = i
            };

            rotations.append (option);
        }
    }
}

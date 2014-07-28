
namespace Utils
{
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


    // copied from GCC panel
    public string? make_aspect_string (uint width, uint height) {
        uint ratio;
        string? aspect = null;

        if (width == 0 || height == 0)
            return null;

        if (width > height)
            ratio = width * 10 / height;
        else
            ratio = height * 10 / width;

        switch (ratio) {
            case 13:
                aspect = "4∶3";
                break;
            case 16:
                aspect = "16∶10";
                break;
            case 17:
                aspect = "16∶9";
                break;
            case 23:
                aspect = "21∶9";
                break;
            case 12:
                aspect = "5∶4";
                break;
                /* This catches 1.5625 as well (1600x1024) when maybe it shouldn't. */
            case 15:
                aspect = "3∶2";
                break;
            case 18:
                aspect = "9∶5";
                break;
            case 10:
                aspect = "1∶1";
                break;
        }

        return aspect;
    }
}


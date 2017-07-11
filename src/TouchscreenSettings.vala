
public class Display.TouchscreenSettings : Granite.Services.Settings {
    public bool orientation_lock { get; set; }

    public TouchscreenSettings () {
        base ("org.gnome.settings-daemon.peripherals.touchscreen");
    }
}

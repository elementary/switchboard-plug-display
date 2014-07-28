
[DBus (name = "org.gnome.SettingsDaemon.XRANDR_2")]
public interface SettingsDaemon : Object
{
	public abstract void apply_configuration (int64 parent_window_xid, int64 timestamp) throws Error;
}

public static SettingsDaemon? get_settings_daemon () throws Error
{
	SettingsDaemon daemon;

	try {
		daemon = Bus.get_proxy_sync (BusType.SESSION, "org.gnome.SettingsDaemon.XRANDR", "/org/gnome/SettingsDaemon/XRANDR");
	} catch (Error e) {
		throw e;
		return null;
	}

	return daemon;
}

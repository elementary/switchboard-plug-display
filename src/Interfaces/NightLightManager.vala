/*
* Copyright (c) 2018 elementary LLC (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

[DBus (name="org.gnome.SettingsDaemon.Color")]
public interface Display.NightLightInterface : DBusProxy {
    public abstract bool disabled_until_tomorrow { get; set; }
}

public class Display.NightLightManager : Object {
    private NightLightInterface night_light_interface;

    private bool snooze_cache;
    public bool snoozed {
        get {
            return snooze_cache;
        } set {
            if (value != snooze_cache) {
                snooze_cache = value;
                night_light_interface.disabled_until_tomorrow = value;
            }
        }
    }

    static NightLightManager? instance = null;
    public static NightLightManager get_instance () {
        if (instance == null) {
            instance = new NightLightManager ();
        }

        return instance;
    }

    private NightLightManager () {}

    construct {
        try {
            night_light_interface = Bus.get_proxy_sync (
                BusType.SESSION,
                "org.gnome.SettingsDaemon.Color",
                "/org/gnome/SettingsDaemon/Color",
                DBusProxyFlags.NONE
            );
            snooze_cache = night_light_interface.disabled_until_tomorrow;

            night_light_interface.g_properties_changed.connect ((changed, invalid) => {
                var snooze = changed.lookup_value ("DisabledUntilTomorrow", new VariantType ("b"));

                if (snooze != null) {
                    snooze_cache = snooze.get_boolean ();
                }
            });
        } catch (Error e) {
            warning ("Could not connect to color interface: %s", e.message);
        }
    }
}

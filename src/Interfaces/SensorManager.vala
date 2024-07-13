/*
 * SPDX-License-Identifier: LGPL-2.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

[DBus (name = "net.hadess.SensorProxy")]
public interface  Display.SensorProxy : GLib.DBusProxy {
    public abstract bool has_accelerometer { get; }
}

public class Display.SensorManager : Object {
    public bool has_accelerometer { get; private set; }

    private static GLib.Once<SensorManager> instance;
    public static unowned SensorManager get_default () {
        return instance.once (() => new SensorManager ());
    }

    private class SensorManager () { }

    construct {
        setup_sensor_proxy.begin ((obj, res) => {
            var sensor_proxy = setup_sensor_proxy.end (res);
            has_accelerometer = sensor_proxy.has_accelerometer;
        });
    }

    private async SensorProxy? setup_sensor_proxy () {
        try {
            return yield Bus.get_proxy (BusType.SYSTEM, "net.hadess.SensorProxy", "/net/hadess/SensorProxy");
        } catch (Error e) {
            info ("Unable to connect to SensorProxy bus, probably means no accelerometer supported: %s", e.message);
            return null;
        }
    }
}

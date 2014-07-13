
displays: main.vala
	valac -X -DGETTEXT_PACKAGE="\"abc\"" -X -DGNOME_DESKTOP_USE_UNSTABLE_API --pkg granite --pkg gnome-desktop-3.0 --vapidir=. main.vala -o displays -X -lm


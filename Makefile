SOURCES=src/OutputList.vala \
	src/DisplayPopover.vala \
        src/DisplayPlug.vala \
        src/SettingsDaemon.vala \
        src/Utils.vala

displays: $(SOURCES)
	pkg-config --exists "gnome-desktop-3.0 >= 3.12.0";			\
	[ $$? -eq 0 ] && VALAFLAGS="-D HAS_GNOME312";				\
	valac -X -DGETTEXT_PACKAGE="\"abc\""					\
	      -X -DGNOME_DESKTOP_USE_UNSTABLE_API 				\
	      --pkg granite 							\
	      --pkg gnome-desktop-3.0						\
	      --pkg clutter-gtk-1.0						\
	      --pkg gdk-x11-3.0							\
	      --vapidir=.							\
	      $(SOURCES)							\
	      -o displays							\
	      -X -lm								\
	      -g								\
	      $$VALAFLAGS


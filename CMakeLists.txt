# This a sample CMakeLists.txt for compiling plug for Switchboard
# http://elementaryos.org/docs/developer-guide/cmake 

cmake_minimum_required (VERSION 2.8)
cmake_policy (VERSION 2.8)

# Set the Category of the Plug, one of:
# personal, hardware, network, system
set (PLUGCATEGORY "hardware")
# Set the Title to use for the Plug in the Overview and in the Titlebar
set (PLUGTITLE "Display")
# Set the version for the plug
set (VERSION "0.1.3")

# Set the Name of the plug, should be an executable command, lowercase, no spaces 
project (pantheon-display)

#########################################################
# Only alter stuff below if you know what you are doing #
#########################################################

include (GNUInstallDirs)
set (DATADIR "${CMAKE_INSTALL_FULL_LIBDIR}/switchboard")
set (PKGDATADIR "${DATADIR}/${PLUGCATEGORY}/${CMAKE_PROJECT_NAME}")
set (GETTEXT_PACKAGE "${CMAKE_PROJECT_NAME}-plug")

list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

# Configure file
add_definitions (-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")
add_definitions (-DGNOME_DESKTOP_USE_UNSTABLE_API)

# Traslation stuff
add_subdirectory (po)

add_subdirectory(src)

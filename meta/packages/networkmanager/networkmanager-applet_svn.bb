DESCRIPTION = "GTK+ applet for NetworkManager" 
LICENSE = "GPL"
DEPENDS = "networkmanager dbus-glib libglade gconf gnome-keyring"
#TODO DEPENDS libnotify
RDEPENDS = "networkmanager"
PR = "r2"

inherit gnome gtk-icon-cache

SRC_URI = "svn://svn.gnome.org/svn/network-manager-applet/;module=trunk;proto=http \
           file://applet-no-gnome.diff;patch=1;pnum=0 \
           file://applet-no-animation.patch;patch=1 \
	   file://70NetworkManagerApplet"

PV = "0.0+svnr${SRCREV}"

S = "${WORKDIR}/trunk"

FILES_${PN} += "${datadir}/nm-applet/ \
        ${datadir}/gnome-vpn-properties/ \
        ${datadir}/gnome/autostart/ \
        "

do_install_append () {
	install -d ${D}${sysconfdir}/X11/Xsession.d/
	install -m 755 ${WORKDIR}/70NetworkManagerApplet ${D}${sysconfdir}/X11/Xsession.d/
}
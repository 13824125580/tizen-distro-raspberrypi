SUMMARY = "New user to do specific job"
DESCRIPTION = "This recipe create a new user named ${PN}, who is used for specific jobs like building. The task can be auto started via mini X"
SECTION = "x11"
PR = "r5"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://builder_hob_start.sh;endline=5;md5=84796c3c41785d86100fdabcbdade00e"

SRC_URI = "file://builder_hob_start.sh \
           file://please_wait_dialog.py \
          "

S = "${WORKDIR}"

RDEPENDS_${PN} = "mini-x-session"

inherit useradd

# builder user password is "builder"
BUILDER_PASSWORD ?= ".gLibiNXn0P12"
USERADD_PACKAGES = "${PN}"
USERADD_PARAM_${PN} = "--system --create-home \
                       --groups video,tty,audio \
                       --user-group ${PN} \
                       --password ${BUILDER_PASSWORD}"

do_install () {
	install -d -m 755 ${D}${sysconfdir}/mini_x/session.d
	install -p -m 755 builder_hob_start.sh ${D}${sysconfdir}/mini_x/session.d/

	chown  ${PN}.${PN} ${D}${sysconfdir}/mini_x/session.d/builder_hob_start.sh
        install -p -m 755 please_wait_dialog.py ${D}${sysconfdir}/mini_x
}


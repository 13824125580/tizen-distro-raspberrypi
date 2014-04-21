SUMMARY = "Rsyslog is an enhanced multi-threaded syslogd"
DESCRIPTION = "\
Rsyslog is an enhanced syslogd supporting, among others, MySQL,\
 PostgreSQL, failover log destinations, syslog/tcp, fine grain\
 output format control, high precision timestamps, queued operations\
 and the ability to filter on any message part. It is quite\
 compatible to stock sysklogd and can be used as a drop-in replacement.\
 Its advanced features make it suitable for enterprise-class,\
 encryption protected syslog relay chains while at the same time being\
 very easy to setup for the novice user."

DEPENDS = "zlib libestr json-c"
HOMEPAGE = "http://www.rsyslog.com/"
LICENSE = "GPLv3 & LGPLv3 & Apache-2.0"
LIC_FILES_CHKSUM = "file://COPYING;md5=51d9635e646fb75e1b74c074f788e973 \
                    file://COPYING.LESSER;md5=cb7903f1e5c39ae838209e130dca270a \
                    file://COPYING.ASL20;md5=052f8a09206615ab07326ff8ce2d9d32\
"

SRC_URI = "http://www.rsyslog.com/files/download/rsyslog/${BPN}-${PV}.tar.gz \
           file://initscript \
"

SRC_URI[md5sum] = "ebcc010a6205c28eb505c0fe862f32c6"
SRC_URI[sha256sum] = "276d094d1e4c62c770ec8a72723667f119eee038912b79cf3337d439bc2f9087"

inherit autotools pkgconfig systemd update-rc.d

EXTRA_OECONF += "--enable-cached-man-pages"

# first line is default yes in configure
PACKAGECONFIG ??= " \
    zlib rsyslogd rsyslogrt klog inet regexp uuid libgcrypt \
    imdiag gnutls \
    ${@base_contains('DISTRO_FEATURES', 'snmp', 'snmp', '', d)} \
    ${@base_contains('DISTRO_FEATURES', 'systemd', 'systemd', '', d)} \
"

# default yes in configure
PACKAGECONFIG[zlib] = "--enable-zlib,--disable-zlib,zlib,"
PACKAGECONFIG[rsyslogd] = "--enable-rsyslogd,--disable-rsyslogd,,"
PACKAGECONFIG[rsyslogrt] = "--enable-rsyslogrt,--disable-rsyslogrt,,"
PACKAGECONFIG[inet] = "--enable-inet,--disable-inet,,"
PACKAGECONFIG[klog] = "--enable-klog,--disable-klog,,"
PACKAGECONFIG[regexp] = "--enable-regexp,--disable-regexp,,"
PACKAGECONFIG[uuid] = "--enable-uuid,--disable-uuid,util-linux,"
PACKAGECONFIG[libgcrypt] = "--enable-libgcrypt,--disable-libgcrypt,libgcrypt,"
PACKAGECONFIG[testbench] = "--enable-testbench,--disable-testbench,,"

# default no in configure
PACKAGECONFIG[debug] = "--enable-debug,--disable-debug,,"
PACKAGECONFIG[imdiag] = "--enable-imdiag,--disable-imdiag,,"
PACKAGECONFIG[snmp] = "--enable-snmp,--disable-snmp,net-snmp,"
PACKAGECONFIG[gnutls] = "--enable-gnutls,--disable-gnutls,gnutls,"
PACKAGECONFIG[systemd] = "--with-systemdsystemunitdir=${systemd_unitdir}/system/,--without-systemdsystemunitdir,systemd,"
PACKAGECONFIG[mysql] = "--enable-mysql,--disable-mysql,mysql5,"
PACKAGECONFIG[postgresql] = "--enable-pgsql,--disable-pgsql,postgresql,"
PACKAGECONFIG[libdbi] = "--enable-libdbi,--disable-libdbi,libdbi,"
PACKAGECONFIG[mail] = "--enable-mail,--disable-mail,,"
PACKAGECONFIG[gui] = "--enable-gui,--disable-gui,,"

do_install_append() {
    install -d "${D}${sysconfdir}/init.d"
    install -m 755 ${WORKDIR}/initscript ${D}${sysconfdir}/init.d/rsyslogd
    install -m 755 ${S}/platform/redhat/rsyslog.conf ${D}${sysconfdir}/rsyslog.conf
}

FILES_${PN} += "${bindir}"

INITSCRIPT_NAME = "rsyslogd"
INITSCRIPT_PARAMS = "defaults"

CONFFILES_${PN} = "${sysconfdir}/rsyslog.conf"

RPROVIDES_${PN} += "${PN}-systemd"
RREPLACES_${PN} += "${PN}-systemd"
RCONFLICTS_${PN} += "${PN}-systemd"
SYSTEMD_SERVICE_${PN} = "${BPN}.service"

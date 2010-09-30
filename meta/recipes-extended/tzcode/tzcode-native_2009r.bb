DESCRIPTION = "tzcode, timezone zoneinfo utils -- zic, zdump, tzselect"
LICENSE = "Public Domain"
PR = "r0"

SRC_URI = "ftp://elsie.nci.nih.gov/pub/tzcode${PV}.tar.gz \
           ftp://elsie.nci.nih.gov/pub/tzdata2009s.tar.gz"

S = "${WORKDIR}"

inherit native

do_install () {
        install -d ${D}${bindir}/
        install -m 755 zic ${D}${bindir}/
        install -m 755 zdump ${D}${bindir}/
        install -m 755 tzselect ${D}${bindir}/
}

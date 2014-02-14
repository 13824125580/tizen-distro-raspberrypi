#
# Copyright 2006-2008 OpenedHand Ltd.
#

inherit package

IMAGE_PKGTYPE ?= "deb"

DPKG_ARCH ?= "${TARGET_ARCH}" 

PKGWRITEDIRDEB = "${WORKDIR}/deploy-debs"

APTCONF_TARGET = "${WORKDIR}"

APT_ARGS = "${@['', '--no-install-recommends'][d.getVar("NO_RECOMMENDATIONS", True) == "1"]}"

#
# install a bunch of packages using apt
# the following shell variables needs to be set before calling this func:
# INSTALL_ROOTFS_DEB - install root dir
# INSTALL_BASEARCH_DEB - install base architecutre
# INSTALL_ARCHS_DEB - list of available archs
# INSTALL_PACKAGES_NORMAL_DEB - packages to be installed
# INSTALL_PACKAGES_ATTEMPTONLY_DEB - packages attemped to be installed only
# INSTALL_PACKAGES_LINGUAS_DEB - additional packages for uclibc
# INSTALL_TASK_DEB - task name

python do_package_deb () {
    import re, copy
    import textwrap
    import subprocess

    workdir = d.getVar('WORKDIR', True)
    if not workdir:
        bb.error("WORKDIR not defined, unable to package")
        return

    outdir = d.getVar('PKGWRITEDIRDEB', True)
    if not outdir:
        bb.error("PKGWRITEDIRDEB not defined, unable to package")
        return

    packages = d.getVar('PACKAGES', True)
    if not packages:
        bb.debug(1, "PACKAGES not defined, nothing to package")
        return

    tmpdir = d.getVar('TMPDIR', True)

    if os.access(os.path.join(tmpdir, "stamps", "DEB_PACKAGE_INDEX_CLEAN"),os.R_OK):
        os.unlink(os.path.join(tmpdir, "stamps", "DEB_PACKAGE_INDEX_CLEAN"))

    if packages == []:
        bb.debug(1, "No packages; nothing to do")
        return

    pkgdest = d.getVar('PKGDEST', True)

    def cleanupcontrol(root):
        for p in ['CONTROL', 'DEBIAN']:
            p = os.path.join(root, p)
            if os.path.exists(p):
                bb.utils.prunedir(p)

    for pkg in packages.split():
        localdata = bb.data.createCopy(d)
        root = "%s/%s" % (pkgdest, pkg)

        lf = bb.utils.lockfile(root + ".lock")

        localdata.setVar('ROOT', '')
        localdata.setVar('ROOT_%s' % pkg, root)
        pkgname = localdata.getVar('PKG_%s' % pkg, True)
        if not pkgname:
            pkgname = pkg
        localdata.setVar('PKG', pkgname)

        localdata.setVar('OVERRIDES', pkg)

        bb.data.update_data(localdata)
        basedir = os.path.join(os.path.dirname(root))

        pkgoutdir = os.path.join(outdir, localdata.getVar('PACKAGE_ARCH', True))
        bb.utils.mkdirhier(pkgoutdir)

        os.chdir(root)
        cleanupcontrol(root)
        from glob import glob
        g = glob('*')
        if not g and localdata.getVar('ALLOW_EMPTY') != "1":
            bb.note("Not creating empty archive for %s-%s-%s" % (pkg, localdata.getVar('PKGV', True), localdata.getVar('PKGR', True)))
            bb.utils.unlockfile(lf)
            continue

        controldir = os.path.join(root, 'DEBIAN')
        bb.utils.mkdirhier(controldir)
        os.chmod(controldir, 0755)
        try:
            ctrlfile = open(os.path.join(controldir, 'control'), 'w')
            # import codecs
            # ctrlfile = codecs.open("someFile", "w", "utf-8")
        except OSError:
            bb.utils.unlockfile(lf)
            raise bb.build.FuncFailed("unable to open control file for writing.")

        fields = []
        pe = d.getVar('PKGE', True)
        if pe and int(pe) > 0:
            fields.append(["Version: %s:%s-%s\n", ['PKGE', 'PKGV', 'PKGR']])
        else:
            fields.append(["Version: %s-%s\n", ['PKGV', 'PKGR']])
        fields.append(["Description: %s\n", ['DESCRIPTION']])
        fields.append(["Section: %s\n", ['SECTION']])
        fields.append(["Priority: %s\n", ['PRIORITY']])
        fields.append(["Maintainer: %s\n", ['MAINTAINER']])
        fields.append(["Architecture: %s\n", ['DPKG_ARCH']])
        fields.append(["OE: %s\n", ['PN']])
        fields.append(["PackageArch: %s\n", ['PACKAGE_ARCH']])
        if d.getVar('HOMEPAGE', True):
            fields.append(["Homepage: %s\n", ['HOMEPAGE']])

        # Package, Version, Maintainer, Description - mandatory
        # Section, Priority, Essential, Architecture, Source, Depends, Pre-Depends, Recommends, Suggests, Conflicts, Replaces, Provides - Optional


        def pullData(l, d):
            l2 = []
            for i in l:
                data = d.getVar(i, True)
                if data is None:
                    raise KeyError(f)
                if i == 'DPKG_ARCH' and d.getVar('PACKAGE_ARCH', True) == 'all':
                    data = 'all'
                elif i == 'PACKAGE_ARCH' or i == 'DPKG_ARCH':
                   # The params in deb package control don't allow character
                   # `_', so change the arch's `_' to `-'. Such as `x86_64'
                   # -->`x86-64'
                   data = data.replace('_', '-')
                l2.append(data)
            return l2

        ctrlfile.write("Package: %s\n" % pkgname)
        # check for required fields
        try:
            for (c, fs) in fields:
                for f in fs:
                     if localdata.getVar(f) is None:
                         raise KeyError(f)
                # Special behavior for description...
                if 'DESCRIPTION' in fs:
                     summary = localdata.getVar('SUMMARY', True) or localdata.getVar('DESCRIPTION', True) or "."
                     ctrlfile.write('Description: %s\n' % unicode(summary))
                     description = localdata.getVar('DESCRIPTION', True) or "."
                     description = textwrap.dedent(description).strip()
                     if '\\n' in description:
                         # Manually indent
                         for t in description.split('\\n'):
                             # We don't limit the width when manually indent, but we do
                             # need the textwrap.fill() to set the initial_indent and
                             # subsequent_indent, so set a large width
                             ctrlfile.write('%s\n' % unicode(textwrap.fill(t, width=100000, initial_indent=' ', subsequent_indent=' ')))
                     else:
                         # Auto indent
                         ctrlfile.write('%s\n' % unicode(textwrap.fill(description.strip(), width=74, initial_indent=' ', subsequent_indent=' ')))

                else:
                     ctrlfile.write(unicode(c % tuple(pullData(fs, localdata))))
        except KeyError:
            import sys
            (type, value, traceback) = sys.exc_info()
            bb.utils.unlockfile(lf)
            ctrlfile.close()
            raise bb.build.FuncFailed("Missing field for deb generation: %s" % value)
        # more fields

        custom_fields_chunk = get_package_additional_metadata("deb", localdata)
        if custom_fields_chunk is not None:
            ctrlfile.write(unicode(custom_fields_chunk))
            ctrlfile.write("\n")

        mapping_rename_hook(localdata)

        def debian_cmp_remap(var):
            # dpkg does not allow for '(' or ')' in a dependency name
            # replace these instances with '__' and '__'
            #
            # In debian '>' and '<' do not mean what it appears they mean
            #   '<' = less or equal
            #   '>' = greater or equal
            # adjust these to the '<<' and '>>' equivalents
            #
            for dep in var:
                if '(' in dep:
                    newdep = dep.replace('(', '__')
                    newdep = newdep.replace(')', '__')
                    if newdep != dep:
                        var[newdep] = var[dep]
                        del var[dep]
            for dep in var:
                for i, v in enumerate(var[dep]):
                    if (v or "").startswith("< "):
                        var[dep][i] = var[dep][i].replace("< ", "<< ")
                    elif (v or "").startswith("> "):
                        var[dep][i] = var[dep][i].replace("> ", ">> ")

        rdepends = bb.utils.explode_dep_versions2(localdata.getVar("RDEPENDS", True) or "")
        debian_cmp_remap(rdepends)
        for dep in rdepends:
                if '*' in dep:
                        del rdepends[dep]
        rrecommends = bb.utils.explode_dep_versions2(localdata.getVar("RRECOMMENDS", True) or "")
        debian_cmp_remap(rrecommends)
        for dep in rrecommends:
                if '*' in dep:
                        del rrecommends[dep]
        rsuggests = bb.utils.explode_dep_versions2(localdata.getVar("RSUGGESTS", True) or "")
        debian_cmp_remap(rsuggests)
        rprovides = bb.utils.explode_dep_versions2(localdata.getVar("RPROVIDES", True) or "")
        debian_cmp_remap(rprovides)
        rreplaces = bb.utils.explode_dep_versions2(localdata.getVar("RREPLACES", True) or "")
        debian_cmp_remap(rreplaces)
        rconflicts = bb.utils.explode_dep_versions2(localdata.getVar("RCONFLICTS", True) or "")
        debian_cmp_remap(rconflicts)
        if rdepends:
            ctrlfile.write("Depends: %s\n" % unicode(bb.utils.join_deps(rdepends)))
        if rsuggests:
            ctrlfile.write("Suggests: %s\n" % unicode(bb.utils.join_deps(rsuggests)))
        if rrecommends:
            ctrlfile.write("Recommends: %s\n" % unicode(bb.utils.join_deps(rrecommends)))
        if rprovides:
            ctrlfile.write("Provides: %s\n" % unicode(bb.utils.join_deps(rprovides)))
        if rreplaces:
            ctrlfile.write("Replaces: %s\n" % unicode(bb.utils.join_deps(rreplaces)))
        if rconflicts:
            ctrlfile.write("Conflicts: %s\n" % unicode(bb.utils.join_deps(rconflicts)))
        ctrlfile.close()

        for script in ["preinst", "postinst", "prerm", "postrm"]:
            scriptvar = localdata.getVar('pkg_%s' % script, True)
            if not scriptvar:
                continue
            try:
                scriptfile = open(os.path.join(controldir, script), 'w')
            except OSError:
                bb.utils.unlockfile(lf)
                raise bb.build.FuncFailed("unable to open %s script file for writing." % script)
            scriptfile.write("#!/bin/sh\n")
            scriptfile.write(scriptvar)
            scriptfile.close()
            os.chmod(os.path.join(controldir, script), 0755)

        conffiles_str = localdata.getVar("CONFFILES", True)
        if conffiles_str:
            try:
                conffiles = open(os.path.join(controldir, 'conffiles'), 'w')
            except OSError:
                bb.utils.unlockfile(lf)
                raise bb.build.FuncFailed("unable to open conffiles for writing.")
            for f in conffiles_str.split():
                if os.path.exists(oe.path.join(root, f)):
                    conffiles.write('%s\n' % f)
            conffiles.close()

        os.chdir(basedir)
        ret = subprocess.call("PATH=\"%s\" dpkg-deb -b %s %s" % (localdata.getVar("PATH", True), root, pkgoutdir), shell=True)
        if ret != 0:
            bb.utils.unlockfile(lf)
            raise bb.build.FuncFailed("dpkg-deb execution failed")

        cleanupcontrol(root)
        bb.utils.unlockfile(lf)
}

SSTATETASKS += "do_package_write_deb"
do_package_write_deb[sstate-inputdirs] = "${PKGWRITEDIRDEB}"
do_package_write_deb[sstate-outputdirs] = "${DEPLOY_DIR_DEB}"

python do_package_write_deb_setscene () {
    tmpdir = d.getVar('TMPDIR', True)

    if os.access(os.path.join(tmpdir, "stamps", "DEB_PACKAGE_INDEX_CLEAN"),os.R_OK):
        os.unlink(os.path.join(tmpdir, "stamps", "DEB_PACKAGE_INDEX_CLEAN"))

    sstate_setscene(d)
}
addtask do_package_write_deb_setscene

python () {
    if d.getVar('PACKAGES', True) != '':
        deps = ' dpkg-native:do_populate_sysroot virtual/fakeroot-native:do_populate_sysroot'
        d.appendVarFlag('do_package_write_deb', 'depends', deps)
        d.setVarFlag('do_package_write_deb', 'fakeroot', "1")

    # Map TARGET_ARCH to Debian's ideas about architectures
    darch = d.getVar('DPKG_ARCH', True)
    if darch in ["x86", "i486", "i586", "i686", "pentium"]:
         d.setVar('DPKG_ARCH', 'i386')
    elif darch == "arm":
         d.setVar('DPKG_ARCH', 'armel')
}

python do_package_write_deb () {
    bb.build.exec_func("read_subpackage_metadata", d)
    bb.build.exec_func("do_package_deb", d)
}
do_package_write_deb[dirs] = "${PKGWRITEDIRDEB}"
do_package_write_deb[cleandirs] = "${PKGWRITEDIRDEB}"
do_package_write_deb[umask] = "022"
addtask package_write_deb before do_package_write after do_packagedata do_package


PACKAGEINDEXDEPS += "dpkg-native:do_populate_sysroot"
PACKAGEINDEXDEPS += "apt-native:do_populate_sysroot"

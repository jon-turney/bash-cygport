#!/bin/bash
#
# Generic package build script
#
# $Id: generic-build-script,v 1.46 2006/01/28 20:33:13 igor Exp $
#
# Package maintainers: if the original source is not distributed as a
# (possibly compressed) tarball, set the value of ${src_orig_pkg_name},
# and redefine the unpack() helper function appropriately.
# Also, if the Makefile rule to run the test suite is not "check", change
# the definition of ${test_rule} below.

# find out where the build script is located
tdir=`echo "$0" | sed 's%[\\/][^\\/][^\\/]*$%%'`
test "x$tdir" = "x$0" && tdir=.
scriptdir=`cd $tdir; pwd`
# find src directory.
# If scriptdir ends in SPECS, then topdir is $scriptdir/..
# If scriptdir ends in CYGWIN-PATCHES, then topdir is $scriptdir/../..
# Otherwise, we assume that topdir = scriptdir
topdir1=`echo ${scriptdir} | sed 's%/SPECS$%%'`
topdir2=`echo ${scriptdir} | sed 's%/CYGWIN-PATCHES$%%'`
if [ "x$topdir1" != "x$scriptdir" ] ; then # SPECS
  topdir=`cd ${scriptdir}/..; pwd`
else
  if [ "x$topdir2" != "x$scriptdir" ] ; then # CYGWIN-PATCHES
    topdir=`cd ${scriptdir}/../..; pwd`
  else
    topdir=`cd ${scriptdir}; pwd`
  fi
fi

tscriptname=`basename $0 .sh`
export PKG=`echo $tscriptname | sed -e 's/\-[^\-]*\-[^\-]*$//'`
export VER=`echo $tscriptname | sed -e "s/${PKG}\-//" -e 's/\-[^\-]*$//'`
export REL=`echo $tscriptname | sed -e "s/${PKG}\-${VER}\-//"`
# BASEPKG refers to the upstream base package
# SHORTPKG refers to the Cygwin package
# Normally, these are identical, but if the Cygwin package name is different
# from the upstream package name, you will want to redefine BASEPKG.
# Example: For Apache 2, BASEPKG=httpd-2.x.xx but SHORTPKG=apache2-2.x.xx
export BASEPKG=${PKG}-${VER}
export SHORTPKG=${PKG}-${VER}
export FULLPKG=${SHORTPKG}-${REL}

# determine correct decompression option and tarball filename
export src_orig_pkg_name=
if [ -e "${src_orig_pkg_name}" ] ; then
  export opt_decomp=? # Make sure tar punts if unpack() is not redefined
elif [ -e ${BASEPKG}.tar.bz2 ] ; then
  export opt_decomp=j
  export src_orig_pkg_name=${BASEPKG}.tar.bz2
elif [ -e ${BASEPKG}.tar.gz ] ; then
  export opt_decomp=z
  export src_orig_pkg_name=${BASEPKG}.tar.gz
elif [ -e ${BASEPKG}.tgz ] ; then
  export opt_decomp=z
  export src_orig_pkg_name=${BASEPKG}.tgz
elif [ -e ${BASEPKG}.tar ] ; then
  export opt_decomp=
  export src_orig_pkg_name=${BASEPKG}.tar
else
  echo "Cannot find PKG:${PKG} VER:${VER} REL:${REL}.  Rename $0 to"
  echo "something more appropriate, and try again."
  exit 1
fi

export src_orig_pkg=${topdir}/${src_orig_pkg_name}

# determine correct names for generated files
export src_pkg_name=${FULLPKG}-src.tar.bz2
export src_patch_name=${FULLPKG}.patch
export src_patch_tar_name=${FULLPKG}.patch.tar.bz2
export bin_pkg_name=${FULLPKG}.tar.bz2
export log_pkg_name=${FULLPKG}-BUILDLOGS.tar.bz2

export configurelogname=${FULLPKG}-CONFIGURE.LOG
export makelogname=${FULLPKG}-MAKE.LOG
export checklogname=${FULLPKG}-CHECK.LOG
export installlogname=${FULLPKG}-INSTALL.LOG

export src_pkg=${topdir}/${src_pkg_name}
export src_patch=${topdir}/${src_patch_name}
export src_patch_tar=${topdir}/${src_patch_tar_name}
export bin_pkg=${topdir}/${bin_pkg_name}
export srcdir=${topdir}/${BASEPKG}
export objdir=${srcdir}/.build
export instdir=${srcdir}/.inst
export srcinstdir=${srcdir}/.sinst
export buildlogdir=${srcdir}/.buildlogs
export patchdir=${srcdir}/.patches
export upstream_patchlist=${srcdir}/CYGWIN-PATCHES/upstream_patches.lst
export configurelogfile=${srcinstdir}/${configurelogname}
export makelogfile=${srcinstdir}/${makelogname}
export checklogfile=${srcinstdir}/${checklogname}
export installlogfile=${srcinstdir}/${installlogname}

prefix=/usr
sysconfdir=/etc
localstatedir=/var

# Interaction with bashdb
export DEBUGGER_START_FILE=${prefix}/share/bashdb/bashdb-main.inc

if [ -z "$MY_CFLAGS" ]; then
  MY_CFLAGS="-O2"
fi
if [ -z "$MY_LDFLAGS" ]; then
  MY_LDFLAGS=
fi

export install_docs="\
	ABOUT-NLS \
	ANNOUNCE \
	AUTHORS \
	BUG-REPORTS \
	CHANGES \
	CONTRIBUTORS \
	COPYING \
	COPYRIGHT \
	CREDITS \
	CHANGELOG \
	ChangeLog* \
	FAQ \
	HOW-TO-CONTRIBUTE \
	INSTALL \
	KNOWNBUG \
	LEGAL \
	LICENSE \
	NEWS \
	NOTES \
	PROGLIST \
	README \
	RELEASE_NOTES \
	THANKS \
	TODO \
	USAGE \
"
export install_docs="`for i in ${install_docs}; do echo $i; done | sort -u`"
export test_rule=check
if [ -z "$SIG" ]; then
  export SIG=0	# set to 1 to turn on signing by default
fi
# Sort in POSIX order.
export LC_ALL=C

# helper functions

# Provide help.
help() {
cat <<EOF
This is the cygwin packaging script for ${FULLPKG}.
Usage: $0 <action>
Actions are:
    help, --help	Print this message
    version, --version	Print the version message
    prep		Unpack and patch into ${srcdir}
    mkdirs		Make hidden directories needed during build
    conf, configure	Configure the package (./configure)
    reconf		Rerun configure
    build, make		Build the package (make)
    check, test		Run the testsuite (make ${test_rule})
    clean		Remove built files (make clean)
    install		Install package to staging area (make install)
    list		List package contents
    depend		List package dependencies
    strip		Strip package executables
    pkg, package	Prepare the binary package ${bin_pkg_name}
    mkpatch		Prepare the patch file ${src_patch_name}
    acceptpatch		Copy patch file ${src_patch_name} to ${topdir}
    spkg, src-package	Prepare the source package ${src_pkg_name}
    finish		Remove source directory ${srcdir}
    checksig		Validate GPG signatures (requires gpg)
    first		Full run for spkg (mkdirs, spkg, finish)
    almostall		Full run for bin pkg, except for finish
    all			Full run for bin pkg
EOF
}

# Provide version of generic-build-script modified to make this
version() {
    vers=`echo '$Revision: 1.46 $' | sed -e 's/Revision: //' -e 's/ *\\$//g'`
    echo "$0 based on generic-build-script $vers"
}

# unpacks the original package source archive into ./${BASEPKG}/
# change this if the original package was not tarred
# or if it doesn't unpack to a correct directory
unpack() {
  tar xv${opt_decomp}f "$1"
}

# make hidden directories used by g-b-s
mkdirs() {
  (cd ${topdir} && \
  rm -fr ${objdir} ${instdir} ${srcinstdir} ${patchdir} && \
  mkdir -p ${objdir} ${instdir} ${srcinstdir} ${patchdir} &&
  { expr $REL - 1 > ${objdir}/.build; :; } )
}
mkdirs_log() {
  (cd ${topdir} && \
  mkdirs "$@" && \
  rm -fr ${buildlogdir} && \
  mkdir -p ${buildlogdir} )
}

# Internal function for applying upstream patches
# $1 is directory to patch, $2 is file containing patch names
fixup() {
  if [ -f "$2" ] ; then
    (cd "$1" &&
    for patch in `cat "$2"` ; do
      echo "APPLYING UPSTREAM PATCH `basename ${patch}`"
      patch -Z -p0 < ${srcdir}/${patch}
    done &&
    find . \( -name '*.orig' -o -name '*.rej' \) -exec rm -f {} \;
    )
  fi
}

# Unpack the original tarball, and get everything set up for g-b-s
prep() {
  (cd ${topdir} && \
  unpack ${src_orig_pkg} && \
  mkdirs && \
  if [ -f ${src_patch_tar} ] ; then
    (cd ${patchdir} &&
    tar xvjf ${src_patch_tar} &&
    if [ -f ${src_patch_name} ] ; then
      mv ${src_patch_name} ${src_patch}
    fi &&
    if [ -f upstream_patches.lst ] ; then
      for patch in `cat upstream_patches.lst` ; do
	cp -p ${patch} ${srcdir}/${patch} &&
	if [ -f ${patch}.sig ] ; then
	  cp -p ${patch}.sig ${srcdir}/${patch}.sig
	fi
      done
    fi )
  fi &&
  fixup "${srcdir}" ${patchdir}/upstream_patches.lst &&
  cd ${topdir} && \
  if [ -f ${src_patch} ] ; then \
    patch -Z -p0 < ${src_patch} ;\
  fi )
}
prep_log() {
  prep "$@" && \
  mkdirs_log && \
  if [ -f ${topdir}/${log_pkg_name} ] ; then \
    cd ${buildlogdir} && \
    tar xvjf ${topdir}/${log_pkg_name}
  fi
}

# Configure the package
conf() {
  (cd ${objdir} && \
  CFLAGS="${MY_CFLAGS}" LDFLAGS="${MY_LDFLAGS}" \
  ${srcdir}/configure \
  --srcdir=${srcdir} --prefix="${prefix}" \
  --exec-prefix='${prefix}' --sysconfdir="${sysconfdir}" \
  --libdir='${prefix}/lib' --includedir='${prefix}/include' \
  --mandir='${prefix}/share/man' --infodir='${prefix}/share/info' \
  --libexecdir='${sbindir}' --localstatedir="${localstatedir}" \
  --datadir='${prefix}/share' --without-libiconv-prefix \
  --without-libintl-prefix --with-installed-readline )
}
conf_log() {
  conf "$@" 2>&1 | tee ${configurelogfile}
  return ${PIPESTATUS[0]}
}

# Rerun configure
reconf() {
  (cd ${topdir} && \
  rm -fr ${objdir} && \
  mkdir -p ${objdir} && \
  conf )
}
reconf_log() {
  reconf "$@" 2>&1 | tee ${configurelogfile}
  return ${PIPESTATUS[0]}
}

# Run make
build() {
  (cd ${objdir} && \
  make CFLAGS="${MY_CFLAGS}" )
}
build_log() {
  build "$@" 2>&1 | tee ${makelogfile}
  return ${PIPESTATUS[0]}
}

# Run the package testsuite
check() {
  (cd ${objdir} && \
  make -k ${test_rule} )
}
check_log() {
  check "$@" 2>&1 | tee ${checklogfile}
  return ${PIPESTATUS[0]}
}

# Remove built files
clean() {
  (cd ${objdir} && \
  make clean )
}

# Install the package, with DESTDIR of .inst
# postinstall named 00bash.sh to ensure /bin/sh exists before other
# postinstall scripts are run, even when old ash package is uninstalled.
# bash.1 cannot be compressed if bash_builtins.1 is to work.
install() {
  (cd ${objdir} && \
  rm -fr ${instdir}/* && \
  make install DESTDIR=${instdir} && \
  for f in ${prefix}/share/info/dir ${prefix}/info/dir ; do \
    if [ -f ${instdir}${f} ] ; then \
      rm -f ${instdir}${f} ; \
    fi ;\
  done &&\
  for d in ${prefix}/share/doc/${SHORTPKG} ${prefix}/share/doc/Cygwin ; do \
    if [ ! -d ${instdir}${d} ] ; then \
      mkdir -p ${instdir}${d} ;\
    fi ;\
  done &&\
  if [ -d ${instdir}${prefix}/share/info ] ; then \
    find ${instdir}${prefix}/share/info -name "*.info" | xargs -r gzip -q ; \
  fi && \
  if [ -d ${instdir}${prefix}/share/man ] ; then \
    find ${instdir}${prefix}/share/man \( -name "*.1" -o -name "*.3" -o \
      -name "*.3x" -o -name "*.3pm" -o -name "*.5" -o -name "*.6" -o \
      -name "*.7" -o -name "*.8" \) ! -name "bash.1" | xargs -r gzip -q ; \
  fi && \
  echo '.so man1/bash.1' > ${instdir}${prefix}/share/man/man1/sh.1 &&
  echo '.so man1/bash_builtins.1.gz' \
    > ${instdir}${prefix}/share/man/man1/alias.1 &&
  for f in bg bind break builtin caller case cd command compgen complete \
     continue declare dirs disown do done elif else enable esac eval exec \
     exit export fc fg fi for function getopts hash help history if in jobs \
     let local logout popd pushd read readonly return select set shift shopt \
     source suspend then time times trap type typeset ulimit umask unalias \
     unset until wait while ; do
    ln -f ${instdir}${prefix}/share/man/man1/alias.1 \
      ${instdir}${prefix}/share/man/man1/$f.1
  done &&
  templist="" && \
  for fp in ${install_docs} ; do \
    case "$fp" in \
      */) templist="$templist `find ${srcdir}/$fp -type f`" ;;
      *)  for f in ${srcdir}/$fp ; do \
	    if [ -f $f ] ; then \
	      templist="$templist $f"; \
	    fi ; \
	  done ;; \
    esac ; \
  done && \
  if [ ! "x$templist" = "x" ]; then \
    /usr/bin/install -m 644 $templist \
	 ${instdir}${prefix}/share/doc/${SHORTPKG} ; \
  fi && \
  if [ -f ${srcdir}/CYGWIN-PATCHES/${PKG}.README ]; then \
    /usr/bin/install -m 644 ${srcdir}/CYGWIN-PATCHES/${PKG}.README \
      ${instdir}${prefix}/share/doc/Cygwin/${SHORTPKG}.README ; \
  elif [ -f ${srcdir}/CYGWIN-PATCHES/README ] ; then \
    /usr/bin/install -m 644 ${srcdir}/CYGWIN-PATCHES/README \
      ${instdir}${prefix}/share/doc/Cygwin/${SHORTPKG}.README ; \
  fi && \
  if [ -f ${srcdir}/CYGWIN-PATCHES/${PKG}.sh ] ; then \
    if [ ! -d ${instdir}${sysconfdir}/postinstall ]; then \
      mkdir -p ${instdir}${sysconfdir}/postinstall ; \
    fi && \
    /usr/bin/install -m 755 ${srcdir}/CYGWIN-PATCHES/${PKG}.sh \
      ${instdir}${sysconfdir}/postinstall/${PKG}.sh ; \
  elif [ -f ${srcdir}/CYGWIN-PATCHES/postinstall.sh ] ; then \
    if [ ! -d ${instdir}${sysconfdir}/postinstall ]; then \
      mkdir -p ${instdir}${sysconfdir}/postinstall ; \
    fi && \
    /usr/bin/install -m 755 ${srcdir}/CYGWIN-PATCHES/postinstall.sh \
      ${instdir}${sysconfdir}/postinstall/00${PKG}.sh ; \
  fi && \
  mkdir -p ${instdir}${sysconfdir}/profile.d &&
  /usr/bin/install -m 755 ${srcdir}/CYGWIN-PATCHES/postinstall.bat \
    ${instdir}${sysconfdir}/postinstall/01${PKG}.bat &&
  /usr/bin/install -m 755 ${srcdir}/CYGWIN-PATCHES/00${PKG}.sh \
    ${instdir}${sysconfdir}/profile.d/00${PKG}.sh &&
  if [ -f ${srcdir}/CYGWIN-PATCHES/preremove.sh ] ; then \
    if [ ! -d ${instdir}${sysconfdir}/preremove ]; then \
      mkdir -p ${instdir}${sysconfdir}/preremove ; \
    fi && \
    /usr/bin/install -m 755 ${srcdir}/CYGWIN-PATCHES/preremove.sh \
      ${instdir}${sysconfdir}/preremove/~~${PKG}.sh ; \
  fi &&
  if [ -f ${srcdir}/CYGWIN-PATCHES/manifest.lst ] ; then
    if [ ! -d ${instdir}${sysconfdir}/preremove ]; then
      mkdir -p ${instdir}${sysconfdir}/preremove ;
    fi &&
    /usr/bin/install -m 644 ${srcdir}/CYGWIN-PATCHES/manifest.lst \
      ${instdir}${sysconfdir}/preremove/${PKG}-manifest.lst ;
  fi )
}
install_log() {
  install "$@" 2>&1 | tee ${installlogfile}
  return ${PIPESTATUS[0]}
}

# Strip binaries
strip() {
  (cd ${instdir} && \
  find . -name "*.dll" -or -name "*.exe" | xargs -r strip 2>&1 ; \
  true )
}

# List files that belong to the package
list() {
  (cd ${instdir} && \
  find . -name "*" ! -type d | sed 's%^\.%  %' | sort ; \
  true )
}

# List .dll dependencies of the package
depend() {
  (cd ${instdir} && \
  find ${instdir} -name "*.exe" -o -name "*.dll" | xargs -r cygcheck | \
  sed -ne '/^  [^ ]/ s,\\,/,gp' | sort -bu | \
  xargs -r -n1 cygpath -u | xargs -r cygcheck -f | sed 's%^%  %' | sort -u ; \
  true )
}

# Build the binary package
pkg() {
  (cd ${instdir} && \
  tar cvjf ${bin_pkg} * )
}

# Compare the original tarball with cygwin modifications
mkpatch() {
  (cd ${srcdir} && \
  find . -name "autom4te.cache" | xargs -r rm -rf ; \
  unpack ${src_orig_pkg} && \
  mv ${BASEPKG} ../${BASEPKG}-orig && \
  fixup "../${BASEPKG}-orig" ${upstream_patchlist} &&
  cd ${topdir} && \
  rm -f ${BASEPKG}-filter &&
  if [ -f ${upstream_patchlist} ] ; then
    cp ${upstream_patchlist} ${BASEPKG}-filter &&
    for patch in `cat ${upstream_patchlist}` ; do
      echo ${patch}.sig >> ${BASEPKG}-filter
    done
  else
    touch ${BASEPKG}-filter
  fi &&
  for dir in '.build' '.inst' '.sinst' '.buildlogs' '.patches' ; do
    echo ${dir} >> ${BASEPKG}-filter
  done &&
  diff -urN -X ${BASEPKG}-filter \
    -x 'build' \
    ${BASEPKG}-orig ${BASEPKG} > \
    ${srcinstdir}/${src_patch_name} ; \
  rm -rf ${BASEPKG}-filter ${BASEPKG}-orig &&
  if [ -f ${upstream_patchlist} ] ; then
    rm -Rf ${patchdir} &&
    mkdir -p ${patchdir} &&
    mv ${srcinstdir}/${src_patch_name} ${patchdir}/${src_patch_name} &&
    for patch in `cat ${upstream_patchlist}` ; do
      cp -p ${srcdir}/${patch} ${patchdir}/ &&
      if [ -f ${srcdir}/${patch}.sig ] ; then
	cp -p ${srcdir}/${patch}.sig ${patchdir}/
      fi
    done &&
    cp ${upstream_patchlist} ${patchdir}/upstream_patches.lst &&
    (cd ${patchdir} &&
    tar cvjf ${srcinstdir}/${src_patch_tar_name} *
    )
  fi
  )
}

# Note: maintainer-only functionality
acceptpatch() {
  cp --backup=numbered ${srcinstdir}/${src_patch_name} ${topdir}
}

# Build the source tarball
spkg() {
  (mkpatch && \
  if [ -f ${upstream_patchlist} ] ; then
    name=${srcinstdir}/${src_patch_tar_name} text="PATCH" sigfile
  else
    name=${srcinstdir}/${src_patch_name} text="PATCH" sigfile
  fi &&
  cp ${src_orig_pkg} ${srcinstdir}/${src_orig_pkg_name} && \
  if [ -e ${src_orig_pkg}.sig ] ; then \
    cp ${src_orig_pkg}.sig ${srcinstdir}/ ; \
  fi && \
  cp $0 ${srcinstdir}/`basename $0` && \
  name=$0 text="SCRIPT" sigfile && \
  if [ "${SIG}" -eq 1 ] ; then \
    cp $0.sig ${srcinstdir}/ ; \
  fi && \
  cd ${srcinstdir} && \
  tar cvjf ${src_pkg} * )
}
spkg_log() {
  spkg "$@" && \
  (cd ${srcinstdir} && \
  if [ -e ${configurelogname} -o -e ${makelogname} -o \
       -e ${checklogname} -o -e ${installlogname} ]; then
    tar --ignore-failed-read -cvjf ${log_pkg_name} \
      ${configurelogname} ${makelogname} ${checklogname} ${installlogname} && \
    rm -f \
      ${configurelogname} ${makelogname} ${checklogname} ${installlogname} ; \
  fi && \
  tar uvjf ${src_pkg} * )
}

# Clean up everything
finish() {
  rm -rf ${srcdir}
}

# Generate GPG signatures
sigfile() {
  if [ \( "${SIG}" -eq 1 \) -a \( -e $name \) -a \( \( ! -e $name.sig \) -o \( $name -nt $name.sig \) \) ]; then \
    if [ -x /usr/bin/gpg ]; then \
      echo "$text signature need to be updated"; \
      rm -f $name.sig; \
      /usr/bin/gpg --detach-sign $name; \
    else \
      echo "You need the gnupg package installed in order to make signatures."; \
    fi; \
  fi
}

# Validate signatures
checksig() {
  if [ -x /usr/bin/gpg ]; then \
    if [ -e ${src_orig_pkg}.sig ]; then \
      echo "ORIGINAL PACKAGE signature follows:"; \
      /usr/bin/gpg --verify ${src_orig_pkg}.sig ${src_orig_pkg}; \
    else \
      echo "ORIGINAL PACKAGE signature missing."; \
    fi; \
    if [ -f ${upstream_patchlist} ] ; then
      for patch in `cat ${upstream_patchlist}` ; do
	if [ -f ${srcdir}/${patch}.sig ] ; then
	  echo "UPSTREAM PATCH ${patch} signature follows:"
	  /usr/bin/gpg --verify ${srcdir}/${patch}.sig ${srcdir}/${patch}
	else
	  echo "UPSTREAM PATCH ${patch} signature missing."
	fi
      done
    fi
    if [ -e $0.sig ]; then \
      echo "SCRIPT signature follows:"; \
      /usr/bin/gpg --verify $0.sig $0; \
    else \
      echo "SCRIPT signature missing."; \
    fi; \
    if [ -f ${src_patch_tar} ] ; then
      if [ -f ${src_patch_tar}.sig ] ; then
        echo "PATCH signature follows:"; \
        /usr/bin/gpg --verify ${src_patch_tar}.sig ${src_patch_tar}; \
      else \
        echo "PATCH signature missing."; \
      fi; \
    elif [ -e ${src_patch} ] ; then
      if [ -e ${src_patch}.sig ]; then \
        echo "PATCH signature follows:"; \
        /usr/bin/gpg --verify ${src_patch}.sig ${src_patch}; \
      else \
        echo "PATCH signature missing."; \
      fi; \
    fi
  else
    echo "You need the gnupg package installed in order to check signatures." ; \
  fi
}

f_mkdirs=mkdirs
f_prep=prep
f_conf=conf
f_reconf=conf
f_build=build
f_check=check
f_install=install
f_spkg=spkg

enablelogging() {
  f_mkdirs=mkdirs_log && \
  f_prep=prep_log && \
  f_conf=conf_log && \
  f_reconf=reconf_log && \
  f_build=build_log && \
  f_check=check_log && \
  f_install=install_log && \
  f_spkg=spkg_log
}

while test -n "$1" ; do
  case $1 in
    help|--help)	help ; STATUS=$? ;;
    version|--version)	version ; STATUS=$? ;;
    with_logs|--logs)	enablelogging ; STATUS=$? ;;
    prep)		$f_prep ; STATUS=$? ;;
    mkdirs)		$f_mkdirs ; STATUS=$? ;;
    conf)		$f_conf ; STATUS=$? ;;
    configure)		$f_conf ; STATUS=$? ;;
    reconf)		$f_reconf ; STATUS=$? ;;
    build)		$f_build ; STATUS=$? ;;
    make)		$f_build ; STATUS=$? ;;
    check)		$f_check ; STATUS=$? ;;
    test)		$f_check ; STATUS=$? ;;
    clean)		$f_clean ; STATUS=$? ;;
    install)		$f_install ; STATUS=$? ;;
    list)		list ; STATUS=$? ;;
    depend)		depend ; STATUS=$? ;;
    strip)		strip ; STATUS=$? ;;
    package)		pkg ; STATUS=$? ;;
    pkg)		pkg ; STATUS=$? ;;
    mkpatch)		mkpatch ; STATUS=$? ;;
    acceptpatch)	acceptpatch ; STATUS=$? ;;
    src-package)	$f_spkg ; STATUS=$? ;;
    spkg)		$f_spkg ; STATUS=$? ;;
    finish)		finish ; STATUS=$? ;;
    checksig)		checksig ; STATUS=$? ;;
    first)		$f_mkdirs && $f_spkg && finish ; STATUS=$? ;;
    almostall)		checksig && $f_prep && $f_conf && $f_build && \
			$f_install && strip && pkg && $f_spkg ; STATUS=$? ;;
    all)		checksig && $f_prep && $f_conf && $f_build && \
			$f_install && strip && pkg && $f_spkg && finish ; \
			STATUS=$? ;;
    *) echo "Error: bad arguments" ; exit 1 ;;
  esac
  ( exit ${STATUS} ) || exit ${STATUS}
  shift
done
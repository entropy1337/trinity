#!/bin/bash

CONFIGH="config.h"

if [ -t 1 ]; then
	RED="[1;31m"
	GREEN="[1;32m"
	COL_RESET="[0;m"
fi

MISSING_DEFS=0

[ -z "$CC" ] && CC=gcc

# expand tilde
CC="$(eval echo ${CROSS_COMPILE}${CC})"

CFLAGS="${CFLAGS}"
if [ "${SYSROOT}xx" != "xx" ]; then
	CFLAGS="${CFLAGS} $(eval echo --sysroot=${SYSROOT} )"
fi

echo "#pragma once" > $CONFIGH
echo "/* This file is auto-generated by configure.sh */" >> $CONFIGH

TMP=$(mktemp)

check_header()
{
	echo -n "[*] Checking header $1 ... "

	rm -f "$TMP" || exit 1
	echo "#include <$1>" >"$TMP.c"

	${CC} ${CFLAGS} "$TMP.c" -E &>"$TMP.log"
	if [ $? -eq 0 ]; then
		echo $GREEN "[YES]" $COL_RESET
		echo "#define $2 1" >> $CONFIGH
	else
		echo $RED "[NO]" $COL_RESET
		MISSING_DEFS=1
	fi
}

#############################################################################################

echo "[*] Checking system headers."

#############################################################################################
# Are ipv6 headers usable ?
[ -z "$IPV6" ] && IPV6=yes
if [[ "$IPV6" == "yes" ]]; then
	echo -n "[*] Checking ipv6 headers ... "
	RET=$(grep __UAPI_DEF_IN6_PKTINFO /usr/include/linux/ipv6.h)
	if [ -z "$RET" ]; then
		echo $RED "[BROKEN]" $COL_RESET "See https://patchwork.ozlabs.org/patch/425881/"
	else
		echo $GREEN "[OK]" $COL_RESET
		echo "#define USE_IPV6 1" >> $CONFIGH
	fi
fi

#############################################################################################
# is /usr/include/linux/if_pppox.h new enough to feature pppol2tpin6/pppol2tpv3in6
#
echo -n "[*] Checking if pppox can use pppol2tpin6.. "
rm -f "$TMP" || exit 1

cat >"$TMP.c" << EOF
#include <stdio.h>
#include <netinet/in.h>
#include <linux/if.h>
#include <linux/if_pppox.h>

void main()
{
	struct sockaddr_pppol2tpin6 *pppox;
	printf("%d\n", pppox->sa_family);
}
EOF

${CC} ${CFLAGS} "$TMP.c" -o "$TMP" &>"$TMP.log"
if [ ! -x "$TMP" ]; then
	echo $RED "[NO]" $COL_RESET
	MISSING_DEFS=1
else
	echo $GREEN "[YES]" $COL_RESET
	echo "#define USE_PPPOL2TPIN6 1" >> $CONFIGH
fi

#############################################################################################
# is /usr/include/linux/if_pppox.h new enough to feature pppol2tpv3
#
echo -n "[*] Checking if pppox can use pppol2tv3.. "
rm -f "$TMP" || exit 1

cat >"$TMP.c" << EOF
#include <stdio.h>
#include <netinet/in.h>
#include <linux/if.h>
#include <linux/if_pppox.h>

void main()
{
	struct sockaddr_pppol2tpv3 *pppox;
	printf("%d\n", pppox->sa_family);
}
EOF

${CC} ${CFLAGS} "$TMP.c" -o "$TMP" &>"$TMP.log"
if [ ! -x "$TMP" ]; then
	echo $RED "[NO]" $COL_RESET
	MISSING_DEFS=1
else
	echo $GREEN "[YES]" $COL_RESET
	echo "#define USE_PPPOL2TPV3 1" >> $CONFIGH
fi

#############################################################################################
# is /usr/include/linux/if_pppox.h new enough to feature pptp
#
echo -n "[*] Checking if pppox can use pptp.. "
rm -f "$TMP" || exit 1

cat >"$TMP.c" << EOF
#include <stdio.h>
#include <netinet/in.h>
#include <linux/if.h>
#include <linux/if_pppox.h>

void main()
{
	struct sockaddr_pppox *pppox;
	printf("%d\n", pppox->sa_addr.pptp.call_id);
}
EOF

${CC} ${CFLAGS} "$TMP.c" -o "$TMP" &>"$TMP.log"
if [ ! -x "$TMP" ]; then
	echo $RED "[NO]" $COL_RESET
	MISSING_DEFS=1
else
	echo $GREEN "[YES]" $COL_RESET
	echo "#define USE_PPPOX_PPTP 1" >> $CONFIGH
fi

#############################################################################################
# is /usr/include/linux/llc.h new enough to feature LLC_OPT_PKTINFO
#
echo -n "[*] Checking if llc can use LLC_OPT_PKTINFO.. "
rm -f "$TMP" || exit 1

cat >"$TMP.c" << EOF
#include <stdio.h>
#include <net/if.h>
#include <linux/llc.h>

void main()
{
	printf("%d\n", LLC_OPT_PKTINFO);
}
EOF

${CC} ${CFLAGS} "$TMP.c" -o "$TMP" &>"$TMP.log"
if [ ! -x "$TMP" ]; then
	echo $RED "[NO]" $COL_RESET
	MISSING_DEFS=1
else
	echo $GREEN "[YES]" $COL_RESET
	echo "#define USE_LLC_OPT_PKTINFO 1" >> $CONFIGH
fi

#############################################################################################
# Do glibc headers provides struct termios2

echo -n "[*] Checking if glibc headers provide termios2.. "
rm -f "$TMP" || exit 1

cat >"$TMP.c" << EOF
#include <sys/ioctl.h>
#include <sys/vt.h>
#include <termios.h>

int main()
{
	struct termios2 test;
}
EOF

${CC} ${CFLAGS} "$TMP.c" -o "$TMP" &>"$TMP.log"
if [ ! -x "$TMP" ]; then
	echo $RED "[NO]" $COL_RESET
	MISSING_DEFS=1
else
	echo $GREEN "[YES]" $COL_RESET
	echo "#define HAVE_TERMIOS2 1" >> $CONFIGH
fi

#############################################################################################

check_header linux/caif/caif_socket.h USE_CAIF
check_header linux/if_alg.h USE_IF_ALG
check_header linux/rds.h USE_RDS
check_header linux/vfio.h USE_VFIO
check_header linux/btrfs.h USE_BTRFS
check_header drm/drm.h USE_DRM
check_header drm/exynos_drm.h USE_DRM_EXYNOS
check_header sound/compress_offload.h USE_SNDDRV_COMPRESS_OFFLOAD
check_header linux/kvm.h USE_KVM
check_header linux/seccomp.h USE_SECCOMP
check_header linux/vhost.h USE_VHOST
check_header execinfo.h USE_BACKTRACE
check_header netatalk/at.h USE_APPLETALK
check_header netrom/netrom.h USE_NETROM
check_header netrose/rose.h USE_ROSE
check_header linux/nvme.h USE_NVME

rm -f "$TMP" "$TMP.log" "$TMP.c"

#############################################################################################

if [ "$MISSING_DEFS" == "1" ]; then
  echo "[-] Some header definitions were missing. This is not fatal."
  echo "    It usually means you're building on an older distribution which doesn't"
  echo "    have header files describing newer kernel features."
  echo "    Trinity will still compile and run, it just won't use those new features."
  echo "    Go ahead, and run 'make'"
fi

exit 0

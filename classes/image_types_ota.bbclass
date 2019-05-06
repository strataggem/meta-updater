# Image to use with u-boot as BIOS and OSTree deployment system

#inherit image_types

# Boot filesystem size in MiB
# OSTree updates may require some space on boot file system for
# boot scripts, kernel and initramfs images
#

do_image_otaimg[depends] += "e2fsprogs-native:do_populate_sysroot \
			${@'grub:do_populate_sysroot' if d.getVar('OSTREE_BOOTLOADER', True) == 'grub' else ''} \
			${@'virtual/bootloader:do_deploy' if d.getVar('OSTREE_BOOTLOADER', True) == 'u-boot' else ''}"

calculate_size () {
	BASE=$1
	SCALE=$2
	MIN=$3
	MAX=$4
	EXTRA=$5
	ALIGN=$6

	SIZE=`echo "$BASE * $SCALE" | bc -l`
	REM=`echo $SIZE | cut -d "." -f 2`
	SIZE=`echo $SIZE | cut -d "." -f 1`

	if [ -n "$REM" -o ! "$REM" -eq 0 ]; then
		SIZE=`expr $SIZE \+ 1`
	fi

	if [ "$SIZE" -lt "$MIN" ]; then
		SIZE=$MIN
	fi

	SIZE=`expr $SIZE \+ $EXTRA`
	SIZE=`expr $SIZE \+ $ALIGN \- 1`
	SIZE=`expr $SIZE \- $SIZE \% $ALIGN`

	if [ -n "$MAX" ]; then
		if [ "$SIZE" -gt "$MAX" ]; then
			return -1
		fi
	fi
	
	echo "${SIZE}"
}

IMAGE_CMD_otaimg () {
	if ${@bb.utils.contains('IMAGE_FSTYPES', 'otaimg', 'false', 'true', d)}; then
		return
	fi
	if [ -z "$OSTREE_REPO" ]; then
		bbfatal "OSTREE_REPO should be set in your local.conf"
	fi

	if [ -z "$OSTREE_OSNAME" ]; then
		bbfatal "OSTREE_OSNAME should be set in your local.conf"
	fi

	if [ -z "$OSTREE_BRANCHNAME" ]; then
		bbfatal "OSTREE_BRANCHNAME should be set in your local.conf"
	fi

	PHYS_SYSROOT=`mktemp -d ${WORKDIR}/ota-sysroot-XXXXX`

	ostree admin --sysroot=${PHYS_SYSROOT} init-fs ${PHYS_SYSROOT}
	ostree admin --sysroot=${PHYS_SYSROOT} os-init ${OSTREE_OSNAME}

	mkdir -p ${PHYS_SYSROOT}/boot/loader.0
	ln -s loader.0 ${PHYS_SYSROOT}/boot/loader

	if [ "${OSTREE_BOOTLOADER}" = "grub" ]; then
		mkdir -p ${PHYS_SYSROOT}/boot/grub2
		ln -s ../loader/grub.cfg ${PHYS_SYSROOT}/boot/grub2/grub.cfg
	elif [ "${OSTREE_BOOTLOADER}" = "u-boot" ]; then
		touch ${PHYS_SYSROOT}/boot/loader/uEnv.txt
	else
		bbfatal "Invalid bootloader: ${OSTREE_BOOTLOADER}"
	fi

	ostree_target_hash=$(cat ${OSTREE_REPO}/refs/heads/${OSTREE_BRANCHNAME}-${IMAGE_BASENAME})

	ostree --repo=${PHYS_SYSROOT}/ostree/repo pull-local --remote=${OSTREE_OSNAME} ${OSTREE_REPO} ${ostree_target_hash}
	kargs_list=""
	for arg in ${OSTREE_KERNEL_ARGS}; do
		kargs_list="${kargs_list} --karg-append=$arg"
	done

	ostree admin --sysroot=${PHYS_SYSROOT} deploy ${kargs_list} --os=${OSTREE_OSNAME} ${ostree_target_hash}

	# Copy deployment /home and /var/sota to sysroot
	HOME_TMP=`mktemp -d ${WORKDIR}/home-tmp-XXXXX`
	tar --xattrs --xattrs-include='*' -C ${HOME_TMP} -xf ${DEPLOY_DIR_IMAGE}/${IMAGE_LINK_NAME}.rootfs.ostree.tar.bz2 ./usr/homedirs ./var/local || true

	cp -a ${IMAGE_ROOTFS}/var/sota ${PHYS_SYSROOT}/ostree/deploy/${OSTREE_OSNAME}/var/ || true
	# Create /var/sota if it doesn't exist yet
	mkdir -p ${PHYS_SYSROOT}/ostree/deploy/${OSTREE_OSNAME}/var/sota
	# Ensure the permissions are correctly set
	chmod 700 ${PHYS_SYSROOT}/ostree/deploy/${OSTREE_OSNAME}/var/sota

	mv ${HOME_TMP}/var/local ${PHYS_SYSROOT}/ostree/deploy/${OSTREE_OSNAME}/var/ || true
	mv ${HOME_TMP}/usr/homedirs/home ${PHYS_SYSROOT}/ || true
	# Ensure that /var/local exists (AGL symlinks /usr/local to /var/local)
	install -d ${PHYS_SYSROOT}/ostree/deploy/${OSTREE_OSNAME}/var/local
	# Set package version for the first deployment
	target_version=${ostree_target_hash}
	if [ -n "${GARAGE_TARGET_VERSION}" ]; then
		target_version=${GARAGE_TARGET_VERSION}
	elif [ -e "${STAGING_DATADIR_NATIVE}/target_version" ]; then
		target_version=$(cat "${STAGING_DATADIR_NATIVE}/target_version")
	fi
	mkdir -p ${PHYS_SYSROOT}/ostree/deploy/${OSTREE_OSNAME}/var/sota/import
	echo "{\"${ostree_target_hash}\":\"${GARAGE_TARGET_NAME}-${target_version}\"}" > ${PHYS_SYSROOT}/ostree/deploy/${OSTREE_OSNAME}/var/sota/import/installed_versions

	rm -rf ${HOME_TMP}

	# Calculate image size
	OTA_ROOTFS_SIZE=$(calculate_size `du -ks $PHYS_SYSROOT | cut -f 1`  "${IMAGE_OVERHEAD_FACTOR}" "${IMAGE_ROOTFS_SIZE}" "${IMAGE_ROOTFS_MAXSIZE}" `expr ${IMAGE_ROOTFS_EXTRA_SPACE}` "${IMAGE_ROOTFS_ALIGNMENT}")

	if [ ${OTA_ROOTFS_SIZE} -lt 0 ]; then
		exit -1
	fi
	eval local COUNT=\"0\"
	eval local MIN_COUNT=\"60\"
	if [ ${OTA_ROOTFS_SIZE} -lt ${MIN_COUNT} ]; then
		eval COUNT=\"${MIN_COUNT}\"
	fi

	# create image
	rm -rf ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.otaimg
	sync
	dd if=/dev/zero of=${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.otaimg seek=${OTA_ROOTFS_SIZE} count=${COUNT} bs=1024
	mkfs.ext4 -O ^64bit ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.otaimg -L otaroot -d ${PHYS_SYSROOT}
	rm -rf ${PHYS_SYSROOT}

	rm -f ${DEPLOY_DIR_IMAGE}/${IMAGE_LINK_NAME}.otaimg
	ln -s ${IMAGE_NAME}.otaimg ${DEPLOY_DIR_IMAGE}/${IMAGE_LINK_NAME}.otaimg
	# for forward compatibility
	rm -f ${DEPLOY_DIR_IMAGE}/${IMAGE_LINK_NAME}.ota-ext4
	ln -s ${IMAGE_NAME}.otaimg ${DEPLOY_DIR_IMAGE}/${IMAGE_LINK_NAME}.ota-ext4
}

IMAGE_TYPEDEP_otaimg = "ostree"

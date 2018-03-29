include recipes-core/images/core-image-minimal.bb

#export SOTA_PRIMARY_HARDWARE_ID
#export SOTA_HARDWARE_ID

SUMMARY = "A minimal Uptane Primary image running aktualizr, for testing with a Linux secondary"

LICENSE = "MIT"

python () {
    if d.getVar("SOTA_PRIMARY_HARDWARE_ID", True):
        d.setVar("SOTA_HARDWARE_ID", d.getVar("SOTA_PRIMARY_HARDWARE_ID", True))
}

IMAGE_INSTALL_remove = " \
                        "

IMAGE_INSTALL_append = " \
                        primary-network-config \
                       "

# vim:set ts=4 sw=4 sts=4 expandtab:

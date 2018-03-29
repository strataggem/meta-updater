include recipes-core/images/core-image-minimal.bb

export SOTA_SECONDARY_HARDWARE_ID
export SOTA_HARDWARE_ID

SUMMARY = "A minimal Uptane Secondary image running aktualizr-secondary"

LICENSE = "MIT"

IMAGE_TYPEDEP_garagesign_append = " set_hardware_id "
IMAGE_CMD_set_hardware_id() {
  if [ -n "${SOTA_SECONDARY_HARDWARE_ID}" ]; then
    SOTA_HARDWARE_ID="${SOTA_SECONDARY_HARDWARE_ID}"
  fi
}
#python IMAGE_CMD_set_hardware_id() {
#    if d.getVar("SOTA_SECONDARY_HARDWARE_ID", True):
#        d.setVar("SOTA_HARDWARE_ID", d.getVar("SOTA_SECONDARY_HARDWARE_ID", True))
#}

# Remove default aktualizr primary, and the provisioning configuration (which
# RDEPENDS on aktualizr)
IMAGE_INSTALL_remove = " \
                        aktualizr \
                        aktualizr-auto-prov \
                        aktualizr-ca-implicit-prov \
                        aktualizr-hsm-prov \
                        aktualizr-implicit-prov \
                        connman \
                        connman-client \
                        "

IMAGE_INSTALL_append = " \
                        aktualizr-secondary \
                        aktualizr-secondary-conf \
                        secondary-network-config \
                        "

# vim:set ts=4 sw=4 sts=4 expandtab:

SUMMARY = "Aktualizr secondary configuration"
DESCRIPTION = "Systemd service and configurations for Aktualizr secondaries"
HOMEPAGE = "https://github.com/advancedtelematic/aktualizr"
SECTION = "base"
LICENSE = "MPL-2.0"
LIC_FILES_CHKSUM = "file://${WORKDIR}/LICENSE;md5=9741c346eef56131163e13b9db1241b3"
RDEPENDS_${PN} = "aktualizr-secondary"
PV = "1.0"

SRC_URI = " \
  file://LICENSE \
  "

export SOTA_SECONDARY_HARDWARE_ID

do_install() {
  AKTUALIZR_PARAMETERS_CONFIGFILE="--config /usr/lib/sota/sota_secondary.toml"
  if [ -n "${SOTA_SECONDARY_HARDWARE_ID}" ]; then
    AKTUALIZR_PARAMETERS_HARDWARE_ID="--ecu-hardware-id ${SOTA_SECONDARY_HARDWARE_ID}";
  fi

  install -d ${D}${libdir}/sota
  echo "AKTUALIZR_CMDLINE_PARAMETERS=${AKTUALIZR_PARAMETERS_CONFIGFILE} ${AKTUALIZR_PARAMETERS_HARDWARE_ID}" > ${D}${libdir}/sota/sota.env
}

FILES_${PN} = "${libdir}/sota/sota.env"

# vim:set ts=4 sw=4 sts=4 expandtab:

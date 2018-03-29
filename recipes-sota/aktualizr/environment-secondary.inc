export SOTA_SECONDARY_HARDWARE_ID

do_install_append() {
  AKTUALIZR_PARAMETERS_CONFIGFILE="--config /usr/lib/sota/sota_secondary.toml"
  if [ -n "${SOTA_PRIMARY_HARDWARE_ID}" ]; then
    AKTUALIZR_PARAMETERS_HARDWARE_ID="--ecu-hardware-id ${SOTA_PRIMARY_HARDWARE_ID}"
  fi

  echo "AKTUALIZR_CMDLINE_PARAMETERS=${AKTUALIZR_PARAMETERS_CONFIGFILE} ${AKTUALIZR_PARAMETERS_HARDWARE_ID}" > ${D}${libdir}/sota/sota.env
}

FILES_${PN}_append = " ${libdir}/sota/sota.env"

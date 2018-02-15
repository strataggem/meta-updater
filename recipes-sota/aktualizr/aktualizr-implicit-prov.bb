SUMMARY = "Aktualizr configuration for implicit provisioning"
DESCRIPTION = "Systemd service and configurations for implicitly provisioning Aktualizr, the SOTA Client application written in C++"
HOMEPAGE = "https://github.com/advancedtelematic/aktualizr"
SECTION = "base"
LICENSE = "MPL-2.0"
LIC_FILES_CHKSUM = "file://${WORKDIR}/LICENSE;md5=9741c346eef56131163e13b9db1241b3"

DEPENDS = "aktualizr-native openssl-native"
RDEPENDS_${PN} = "aktualizr"

SRC_URI = " \
  file://LICENSE \
  "
PV = "1.0"
PR = "1"

require environment.inc
require credentials.inc

export SOTA_CACERT_PATH
export SOTA_CAKEY_PATH
do_install() {
    install -d ${D}${libdir}/sota

    if [ -z ${SOTA_CACERT_PATH} ]; then
        SOTA_CACERT_PATH=${DEPLOY_DIR_IMAGE}/CA/cacert.pem
        SOTA_CAKEY_PATH=${DEPLOY_DIR_IMAGE}/CA/ca.private.pem
        mkdir -p ${DEPLOY_DIR_IMAGE}/CA
        bbwarn "SOTA_CACERT_PATH is not specified, use default one at $SOTA_CACERT_PATH" 

        if [ ! -f ${SOTA_CACERT_PATH} ]; then
            bbwarn "${SOTA_CACERT_PATH} doesn't exist, generate a new CA"
                SOTA_CACERT_DIR_PATH="$(dirname "$SOTA_CACERT_PATH")"
            openssl genrsa -out ${SOTA_CERTCA_DIR_PATH}/ca.private.pem 4096
            openssl req -key ${SOTA_CERTCA_DIR_PATH}/ca.private.pem -new -x509 -days 7300 -out ${SOTA_CACERT_PATH} -subj "/C=DE/ST=Berlin/O=Reis und Kichererbsen e.V/commonName=meta-updater" -batch
            bbwarn "${SOTA_CACERT_PATH} has been created, you'll need to upload it to the server"
        fi
    fi

    if [ -z ${SOTA_CAKEY_PATH} ]; then
        bberror "SOTA_CAKEY_PATH should be set when using implicit provisioning"
    fi

    if [ -z "${SOTA_PACKED_CREDENTIALS}" ]; then
        bberror "SOTA_PACKED_CREDENTIALS are required for implicit provisioning"
    fi

    install -d ${D}${libdir}/sota
    install -d ${D}${localstatedir}/sota
    install -m 0644 ${STAGING_DIR_NATIVE}${libdir}/sota/sota_implicit_prov.toml ${D}${libdir}/sota/sota.toml
    aktualizr_cert_provider --credentials ${SOTA_PACKED_CREDENTIALS} \
                            --device-ca ${SOTA_CACERT_PATH} \
                            --device-ca-key ${SOTA_CAKEY_PATH} \
                            -r \
                            --local ${D}${localstatedir}/sota \
                            --config ${D}{libdir}/sota/sota.toml
}

FILES_${PN} = " \
                ${libdir}/sota/sota.toml \
                ${libdir}/sota/root.crt \
                "

# vim:set ts=4 sw=4 sts=4 expandtab:

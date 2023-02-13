local FRIENT_DEVICE_FINGERPRINTS = {
  { mfr = "frient A/S", model = "HESZB-120", subdriver = "heat", ENDPOINT_SIREN = 0x23, ENDPOINT_TEMPERATURE = 0x26,
    ENDPOINT_TAMPER = 0x23 } -- Siren, Temperature, Heat
}

return FRIENT_DEVICE_FINGERPRINTS

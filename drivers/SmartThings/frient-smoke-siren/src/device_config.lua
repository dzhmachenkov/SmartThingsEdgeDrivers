local FRIENT_DEVICE_FINGERPRINTS = {
  { mfr = "frient A/S", model = "FLSZB-110", subdriver = "waterleak", ENDPOINT_SIREN = 0x23, ENDPOINT_TEMPERATURE = 0x26,
    ENDPOINT_TAMPER = 0x23 } -- Siren, Temperature, WaterLeak
}

return FRIENT_DEVICE_FINGERPRINTS

local FRIENT_DEVICE_FINGERPRINTS = {
  { mfr = "frient A/S", model = "WISZB-120", subdriver = "sensor", ENDPOINT_TEMPERATURE = 0x26, ENDPOINT_TAMPER = 0x23 }, -- Temperature, Tamper/Contact (combined)
  { mfr = "frient A/S", model = "WISZB-121", subdriver = "sensor", ENDPOINT_TAMPER = 0x23 } -- Contact
}

return FRIENT_DEVICE_FINGERPRINTS

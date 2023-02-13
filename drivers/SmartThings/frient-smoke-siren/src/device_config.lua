local FRIENT_DEVICE_FINGERPRINTS = {
  { mfr = "frient A/S", model = "SMSZB-120", subdriver = "smoke", ENDPOINT_SIREN = 0x23, ENDPOINT_TEMPERATURE = 0x26,
    ENDPOINT_TAMPER = 0x23 }, -- Siren, Temperature, Smoke
  { mfr = "frient A/S", model = "SIRZB-110", subdriver = "siren", ENDPOINT_SIREN = 0x2B, ENDPOINT_TAMPER = 0x2B }, -- Siren, Tamper
  { mfr = "frient A/S", model = "HESZB-120", subdriver = "heat", ENDPOINT_SIREN = 0x23, ENDPOINT_TEMPERATURE = 0x26,
    ENDPOINT_TAMPER = 0x23 }, -- Siren, Temperature, Heat
  { mfr = "frient A/S", model = "FLSZB-110", subdriver = "waterleak", ENDPOINT_SIREN = 0x23, ENDPOINT_TEMPERATURE = 0x26,
    ENDPOINT_TAMPER = 0x23 }, -- Siren, Temperature, WaterLeak
  { mfr = "frient A/S", model = "REXZB-111", subdriver = "siren", ENDPOINT_SIREN = 0x2B, ENDPOINT_TAMPER = 0x2B }, -- Siren, Tamper
}

return FRIENT_DEVICE_FINGERPRINTS

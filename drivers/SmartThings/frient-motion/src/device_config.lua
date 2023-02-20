local FRIENT_DEVICE_FINGERPRINTS = {
  { mfr = "frient A/S", model = "MOSZB-140", subdriver = "sensor", ENDPOINT_OCCUPANCY = 0x22, ENDPOINT_TEMPERATURE = 0x26, ENDPOINT_ILLUMINANCE = 0x27, ENDPOINT_TAMPER = 0x23 }, -- Occupancy, Temperature, Light, Tamper
  { mfr = "frient A/S", model = "MOSZB-141", subdriver = "sensor", ENDPOINT_OCCUPANCY = 0x22, }, -- Occupancy
  { mfr = "frient A/S", model = "MOSZB-153", subdriver = "sensor", ENDPOINT_OCCUPANCY = 0x22, ENDPOINT_TEMPERATURE = 0x26, ENDPOINT_ILLUMINANCE = 0x27 } -- Occupancy, Temperature, Light
}

return FRIENT_DEVICE_FINGERPRINTS

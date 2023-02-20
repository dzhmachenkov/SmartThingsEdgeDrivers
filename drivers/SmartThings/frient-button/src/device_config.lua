local FRIENT_DEVICE_FINGERPRINTS = {
  { mfr = "frient A/S", model = "SBTZB-110", subdriver = "smart", ENDPOINT_BUTTON = 0x20, ENDPOINT_BATTERY = 0x20 }, -- Button, battery
  { mfr = "frient A/S", model = "PBTZB-110", subdriver = "panic", ENDPOINT_BUTTON = 0x23, ENDPOINT_BATTERY = 0x23 } -- Button, battery
}

return FRIENT_DEVICE_FINGERPRINTS

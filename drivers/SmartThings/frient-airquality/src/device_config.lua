local FRIENT_DEVICE_FINGERPRINTS = {
  { mfr = "frient A/S", model = "AQSZB-110", subdriver = "airquality", ENDPOINT_TEMPERATURE = 0x26, ENDPOINT_HUMIDITY = 0x26, ENDPOINT_AIRQUALITY = 0x26 }, -- Temperature, Humidity, AirQuality
  { mfr = "frient A/S", model = "HMSZB-120", subdriver = "humidity", ENDPOINT_TEMPERATURE = 0x26, ENDPOINT_HUMIDITY = 0x26 } -- Temperature, Humidity
}

return FRIENT_DEVICE_FINGERPRINTS

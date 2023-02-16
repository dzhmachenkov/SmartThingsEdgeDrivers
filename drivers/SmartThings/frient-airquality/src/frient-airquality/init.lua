local capabilities                 = require "st.capabilities"
local util                         = require "st.utils"
local log                          = require "log"

local FRIENT_DEVICE_FINGERPRINTS   = require "device_config"
local Frient_VOCMeasurement        = require "frient_voc_measurement"
local MAX_VOC_REPORTABLE_VALUE     = 5500 -- Max VOC reportable value

--- Table to map VOC (ppb) to HealthConcern
local VOC_TO_HEALTHCONCERN_MAPPING = {
  [5501] = "hazardous",
  [2201] = "veryUnhealthy",
  [661] = "unhealthy",
  [221] = "slightlyUnhealthy",
  [66] = "moderate",
  [0] = "good",
}

--- Table to map VOC (ppb) to VOCLevel
local VOC_TO_LEVEL_MAPPING         = {
  [2201] = "unhealthy",
  [661] = "poor",
  [221] = "moderate",
  [66] = "good",
  [0] = "excellent",
}

--- Map VOC (ppb) to HealthConcern
--- @param raw_voc integer Value of the VOC level
local function voc_to_healthconcern(raw_voc)
  for voc, perc in util.rkeys(VOC_TO_HEALTHCONCERN_MAPPING) do
    if raw_voc >= voc then
      return perc
    end
  end
end

--- Map VOC (ppb) to CAQI
--- @param raw_voc integer Value of the VOC level
local function voc_to_caqi(raw_voc)
  if (raw_voc > 5500) then
    return 100
  else
    return math.floor(raw_voc * 99 / 5500)
  end
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param attr_val st.zigbee.data_types.Uint16 the value of the attribute
--- @param zb_rx st.zigbee.ZigbeeMessageRx the full message this report came in
local function voc_measure_value_attr_handler(driver, device, attr_val, zb_rx)
  local voc_value = attr_val.value
  if (voc_value < 65535) then
    -- ignore it if it's outside the limits
    log.trace("Received VOC MeasuredValue :" .. util.stringify_table(voc_value))
    voc_value = util.clamp_value(voc_value, 0, MAX_VOC_REPORTABLE_VALUE)
    device:emit_event(capabilities.airQualitySensor.airQuality(voc_to_caqi(voc_value)))
    device:emit_event(capabilities.tvocHealthConcern.tvocHealthConcern(voc_to_healthconcern(voc_value)))
    device:emit_event(capabilities.tvocMeasurement.tvocLevel({ value = voc_value / 1000, unit = "ppm" })) -- convert ppb to ppm
  else
    log.warn("Ignoring invalid VOC MeasuredValue : " .. util.stringify_table(voc_value))
  end
end

--- @param opts table A table containing optional arguments that can be used to determine if something is handleable
--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
local function can_handle_frient(opts, driver, device, ...)
  for _, fingerprint in ipairs(FRIENT_DEVICE_FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model and fingerprint.subdriver == "airquality" then
      return true
    end
  end
  return false
end

local frient_airquality_sensor = {
  NAME = "frient Air Quality Sensor",
  zigbee_handlers = {
    cluster = {},
    attr = {
      [Frient_VOCMeasurement.ID] = {
        [Frient_VOCMeasurement.attributes.MeasuredValue.ID] = voc_measure_value_attr_handler,
      }
    }
  },
  can_handle = can_handle_frient
}

return frient_airquality_sensor

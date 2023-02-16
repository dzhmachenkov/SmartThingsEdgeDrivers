local capabilities     = require "st.capabilities"
local ZigbeeDriver     = require "st.zigbee"
local defaults         = require "st.zigbee.defaults"

local battery_defaults = require "st.zigbee.defaults.battery_defaults"
local configurationMap = require "configurations"

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
local function device_init(driver, device)
  battery_defaults.build_linear_voltage_init(2.5, 3.0)(driver, device)

  local configuration = configurationMap.get_device_configuration(device)
  if configuration ~= nil then
    for _, attribute in ipairs(configuration) do
      device:add_configured_attribute(attribute)
      device:add_monitored_attribute(attribute)
    end
  end
end

local frient_airquality_driver_template = {
  NAME = "frient air quality driver",
  supported_capabilities = {
    capabilities.tvocMeasurement,
    capabilities.tvocHealthConcern,
    capabilities.airQualitySensor,
    capabilities.relativeHumidityMeasurement,
    capabilities.temperatureMeasurement,
    capabilities.battery,
  },
  sub_drivers = {
    require("frient-humidity")
  },
  lifecycle_handlers = {
    init = device_init
  },
  zigbee_handlers = {
  },
  capability_handlers = {
  }
}

defaults.register_for_default_handlers(frient_airquality_driver_template,
    frient_airquality_driver_template.supported_capabilities)
local frient_sensor = ZigbeeDriver("freint-airquality", frient_airquality_driver_template)
frient_sensor:run()

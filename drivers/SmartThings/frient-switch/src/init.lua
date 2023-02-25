local capabilities                       = require "st.capabilities"
local ZigbeeDriver                       = require "st.zigbee"
local zcl_clusters                       = require "st.zigbee.zcl.clusters"
local defaults                           = require "st.zigbee.defaults"

local SimpleMetering                     = zcl_clusters.SimpleMetering
local ElectricalMeasurement              = zcl_clusters.ElectricalMeasurement

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param event string The lifecycle event name
--- @param args table Table containing information relevant to the lifecycle event
local function do_configure(driver, device, event, args)
  device:configure()
  device:refresh()

  -- Additional one time configuration
  if device:supports_capability(capabilities.energyMeter) or device:supports_capability(capabilities.powerMeter) then
    -- Divisor and multipler for EnergyMeter
    device:send(ElectricalMeasurement.attributes.ACPowerDivisor:read(device))
    device:send(ElectricalMeasurement.attributes.ACPowerMultiplier:read(device))
    -- Divisor and multipler for PowerMeter
    device:send(SimpleMetering.attributes.Divisor:read(device))
    device:send(SimpleMetering.attributes.Multiplier:read(device))
  end
end

local frient_switch_driver = {
  NAME = "frient switch driver",
  supported_capabilities = {
    capabilities.switch,
    capabilities.powerMeter,
    capabilities.energyMeter,
    capabilities.voltageMeasurement,
    capabilities.currentMeasurement,
    capabilities.battery,
    capabilities.tamperAlert,
  },
  sub_drivers = {
    require("frient-miniplug")
  },
  lifecycle_handlers = {
    doConfigure = do_configure
  },
  zigbee_handlers = {
    cluster = {
    },
    attr = {
    }
  },
  capability_handlers = {
  },
}

defaults.register_for_default_handlers(frient_switch_driver, frient_switch_driver.supported_capabilities)
local frient_switch = ZigbeeDriver("zigbee-switch", frient_switch_driver)
frient_switch:run()

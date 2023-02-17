local capabilities = require "st.capabilities"
local battery_defaults = require "st.zigbee.defaults.battery_defaults"
local device_management = require "st.zigbee.device_management"
local data_types = require "st.zigbee.data_types"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local log = require "log"

local PowerConfiguration = zcl_clusters.PowerConfiguration
local IASZone = zcl_clusters.IASZone

local FRIENT_DEVICE_FINGERPRINTS = require "device_config"

local battery_table = {
  [2.90] = 100,
  [2.80] = 80,
  [2.75] = 60,
  [2.70] = 50,
  [2.65] = 40,
  [2.60] = 30,
  [2.50] = 20,
  [2.40] = 15,
  [2.20] = 10,
  [2.10] = 5,
  [2.00] = 1,
  [1.90] = 0,
  [0.00] = 0
}

local BASE_FUNCTIONS = {}

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
function BASE_FUNCTIONS.do_init(driver, device)
  for _, fingerprint in ipairs(FRIENT_DEVICE_FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
      --battery_defaults.build_linear_voltage_init(2.1, 3.0)(driver, device)
      battery_defaults.enable_battery_voltage_table(device, battery_table)
      if fingerprint.ENDPOINT_BUTTON then
        device:emit_event_for_endpoint(fingerprint.ENDPOINT_BUTTON, capabilities.button.supportedButtonValues({"pushed"}))
        device:emit_event_for_endpoint(fingerprint.ENDPOINT_BUTTON, capabilities.button.numberOfButtons({value = 1}))
      end
    end
  end
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
function BASE_FUNCTIONS.do_refresh(driver, device)
  device:refresh()
  for _, fingerprint in ipairs(FRIENT_DEVICE_FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
      if fingerprint.ENDPOINT_BUTTON then
      end
      if fingerprint.ENDPOINT_BATTERY then
        if device:supports_capability(capabilities.battery) then
        end
      end
    end
  end
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param event string The lifecycle event name
--- @param args table Table containing information relevant to the lifecycle event
function BASE_FUNCTIONS.do_configure(driver, device, event, args)
  device:configure()
  for _, fingerprint in ipairs(FRIENT_DEVICE_FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
    end
  end
end

return BASE_FUNCTIONS

local capabilities      = require "st.capabilities"
local ZigbeeDriver      = require "st.zigbee"
local zcl_clusters      = require "st.zigbee.zcl.clusters"
local defaults          = require "st.zigbee.defaults"
local battery_defaults  = require "st.zigbee.defaults.battery_defaults"
local device_management = require "st.zigbee.device_management"
local constants         = require "st.zigbee.constants"

local IASZone           = zcl_clusters.IASZone

local battery_table     = {
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

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param zone_status st.zigbee.zcl.types.IasZoneStatus 2 byte bitmap zoneStatus attribute value of the IAS Zone cluster
--- @param zb_rx st.zigbee.ZigbeeMessageRx the full message this report came in
local function generate_event_from_zone_status(driver, device, zone_status, zb_rx)
  local event
  local additional_fields = {
    state_change = true
  }
  if zone_status:is_alarm2_set() then
    event = capabilities.button.button.pushed(additional_fields)
  end
  if event ~= nil then
    device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, event)
  end
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param zone_status st.zigbee.zcl.types.IasZoneStatus the value of the attribute
--- @param zb_rx st.zigbee.ZigbeeMessageRx the full message this report came in
local function ias_zone_status_attr_handler(driver, device, zone_status, zb_rx)
  generate_event_from_zone_status(driver, device, zone_status, zb_rx)
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param zb_rx st.zigbee.ZigbeeMessageRx the full message this report came in
local function ias_zone_status_change_handler(driver, device, zb_rx)
  local zone_status = zb_rx.body.zcl_body.zone_status
  generate_event_from_zone_status(driver, device, zone_status, zb_rx)
end

local function device_added(driver, device)
  device:emit_event(capabilities.button.supportedButtonValues({ "pushed" }, { visibility = { displayed = false } }))
  device:emit_event(capabilities.button.numberOfButtons({ value = 1 }))
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
local function device_init(driver, device)
  battery_defaults.enable_battery_voltage_table(device, battery_table)
end

local frient_button_driver = {
  NAME = "frient button driver",
  supported_capabilities = {
    capabilities.button,
    capabilities.battery
  },
  sub_drivers = {
    require("frient-panic")
  },
  lifecycle_handlers = {
    added = device_added,
    init = device_init
  },
  zigbee_handlers = {
    cluster = {
      [IASZone.ID] = {
        [IASZone.client.commands.ZoneStatusChangeNotification.ID] = ias_zone_status_change_handler
      }
    },
    attr = {
      [IASZone.ID] = {
        [IASZone.attributes.ZoneStatus.ID] = ias_zone_status_attr_handler
      }
    },
  },
  capability_handlers = {

  },
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE,
}

defaults.register_for_default_handlers(frient_button_driver, frient_button_driver.supported_capabilities)
local frient_switch = ZigbeeDriver("zigbee-button", frient_button_driver)
frient_switch:run()

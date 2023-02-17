local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local defaults = require "st.zigbee.defaults"
local constants = require "st.zigbee.constants"
local log = require "log"

local BASE_FUNCTIONS = require "device_base_functions"

local IASZone = zcl_clusters.IASZone
local BasicInput = zcl_clusters.BasicInput

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param value st.zigbee.data_types.Uint16 the value of the event
--- @param zb_rx st.zigbee.ZigbeeMessageRx the full message this report came in
local function present_value_attr_handler(driver, device, value, zb_rx)
  local event
  local additional_fields = {
    state_change = true
  }
  if value.value == true then
    event = capabilities.button.button.pushed(additional_fields)
    device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, event)
  end
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param zone_status st.zigbee.zcl.types.IasZoneStatus 2 byte bitmap zoneStatus attribute value of the IAS Zone cluster
--- @param zb_rx st.zigbee.ZigbeeMessageRx the full message this report came in
local function generate_event_from_zone_status(driver, device, zone_status, zb_rx)
  --log.trace("Received IAS report:"..util.stringify_table(zone_status, nil, true))
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

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
local function device_init(driver, device)
  log.trace "Initializing button"
  BASE_FUNCTIONS.do_init(driver, device)
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
local function do_refresh(driver, device)
  log.trace "Refreshing button attributes"
  BASE_FUNCTIONS.do_refresh(driver, device)
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param event string The lifecycle event name
--- @param args table Table containing information relevant to the lifecycle event
local function do_configure(driver, device, event, args)
  log.trace("Configuring button:"..event)--..", "..util.stringify_table(args, nil, true))
  if ((event == "doConfigure") or (args and args.old_st_store)) then -- Only if we got a parameter update then reinitialize, infoChanged could be called periodically also
    BASE_FUNCTIONS.do_configure(driver, device, event, args)
  end

  device.thread:call_with_delay(5, function()
    do_refresh(driver, device)
  end)
end

local frient_button_driver = {
  NAME = "frient button driver",
  supported_capabilities = {
    capabilities.button,
    capabilities.battery,
  },
  sub_drivers = {
    require("frient-smart"),
    require("frient-panic"),
  },
  lifecycle_handlers = {
    init = device_init,
    doConfigure = do_configure,
    infoChanged = do_configure,
  },
  zigbee_handlers = {
    cluster = {
      [IASZone.ID] = {
        [IASZone.client.commands.ZoneStatusChangeNotification.ID] = ias_zone_status_change_handler
      }
    },
    attr = {
      [BasicInput.ID] = {
        [BasicInput.attributes.PresentValue.ID] = present_value_attr_handler
      },
      [IASZone.ID] = {
        [IASZone.attributes.ZoneStatus.ID] = ias_zone_status_attr_handler
      }
    },
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh,
    }
  },
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE,
}

defaults.register_for_default_handlers(frient_button_driver, frient_button_driver.supported_capabilities)
local frient_switch = ZigbeeDriver("zigbee-button", frient_button_driver)
frient_switch:run()

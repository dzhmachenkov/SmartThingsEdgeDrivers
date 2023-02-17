local capabilities = require "st.capabilities"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local cluster_base = require "st.zigbee.cluster_base"
local battery_defaults = require "st.zigbee.defaults.battery_defaults"
local device_management = require "st.zigbee.device_management"
local data_types = require "st.zigbee.data_types"
local util = require "st.utils"
local log = require "log"

local BasicInput = zcl_clusters.BasicInput
local OnOff = zcl_clusters.OnOff

local FRIENT_DEVICE_FINGERPRINTS = require "device_config"
local BASE_FUNCTIONS = require "device_base_functions"

local DEVELCO_MANUFACTURER_CODE = 0x1015
local BUTTON_LED_COLOR = 0x8002
local BUTTON_PRESS_DELAY = 0x8001

--- @param opts table A table containing optional arguments that can be used to determine if something is handleable
--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
local function can_handle_frient(opts, driver, device, ...)
  for _, fingerprint in ipairs(FRIENT_DEVICE_FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model and fingerprint.subdriver == "smart" then
      --[[
      log.warn("OPTS"..util.stringify_table(opts, nil, true))
      log.warn("DRIVER:"..util.stringify_table(driver, nil, true))
      log.warn("DEVICE:"..util.stringify_table(device, nil, true))
      --]]
      return true
    end
  end
  return false
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
local function device_init(driver, device)
  log.trace "Initializing smart button"
  for _, fingerprint in ipairs(FRIENT_DEVICE_FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
      BASE_FUNCTIONS.do_init(driver, device)
  end
  end
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
local function do_refresh(driver, device)
  log.trace "Refreshing smart button attributes"
  for _, fingerprint in ipairs(FRIENT_DEVICE_FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
      BASE_FUNCTIONS.do_refresh(driver, device)
    end
  end
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param event string The lifecycle event name
--- @param args table Table containing information relevant to the lifecycle event
local function do_configure(driver, device, event, args)
  log.trace("Configuring smart button:"..event)--..", "..util.stringify_table(args, nil, true))
  if ((event == "doConfigure") or (args and args.old_st_store)) then -- Only if we got a parameter update then reinitialize, infoChanged could be called periodically also
    for _, fingerprint in ipairs(FRIENT_DEVICE_FINGERPRINTS) do
      if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
        BASE_FUNCTIONS.do_configure(driver, device, event, args)
        if fingerprint.ENDPOINT_BUTTON then
          local message

          device:send(device_management.build_bind_request(device, BasicInput.ID, driver.environment_info.hub_zigbee_eui, fingerprint.ENDPOINT_BUTTON))
          device:send(BasicInput.attributes.PresentValue:configure_reporting(device, 0, 6*60*60):to_endpoint(fingerprint.ENDPOINT_BUTTON))
          
          --device:send(device_management.build_bind_request(device, OnOff.ID, driver.environment_info.hub_zigbee_eui, fingerprint.ENDPOINT_BUTTON))

          if (args and args.old_st_store == nil) or args.old_st_store.preferences.ledColor ~= device.preferences.ledColor then -- Send this only if the value has changed because it resets the meter (or upon first initialization, there's no args.old_st_store)
            local ledColor = tonumber(device.preferences.ledColor) or 2
            log.debug("Writing LED Color: "..ledColor)

            message = cluster_base.write_manufacturer_specific_attribute(device, OnOff.ID, BUTTON_LED_COLOR, DEVELCO_MANUFACTURER_CODE, data_types.Enum8, ledColor):to_endpoint(fingerprint.ENDPOINT_BUTTON)
            message.body.zcl_header.frame_ctrl:set_direction() -- This is a client cluster, ST EDGE API doesn't allow you to set it while creation, so do it manually
            device:send(message)

            -- Verify
            message = cluster_base.read_manufacturer_specific_attribute(device, OnOff.ID, BUTTON_LED_COLOR, DEVELCO_MANUFACTURER_CODE):to_endpoint(fingerprint.ENDPOINT_BUTTON)
            message.body.zcl_header.frame_ctrl:set_direction() -- This is a client cluster, ST EDGE API doesn't allow you to set it while creation, so do it manually
            device:send(message)
          end
          
          if (args and args.old_st_store == nil) or args.old_st_store.preferences.buttonDelay ~= device.preferences.buttonDelay then -- Send this only if the value has changed because it resets the meter (or upon first initialization, there's no args.old_st_store)
            local buttonDelay = device.preferences.buttonDelay or 100
            log.debug("Writing Button delay (ms): "..buttonDelay)
            message = cluster_base.write_manufacturer_specific_attribute(device, OnOff.ID, BUTTON_PRESS_DELAY, DEVELCO_MANUFACTURER_CODE, data_types.Uint16, buttonDelay):to_endpoint(fingerprint.ENDPOINT_BUTTON)
            message.body.zcl_header.frame_ctrl:set_direction() -- This is a client cluster, ST EDGE API doesn't allow you to set it while creation, so do it manually
            device:send(message)

            -- Verify
            message = cluster_base.read_manufacturer_specific_attribute(device, OnOff.ID, BUTTON_PRESS_DELAY, DEVELCO_MANUFACTURER_CODE):to_endpoint(fingerprint.ENDPOINT_BUTTON)
            message.body.zcl_header.frame_ctrl:set_direction() -- This is a client cluster, ST EDGE API doesn't allow you to set it while creation, so do it manually
            device:send(message)
          end
        end
      end
    end
  end

  device.thread:call_with_delay(5, function()
    do_refresh(driver, device)
  end)
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param value st.zigbee.data_types.Uint16 the value of the Attribute
--- @param zb_rx st.zigbee.ZigbeeMessageRx the full message this report came in
local function custom_on_off_attr_handler(driver, device, value, zb_rx)
  log.warn("Received On/Off Custom Attribute report: 0x"..string.format("%x", zb_rx.body.zcl_body.attr_records[1].attr_id.value).."="..value.value)
end

local frient_smart_button = {
  NAME = "Frient Smart Button",
  lifecycle_handlers = {
    init = device_init,
    doConfigure = do_configure,
    infoChanged = do_configure,
  },
  zigbee_handlers = {
    cluster = {
    },
    attr = {
      [OnOff.ID] = {
        [BUTTON_LED_COLOR] = custom_on_off_attr_handler,
        [BUTTON_PRESS_DELAY] = custom_on_off_attr_handler,
      }
    },
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh,
    }
  },
  can_handle = can_handle_frient
}

return frient_smart_button

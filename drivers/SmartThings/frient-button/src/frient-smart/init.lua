local zcl_clusters               = require "st.zigbee.zcl.clusters"
local cluster_base               = require "st.zigbee.cluster_base"
local data_types                 = require "st.zigbee.data_types"

local OnOff                      = zcl_clusters.OnOff

local FRIENT_DEVICE_FINGERPRINTS = require "device_config"

local MFG_CODE                   = 0x1015
local BUTTON_LED_COLOR           = 0x8002
local BUTTON_PRESS_DELAY         = 0x8001

--- @param opts table A table containing optional arguments that can be used to determine if something is handleable
--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
local function can_handle_frient(opts, driver, device, ...)
  for _, fingerprint in ipairs(FRIENT_DEVICE_FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model and fingerprint.subdriver == "smart" then
      return true
    end
  end
  return false
end

local function write_client_manufacturer_specific_attribute(device, cluster_id, attr_id, mfg_specific_code, data_type,
    payload)
  local msg = cluster_base.write_manufacturer_specific_attribute(device, cluster_id, attr_id, mfg_specific_code,
      data_type, payload)
  msg.body.zcl_header.frame_ctrl:set_direction_client()
  return msg
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param event string The lifecycle event name
--- @param args table Table containing information relevant to the lifecycle event
local function device_info_changed(driver, device, event, args)
  if args.old_st_store.preferences.ledColor ~= device.preferences.ledColor then
    device:send(write_client_manufacturer_specific_attribute(device, OnOff.ID, BUTTON_LED_COLOR, MFG_CODE,
        data_types.Enum8,
        tonumber(device.preferences.ledColor)))
  end
  if args.old_st_store.preferences.buttonDelay ~= device.preferences.buttonDelay then
    device:send(write_client_manufacturer_specific_attribute(device, OnOff.ID, BUTTON_PRESS_DELAY, MFG_CODE,
        data_types.Uint16,
        device.preferences.buttonDelay))
  end
end

local frient_smart_button = {
  NAME = "Frient Smart Button",
  lifecycle_handlers = {
    infoChanged = device_info_changed,
  },
  zigbee_handlers = {
    cluster = {
    },
    attr = {
    }
  },
  capability_handlers = {
  },
  can_handle = can_handle_frient
}

return frient_smart_button

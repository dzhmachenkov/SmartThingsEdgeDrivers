local capabilities                      = require "st.capabilities"
local zcl_clusters                      = require "st.zigbee.zcl.clusters"
local log                               = require "log"

local IASZone                           = zcl_clusters.IASZone
local Basic                             = zcl_clusters.Basic

local FRIENT_DEVICE_FINGERPRINTS        = require "device_config"
local BASE_FUNCTIONS                    = require "device_base_functions"

local WATERLEAK_FIXED_ENDIAN_SW_VERSION = "040003"

--- @param opts table A table containing optional arguments that can be used to determine if something is handleable
--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
local function can_handle_frient(opts, driver, device, ...)
  for _, fingerprint in ipairs(FRIENT_DEVICE_FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model and fingerprint.subdriver == "waterleak" then
      return true
    end
  end
  return false
end

--- @param driver Driver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param zone_status st.zigbee.zcl.types.IasZoneStatus 2 byte bitmap zoneStatus attribute value of the IAS Zone cluster
--- @param zigbee_message st.zigbee.ZigbeeMessageRx the full message this report came in
local generate_event_from_zone_status = function(driver, device, zone_status, zigbee_message)
  device:emit_event_for_endpoint(
      zigbee_message.address_header.src_endpoint.value,
      (zone_status:is_alarm1_set() or zone_status:is_test_set()) and capabilities.waterSensor.water.wet() or capabilities.waterSensor.water.dry())
end

--- @param driver Driver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param zone_status st.zigbee.zcl.types.IasZoneStatus 2 byte bitmap zoneStatus attribute value of the IAS Zone cluster
--- @param zb_rx st.zigbee.ZigbeeMessageRx the full message this report came in
local function ias_zone_status_attr_handler(driver, device, zone_status, zb_rx)
  generate_event_from_zone_status(driver, device, zone_status, zb_rx)
end

--- @param driver Driver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param zb_rx st.zigbee.ZigbeeMessageRx containing zoneStatus attribute value of the IAS Zone cluster
local function ias_zone_status_change_handler(driver, device, zb_rx)
  local zone_status = zb_rx.body.zcl_body.zone_status
  generate_event_from_zone_status(driver, device, zone_status, zb_rx)
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param value st.zigbee.data_types.StringABC the value of the Attribute
--- @param zb_rx st.zigbee.ZigbeeMessageRx the full message this report came in
local function primary_sw_version_attr_handler(driver, device, value, zb_rx)
  --log.warn("Siren Primary Software Version Attribute report: 0x"..string.format("%x", zb_rx.body.zcl_body.attr_records[1].attr_id.value).."=0x"..value.value)
  local primary_sw_version = value.value:gsub('.', function(c) return string.format('%02x', string.byte(c)) end)
  log.debug("Water Leak Primary Software Version firmware: 0x" .. primary_sw_version)
  device:set_field(BASE_FUNCTIONS.PRIMARY_SW_VERSION, primary_sw_version, { persist = true })
  if (primary_sw_version < WATERLEAK_FIXED_ENDIAN_SW_VERSION) then
    log.warn("Device has reverse Siren endian firmware")
    device:set_field(BASE_FUNCTIONS.SIREN_ENDIAN, "reverse", { persist = true })
  end
end

local frient_sensor = {
  NAME = "Frient Water Leak Sensor",
  zigbee_handlers = {
    cluster = {
      [IASZone.ID] = {
        [IASZone.client.commands.ZoneStatusChangeNotification.ID] = ias_zone_status_change_handler
      }
    },
    attr = {
      [Basic.ID] = {
        [BASE_FUNCTIONS.DEVELCO_BASIC_PRIMARY_SW_VERSION_ATTR] = primary_sw_version_attr_handler,
      },
      [IASZone.ID] = {
        [IASZone.attributes.ZoneStatus.ID] = ias_zone_status_attr_handler
      }
    },
  },
  can_handle = can_handle_frient
}

return frient_sensor

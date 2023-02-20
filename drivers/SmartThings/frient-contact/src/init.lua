local capabilities               = require "st.capabilities"
local ZigbeeDriver               = require "st.zigbee"
local constants                  = require "st.zigbee.constants"
local defaults                   = require "st.zigbee.defaults"
local zcl_clusters               = require "st.zigbee.zcl.clusters"
local battery_defaults           = require "st.zigbee.defaults.battery_defaults"
local contact_sensor_defaults    = require "st.zigbee.defaults.contactSensor_defaults"
local log                        = require "log"
local util                       = require "st.utils"

local TemperatureMeasurement     = zcl_clusters.TemperatureMeasurement
local IASZone                    = zcl_clusters.IASZone
local PowerConfiguration         = zcl_clusters.PowerConfiguration

local FRIENT_DEVICE_FINGERPRINTS = require "device_config"

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param zone_status st.zigbee.zcl.types.IasZoneStatus the value of the attribute
--- @param zb_rx st.zigbee.ZigbeeMessageRx the full message this report came in
local function generate_event_from_zone_status(driver, device, zone_status, zb_rx)
  if device:supports_capability(capabilities.tamperAlert) then
    device:emit_event(zone_status:is_tamper_set() and capabilities.tamperAlert.tamper.detected() or capabilities.tamperAlert.tamper.clear())
  end
end

local function temperature_measurement_measured_value_attr_configure(device, reportable_change)
  local attribute = {
    cluster = TemperatureMeasurement.ID,
    attribute = TemperatureMeasurement.attributes.MeasuredValue.ID,
    minimum_interval = 30,
    maximum_interval = 300,
    data_type = TemperatureMeasurement.attributes.MeasuredValue.base_type,
    reportable_change = reportable_change
  }
  device:add_configured_attribute(attribute)
  device:add_monitored_attribute(attribute)
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param attr_val st.zigbee.zcl.types.IasZoneStatus the value of the attribute
--- @param zb_rx st.zigbee.ZigbeeMessageRx the full message this report came in
local function ias_zone_status_attr_handler(driver, device, attr_val, zb_rx)
  contact_sensor_defaults.ias_zone_status_attr_handler(driver, device, attr_val, zb_rx)
  generate_event_from_zone_status(driver, device, attr_val, zb_rx)
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param zb_rx st.zigbee.ZigbeeMessageRx the full message this report came in
local function ias_zone_status_change_handler(driver, device, zb_rx)
  contact_sensor_defaults.ias_zone_status_change_handler(driver, device, zb_rx)
  generate_event_from_zone_status(driver, device, zb_rx.body.zcl_body.zone_status, zb_rx)
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
local function device_init(driver, device)
  battery_defaults.build_linear_voltage_init(2.1, 3.0)(driver, device)
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param event string The lifecycle event name
--- @param args table Table containing information relevant to the lifecycle event
local function do_configure(driver, device, event, args)
  temperature_measurement_measured_value_attr_configure(device, (device.preferences.temperatureSensitivity or 1) * 100)

  device:configure()
  device:refresh()
end

local function info_changed(driver, device, event, args)
  if args.old_st_store.preferences.temperatureSensitivity ~= device.preferences.temperatureSensitivity then
    temperature_measurement_measured_value_attr_configure(device,
        (device.preferences.temperatureSensitivity or 1) * 100)

    device:configure()
    device:refresh()
  end
end

local frient_contact_driver_template = {
  NAME = "frient contact driver",
  supported_capabilities = {
    capabilities.contactSensor,
    capabilities.temperatureMeasurement,
    capabilities.battery,
    capabilities.tamperAlert,
  },
  sub_drivers = {
    require("frient-sensor"),
  },
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE,
  lifecycle_handlers = {
    init = device_init,
    doConfigure = do_configure,
    infoChanged = info_changed,
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
    }
  },
  capability_handlers = {
  }
}

defaults.register_for_default_handlers(frient_contact_driver_template,
    frient_contact_driver_template.supported_capabilities)
local frient_contact = ZigbeeDriver("zigbee-contact", frient_contact_driver_template)
frient_contact:run()

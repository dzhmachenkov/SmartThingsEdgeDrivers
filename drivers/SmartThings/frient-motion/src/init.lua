local capabilities           = require "st.capabilities"
local ZigbeeDriver           = require "st.zigbee"
local zcl_clusters           = require "st.zigbee.zcl.clusters"
local battery_defaults       = require "st.zigbee.defaults.battery_defaults"
local motion_sensor_defaults = require "st.zigbee.defaults.motionSensor_defaults"
local defaults               = require "st.zigbee.defaults"
local constants              = require "st.zigbee.constants"

local OccupancySensing       = zcl_clusters.OccupancySensing
local TemperatureMeasurement = zcl_clusters.TemperatureMeasurement
local IASZone                = zcl_clusters.IASZone

local CONFIGURATION          = {
  {
    cluster = OccupancySensing.ID,
    attribute = OccupancySensing.attributes.Occupancy.ID,
    minimum_interval = 0,
    maximum_interval = 3600,
    data_type = OccupancySensing.attributes.Occupancy.base_type
  }
}

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
--- @param occupancy st.zigbee.data_types.Uint16 the value of the attribute
--- @param zb_rx st.zigbee.ZigbeeMessageRx the full message this report came in
local function occupancy_attr_handler(driver, device, occupancy, zb_rx)
  device:emit_event(occupancy.value == 0x01 and capabilities.motionSensor.motion.active() or capabilities.motionSensor.motion.inactive())
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param zone_status st.zigbee.zcl.types.IasZoneStatus the value of the ZoneStatus
--- @param zb_rx st.zigbee.ZigbeeMessageRx the full message this report came in
local function generate_event_from_zone_status(driver, device, zone_status, zb_rx)
  device:emit_event(zone_status:is_tamper_set() and capabilities.tamperAlert.tamper.detected() or capabilities.tamperAlert.tamper.clear())
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param attr_val st.zigbee.zcl.types.IasZoneStatus the value of the attribute
--- @param zb_rx st.zigbee.ZigbeeMessageRx the full message this report came in
local function ias_zone_status_attr_handler(driver, device, attr_val, zb_rx)
  motion_sensor_defaults.ias_zone_status_attr_handler(driver, device, attr_val, zb_rx)
  generate_event_from_zone_status(driver, device, attr_val, zb_rx)
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param zb_rx st.zigbee.ZigbeeMessageRx the Zigbee message received
local function ias_zone_status_change_handler(driver, device, zb_rx)
  motion_sensor_defaults.ias_zone_status_change_handler(driver, device, zb_rx)
  generate_event_from_zone_status(driver, device, zb_rx.body.zcl_body.zone_status, zb_rx)
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
local function device_init(driver, device)
  battery_defaults.build_linear_voltage_init(2.4, 3.0)(driver, device)

  for _, attribute in ipairs(CONFIGURATION) do
    if attribute.configurable ~= false then
      device:add_configured_attribute(attribute)
    end
    if attribute.monitored ~= false then
      device:add_monitored_attribute(attribute)
    end
  end
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param event string The lifecycle event name
--- @param args table Table containing information relevant to the lifecycle event
local function do_configure(driver, device, event, args)
  temperature_measurement_measured_value_attr_configure(device, (device.preferences.temperatureSensitivity or 1) * 100)

  device:configure()
  device:refresh()

  local occupiedToUnoccupiedDelay     = device.preferences.occupiedToUnoccupiedD or 240
  local unoccupiedToOccupiedDelay     = device.preferences.unoccupiedToOccupiedD or 0
  local unoccupiedToOccupiedThreshold = device.preferences.unoccupiedToOccupiedT or 0

  for _, ep in pairs(device.zigbee_endpoints) do
    if device:supports_server_cluster(OccupancySensing.ID, ep.id) then
      device:send(OccupancySensing  .attributes.PIROccupiedToUnoccupiedDelay:write(device,
          occupiedToUnoccupiedDelay):to_endpoint(ep.id))
      device:send(OccupancySensing  .attributes.PIRUnoccupiedToOccupiedDelay:write(device,
          unoccupiedToOccupiedDelay):to_endpoint(ep.id))
      device:send(OccupancySensing      .attributes.PIRUnoccupiedToOccupiedThreshold:write(device,
          unoccupiedToOccupiedThreshold):to_endpoint(ep.id))
    end
  end

end

local function info_changed(driver, device, event, args)
  if args.old_st_store.preferences.occupiedToUnoccupiedD ~= device.preferences.occupiedToUnoccupiedD then
    for _, ep in pairs(device.zigbee_endpoints) do
      if device:supports_server_cluster(OccupancySensing.ID, ep.id) then
        device:send(OccupancySensing                 .attributes.PIROccupiedToUnoccupiedDelay:write(device,
            device.preferences.occupiedToUnoccupiedD):to_endpoint(ep.id))
      end
    end
  end
  if args.old_st_store.preferences.unoccupiedToOccupiedD ~= device.preferences.unoccupiedToOccupiedD then
    for _, ep in pairs(device.zigbee_endpoints) do
      if device:supports_server_cluster(OccupancySensing.ID, ep.id) then
        device:send(OccupancySensing                 .attributes.PIRUnoccupiedToOccupiedDelay:write(device,
            device.preferences.unoccupiedToOccupiedD):to_endpoint(ep.id))
      end
    end
  end
  if args.old_st_store.preferences.unoccupiedToOccupiedT ~= device.preferences.unoccupiedToOccupiedT then
    for _, ep in pairs(device.zigbee_endpoints) do
      if device:supports_server_cluster(OccupancySensing.ID, ep.id) then
        device:send(OccupancySensing                 .attributes.PIRUnoccupiedToOccupiedThreshold:write(device,
            device.preferences.unoccupiedToOccupiedT):to_endpoint(ep.id))
      end
    end
  end
  if args.old_st_store.preferences.temperatureSensitivity ~= device.preferences.temperatureSensitivity then
    temperature_measurement_measured_value_attr_configure(device,
        (device.preferences.temperatureSensitivity or 1) * 100)
  end
end

local frient_motion_driver = {
  NAME = "frient motion driver",
  supported_capabilities = {
    capabilities.motionSensor,
    capabilities.temperatureMeasurement,
    capabilities.illuminanceMeasurement,
    capabilities.battery,
    capabilities.tamperAlert
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
      [OccupancySensing.ID] = {
        [OccupancySensing.attributes.Occupancy.ID] = occupancy_attr_handler
      },
      [IASZone.ID] = {
        [IASZone.attributes.ZoneStatus.ID] = ias_zone_status_attr_handler
      }
    }
  },
  capability_handlers = {

  }
}

defaults.register_for_default_handlers(frient_motion_driver, frient_motion_driver.supported_capabilities)
local frient_motion = ZigbeeDriver("zigbee-motion", frient_motion_driver)
frient_motion:run()

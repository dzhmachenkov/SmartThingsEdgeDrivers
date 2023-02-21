local capabilities                       = require "st.capabilities"
local zcl_clusters                       = require "st.zigbee.zcl.clusters"
local log                                = require "log"

local DeviceTemperatureConfiguration     = zcl_clusters.DeviceTemperatureConfiguration
local ElectricalMeasurement              = zcl_clusters.ElectricalMeasurement
local Alarms                             = zcl_clusters.Alarms
local SimpleMetering                     = zcl_clusters.SimpleMetering

local FRIENT_DEVICE_FINGERPRINTS         = require "device_config"

local VOLTAGE_MEASUREMENT_MULTIPLIER_KEY = "__voltage_measurement_multiplier"
local VOLTAGE_MEASUREMENT_DIVISOR_KEY    = "__voltage_measurement_divisor"
local CURRENT_MEASUREMENT_MULTIPLIER_KEY = "__current_measurement_multiplier"
local CURRENT_MEASUREMENT_DIVISOR_KEY    = "__current_measurement_divisor"
local POWER_FAILURE_ALARM_CODE           = 0x03

local CONFIGURATION                      = {
  {
    cluster = zcl_clusters.ElectricalMeasurement.ID,
    attribute = zcl_clusters.ElectricalMeasurement.attributes.RMSVoltage.ID,
    minimum_interval = 60,
    maximum_interval = 3600,
    data_type = zcl_clusters.ElectricalMeasurement.attributes.RMSVoltage.base_type,
    reportable_change = 100
  },
  {
    cluster = zcl_clusters.ElectricalMeasurement.ID,
    attribute = zcl_clusters.ElectricalMeasurement.attributes.RMSCurrent.ID,
    minimum_interval = 30,
    maximum_interval = 3600,
    data_type = zcl_clusters.ElectricalMeasurement.attributes.RMSCurrent.base_type,
    reportable_change = 16
  },
  {
    cluster = zcl_clusters.DeviceTemperatureConfiguration.ID,
    attribute = zcl_clusters.DeviceTemperatureConfiguration.attributes.CurrentTemperature.ID,
    minimum_interval = 60,
    maximum_interval = 3600,
    data_type = zcl_clusters.DeviceTemperatureConfiguration.attributes.CurrentTemperature.base_type,
    reportable_change = 16
  }
}

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param zb_rx st.zigbee.ZigbeeMessageRx the Zigbee message received
local function alarms_alarm_handler(driver, device, zb_rx)
  local alarm_status = zb_rx.body.zcl_body
  if ((alarm_status.cluster_identifier.value == SimpleMetering.ID) and (alarm_status.alarm_code.value == POWER_FAILURE_ALARM_CODE)) then
    device:emit_event(capabilities.powerSource.powerSource.unknown())
  end
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param value st.zigbee.data_types.Uint16 the value of the CurrentTemperature
--- @param zb_rx st.zigbee.ZigbeeMessageRx the full message this report came in
local function device_temperature_configuration_current_temperature_attr_handler(driver, device, value, zb_rx)
  local raw_value = value.value
  device:emit_event(capabilities.temperatureMeasurement.temperature({ value = raw_value, unit = "C" }))
  device:emit_event(capabilities.powerSource.powerSource.mains()) -- We're back online, reset the powerSource
end

local function electrical_measurement_rms_voltage_attr_handler(driver, device, value, zb_rx)
  local raw_value  = value.value
  -- By default emit raw value
  local multiplier = device:get_field(VOLTAGE_MEASUREMENT_MULTIPLIER_KEY) or 1
  local divisor    = device:get_field(VOLTAGE_MEASUREMENT_DIVISOR_KEY) or 1

  if divisor == 0 then
    log.warn("Voltage scale divisor is 0; using 1 to avoid division by zero")
    divisor = 1
  end

  raw_value  = raw_value * multiplier / divisor

  local mult = 10 ^ 1 -- Round off to 1 decimal place
  raw_value  = math.floor(raw_value * mult + 0.5) / mult

  device:emit_event(capabilities.voltageMeasurement.voltage({ value = raw_value, unit = "V" }))
end

local function electrical_measurement_ac_voltage_divisor_attr_handler(driver, device, divisor, zb_rx)
  local raw_value = divisor.value
  device:set_field(VOLTAGE_MEASUREMENT_DIVISOR_KEY, raw_value, { persist = true })
end

local function electrical_measurement_ac_voltage_multiplier_attr_handler(driver, device, multiplier, zb_rx)
  local raw_value = multiplier.value
  device:set_field(VOLTAGE_MEASUREMENT_MULTIPLIER_KEY, raw_value, { persist = true })
end

local function electrical_measurement_ac_current_divisor_attr_handler(driver, device, divisor, zb_rx)
  local raw_value = divisor.value
  device:set_field(CURRENT_MEASUREMENT_DIVISOR_KEY, raw_value, { persist = true })
end

local function electrical_measurement_ac_current_multiplier_attr_handler(driver, device, multiplier, zb_rx)
  local raw_value = multiplier.value
  device:set_field(CURRENT_MEASUREMENT_MULTIPLIER_KEY, raw_value, { persist = true })
end

local function electrical_measurement_rms_current_attr__handler(driver, device, value, zb_rx)
  local raw_value  = value.value
  -- By default emit raw value
  local multiplier = device:get_field(CURRENT_MEASUREMENT_MULTIPLIER_KEY) or 1
  local divisor    = device:get_field(CURRENT_MEASUREMENT_DIVISOR_KEY) or 1

  if divisor == 0 then
    log.warn("Current scale divisor is 0; using 1 to avoid division by zero")
    divisor = 1
  end

  raw_value  = raw_value * multiplier / divisor

  local mult = 10 ^ 3 -- Round off to 3 decimal places
  raw_value  = math.floor(raw_value * mult + 0.5) / mult

  device:emit_event(capabilities.currentMeasurement.current({ value = raw_value, unit = "A" }))
end

local function device_temperature_configuration_current_temperature_attr_configure(device, reportable_change)
  local attribute = {
    zcl_clusters.DeviceTemperatureConfiguration.ID,
    attribute = zcl_clusters.DeviceTemperatureConfiguration.attributes.CurrentTemperature.ID,
    minimum_interval = 60,
    maximum_interval = 3600,
    data_type = zcl_clusters.DeviceTemperatureConfiguration.attributes.CurrentTemperature.base_type,
    reportable_change = math.floor((reportable_change or 1) * 100 + 0.5)
  }
  device:add_configured_attribute(attribute)
  device:add_monitored_attribute(attribute)
end

--- @param opts table A table containing optional arguments that can be used to determine if something is handleable
--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
local function can_handle_frient(opts, driver, device, ...)
  for _, fingerprint in ipairs(FRIENT_DEVICE_FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model and fingerprint.subdriver == "miniplug" then
      return true
    end
  end
  return false
end

--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
local function device_init(driver, device)
  local configuration = CONFIGURATION

  for _, attribute in ipairs(configuration) do
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
local function do_configure(self, device, event, args)
  device_temperature_configuration_current_temperature_attr_configure(device, device.preferences.temperatureSensitivity)

  self.lifecycle_handlers.doConfigure(self, device, event, args)

  if device:supports_capability(capabilities.voltageMeasurement) then
    device:send(ElectricalMeasurement.attributes.ACVoltageDivisor:read(device))
    device:send(ElectricalMeasurement.attributes.ACVoltageMultiplier:read(device))
  end

  if device:supports_capability(capabilities.currentMeasurement) then
    device:send(ElectricalMeasurement.attributes.ACCurrentDivisor:read(device))
    device:send(ElectricalMeasurement.attributes.ACCurrentMultiplier:read(device))
  end

  device:emit_event(capabilities.powerSource.powerSource.mains())
end

local function info_changed(self, device, event, args)
  if args.old_st_store.preferences.temperatureSensitivity ~= device.preferences.temperatureSensitivity then
    device_temperature_configuration_current_temperature_attr_configure(device,
        device.preferences.temperatureSensitivity)
    device:configure()
  end
end

local frient_switch = {
  NAME = "Frient Mini Plug",
  lifecycle_handlers = {
    init = device_init,
    doConfigure = do_configure,
    infoChanged = info_changed
  },
  zigbee_handlers = {
    cluster = {
      [Alarms.ID] = {
        [Alarms.client.commands.Alarm.ID] = alarms_alarm_handler
      }
    },
    attr = {
      [DeviceTemperatureConfiguration.ID] = {
        [DeviceTemperatureConfiguration.attributes.CurrentTemperature.ID] = device_temperature_configuration_current_temperature_attr_handler,
      },
      [ElectricalMeasurement.ID] = {
        [ElectricalMeasurement.attributes.RMSVoltage.ID] = electrical_measurement_rms_voltage_attr_handler,
        [ElectricalMeasurement.attributes.ACVoltageDivisor.ID] = electrical_measurement_ac_voltage_divisor_attr_handler,
        [ElectricalMeasurement.attributes.ACVoltageMultiplier.ID] = electrical_measurement_ac_voltage_multiplier_attr_handler,
        [ElectricalMeasurement.attributes.RMSCurrent.ID] = electrical_measurement_rms_current_attr__handler,
        [ElectricalMeasurement.attributes.ACCurrentDivisor.ID] = electrical_measurement_ac_current_divisor_attr_handler,
        [ElectricalMeasurement.attributes.ACCurrentMultiplier.ID] = electrical_measurement_ac_current_multiplier_attr_handler
      }
    }
  },
  can_handle = can_handle_frient
}

return frient_switch

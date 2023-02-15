-- Copyright 2022 SmartThings
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
local log                        = require "log"
local st_utils                   = require "st.utils"

--Capability
local capabilities               = require "st.capabilities"
local alarm                      = capabilities.alarm

--Clusters
local clusters                   = require "st.zigbee.zcl.clusters"
local TemperatureMeasurement     = clusters.TemperatureMeasurement
local IASWD                      = clusters.IASWD
local SirenConfiguration         = IASWD.types.SirenConfiguration
local WarningMode                = IASWD.types.WarningMode
local Strobe                     = IASWD.types.Strobe
local IaswdLevel                 = IASWD.types.IaswdLevel

local Status                     = require "st.zigbee.generated.types.ZclStatus"
local device_management          = require "st.zigbee.device_management"
local zcl_global_commands        = require "st.zigbee.zcl.global_commands"
local data_types                 = require "st.zigbee.data_types"
local battery_defaults           = require "st.zigbee.defaults.battery_defaults"

local battery_init               = battery_defaults.build_linear_voltage_init(2.3, 3.0)

--Constants
local ALARM_DEFAULT_MAX_DURATION = 0xF0
local ALARM_LAST_DURATION        = "__last_duration"
local ALARM_COMMAND              = "__alarm_cmd"
local ALARM_STROBE_DUTY_CYCLE    = 40

local FINGERPRINTS               = {
  { mfr = "frient A/S", model = "SMSZB-120" }
}

local function can_handle(opts, driver, device)
  for _, fingerprint in ipairs(FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
      return true
    end
  end
  return false
end

local function emit_alarm_event(device, cmd)
  if cmd == alarm.commands.off.NAME then
    device:emit_event(capabilities.alarm.alarm.off())
  else
    if cmd == alarm.commands.siren.NAME then
      device:emit_event(capabilities.alarm.alarm.siren())
    elseif cmd == alarm.commands.strobe.NAME then
      device:emit_event(capabilities.alarm.alarm.strobe())
    else
      device:emit_event(capabilities.alarm.alarm.both())
    end
  end
end

local function send_siren_command(device, warning_mode, warning_siren_level, strobe_active, strobe_level)
  local max_duration     = device.preferences.warningDuration
  local warning_duration = max_duration and max_duration or ALARM_DEFAULT_MAX_DURATION
  local duty_cycle       = ALARM_STROBE_DUTY_CYCLE

  device:set_field(ALARM_LAST_DURATION, warning_duration, { persist = true })

  local siren_configuration = SirenConfiguration(0x00)

  siren_configuration:set_warning_mode(warning_mode)
  siren_configuration:set_strobe(strobe_active)
  siren_configuration:set_siren_level(warning_siren_level)

  device:send(
      IASWD.server.commands.StartWarning(
          device,
          siren_configuration,
          data_types.Uint16(warning_duration),
          data_types.Uint8(duty_cycle),
          data_types.Enum8(strobe_level)
      )
  )
end

local function temperature_measurement_measured_value_attr_config(device, reportable_change)
  local attribute = {
    cluster = TemperatureMeasurement.ID,
    attribute = TemperatureMeasurement.attributes.MeasuredValue.ID,
    minimum_interval = 30,
    maximum_interval = 300,
    data_type = TemperatureMeasurement.attributes.MeasuredValue.base_type,
    reportable_change = device.preferences.temperatureSensitivity * 100
  }
  device:add_configured_attribute(attribute)
  device:add_monitored_attribute(attribute)

  for _, ep in pairs(device.zigbee_endpoints) do
    if device:supports_server_cluster(attribute.cluster, ep.id) then
      device:send(device_management.build_bind_request(device, attribute.cluster, device.driver.environment_info.hub_zigbee_eui, ep.id):to_endpoint(ep.id))
      device:send(device_management.attr_config(device, attribute):to_endpoint(ep.id))
    end
  end
end

local function device_added(self, device, event, args)
  device:emit_event(alarm.alarm.off())
end

local function device_init(self, device, event, args)
  battery_init(self, device, event, args)
end

local function device_do_configure(self, device, event, args)
  device:send(IASWD.attributes.MaxDuration:write(device, device.preferences.warningDuration or ALARM_DEFAULT_MAX_DURATION))

  temperature_measurement_measured_value_attr_config(device, device.preferences.temperatureSensitivity)

  device:configure()
  device:refresh()
end

local function device_info_changed(self, device, event, args)
  if args.old_st_store.preferences.warningDuration ~= device.preferences.warningDuration then
    device:send(IASWD.attributes.MaxDuration:write(device, device.preferences.warningDuration or ALARM_DEFAULT_MAX_DURATION))
  end
  if args.old_st_store.preferences.temperatureSensitivity ~= device.preferences.temperatureSensitivity then
    temperature_measurement_measured_value_attr_config(device, device.preferences.temperatureSensitivity)
  end
end

local function default_response_handler(driver, device, zigbee_message)
  local is_success = zigbee_message.body.zcl_body.status.value
  local command    = zigbee_message.body.zcl_body.cmd.value
  local alarm_ev   = device:get_field(ALARM_COMMAND)

  if command == IASWD.server.commands.StartWarning.ID and is_success == Status.SUCCESS then
    if alarm_ev ~= alarm.commands.off.NAME then
      emit_alarm_event(device, alarm_ev)
      local lastDuration = device:get_field(ALARM_LAST_DURATION) or ALARM_DEFAULT_MAX_DURATION
      device.thread:call_with_delay(lastDuration, function(d)
        device:emit_event(capabilities.alarm.alarm.off())
      end)
    else
      emit_alarm_event(device, alarm.commands.off.NAME)
    end
  end
end

local function siren_switch_off_handler(driver, device, command)
  device:set_field(ALARM_COMMAND, command.command, { persist = true })
  send_siren_command(device, WarningMode.STOP, IaswdLevel.LOW_LEVEL, Strobe.NO_STROBE, IaswdLevel.LOW_LEVEL)
end

local function siren_alarm_siren_handler(driver, device, command)
  device:set_field(ALARM_COMMAND, command.command, { persist = true })
  send_siren_command(device, WarningMode.BURGLAR, IaswdLevel.VERY_HIGH_LEVEL, Strobe.NO_STROBE, IaswdLevel.LOW_LEVEL)
end

local frient_smoke_detector = {
  NAME = "Freint Smoke Detector",
  lifecycle_handlers = {
    added = device_added,
    init = device_init,
    doConfigure = device_do_configure,
    infoChanged = device_info_changed
  },
  zigbee_handlers = {
    global = {
      [IASWD.ID] = {
        [zcl_global_commands.DEFAULT_RESPONSE_ID] = default_response_handler
      }
    }
  },
  capability_handlers = {
    [alarm.ID] = {
      [alarm.commands.off.NAME] = siren_switch_off_handler,
      [alarm.commands.siren.NAME] = siren_alarm_siren_handler
    }
  },
  can_handle = can_handle
}

return frient_smoke_detector

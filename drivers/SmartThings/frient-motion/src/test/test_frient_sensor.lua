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

-- Mock out globals
local test                   = require "integration_test"
local clusters               = require "st.zigbee.zcl.clusters"
local IASZone                = clusters.IASZone
local PowerConfiguration     = clusters.PowerConfiguration
local TemperatureMeasurement = clusters.TemperatureMeasurement
local IlluminanceMeasurement = clusters.IlluminanceMeasurement
local OccupancySensing       = clusters.OccupancySensing
local OccupancyAttribute     = clusters.OccupancySensing.attributes.Occupancy
local capabilities           = require "st.capabilities"
local zigbee_test_utils      = require "integration_test.zigbee_test_utils"
local IasEnrollResponseCode  = require "st.zigbee.generated.zcl_clusters.IASZone.types.EnrollResponseCode"
local t_utils                = require "integration_test.utils"

local mock_device1 = test.mock_device.build_test_zigbee_device(
    {
      profile = t_utils.get_profile_definition("motion-temp-illuminance-tamper-battery.yml"),
      fingerprinted_endpoint_id = 0x01,
      zigbee_endpoints = {
        [0x01] = {
          id = 0x01,
          manufacturer = "frient A/S",
          model = "MOSZB-140",
          server_clusters = { 0x0003, 0x0005, 0x0006 }
        },
        [0x22] = {
          id = 0x22,
          server_clusters = { 0x0000, 0x0003, 0x0406 }
        },
        [0x23] = {
          id = 0x23,
          server_clusters = { 0x0000, 0x0001, 0x0003, 0x000f, 0x0020, 0x0500 }
        },
        [0x26] = {
          id = 0x26,
          server_clusters = { 0x0000, 0x0003, 0x0402 }
        },
        [0x27] = {
          id = 0x27,
          server_clusters = { 0x0000, 0x0003, 0x0400 }
        },
        [0x28] = {
          id = 0x28,
          server_clusters = { 0x0000, 0x0003, 0x0406 }
        },
        [0x29] = {
          id = 0x29,
          server_clusters = { 0x0000, 0x0003, 0x0406 }
        }
      }
    }
)

local mock_device2           = test.mock_device.build_test_zigbee_device(
    {
      profile = t_utils.get_profile_definition("motion-battery.yml"),
      fingerprinted_endpoint_id = 0x01,
      zigbee_endpoints = {
        [0x01] = {
          id = 0x01,
          manufacturer = "frient A/S",
          model = "MOSZB-141",
          server_clusters = { 0x0003, 0x0005, 0x0006 }
        },
        [0x22] = {
          id = 0x22,
          server_clusters = { 0x0000, 0x0003, 0x0406 }
        },
        [0x23] = {
          id = 0x23,
          server_clusters = { 0x0000, 0x0001, 0x0003, 0x000f, 0x0020, 0x0500 }
        },
        [0x28] = {
          id = 0x28,
          server_clusters = { 0x0000, 0x0003, 0x0406 }
        },
        [0x29] = {
          id = 0x29,
          server_clusters = { 0x0000, 0x0003, 0x0406 }
        }
      }
    }
)

local mock_device3 = test.mock_device.build_test_zigbee_device(
    {
      profile = t_utils.get_profile_definition("motion-temp-illuminance-battery.yml"),
      fingerprinted_endpoint_id = 0x01,
      zigbee_endpoints = {
        [0x01] = {
          id = 0x01,
          manufacturer = "frient A/S",
          model = "MOSZB-153",
          server_clusters = { 0x0003, 0x0005, 0x0006 }
        },
        [0x22] = {
          id = 0x22,
          server_clusters = { 0x0000, 0x0003, 0x0406 }
        },
        [0x23] = {
          id = 0x23,
          server_clusters = { 0x0000, 0x0001, 0x0003, 0x000f, 0x0020, 0x0500 }
        },
        [0x26] = {
          id = 0x26,
          server_clusters = { 0x0000, 0x0003, 0x0402 }
        },
        [0x27] = {
          id = 0x27,
          server_clusters = { 0x0000, 0x0003, 0x0400 }
        },
        [0x28] = {
          id = 0x28,
          server_clusters = { 0x0000, 0x0003, 0x0406 }
        },
        [0x29] = {
          id = 0x29,
          server_clusters = { 0x0000, 0x0003, 0x0406 }
        }
      }
    }
)

zigbee_test_utils.prepare_zigbee_env_info()
local function test_init()
  test.mock_device.add_test_device(mock_device1)
  test.mock_device.add_test_device(mock_device2)
  test.mock_device.add_test_device(mock_device3)
  zigbee_test_utils.init_noop_health_check_timer()
end
test.set_test_init_function(test_init)

test.register_coroutine_test(
    "[MOSZB-140] Configure should configure all necessary attributes",
    function()
      test.wait_for_events()
      test.socket.device_lifecycle:__queue_receive({ mock_device1.id, "init" })
      test.socket.device_lifecycle:__queue_receive({ mock_device1.id, "doConfigure" })
      test.socket.zigbee:__set_channel_ordering("relaxed")

      test.socket.zigbee:__expect_send({
        mock_device1.id,
        zigbee_test_utils.build_bind_request(mock_device1, zigbee_test_utils.mock_hub_eui, IlluminanceMeasurement.ID,
            0x27)        :to_endpoint(0x27)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        IlluminanceMeasurement.attributes.MeasuredValue:configure_reporting(mock_device1, 1, 3600, 1)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        IlluminanceMeasurement.attributes.MeasuredValue:read(mock_device1)
      })

      test.socket.zigbee:__expect_send({
        mock_device1.id,
        zigbee_test_utils.build_bind_request(mock_device1, zigbee_test_utils.mock_hub_eui, PowerConfiguration.ID,
            0x23)        :to_endpoint(0x23)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        PowerConfiguration.attributes.BatteryVoltage:configure_reporting(mock_device1, 30, 21600, 1)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        PowerConfiguration.attributes.BatteryVoltage:read(mock_device1)
      })

      test.socket.zigbee:__expect_send({
        mock_device1.id,
        zigbee_test_utils.build_bind_request(mock_device1, zigbee_test_utils.mock_hub_eui, TemperatureMeasurement.ID,
            0x26)        :to_endpoint(0x26)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        TemperatureMeasurement.attributes.MeasuredValue:configure_reporting(mock_device1, 30, 300, 100)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        TemperatureMeasurement.attributes.MeasuredValue:read(mock_device1)
      })

      test.socket.zigbee:__expect_send({
        mock_device1.id,
        zigbee_test_utils.build_bind_request(mock_device1, zigbee_test_utils.mock_hub_eui, IASZone.ID,
            0x23)        :to_endpoint(0x23)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        IASZone.attributes.ZoneStatus:configure_reporting(mock_device1, 30, 300, 0)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        IASZone.attributes.ZoneStatus:read(mock_device1)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        IASZone.attributes.IASCIEAddress:write(mock_device1, zigbee_test_utils.mock_hub_eui)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        IASZone.server.commands.ZoneEnrollResponse(mock_device1, IasEnrollResponseCode.SUCCESS, 0x00)
      })

      test.socket.zigbee:__expect_send({
        mock_device1.id,
        zigbee_test_utils.build_bind_request(mock_device1, zigbee_test_utils.mock_hub_eui, OccupancySensing.ID,
            0x28)        :to_endpoint(0x28)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        OccupancySensing.attributes.Occupancy:configure_reporting(mock_device1, 0, 3600, 0):to_endpoint(0x28)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        OccupancySensing.attributes.Occupancy:read(mock_device1):to_endpoint(0x28)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        OccupancySensing.attributes.PIROccupiedToUnoccupiedDelay:write(mock_device1, 0x00f0):to_endpoint(0x28)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        OccupancySensing.attributes.PIRUnoccupiedToOccupiedDelay:write(mock_device1, 0):to_endpoint(0x28)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        OccupancySensing.attributes.PIRUnoccupiedToOccupiedThreshold:write(mock_device1, 0x01):to_endpoint(0x28)
      })

      test.socket.zigbee:__expect_send({
        mock_device1.id,
        zigbee_test_utils.build_bind_request(mock_device1, zigbee_test_utils.mock_hub_eui, OccupancySensing.ID,
            0x29)        :to_endpoint(0x29)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        OccupancySensing.attributes.Occupancy:configure_reporting(mock_device1, 0, 3600, 0):to_endpoint(0x29)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        OccupancySensing.attributes.Occupancy:read(mock_device1):to_endpoint(0x29)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        OccupancySensing.attributes.PIROccupiedToUnoccupiedDelay:write(mock_device1, 0x00f0):to_endpoint(0x29)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        OccupancySensing.attributes.PIRUnoccupiedToOccupiedDelay:write(mock_device1, 0):to_endpoint(0x29)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        OccupancySensing.attributes.PIRUnoccupiedToOccupiedThreshold:write(mock_device1, 0x01):to_endpoint(0x29)
      })

      test.socket.zigbee:__expect_send({
        mock_device1.id,
        zigbee_test_utils.build_bind_request(mock_device1, zigbee_test_utils.mock_hub_eui, OccupancySensing.ID,
            0x22)        :to_endpoint(0x22)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        OccupancySensing.attributes.Occupancy:configure_reporting(mock_device1, 0, 3600, 0):to_endpoint(0x22)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        OccupancySensing.attributes.Occupancy:read(mock_device1):to_endpoint(0x22)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        OccupancySensing.attributes.PIROccupiedToUnoccupiedDelay:write(mock_device1, 0x00f0):to_endpoint(0x22)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        OccupancySensing.attributes.PIRUnoccupiedToOccupiedDelay:write(mock_device1, 0):to_endpoint(0x22)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        OccupancySensing.attributes.PIRUnoccupiedToOccupiedThreshold:write(mock_device1, 0x01):to_endpoint(0x22)
      })

      mock_device1:expect_metadata_update({ provisioning_state = "PROVISIONED" })
    end
)

test.register_message_test(
    "[MOSZB-140] Reported motion should be handled: active",
    {
      {
        channel = "zigbee",
        direction = "receive",
        message = { mock_device1.id, OccupancyAttribute:build_test_attr_report(mock_device1, 0x01) }
      },
      {
        channel = "capability",
        direction = "send",
        message = mock_device1:generate_test_message("main", capabilities.motionSensor.motion.active())
      }
    }
)

test.register_message_test(
    "[MOSZB-140] Reported motion should be handled: inactive",
    {
      {
        channel = "zigbee",
        direction = "receive",
        message = { mock_device1.id, OccupancyAttribute:build_test_attr_report(mock_device1, 0x00) }
      },
      {
        channel = "capability",
        direction = "send",
        message = mock_device1:generate_test_message("main", capabilities.motionSensor.motion.inactive())
      }
    }
)

----------------------------------

test.register_coroutine_test(
    "[MOSZB-141] Configure should configure all necessary attributes",
    function()
      test.wait_for_events()
      test.socket.device_lifecycle:__queue_receive({ mock_device2.id, "init" })
      test.socket.device_lifecycle:__queue_receive({ mock_device2.id, "doConfigure" })
      test.socket.zigbee:__set_channel_ordering("relaxed")

      test.socket.zigbee:__expect_send({
        mock_device2.id,
        zigbee_test_utils.build_bind_request(mock_device2, zigbee_test_utils.mock_hub_eui, PowerConfiguration.ID,
            0x23)        :to_endpoint(0x23)
      })
      test.socket.zigbee:__expect_send({
        mock_device2.id,
        PowerConfiguration.attributes.BatteryVoltage:configure_reporting(mock_device2, 30, 21600, 1)
      })
      test.socket.zigbee:__expect_send({
        mock_device2.id,
        PowerConfiguration.attributes.BatteryVoltage:read(mock_device2)
      })

      test.socket.zigbee:__expect_send({
        mock_device2.id,
        zigbee_test_utils.build_bind_request(mock_device2, zigbee_test_utils.mock_hub_eui, IASZone.ID,
            0x23)        :to_endpoint(0x23)
      })
      test.socket.zigbee:__expect_send({
        mock_device2.id,
        IASZone.attributes.ZoneStatus:configure_reporting(mock_device2, 30, 300, 0)
      })
      test.socket.zigbee:__expect_send({
        mock_device2.id,
        IASZone.attributes.ZoneStatus:read(mock_device2)
      })
      test.socket.zigbee:__expect_send({
        mock_device2.id,
        IASZone.attributes.IASCIEAddress:write(mock_device2, zigbee_test_utils.mock_hub_eui)
      })
      test.socket.zigbee:__expect_send({
        mock_device2.id,
        IASZone.server.commands.ZoneEnrollResponse(mock_device2, IasEnrollResponseCode.SUCCESS, 0x00)
      })

      test.socket.zigbee:__expect_send({
        mock_device2.id,
        zigbee_test_utils.build_bind_request(mock_device2, zigbee_test_utils.mock_hub_eui, OccupancySensing.ID,
            0x28)        :to_endpoint(0x28)
      })
      test.socket.zigbee:__expect_send({
        mock_device2.id,
        OccupancySensing.attributes.Occupancy:configure_reporting(mock_device2, 0, 3600, 0):to_endpoint(0x28)
      })
      test.socket.zigbee:__expect_send({
        mock_device2.id,
        OccupancySensing.attributes.Occupancy:read(mock_device2):to_endpoint(0x28)
      })
      test.socket.zigbee:__expect_send({
        mock_device2.id,
        OccupancySensing.attributes.PIROccupiedToUnoccupiedDelay:write(mock_device2, 0x00f0):to_endpoint(0x28)
      })
      test.socket.zigbee:__expect_send({
        mock_device2.id,
        OccupancySensing.attributes.PIRUnoccupiedToOccupiedDelay:write(mock_device2, 0):to_endpoint(0x28)
      })
      test.socket.zigbee:__expect_send({
        mock_device2.id,
        OccupancySensing.attributes.PIRUnoccupiedToOccupiedThreshold:write(mock_device2, 0x01):to_endpoint(0x28)
      })

      test.socket.zigbee:__expect_send({
        mock_device2.id,
        zigbee_test_utils.build_bind_request(mock_device2, zigbee_test_utils.mock_hub_eui, OccupancySensing.ID,
            0x29)        :to_endpoint(0x29)
      })
      test.socket.zigbee:__expect_send({
        mock_device2.id,
        OccupancySensing.attributes.Occupancy:configure_reporting(mock_device2, 0, 3600, 0):to_endpoint(0x29)
      })
      test.socket.zigbee:__expect_send({
        mock_device2.id,
        OccupancySensing.attributes.Occupancy:read(mock_device2):to_endpoint(0x29)
      })
      test.socket.zigbee:__expect_send({
        mock_device2.id,
        OccupancySensing.attributes.PIROccupiedToUnoccupiedDelay:write(mock_device2, 0x00f0):to_endpoint(0x29)
      })
      test.socket.zigbee:__expect_send({
        mock_device2.id,
        OccupancySensing.attributes.PIRUnoccupiedToOccupiedDelay:write(mock_device2, 0):to_endpoint(0x29)
      })
      test.socket.zigbee:__expect_send({
        mock_device2.id,
        OccupancySensing.attributes.PIRUnoccupiedToOccupiedThreshold:write(mock_device2, 0x01):to_endpoint(0x29)
      })

      test.socket.zigbee:__expect_send({
        mock_device2.id,
        zigbee_test_utils.build_bind_request(mock_device2, zigbee_test_utils.mock_hub_eui, OccupancySensing.ID,
            0x22)        :to_endpoint(0x22)
      })
      test.socket.zigbee:__expect_send({
        mock_device2.id,
        OccupancySensing.attributes.Occupancy:configure_reporting(mock_device2, 0, 3600, 0):to_endpoint(0x22)
      })
      test.socket.zigbee:__expect_send({
        mock_device2.id,
        OccupancySensing.attributes.Occupancy:read(mock_device2):to_endpoint(0x22)
      })
      test.socket.zigbee:__expect_send({
        mock_device2.id,
        OccupancySensing.attributes.PIROccupiedToUnoccupiedDelay:write(mock_device2, 0x00f0):to_endpoint(0x22)
      })
      test.socket.zigbee:__expect_send({
        mock_device2.id,
        OccupancySensing.attributes.PIRUnoccupiedToOccupiedDelay:write(mock_device2, 0):to_endpoint(0x22)
      })
      test.socket.zigbee:__expect_send({
        mock_device2.id,
        OccupancySensing.attributes.PIRUnoccupiedToOccupiedThreshold:write(mock_device2, 0x01):to_endpoint(0x22)
      })

      mock_device2:expect_metadata_update({ provisioning_state = "PROVISIONED" })
    end
)

test.register_message_test(
    "[MOSZB-141] Reported motion should be handled: active",
    {
      {
        channel = "zigbee",
        direction = "receive",
        message = { mock_device2.id, OccupancyAttribute:build_test_attr_report(mock_device2, 0x01) }
      },
      {
        channel = "capability",
        direction = "send",
        message = mock_device2:generate_test_message("main", capabilities.motionSensor.motion.active())
      }
    }
)

test.register_message_test(
    "[MOSZB-141] Reported motion should be handled: inactive",
    {
      {
        channel = "zigbee",
        direction = "receive",
        message = { mock_device2.id, OccupancyAttribute:build_test_attr_report(mock_device2, 0x00) }
      },
      {
        channel = "capability",
        direction = "send",
        message = mock_device2:generate_test_message("main", capabilities.motionSensor.motion.inactive())
      }
    }
)


--------------------------------

test.register_coroutine_test(
    "[MOSZB-153] Configure should configure all necessary attributes",
    function()
      test.wait_for_events()
      test.socket.device_lifecycle:__queue_receive({ mock_device3.id, "init" })
      test.socket.device_lifecycle:__queue_receive({ mock_device3.id, "doConfigure" })
      test.socket.zigbee:__set_channel_ordering("relaxed")

      test.socket.zigbee:__expect_send({
        mock_device3.id,
        zigbee_test_utils.build_bind_request(mock_device3, zigbee_test_utils.mock_hub_eui, IlluminanceMeasurement.ID,
            0x27)        :to_endpoint(0x27)
      })
      test.socket.zigbee:__expect_send({
        mock_device3.id,
        IlluminanceMeasurement.attributes.MeasuredValue:configure_reporting(mock_device3, 1, 3600, 1)
      })
      test.socket.zigbee:__expect_send({
        mock_device3.id,
        IlluminanceMeasurement.attributes.MeasuredValue:read(mock_device3)
      })

      test.socket.zigbee:__expect_send({
        mock_device3.id,
        zigbee_test_utils.build_bind_request(mock_device3, zigbee_test_utils.mock_hub_eui, PowerConfiguration.ID,
            0x23)        :to_endpoint(0x23)
      })
      test.socket.zigbee:__expect_send({
        mock_device3.id,
        PowerConfiguration.attributes.BatteryVoltage:configure_reporting(mock_device3, 30, 21600, 1)
      })
      test.socket.zigbee:__expect_send({
        mock_device3.id,
        PowerConfiguration.attributes.BatteryVoltage:read(mock_device3)
      })

      test.socket.zigbee:__expect_send({
        mock_device3.id,
        zigbee_test_utils.build_bind_request(mock_device3, zigbee_test_utils.mock_hub_eui, TemperatureMeasurement.ID,
            0x26)        :to_endpoint(0x26)
      })
      test.socket.zigbee:__expect_send({
        mock_device3.id,
        TemperatureMeasurement.attributes.MeasuredValue:configure_reporting(mock_device3, 30, 300, 100)
      })
      test.socket.zigbee:__expect_send({
        mock_device3.id,
        TemperatureMeasurement.attributes.MeasuredValue:read(mock_device3)
      })

      test.socket.zigbee:__expect_send({
        mock_device3.id,
        zigbee_test_utils.build_bind_request(mock_device3, zigbee_test_utils.mock_hub_eui, IASZone.ID,
            0x23)        :to_endpoint(0x23)
      })
      test.socket.zigbee:__expect_send({
        mock_device3.id,
        IASZone.attributes.ZoneStatus:configure_reporting(mock_device3, 30, 300, 0)
      })
      test.socket.zigbee:__expect_send({
        mock_device3.id,
        IASZone.attributes.ZoneStatus:read(mock_device3)
      })
      test.socket.zigbee:__expect_send({
        mock_device3.id,
        IASZone.attributes.IASCIEAddress:write(mock_device3, zigbee_test_utils.mock_hub_eui)
      })
      test.socket.zigbee:__expect_send({
        mock_device3.id,
        IASZone.server.commands.ZoneEnrollResponse(mock_device3, IasEnrollResponseCode.SUCCESS, 0x00)
      })

      test.socket.zigbee:__expect_send({
        mock_device3.id,
        zigbee_test_utils.build_bind_request(mock_device3, zigbee_test_utils.mock_hub_eui, OccupancySensing.ID,
            0x28)        :to_endpoint(0x28)
      })
      test.socket.zigbee:__expect_send({
        mock_device3.id,
        OccupancySensing.attributes.Occupancy:configure_reporting(mock_device3, 0, 3600, 0):to_endpoint(0x28)
      })
      test.socket.zigbee:__expect_send({
        mock_device3.id,
        OccupancySensing.attributes.Occupancy:read(mock_device3):to_endpoint(0x28)
      })
      test.socket.zigbee:__expect_send({
        mock_device3.id,
        OccupancySensing.attributes.PIROccupiedToUnoccupiedDelay:write(mock_device3, 0x00f0):to_endpoint(0x28)
      })
      test.socket.zigbee:__expect_send({
        mock_device3.id,
        OccupancySensing.attributes.PIRUnoccupiedToOccupiedDelay:write(mock_device3, 0):to_endpoint(0x28)
      })
      test.socket.zigbee:__expect_send({
        mock_device3.id,
        OccupancySensing.attributes.PIRUnoccupiedToOccupiedThreshold:write(mock_device3, 0x01):to_endpoint(0x28)
      })

      test.socket.zigbee:__expect_send({
        mock_device3.id,
        zigbee_test_utils.build_bind_request(mock_device3, zigbee_test_utils.mock_hub_eui, OccupancySensing.ID,
            0x29)        :to_endpoint(0x29)
      })
      test.socket.zigbee:__expect_send({
        mock_device3.id,
        OccupancySensing.attributes.Occupancy:configure_reporting(mock_device3, 0, 3600, 0):to_endpoint(0x29)
      })
      test.socket.zigbee:__expect_send({
        mock_device3.id,
        OccupancySensing.attributes.Occupancy:read(mock_device3):to_endpoint(0x29)
      })
      test.socket.zigbee:__expect_send({
        mock_device3.id,
        OccupancySensing.attributes.PIROccupiedToUnoccupiedDelay:write(mock_device3, 0x00f0):to_endpoint(0x29)
      })
      test.socket.zigbee:__expect_send({
        mock_device3.id,
        OccupancySensing.attributes.PIRUnoccupiedToOccupiedDelay:write(mock_device3, 0):to_endpoint(0x29)
      })
      test.socket.zigbee:__expect_send({
        mock_device3.id,
        OccupancySensing.attributes.PIRUnoccupiedToOccupiedThreshold:write(mock_device3, 0x01):to_endpoint(0x29)
      })

      test.socket.zigbee:__expect_send({
        mock_device3.id,
        zigbee_test_utils.build_bind_request(mock_device3, zigbee_test_utils.mock_hub_eui, OccupancySensing.ID,
            0x22)        :to_endpoint(0x22)
      })
      test.socket.zigbee:__expect_send({
        mock_device3.id,
        OccupancySensing.attributes.Occupancy:configure_reporting(mock_device3, 0, 3600, 0):to_endpoint(0x22)
      })
      test.socket.zigbee:__expect_send({
        mock_device3.id,
        OccupancySensing.attributes.Occupancy:read(mock_device3):to_endpoint(0x22)
      })
      test.socket.zigbee:__expect_send({
        mock_device3.id,
        OccupancySensing.attributes.PIROccupiedToUnoccupiedDelay:write(mock_device3, 0x00f0):to_endpoint(0x22)
      })
      test.socket.zigbee:__expect_send({
        mock_device3.id,
        OccupancySensing.attributes.PIRUnoccupiedToOccupiedDelay:write(mock_device3, 0):to_endpoint(0x22)
      })
      test.socket.zigbee:__expect_send({
        mock_device3.id,
        OccupancySensing.attributes.PIRUnoccupiedToOccupiedThreshold:write(mock_device3, 0x01):to_endpoint(0x22)
      })

      mock_device3:expect_metadata_update({ provisioning_state = "PROVISIONED" })
    end
)

test.register_message_test(
    "[MOSZB-153] Reported motion should be handled: active",
    {
      {
        channel = "zigbee",
        direction = "receive",
        message = { mock_device3.id, OccupancyAttribute:build_test_attr_report(mock_device3, 0x01) }
      },
      {
        channel = "capability",
        direction = "send",
        message = mock_device3:generate_test_message("main", capabilities.motionSensor.motion.active())
      }
    }
)

test.register_message_test(
    "[MOSZB-153] Reported motion should be handled: inactive",
    {
      {
        channel = "zigbee",
        direction = "receive",
        message = { mock_device3.id, OccupancyAttribute:build_test_attr_report(mock_device3, 0x00) }
      },
      {
        channel = "capability",
        direction = "send",
        message = mock_device3:generate_test_message("main", capabilities.motionSensor.motion.inactive())
      }
    }
)

test.run_registered_tests()

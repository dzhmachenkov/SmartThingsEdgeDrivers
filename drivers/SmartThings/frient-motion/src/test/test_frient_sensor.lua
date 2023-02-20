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
local OccupancySensing       = clusters.OccupancySensing
local OccupancyAttribute     = clusters.OccupancySensing.attributes.Occupancy
local capabilities           = require "st.capabilities"
local zigbee_test_utils      = require "integration_test.zigbee_test_utils"
local IasEnrollResponseCode  = require "st.zigbee.generated.zcl_clusters.IASZone.types.EnrollResponseCode"
local t_utils                = require "integration_test.utils"

local mock_device2 = test.mock_device.build_test_zigbee_device(
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

zigbee_test_utils.prepare_zigbee_env_info()
local function test_init()
  test.mock_device.add_test_device(mock_device2)
  zigbee_test_utils.init_noop_health_check_timer()
end
test.set_test_init_function(test_init)

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

test.run_registered_tests()

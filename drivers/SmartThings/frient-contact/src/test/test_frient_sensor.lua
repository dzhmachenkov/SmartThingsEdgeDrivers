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

local test                   = require "integration_test"
local clusters               = require "st.zigbee.zcl.clusters"
local capabilities           = require "st.capabilities"
local t_utils                = require "integration_test.utils"
local zigbee_test_utils      = require "integration_test.zigbee_test_utils"

local IASZone                = clusters.IASZone
local PowerConfiguration     = clusters.PowerConfiguration
local TemperatureMeasurement = clusters.TemperatureMeasurement

local IASCIEAddress          = IASZone.attributes.IASCIEAddress
local EnrollResponseCode     = IASZone.types.EnrollResponseCode

local mock_device1           = test.mock_device.build_test_zigbee_device(
    {
      profile = t_utils.get_profile_definition("contact-temperature-battery-tamper.yml"),
      zigbee_endpoints = {
        [0x01] = {
          id = 0x01,
          manufacturer = "frient A/S",
          model = "WISZB-120",
          server_clusters = { 0x0003, 0x0005, 0x0006 }
        },
        [0x23] = {
          id = 0x23,
          server_clusters = { 0x0000, 0x0003, 0x0402 }
        },
        [0x26] = {
          id = 0x26,
          server_clusters = { 0x0000, 0x0001, 0x0003, 0x000f, 0x0020, 0x0500 }
        }
      }
    }
)

zigbee_test_utils.prepare_zigbee_env_info()

local function test_init()
  test.mock_device.add_test_device(mock_device1)
end

test.set_test_init_function(test_init)

test.register_coroutine_test(
    "Refresh necessary attributes",
    function()
      test.socket.zigbee:__set_channel_ordering("relaxed")
      test.socket.capability:__queue_receive({ mock_device1.id, { capability = "refresh", component = "main", command = "refresh", args = {} } })
      test.socket.zigbee:__expect_send({ mock_device1.id, IASZone.attributes.ZoneStatus:read(mock_device1) })
      test.socket.zigbee:__expect_send({ mock_device1.id, PowerConfiguration.attributes.BatteryVoltage:read(mock_device1) })
      test.socket.zigbee:__expect_send({ mock_device1.id, TemperatureMeasurement.attributes.MeasuredValue:read(mock_device1) })
    end
)

test.register_coroutine_test(
    "Configure should configure all necessary attributes",
    function()
      test.socket.device_lifecycle:__queue_receive({ mock_device1.id, "added" })
      test.wait_for_events()

      test.socket.zigbee:__set_channel_ordering("relaxed")
      test.socket.device_lifecycle:__queue_receive({ mock_device1.id, "doConfigure" })

      test.socket.zigbee:__expect_send({
        mock_device1.id,
        zigbee_test_utils.build_bind_request(mock_device1, zigbee_test_utils.mock_hub_eui, PowerConfiguration.ID,
            0x26)        :to_endpoint(0x26)
      })
      test.socket.zigbee:__expect_send(
          {
            mock_device1.id,
            PowerConfiguration.attributes.BatteryVoltage:configure_reporting(mock_device1, 30, 21600, 1)
          }
      )
      test.socket.zigbee:__expect_send({ mock_device1.id, PowerConfiguration.attributes.BatteryVoltage:read(mock_device1) })

      test.socket.zigbee:__expect_send({
        mock_device1.id,
        zigbee_test_utils.build_bind_request(mock_device1, zigbee_test_utils.mock_hub_eui, TemperatureMeasurement.ID,
            0x23)        :to_endpoint(0x23)
      })
      test.socket.zigbee:__expect_send(
          {
            mock_device1.id,
            TemperatureMeasurement.attributes.MeasuredValue:configure_reporting(mock_device1, 30, 300,
                100)              :to_endpoint(0x23)
          }
      )
      test.socket.zigbee:__expect_send({ mock_device1.id, TemperatureMeasurement.attributes.MeasuredValue:read(mock_device1) })

      test.socket.zigbee:__expect_send({
        mock_device1.id,
        zigbee_test_utils.build_bind_request(mock_device1, zigbee_test_utils.mock_hub_eui, IASZone.ID,
            0x26)        :to_endpoint(0x26)
      })
      test.socket.zigbee:__expect_send(
          {
            mock_device1.id,
            IASZone.attributes.ZoneStatus:configure_reporting(mock_device1, 30, 300, 1):to_endpoint(0x26)
          }
      )
      test.socket.zigbee:__expect_send({ mock_device1.id, IASCIEAddress:write(mock_device1,
          zigbee_test_utils.mock_hub_eui) })
      test.socket.zigbee:__expect_send({ mock_device1.id, IASZone.server.commands.ZoneEnrollResponse(mock_device1,
          EnrollResponseCode.SUCCESS, 0x00) })
      test.socket.zigbee:__expect_send({ mock_device1.id, IASZone.attributes.ZoneStatus:read(mock_device1) })

      mock_device1:expect_metadata_update({ provisioning_state = "PROVISIONED" })
    end
)

test.register_message_test(
    "Max battery voltage report should be handled",
    {
      {
        channel = "zigbee",
        direction = "receive",
        message = { mock_device1.id, PowerConfiguration.attributes.BatteryVoltage:build_test_attr_report(mock_device1,
            30) }
      },
      {
        channel = "capability",
        direction = "send",
        message = mock_device1:generate_test_message("main", capabilities.battery.battery(100))
      }
    }
)

test.register_message_test(
    "Min battery voltage report should be handled",
    {
      {
        channel = "zigbee",
        direction = "receive",
        message = { mock_device1.id, PowerConfiguration.attributes.BatteryVoltage:build_test_attr_report(mock_device1,
            21) }
      },
      {
        channel = "capability",
        direction = "send",
        message = mock_device1:generate_test_message("main", capabilities.battery.battery(0))
      }
    }
)

test.run_registered_tests()

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

local test                           = require "integration_test"
local t_utils                        = require "integration_test.utils"
local clusters                       = require "st.zigbee.zcl.clusters"
local zigbee_test_utils              = require "integration_test.zigbee_test_utils"

local capabilities                   = require "st.capabilities"

local OnOff                          = clusters.OnOff
local ElectricalMeasurement          = clusters.ElectricalMeasurement
local SimpleMetering                 = clusters.SimpleMetering
local DeviceTemperatureConfiguration = clusters.DeviceTemperatureConfiguration

local mock_device5 = test.mock_device.build_test_zigbee_device(
    { profile = t_utils.get_profile_definition("switch-power-energy.yml"),
      fingerprinted_endpoint_id = 0x01,
      zigbee_endpoints = {
        [0x01] = {
          id = 0x01,
          manufacturer = "frient A/S",
          model = "SPLZB-141",
          server_clusters = { 0x0005, 0x0006 }
        },
        [0x02] = {
          id = 0x02,
          server_clusters = { 0x0000, 0x0702, 0x0003, 0x0009, 0x0b04, 0x0006, 0x0004, 0x0005, 0x0002 }
        }
      }
    }
)

zigbee_test_utils.prepare_zigbee_env_info()

local function test_init()
  test.mock_device.add_test_device(mock_device5)
end

test.set_test_init_function(test_init)

test.register_coroutine_test(
    "Configure should configure all necessary attributes and refresh device",
    function()
      test.wait_for_events()

      test.socket.device_lifecycle:__queue_receive({ mock_device5.id, "doConfigure" })
      test.socket.zigbee:__set_channel_ordering("relaxed")

      test.socket.capability:__expect_send(mock_device5:generate_test_message("main",
          capabilities.powerSource.powerSource.mains()))

      -- binding
      test.socket.zigbee:__expect_send({
        mock_device5.id,
        zigbee_test_utils.build_bind_request(mock_device5, zigbee_test_utils.mock_hub_eui, OnOff.ID)
      })
      test.socket.zigbee:__expect_send({
        mock_device5.id,
        zigbee_test_utils.build_bind_request(mock_device5, zigbee_test_utils.mock_hub_eui, OnOff.ID,
            0x02)        :to_endpoint(0x02)
      })
      test.socket.zigbee:__expect_send({
        mock_device5.id,
        zigbee_test_utils.build_bind_request(mock_device5, zigbee_test_utils.mock_hub_eui, ElectricalMeasurement.ID,
            0x02)        :to_endpoint(0x02)
      })
      test.socket.zigbee:__expect_send({
        mock_device5.id,
        zigbee_test_utils.build_bind_request(mock_device5, zigbee_test_utils.mock_hub_eui, SimpleMetering.ID,
            0x02)        :to_endpoint(0x02)
      })
      test.socket.zigbee:__expect_send({
        mock_device5.id,
        zigbee_test_utils.build_bind_request(mock_device5, zigbee_test_utils.mock_hub_eui,
            DeviceTemperatureConfiguration.ID,
            0x02)        :to_endpoint(0x02)
      })

      -- configuration
      test.socket.zigbee:__expect_send(
          {
            mock_device5.id,
            OnOff.attributes.OnOff:configure_reporting(mock_device5, 0, 300, 1)
          }
      )
      test.socket.zigbee:__expect_send(
          {
            mock_device5.id,
            OnOff.attributes.OnOff:configure_reporting(mock_device5, 0, 300, 1):to_endpoint(0x02)
          }
      )
      test.socket.zigbee:__expect_send(
          {
            mock_device5.id,
            ElectricalMeasurement.attributes.ActivePower:configure_reporting(mock_device5, 1, 3600, 5)
          }
      )
      test.socket.zigbee:__expect_send(
          {
            mock_device5.id,
            ElectricalMeasurement.attributes.RMSVoltage:configure_reporting(mock_device5, 60, 3600, 100)
          }
      )
      test.socket.zigbee:__expect_send(
          {
            mock_device5.id,
            ElectricalMeasurement.attributes.RMSCurrent:configure_reporting(mock_device5, 30, 3600, 16)
          }
      )
      test.socket.zigbee:__expect_send(
          {
            mock_device5.id,
            SimpleMetering.attributes.CurrentSummationDelivered:configure_reporting(mock_device5, 5, 3600, 1)
          }
      )
      test.socket.zigbee:__expect_send(
          {
            mock_device5.id,
            SimpleMetering.attributes.InstantaneousDemand:configure_reporting(mock_device5, 1, 3600, 5)
          }
      )
      test.socket.zigbee:__expect_send(
          {
            mock_device5.id,
            DeviceTemperatureConfiguration.attributes.CurrentTemperature:configure_reporting(mock_device5, 60, 3600, 100)
          }
      )

      -- read
      test.socket.zigbee:__expect_send({ mock_device5.id, OnOff.attributes.OnOff:read(mock_device5) })
      test.socket.zigbee:__expect_send({ mock_device5.id, OnOff.attributes.OnOff:read(mock_device5):to_endpoint(0x02) })
      test.socket.zigbee:__expect_send({ mock_device5.id, ElectricalMeasurement.attributes.ActivePower:read(mock_device5) })
      test.socket.zigbee:__expect_send({ mock_device5.id, ElectricalMeasurement.attributes.ACPowerDivisor:read(mock_device5) })
      test.socket.zigbee:__expect_send({ mock_device5.id, ElectricalMeasurement.attributes.ACPowerMultiplier:read(mock_device5) })
      test.socket.zigbee:__expect_send({ mock_device5.id, ElectricalMeasurement.attributes.RMSVoltage:read(mock_device5) })
      test.socket.zigbee:__expect_send({ mock_device5.id, ElectricalMeasurement.attributes.ACVoltageDivisor:read(mock_device5) })
      test.socket.zigbee:__expect_send({ mock_device5.id, ElectricalMeasurement.attributes.ACVoltageMultiplier:read(mock_device5) })
      test.socket.zigbee:__expect_send({ mock_device5.id, ElectricalMeasurement.attributes.RMSCurrent:read(mock_device5) })
      test.socket.zigbee:__expect_send({ mock_device5.id, ElectricalMeasurement.attributes.ACCurrentDivisor:read(mock_device5) })
      test.socket.zigbee:__expect_send({ mock_device5.id, ElectricalMeasurement.attributes.ACCurrentMultiplier:read(mock_device5) })
      test.socket.zigbee:__expect_send({ mock_device5.id, SimpleMetering.attributes.CurrentSummationDelivered:read(mock_device5) })
      test.socket.zigbee:__expect_send({ mock_device5.id, SimpleMetering.attributes.InstantaneousDemand:read(mock_device5) })
      test.socket.zigbee:__expect_send({ mock_device5.id, SimpleMetering.attributes.Divisor:read(mock_device5) })
      test.socket.zigbee:__expect_send({ mock_device5.id, SimpleMetering.attributes.Multiplier:read(mock_device5) })
      test.socket.zigbee:__expect_send({ mock_device5.id, DeviceTemperatureConfiguration.attributes.CurrentTemperature:read(mock_device5) })

      mock_device5:expect_metadata_update({ provisioning_state = "PROVISIONED" })
    end
)

test.register_message_test(
    "Refresh should read all necessary attributes",
    {
      {
        channel = "capability",
        direction = "receive",
        message = { mock_device5.id, { capability = "refresh", component = "main", command = "refresh", args = {} } }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device5.id,
          OnOff.attributes.OnOff:read(mock_device5)
        }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device5.id,
          OnOff.attributes.OnOff:read(mock_device5):to_endpoint(0x02)
        }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device5.id,
          ElectricalMeasurement.attributes.ActivePower:read(mock_device5)
        }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device5.id,
          ElectricalMeasurement.attributes.RMSVoltage:read(mock_device5)
        }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device5.id,
          ElectricalMeasurement.attributes.RMSCurrent:read(mock_device5)
        }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device5.id,
          SimpleMetering.attributes.CurrentSummationDelivered:read(mock_device5)
        }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device5.id,
          SimpleMetering.attributes.InstantaneousDemand:read(mock_device5)
        }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device5.id,
          DeviceTemperatureConfiguration.attributes.CurrentTemperature:read(mock_device5)
        }
      }
    },
    {
      inner_block_ordering = "relaxed"
    }
)

test.run_registered_tests()

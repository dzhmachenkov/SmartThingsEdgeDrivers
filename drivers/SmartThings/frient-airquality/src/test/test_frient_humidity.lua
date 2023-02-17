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
local t_utils                = require "integration_test.utils"
local zigbee_test_utils      = require "integration_test.zigbee_test_utils"
local clusters               = require "st.zigbee.zcl.clusters"

local PowerConfiguration     = clusters.PowerConfiguration
local TemperatureMeasurement = clusters.TemperatureMeasurement
local RelativeHumidity       = clusters.RelativeHumidity

local capabilities           = require "st.capabilities"

local mock_device1           = test.mock_device.build_test_zigbee_device(
    {
      profile = t_utils.get_profile_definition("humidity-temperature-battery.yml"),
      zigbee_endpoints = {
        [0x01] = {
          id = 0x01,
          manufacturer = "frient A/S",
          model = "HMSZB-110",
          server_clusters = { 0x0003, 0x0005, 0x0006 }
        },
        [0x26] = {
          id = 0x26,
          server_clusters = { 0x0000, 0x0001, 0x0003, 0x0020, 0x0402, 0x0405 }
        }
      }
    }
)

local mock_device2           = test.mock_device.build_test_zigbee_device(
    {
      profile = t_utils.get_profile_definition("humidity-temperature-battery.yml"),
      zigbee_endpoints = {
        [0x01] = {
          id = 0x01,
          manufacturer = "frient A/S",

          model = "HMSZB-120",
          server_clusters = { 0x0003, 0x0005, 0x0006 }
        },
        [0x26] = {
          id = 0x26,
          server_clusters = { 0x0000, 0x0001, 0x0003, 0x0020, 0x0402, 0x0405 }
        }
      }
    }
)

zigbee_test_utils.prepare_zigbee_env_info()
local function test_init()
  test.mock_device.add_test_device(mock_device1)
  test.mock_device.add_test_device(mock_device2)
end

test.set_test_init_function(test_init)

test.register_message_test(
    "[HMSZB-110] Refresh should read all necessary attributes",
    {
      {
        channel = "capability",
        direction = "receive",
        message = { mock_device1.id, { capability = "refresh", component = "main", command = "refresh", args = {} } }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device1.id,
          PowerConfiguration.attributes.BatteryVoltage:read(mock_device1)
        }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device1.id,
          RelativeHumidity.attributes.MeasuredValue:read(mock_device1)
        }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device1.id,
          TemperatureMeasurement.attributes.MeasuredValue:read(mock_device1)
        }
      }
    },
    {
      inner_block_ordering = "relaxed"
    }
)

test.register_coroutine_test(
    "[HMSZB-110] Configure should configure all necessary attributes",
    function()
      test.socket.zigbee:__set_channel_ordering("relaxed")
      test.socket.device_lifecycle:__queue_receive({ mock_device1.id, "init" })
      test.socket.device_lifecycle:__queue_receive({ mock_device1.id, "doConfigure" })

      test.socket.zigbee:__expect_send({
        mock_device1.id,
        zigbee_test_utils.build_bind_request(mock_device1,
            zigbee_test_utils.mock_hub_eui,
            PowerConfiguration.ID,
            0x26
        )                :to_endpoint(0x26)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        PowerConfiguration.attributes.BatteryVoltage:configure_reporting(mock_device1, 30, 21600, 1)
      })

      test.socket.zigbee:__expect_send({
        mock_device1.id,
        zigbee_test_utils.build_bind_request(mock_device1,
            zigbee_test_utils.mock_hub_eui,
            RelativeHumidity.ID,
            0x26
        )                :to_endpoint(0x26)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        RelativeHumidity.attributes.MeasuredValue:configure_reporting(mock_device1, 30, 3600, 100)
      })

      test.socket.zigbee:__expect_send({
        mock_device1.id,
        zigbee_test_utils.build_bind_request(mock_device1,
            zigbee_test_utils.mock_hub_eui,
            TemperatureMeasurement.ID,
            0x26
        )                :to_endpoint(0x26)
      })
      test.socket.zigbee:__expect_send({
        mock_device1.id,
        TemperatureMeasurement.attributes.MeasuredValue:configure_reporting(mock_device1, 30, 300, 16)
      })

      test.socket.zigbee:__expect_send({ mock_device1.id, PowerConfiguration.attributes.BatteryVoltage:read(mock_device1) })
      test.socket.zigbee:__expect_send({ mock_device1.id, RelativeHumidity.attributes.MeasuredValue:read(mock_device1) })
      test.socket.zigbee:__expect_send({ mock_device1.id, TemperatureMeasurement.attributes.MeasuredValue:read(mock_device1) })

      mock_device1:expect_metadata_update({ provisioning_state = "PROVISIONED" })
    end
)

test.register_message_test(
    "[HMSZB-110] Battery percentage remaining report should be handled",
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
    "[HMSZB-110] Temperature report should be handled",
    {
      {
        channel = "zigbee",
        direction = "receive",
        message = { mock_device1.id, TemperatureMeasurement.attributes.MeasuredValue:build_test_attr_report(mock_device1,
            2020) }
      },
      {
        channel = "capability",
        direction = "send",
        message = mock_device1:generate_test_message("main",
            capabilities.temperatureMeasurement.temperature({ unit = "C", value = 20.2 }))
      }
    }
)

test.register_message_test(
    "[HMSZB-110] Humidity report should be handled",
    {
      {
        channel = "zigbee",
        direction = "receive",
        message = { mock_device1.id, RelativeHumidity.attributes.MeasuredValue:build_test_attr_report(mock_device1,
            0x16A8) }
      },
      {
        channel = "capability",
        direction = "send",
        message = mock_device1:generate_test_message("main", capabilities.relativeHumidityMeasurement.humidity(58))
      }
    }
)

test.register_message_test(
    "[HMSZB-120] Refresh should read all necessary attributes",
    {
      {
        channel = "capability",
        direction = "receive",
        message = { mock_device2.id, { capability = "refresh", component = "main", command = "refresh", args = {} } }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device2.id,
          PowerConfiguration.attributes.BatteryVoltage:read(mock_device2)
        }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device2.id,
          RelativeHumidity.attributes.MeasuredValue:read(mock_device2)
        }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device2.id,
          TemperatureMeasurement.attributes.MeasuredValue:read(mock_device2)
        }
      }
    },
    {
      inner_block_ordering = "relaxed"
    }
)

test.register_coroutine_test(
    "[HMSZB-120] Configure should configure all necessary attributes",
    function()
      test.socket.zigbee:__set_channel_ordering("relaxed")
      test.socket.device_lifecycle:__queue_receive({ mock_device2.id, "init" })
      test.socket.device_lifecycle:__queue_receive({ mock_device2.id, "doConfigure" })

      test.socket.zigbee:__expect_send({
        mock_device1.id,
        zigbee_test_utils.build_bind_request(mock_device2,
            zigbee_test_utils.mock_hub_eui,
            PowerConfiguration.ID,
            0x26
        )                :to_endpoint(0x26)
      })
      test.socket.zigbee:__expect_send({
        mock_device2.id,
        PowerConfiguration.attributes.BatteryVoltage:configure_reporting(mock_device2, 30, 21600, 1)
      })

      test.socket.zigbee:__expect_send({
        mock_device2.id,
        zigbee_test_utils.build_bind_request(mock_device2,
            zigbee_test_utils.mock_hub_eui,
            RelativeHumidity.ID,
            0x26
        )                :to_endpoint(0x26)
      })
      test.socket.zigbee:__expect_send({
        mock_device2.id,
        RelativeHumidity.attributes.MeasuredValue:configure_reporting(mock_device2, 30, 3600, 100)
      })

      test.socket.zigbee:__expect_send({
        mock_device2.id,
        zigbee_test_utils.build_bind_request(mock_device2,
            zigbee_test_utils.mock_hub_eui,
            TemperatureMeasurement.ID,
            0x26
        )                :to_endpoint(0x26)
      })
      test.socket.zigbee:__expect_send({
        mock_device2.id,
        TemperatureMeasurement.attributes.MeasuredValue:configure_reporting(mock_device2, 30, 300, 16)
      })

      test.socket.zigbee:__expect_send({ mock_device2.id, PowerConfiguration.attributes.BatteryVoltage:read(mock_device2) })
      test.socket.zigbee:__expect_send({ mock_device2.id, RelativeHumidity.attributes.MeasuredValue:read(mock_device2) })
      test.socket.zigbee:__expect_send({ mock_device2.id, TemperatureMeasurement.attributes.MeasuredValue:read(mock_device2) })

      mock_device1:expect_metadata_update({ provisioning_state = "PROVISIONED" })
    end
)

test.register_message_test(
    "[HMSZB-120] Battery percentage remaining report should be handled",
    {
      {
        channel = "zigbee",
        direction = "receive",
        message = { mock_device2.id, PowerConfiguration.attributes.BatteryVoltage:build_test_attr_report(mock_device2,
            30) }
      },
      {
        channel = "capability",
        direction = "send",
        message = mock_device2:generate_test_message("main", capabilities.battery.battery(100))
      }
    }
)

test.register_message_test(
    "[HMSZB-120] Temperature report should be handled",
    {
      {
        channel = "zigbee",
        direction = "receive",
        message = { mock_device2.id, TemperatureMeasurement.attributes.MeasuredValue:build_test_attr_report(mock_device2,
            2020) }
      },
      {
        channel = "capability",
        direction = "send",
        message = mock_device2:generate_test_message("main",
            capabilities.temperatureMeasurement.temperature({ unit = "C", value = 20.2 }))
      }
    }
)

test.register_message_test(
    "[HMSZB-120] Humidity report should be handled",
    {
      {
        channel = "zigbee",
        direction = "receive",
        message = { mock_device2.id, RelativeHumidity.attributes.MeasuredValue:build_test_attr_report(mock_device2,
            0x16A8) }
      },
      {
        channel = "capability",
        direction = "send",
        message = mock_device2:generate_test_message("main", capabilities.relativeHumidityMeasurement.humidity(58))
      }
    }
)

test.run_registered_tests()

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

local test                    = require "integration_test"
local t_utils                 = require "integration_test.utils"
local zigbee_test_utils       = require "integration_test.zigbee_test_utils"
local data_types              = require "st.zigbee.data_types"
local clusters                = require "st.zigbee.zcl.clusters"

local PowerConfiguration      = clusters.PowerConfiguration
local TemperatureMeasurement  = clusters.TemperatureMeasurement
local RelativeHumidity        = clusters.RelativeHumidity

local VOC_MEASUREMENT_CLUSTER = 0xFC03
local MEASURED_VALUE_ATTR     = 0x0000
local MFG_CODE                = 0x1015

local mock_device             = test.mock_device.build_test_zigbee_device(
    {
      profile = t_utils.get_profile_definition("airquality-humidity-temperature-battery.yml"),
      zigbee_endpoints = {
        [0x01] = {
          id = 0x01,
          manufacturer = "frient A/S",
          model = "AQSZB-110",
          server_clusters = { 0x0003, 0x0005, 0x0006 }
        },
        [0x26] = {
          id = 0x26,
          server_clusters = { 0x0000, 0x0001, 0x0003, 0x0020, 0x0402, 0x0405, 0x042E, 0xFC03 }
        }
      }
    }
)

zigbee_test_utils.prepare_zigbee_env_info()
local function test_init()
  test.mock_device.add_test_device(mock_device)
end

test.set_test_init_function(test_init)

test.register_message_test(
    "Refresh should read all necessary attributes",
    {
      {
        channel = "capability",
        direction = "receive",
        message = { mock_device.id, { capability = "refresh", component = "main", command = "refresh", args = {} } }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device.id,
          PowerConfiguration.attributes.BatteryVoltage:read(mock_device)
        }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device.id,
          RelativeHumidity.attributes.MeasuredValue:read(mock_device)
        }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device.id,
          TemperatureMeasurement.attributes.MeasuredValue:read(mock_device)
        }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device.id,
          zigbee_test_utils.build_attribute_read(mock_device, VOC_MEASUREMENT_CLUSTER, { MEASURED_VALUE_ATTR },
              MFG_CODE)    :to_endpoint(0x26)
        }
      }
    },
    {
      inner_block_ordering = "relaxed"
    }
)

test.register_coroutine_test(
    "Configure should configure all necessary attributes",
    function()
      test.socket.zigbee:__set_channel_ordering("relaxed")
      test.socket.device_lifecycle:__queue_receive({ mock_device.id, "init" })
      test.socket.device_lifecycle:__queue_receive({ mock_device.id, "doConfigure" })

      test.socket.zigbee:__expect_send({
        mock_device.id,
        zigbee_test_utils.build_bind_request(mock_device,
            zigbee_test_utils.mock_hub_eui,
            PowerConfiguration.ID,
            0x26
        )                :to_endpoint(0x26)
      })
      test.socket.zigbee:__expect_send({
        mock_device.id,
        PowerConfiguration.attributes.BatteryVoltage:configure_reporting(mock_device, 30, 21600, 1)
      })

      test.socket.zigbee:__expect_send({
        mock_device.id,
        zigbee_test_utils.build_bind_request(mock_device,
            zigbee_test_utils.mock_hub_eui,
            RelativeHumidity.ID,
            0x26
        )                :to_endpoint(0x26)
      })
      test.socket.zigbee:__expect_send({
        mock_device.id,
        RelativeHumidity.attributes.MeasuredValue:configure_reporting(mock_device, 30, 3600, 100)
      })

      test.socket.zigbee:__expect_send({
        mock_device.id,
        zigbee_test_utils.build_bind_request(mock_device,
            zigbee_test_utils.mock_hub_eui,
            TemperatureMeasurement.ID,
            0x26
        )                :to_endpoint(0x26)
      })
      test.socket.zigbee:__expect_send({
        mock_device.id,
        TemperatureMeasurement.attributes.MeasuredValue:configure_reporting(mock_device, 30, 300, 16)
      })

      test.socket.zigbee:__expect_send({
        mock_device.id,
        zigbee_test_utils.build_bind_request(mock_device,
            zigbee_test_utils.mock_hub_eui,
            VOC_MEASUREMENT_CLUSTER,
            0x26
        )                :to_endpoint(0x26)
      })
      test.socket.zigbee:__expect_send({
        mock_device.id,
        zigbee_test_utils.build_attr_config(mock_device, VOC_MEASUREMENT_CLUSTER, MEASURED_VALUE_ATTR, 60, 600,
            data_types.Uint16, 10, MFG_CODE):to_endpoint(0x26)
      })

      test.socket.zigbee:__expect_send({ mock_device.id, PowerConfiguration.attributes.BatteryVoltage:read(mock_device) })
      test.socket.zigbee:__expect_send({ mock_device.id, RelativeHumidity.attributes.MeasuredValue:read(mock_device) })
      test.socket.zigbee:__expect_send({ mock_device.id, TemperatureMeasurement.attributes.MeasuredValue:read(mock_device) })
      test.socket.zigbee:__expect_send({ mock_device.id, zigbee_test_utils.build_attribute_read(mock_device,
          VOC_MEASUREMENT_CLUSTER, { MEASURED_VALUE_ATTR },
          MFG_CODE)                                                       :to_endpoint(0x26) })

      mock_device:expect_metadata_update({ provisioning_state = "PROVISIONED" })
    end
)

test.run_registered_tests()

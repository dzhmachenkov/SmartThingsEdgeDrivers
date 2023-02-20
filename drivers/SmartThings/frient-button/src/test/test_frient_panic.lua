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
local test               = require "integration_test"
local clusters           = require "st.zigbee.zcl.clusters"
local PowerConfiguration = clusters.PowerConfiguration
local capabilities       = require "st.capabilities"
local zigbee_test_utils  = require "integration_test.zigbee_test_utils"
local IASZone            = clusters.IASZone
local IasZoneStatus      = require "st.zigbee.generated.types.IasZoneStatus"

local button_attr        = capabilities.button.button
local t_utils            = require "integration_test.utils"

local mock_device1       = test.mock_device.build_test_zigbee_device(
    {
      profile = t_utils.get_profile_definition("button-battery.yml"),
      zigbee_endpoints = {
        [0x01] = {
          id = 0x01,
          manufacturer = "frient A/S",
          model = "PBTZB-110",
          server_clusters = { 0x0005, 0x0006 }
        },
        [0x23] = {
          id = 0x23,
          server_clusters = { 0x0000, 0x0001, 0x0003, 0x0020, 0x502 }
        }
      }
    }
)
zigbee_test_utils.prepare_zigbee_env_info()
local function test_init()
  test.mock_device.add_test_device(mock_device1)
  zigbee_test_utils.init_noop_health_check_timer()
end

test.set_test_init_function(test_init)

test.register_message_test(
    "Reported button should be handled: pushed",
    {
      {
        channel = "zigbee",
        direction = "receive",
        message = { mock_device1.id, IASZone.attributes.ZoneStatus:build_test_attr_report(mock_device1,
            IasZoneStatus(0x0002)) }
      },
      {
        channel = "capability",
        direction = "send",
        message = mock_device1:generate_test_message("main", button_attr.pushed({ state_change = true }))
      }
    }
)

test.register_coroutine_test(
    "Battery Voltage test cases",
    function()
      local battery_test_map = {
        [33] = 100,
        [32] = 100,
        [27] = 50,
        [26] = 30,
        [23] = 10,
        [15] = 0,
        [10] = 0
      }

      for voltage, batt_perc in pairs(battery_test_map) do
        test.socket.zigbee:__queue_receive({ mock_device1.id, PowerConfiguration.attributes.BatteryVoltage:build_test_attr_report(mock_device1,
            voltage) })
        test.socket.capability:__expect_send(mock_device1:generate_test_message("main",
            capabilities.battery.battery(batt_perc)))
        test.wait_for_events()
      end
    end
)

test.register_coroutine_test(
    "Configure should configure all necessary attributes",
    function()
      test.socket.zigbee:__set_channel_ordering("relaxed")
      test.socket.device_lifecycle:__queue_receive({ mock_device1.id, "doConfigure" })

      test.socket.zigbee:__expect_send(
          {
            mock_device1.id,
            zigbee_test_utils               .build_bind_request(mock_device1,
                zigbee_test_utils.mock_hub_eui,
                PowerConfiguration.ID, 0x23):to_endpoint(0x23)
          }
      )
      test.socket.zigbee:__expect_send(
          {
            mock_device1.id,
            PowerConfiguration.attributes.BatteryVoltage:configure_reporting(mock_device1,
                30,
                21600,
                1)
          }
      )
      test.socket.zigbee:__expect_send(
          {
            mock_device1.id,
            PowerConfiguration.attributes.BatteryVoltage:read(mock_device1)
          }
      )

      mock_device1:expect_metadata_update({ provisioning_state = "PROVISIONED" })
    end
)

test.run_registered_tests()

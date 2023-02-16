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

local clusters                          = require "st.zigbee.zcl.clusters"

local TemperatureMeasurement            = clusters.TemperatureMeasurement
local RelativeHumidity                  = clusters.RelativeHumidity
local PowerConfiguration                = clusters.PowerConfiguration

local Frient_VOCMeasurement             = require "frient_voc_measurement"

local devices                           = {
  FRIENT_HUMIDITY_TEMP_SENSOR = {
    FINGERPRINTS = {
      { mfr = "frient A/S", model = "AQSZB-110" }
    },
    CONFIGURATION = {
      {
        cluster = Frient_VOCMeasurement.ID,
        attribute = Frient_VOCMeasurement.attributes.MeasuredValue.ID,
        minimum_interval = 60,
        maximum_interval = 600,
        data_type = Frient_VOCMeasurement.attributes.MeasuredValue.base_type,
        reportable_change = 10,
        mfg_code = Frient_VOCMeasurement.ManufacturerSpecificCode
      }
    }
  }
}

local configurations                    = {}

configurations.get_device_configuration = function(zigbee_device)
  for _, device in pairs(devices) do
    for _, fingerprint in pairs(device.FINGERPRINTS) do
      if zigbee_device:get_manufacturer() == fingerprint.mfr and zigbee_device:get_model() == fingerprint.model then
        return device.CONFIGURATION
      end
    end
  end
  return nil
end

return configurations

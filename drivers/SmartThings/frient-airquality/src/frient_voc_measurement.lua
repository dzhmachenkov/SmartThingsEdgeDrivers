local data_types     = require "st.zigbee.data_types"

local VOCMeasurement = {
  ID = 0xFC03,
  ManufacturerSpecificCode = 0x1015,
  attributes = {
    MeasuredValue = { ID = 0x0000, base_type = data_types.Uint16 },
    MinMeasuredValue = { ID = 0x0001, base_type = data_types.Uint16 },
    MaxMeasuredValue = { ID = 0x0002, base_type = data_types.Uint16 },
    Resolution = { ID = 0x0002, base_type = data_types.Uint16 },
  },
}

return VOCMeasurement

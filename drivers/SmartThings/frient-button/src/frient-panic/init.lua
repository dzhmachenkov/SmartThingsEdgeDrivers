local FRIENT_DEVICE_FINGERPRINTS = require "device_config"

--- @param opts table A table containing optional arguments that can be used to determine if something is handleable
--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
local function can_handle_frient(opts, driver, device, ...)
  for _, fingerprint in ipairs(FRIENT_DEVICE_FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model and fingerprint.subdriver == "panic" then
      return true
    end
  end
  return false
end

local frient_panic_button = {
  NAME = "Frient Panic Button",
  lifecycle_handlers = {
  },
  zigbee_handlers = {
    cluster = {
    },
    attr = {
    }
  },
  capability_handlers = {

  },
  can_handle = can_handle_frient
}

return frient_panic_button

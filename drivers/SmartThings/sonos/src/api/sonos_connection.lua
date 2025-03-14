local cosock = require "cosock"
local log = require "log"
local json = require "st.json"

local lb_utils = require "lunchbox.util"
local st_utils = require "st.utils"

local EventHandlers = require "api.event_handlers"
local PlayerFields = require "fields".SonosPlayerFields
local Router = require "api.sonos_websocket_router"
local SonosApi = require "api"
local SonosRestApi = require "api.rest"

--- A class-like lua module that allows for instantiation of a SonosConnection
--- table providing an abstraction layer above the concept of a Sonos websocket connection.
--- The reason for this abstraction is because of the fact that when a Sonos speaker is part
--- of a group, certain messages can be sent to the player directly but others must be sent
--- to a player's "coordinator" device. This abstracts those concerns away from the user,
--- providing an opaque "connection" interface for sending and listening on messages from
--- the speaker itself as well as its coordinator in the event that a player is not
--- its own coordinator.
--- @class SonosConnection
--- @field public driver SonosDriver reference to the Edge Driver
--- @field public device SonosDevice the player for this connection
--- @field private _self_listener_uuid string
--- @field private _coord_listener_uuid string
--- @field private _initialized boolean
local SonosConnection = {}
SonosConnection.__index = SonosConnection

local self_subscriptions = { "groups", "playerVolume", "audioClip" }
local coordinator_subscriptions = { "groupVolume", "playback", "favorites", "playbackMetadata" }
local favorites_version = ""

--- Update subscriptions by constructing Sonos JSON payloads for sending. Sonos
--- commands are JSON that take the form of a 2-element array where the first index is the header
--- and the second index is the body. Hence the empty table in the second position.
---
--- https://developer.sonos.com/reference/control-api-examples-lan/
---@param sonos_conn SonosConnection
---@param namespaces string[]
---@param command "subscribe"|"unsubscribe"
_update_subscriptions_helper = function(sonos_conn, householdId, playerId, groupId, namespaces, command)
  for _, namespace in ipairs(namespaces) do
    local payload_table = {
      {
        namespace = namespace,
        command = command,
        householdId = householdId,
        groupId = groupId,
        playerId = playerId
      },
      {}
    }
    local payload = json.encode(payload_table)
    Router.send_message_to_player(playerId, payload)
  end
end

---@param sonos_conn SonosConnection
---@param namespaces string[]
---@param command "subscribe"|"unsubscribe"
_update_self_subscriptions = function(sonos_conn, namespaces, command)
  local householdId = sonos_conn.device:get_field(PlayerFields.HOUSEHOULD_ID)
  local _, playerId = sonos_conn.driver.sonos:get_player_for_device(sonos_conn.device)
  local _, groupId = sonos_conn.driver.sonos:get_group_for_device(sonos_conn.device)
  _update_subscriptions_helper(sonos_conn, householdId, playerId, groupId, namespaces, command)
end

---@param sonos_conn SonosConnection
---@param namespaces string[]
---@param command "subscribe"|"unsubscribe"
_update_coordinator_subscriptions = function(sonos_conn, namespaces, command)
  local householdId = sonos_conn.device:get_field(PlayerFields.HOUSEHOULD_ID)
  local _, coordinatorId = sonos_conn.driver.sonos:get_coordinator_for_device(sonos_conn.device)
  local _, groupId = sonos_conn.driver.sonos:get_group_for_device(sonos_conn.device)
  _update_subscriptions_helper(sonos_conn, householdId, coordinatorId, groupId, namespaces, command)
end

---@param sonos_conn SonosConnection
---@param household_id HouseholdId
---@param self_player_id PlayerId
local function _open_coordinator_socket(sonos_conn, household_id, self_player_id)
  log.trace("Open coordinator socket for: " .. sonos_conn.device.label)
  local _, coordinator_id, err = sonos_conn.driver.sonos:get_coordinator_for_device(sonos_conn.device)
  if err ~= nil then
    log.error(
      string.format(
        "Could not look up coordinator info for player %s: %s", sonos_conn.device.label, err
      )
    )
  end

  if coordinator_id ~= self_player_id then
    local coordinator = sonos_conn.driver.sonos:get_household(household_id).players[coordinator_id]
    local _, err =
    Router.open_socket_for_player(coordinator_id, coordinator.websocketUrl)

    if err ~= nil then
      log.error(
        string.format(
          "Couldn't open connection to coordinator for %s: %s", sonos_conn.device.label, err
        )
      )
    end

    listener_id, err = Router.register_listener_for_socket(sonos_conn, coordinator_id)
    if err ~= nil or not listener_id then
      log.error(err)
    else
      sonos_conn._coord_listener_uuid = listener_id
    end
  end
end

---@param sonos_conn SonosConnection
local function _spawn_reconnect_task(sonos_conn)
  log.trace("Spawning reconnect task for ", sonos_conn.device.label)
  cosock.spawn(function()
    local backoff = st_utils.backoff_builder(60, 1, 0.1)
    while not sonos_conn:is_running() do
      local start_success = sonos_conn:start()
      if start_success then return end
      cosock.socket.sleep(backoff())
    end
  end, string.format("%s Reconnect Task", sonos_conn.device.label))
end

--- Create a new Sonos connection to manage the given device
--- @param driver SonosDriver
--- @param device SonosDevice
--- @return SonosConnection
function SonosConnection.new(driver, device)
  local self = setmetatable({ driver = driver, device = device, _listener_uuids = {}, _initialized = false },
    SonosConnection)
  local _name = self.device.label

  self.on_message = function(uuid, msg)
    if msg.data then
      local header, body = table.unpack(json.decode(msg.data))
      if header.type == "groups" then
        local household_id, current_coordinator = self.driver.sonos:get_coordinator_for_device(self.device)
        local _, player_id = self.driver.sonos:get_player_for_device(self.device)
        self.driver.sonos:update_household_info(header.householdId, body, self.device)
        local _, updated_coordinator = self.driver.sonos:get_coordinator_for_device(self.device)

        Router.cleanup_unused_sockets(self.driver)

        if not self:coordinator_running() then
          _open_coordinator_socket(self, household_id, player_id)
        end

        if current_coordinator ~= updated_coordinator then
          self:refresh_subscriptions()
        end
      elseif header.type == "playerVolume" then
        local player_id = self.device:get_field(PlayerFields.PLAYER_ID)
        if player_id == header.playerId and body.volume and (body.muted ~= nil) then
          EventHandlers.handle_player_volume(self.device, body.volume, body.muted)
        end
      elseif header.type == "audioClipStatus" then
        local player_id = self.device:get_field(PlayerFields.PLAYER_ID)
        if player_id == header.playerId then
          EventHandlers.handle_audio_clip_status(self.device, body.audioClips)
        end
      elseif header.type == "groupVolume" then
        if body.volume and (body.muted ~= nil) then
          local group = self.driver.sonos:get_household(header.householdId).groups[header.groupId] or { playerIds = {} }
          for _, player_id in ipairs(group.playerIds) do
            local device_for_player = self.driver._player_id_to_device[player_id]
            --- we've seen situations where these messages can be processed while a device
            --- is being deleted so we check for the presence of emit event as a proxy for
            --- whether or not this device is currently capable of emitting events.
            if device_for_player and device_for_player.emit_event then
              EventHandlers.handle_group_volume(device_for_player, body.volume, body.muted)
            end
          end
        end
      elseif header.type == "playbackStatus" then
        local group = self.driver.sonos:get_household(header.householdId).groups[header.groupId] or { playerIds = {} }
        for _, player_id in ipairs(group.playerIds) do
          local device_for_player = self.driver._player_id_to_device[player_id]
          --- we've seen situations where these messages can be processed while a device
          --- is being deleted so we check for the presence of emit event as a proxy for
          --- whether or not this device is currently capable of emitting events.
          if device_for_player and device_for_player.emit_event then
            EventHandlers.handle_playback_status(device_for_player, body.playbackState)
          end
        end
      elseif header.type == "metadataStatus" then
        local group = self.driver.sonos:get_household(header.householdId).groups[header.groupId] or { playerIds = {} }
        for _, player_id in ipairs(group.playerIds) do
          local device_for_player = self.driver._player_id_to_device[player_id]
          --- we've seen situations where these messages can be processed while a device
          --- is being deleted so we check for the presence of emit event as a proxy for
          --- whether or not this device is currently capable of emitting events.
          if device_for_player and device_for_player.emit_event then
            EventHandlers.handle_playback_metadata_update(device_for_player, body)
          end
        end
      elseif header.namespace == "favorites" and header.type == "versionChanged" then
        if body.version ~= favorites_version then
          favorites_version = body.version

          local household = self.driver.sonos:get_household(header.householdId)

          for group_id, group in pairs(household.groups) do
            local coordinator_id = self.driver.sonos:get_coordinator_for_group(header.householdId, group_id)
            local coordinator_player = household.players[coordinator_id]

            local url_ip = lb_utils.force_url_table(coordinator_player.websocketUrl).host

            local favorites_response, err, _ =
            SonosRestApi.get_favorites(url_ip, SonosApi.DEFAULT_SONOS_PORT, header.householdId)

            if err or not favorites_response then
              log.error("Error querying for favorites: " .. err)
            else
              local new_favorites = {}
              for _, favorite in ipairs(favorites_response.items or {}) do
                local new_item = { id = favorite.id, name = favorite.name }
                if favorite.imageUrl then new_item.imageUrl = favorite.imageUrl end
                if favorite.service and favorite.service.name then new_item.mediaSource = favorite.service.name end
                table.insert(new_favorites, new_item)
              end
              self.driver.sonos:update_household_favorites(header.householdId, new_favorites)

              for _, player_id in ipairs(group.playerIds) do
                local device_for_player = self.driver._player_id_to_device[player_id]
                --- we've seen situations where these messages can be processed while a device
                --- is being deleted so we check for the presence of emit event as a proxy for
                --- whether or not this device is currently capable of emitting events.
                if device_for_player and device_for_player.emit_event then
                  EventHandlers.update_favorites(device_for_player, new_favorites)
                end
              end
            end
          end
        end
      end
    end
  end

  self.on_error = function(uuid, err)
    log.error(err or ("unknown websocket error for " .. (self.device.label or "unknown device")))
  end

  self.on_close = function(uuid)
    if self._initialized then self.device:offline() end
    if self._keepalive then _spawn_reconnect_task(self) end
  end

  return self
end

--- Whether or not the connection has all of the live websocket connections it needs to function
--- @return boolean
function SonosConnection:is_running()
  local self_running = self:self_running()
  local coord_running = self:coordinator_running()
  return  self_running and coord_running
end

--- Whether or not the connection has a live websocket connection
--- @return boolean
function SonosConnection:self_running()
  return Router.is_connected(self.device:get_field(PlayerFields.PLAYER_ID)) and self._initialized
end

--- Whether or not the connection has a live websocket connection to its coordinator
--- @return boolean
function SonosConnection:coordinator_running()
  local _, coordinator_id = self.driver.sonos:get_coordinator_for_device(self.device)
  return Router.is_connected(coordinator_id) and self._initialized
end

function SonosConnection:refresh_subscriptions()
  log.trace("Refresh subscriptions on " .. self.device.label)
  _update_self_subscriptions(self, self_subscriptions, "subscribe")
  _update_coordinator_subscriptions(self, coordinator_subscriptions, "subscribe")
end

--- Send a Sonos command object to the player for this connection
--- @param cmd SonosCommand
function SonosConnection:send_command(cmd)
  log.trace("Sending command over websocket channel for device " .. self.device.label)
  local _, coordinator_id = self.driver.sonos:get_coordinator_for_device(self.device)
  local json_payload, err = json.encode(cmd)

  if err or not json_payload then
    log.error("Json encoding error: " .. err)
  else
    Router.send_message_to_player(coordinator_id, json_payload)
  end
end

--- Start a new websocket connection
--- @return boolean success
function SonosConnection:start()
  if self:is_running() then
    log.warn(
      "Called Start on a Sonos WebSocket that was already connected for device "
      .. self.device.label
    )
    return false
  end

  local household_id = self.device:get_field(PlayerFields.HOUSEHOULD_ID)
  local player_id = self.device:get_field(PlayerFields.PLAYER_ID)

  if not self:self_running() then
    local url = self.device:get_field(PlayerFields.WSS_URL) or {}

    local _, err = Router.open_socket_for_player(player_id, url)
    if err ~= nil then
      log.error(err)
      return false
    end

    local listener_id, err = Router.register_listener_for_socket(self, player_id)
    if err ~= nil or not listener_id then
      log.error(err)
    else
      self._self_listener_uuid = listener_id
    end
  end

  if not self:coordinator_running() then
    _open_coordinator_socket(self, household_id, player_id)
  end

  self:refresh_subscriptions()
  local coordinator_id = self.driver.sonos:get_coordinator_for_player(household_id, player_id)
  if Router.is_connected(player_id) and Router.is_connected(coordinator_id) then
    self.device:online()
    self._initialized = true
    self._keepalive = true
    return true
  end

  return false
end

--- Stop the websocket processing loop and close the connection
function SonosConnection:stop()
  self._initialized = false
  self._keepalive = false
  log.info("Stopping Sonos connection for " .. self.device.label)
  local _, player_id = self.driver.sonos:get_player_for_device(self.device)
  local household_id, group_id = self.driver.sonos:get_group_for_device(self.device)
  local coordinator_id = self.driver.sonos:get_coordinator_for_group(household_id, group_id)

  if not player_id == coordinator_id then
    Router.close_socket_for_player(player_id)
  end
end

return SonosConnection

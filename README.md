# Roblox Network & Signal Module

A lightweight, type-safe networking and signal system for Roblox built with strict Luau. This module provides a clean abstraction over RemoteEvents with built-in request/response patterns, unreliable messaging, and a custom Signal implementation.

[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

## Features

- **Type-Safe**: Full strict type checking for safe and predictable code
- **Request/Response Pattern**: Built-in client-server request system with timeouts available
- **Reliable & Unreliable Messaging**: Support for both RemoteEvent and UnreliableRemoteEvent
- **Custom Signal System**: Event system with connection management
- **Clean API**: Simple and intuitive methods for all networking needs
- **Error Handling**: Comprehensive error messages and validation

## 📦 Installation

1. Clone this repository or download the source files
2. In Roblox Studio, place both `NetworkModule.luau` and `Signal.luau` inside:
   ```
   ReplicatedStorage
   └── Modules
       ├── NetworkModule.luau
       └── Signal.luau
   ```

## 🚀 Quick Start

### Basic Setup

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Modules.NetworkModule)

-- Listen for an event
Network:get("playerJoined"):connect(function(...)
    print("Player joined event received!")
end)

-- Send an event
Network:send("playerJoined", "PlayerName", 100)
```

## 📖 API Reference

### Network:get()
Get or create a signal for a specific event name.

```lua
local signal = Network:get(eventName: string) -> Signal
```

**Example:**
```lua
local chatSignal = Network:get("chatMessage")
chatSignal:connect(function(player, message)
    print(player.Name .. " said: " .. message)
end)
```

---

### Network:send()
Send a reliable message to the server, from client, or all clients, from server,.

```lua
Network:send(eventName: string, ...args: any)
```

**Client Example:**
```lua
-- Send data to server
Network:send("purchaseItem", "Sword", 150)
```

**Server Example:**
```lua
-- Send data to all clients
Network:send("serverAnnouncement", "Server restarting in 5 minutes!")
```

---

### Network:sendTo()
Send a reliable message to a specific player. **(Server-only)**

```lua
Network:sendTo(player: Player, eventName: string, ...args: any)
```

**Example:**
```lua
-- Send a reward notification to a specific player
local player = game.Players:FindFirstChild("PlayerName")
if player then
    Network:sendTo(player, "rewardNotification", "Gold Coin", 50)
end
```

---

### Network:sendUnreliable()
Send an unreliable message (no guaranteed delivery, but faster).

```lua
Network:sendUnreliable(eventName: string, ...args: any)
```

**Example:**
```lua
-- Send player position updates (can afford to lose some)
Network:sendUnreliable("playerPosition", player.Character.HumanoidRootPart.Position)
```

---

### Network:sendToUnreliable()
Send an unreliable message to a specific player. **(Server-only)**

```lua
Network:sendToUnreliable(player: Player, eventName: string, ...args: any)
```

**Example:**
```lua
-- Send fast-updating data to specific player
Network:sendToUnreliable(player, "nearbyPlayers", playersInRange)
```

---

### Network:request()
Send a request from client to server and wait for a response with timeout. **(Client-only)**

```lua
local response = Network:request(eventName: string, timeoutSeconds: number?, ...args: any) -> ...any
```

**Client Example:**
```lua
-- Request player data from server
local playerData = Network:request("getPlayerData", 5) -- 5 second timeout

if playerData then
    print("Received data:", playerData)
else
    warn("Request timed out!")
end
```

**Server Handler Example:**
```lua
Network:get("getPlayerData"):connect(function(player, requestId)
    local data = {
        coins = 1000,
        level = 25,
        inventory = {"Sword", "Shield"}
    }
    
    Network:respond(player, requestId, data)
end)
```

---

### Network:respond()
Respond to a client request. **(Server-only)**

```lua
Network:respond(player: Player, requestId: string, ...args: any)
```

**Example:**
```lua
Network:get("validatePurchase"):connect(function(player, requestId, itemId)
    local canPurchase = checkIfPlayerCanPurchase(player, itemId)
    Network:respond(player, requestId, canPurchase)
end)
```

---

### Network:serialize()
Convert a table to JSON string.

```lua
local jsonString = Network:serialize(data: any) -> string
```

**Example:**
```lua
local playerData = {
    name = "Player1",
    score = 100
}
local json = Network:serialize(playerData)
```

---

### Network:deserialize()
Convert a JSON string back to a table.

```lua
local data = Network:deserialize(jsonString: string) -> any
```

**Example:**
```lua
local json = '{"name":"Player1","score":100}'
local data = Network:deserialize(json)
print(data.name) -- "Player1"
```

---

## 🎯 Signal API

The Signal module provides a custom event system used internally by the Network module.

### Signal Methods

```lua
local Signal = require(ReplicatedStorage.Modules.Signal)

-- Create a new signal
local mySignal = Signal.new()

-- Connect a listener
local connection = mySignal:connect(function(value)
    print("Received:", value)
end)

-- Fire the signal
mySignal:fire("Hello!")

-- Disconnect listener
connection:disconnect()

-- Connect once (auto-disconnects after first fire)
mySignal:once(function(value)
    print("This only prints once:", value)
end)

-- Wait for signal (yields)
task.spawn(function()
    local value = mySignal:wait()
    print("Received after waiting:", value)
end)

-- Check if signal has listeners
if mySignal:hasListeners() then
    print("Signal has active listeners")
end

-- Disconnect all listeners
mySignal:disconnectAll()

-- Destroy signal
mySignal:destroy()
```

---

## 💡 Usage Examples

### Example 1: Chat System

**Server:**
```lua
local Network = require(game.ReplicatedStorage.Modules.NetworkModule)

Network:get("sendChatMessage"):connect(function(player, message)
    -- Validate and broadcast to all players
    if #message > 0 and #message <= 200 then
        Network:send("receiveChatMessage", player.Name, message)
    end
end)
```

**Client:**
```lua
local Network = require(game.ReplicatedStorage.Modules.NetworkModule)

-- Listen for chat messages
Network:get("receiveChatMessage"):connect(function(playerName, message)
    print(playerName .. ": " .. message)
end)

-- Send a chat message
Network:send("sendChatMessage", "Hello everyone!")
```

---

### Example 2: Player Data Request

**Server:**
```lua
local Network = require(game.ReplicatedStorage.Modules.NetworkModule)

Network:get("requestPlayerStats"):connect(function(player, requestId)
    local stats = {
        level = player.leaderstats.Level.Value,
        coins = player.leaderstats.Coins.Value,
        playtime = getPlayerPlaytime(player)
    }
    
    Network:respond(player, requestId, stats)
end)
```

**Client:**
```lua
local Network = require(game.ReplicatedStorage.Modules.NetworkModule)

local stats = Network:request("requestPlayerStats", 5)

if stats then
    print("Level:", stats.level)
    print("Coins:", stats.coins)
    print("Playtime:", stats.playtime)
else
    warn("Failed to get player stats")
end
```

---

### Example 3: Real-time Position Updates

**Client:**
```lua
local Network = require(game.ReplicatedStorage.Modules.NetworkModule)
local RunService = game:GetService("RunService")
local player = game.Players.LocalPlayer

RunService.Heartbeat:Connect(function()
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local position = player.Character.HumanoidRootPart.Position
        -- Use unreliable for frequent updates
        Network:sendUnreliable("updatePosition", position)
    end
end)
```

**Server:**
```lua
local Network = require(game.ReplicatedStorage.Modules.NetworkModule)

Network:get("updatePosition"):connect(function(player, position)
    -- Update player position for other systems
    playerPositions[player] = position
end)
```

---

## Recommended Use

1. **Use unreliable messages for high frequency events** where occasional packet loss is acceptable
2. **Use reliable messages for important game events** such as purchases, rewards, game state changes
3. **Always validate data on the server** - don't ever trust the client's input
4. **Set appropriate timeouts for requests** to prevent infinite yield
5. **Disconnect signals when no longer needed** to prevent memory leaks
6. **Use the request/response pattern** for client-server communication requiring confirmation
---

## ⭐ Show Your Support

If you found these modules helpful, please consider giving it a star!

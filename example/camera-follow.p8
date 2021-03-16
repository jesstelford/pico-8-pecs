pico-8 cartridge // http://www.pico-8.com
version 32
__lua__
#include ../pecs.lua
-- A camera follow example showing how to use PECS (PICO-8 Entity Component
-- System) by Jess Telford: https://github.com/jesstelford/pico-8-pecs
-- This example is optimised for readability, not token or character count.
-- License: MIT Copyright (c) 2021 Jess Telford

-------------------
--[[ ECS SETUP ]]--

-- Setup the world where all Components, Entities, and Systems will live
local world = createECSWorld()

--[[ END ECS SETUP ]]--
-----------------------

------------------------
--[[ ECS COMPONENTS ]]--

-- Create instantiable Components with default values
-- These values will all be used later in the Systems
-- Individual values can be overriden when instiating a Component

-- An entity's origin is the top-left corner (ie; -x, -y), relative to the
-- world's origin
local Position = world.createComponent({ x = 0, y = 0 })

-- Make an entity relative to a some other entity
local RelativePosition = world.createComponent({ x = 0, y = 0, parent = nil })

-- Give an entity a size (aka; a Bounding Box)
local Size = world.createComponent({ width = 0, height = 0 })

-- Special component for the player. This example has only one, but in the
-- future there may be many, so we use a component for the various data related
-- to a player.
local Player = world.createComponent({ moveSpeedX = 60, moveSpeedY = 60 })

-- Information on how to render an entity
local Renderable = world.createComponent({ borderColor = 0 })

-- The boundaries an entity must exist within (inclusive), relative to the world
-- origin
local Contained = world.createComponent({ x = 0, y = 0, width = 120, height = 120})

-- A follower has an entity it is _following_. The bounaries are relative to the
-- follower entity's origin. As the following entity moves outside the bounds of
-- the follower, the follower should move to catch up with the entity it is
-- following.
local Follower = world.createComponent({ within = nil, following = nil })

--[[ END ECS COMPONENTS ]]--
----------------------------

function _init()
  -- For debug purposes; Show the "world" box
  world.createEntity(
    {},
    Position({ x = 10, y = 10 }),
    Size({ width = 110, height = 110 }),
    Renderable({ borderColor = 13 })
  )

  local playerEntity = world.createEntity(
    {},
    Player(),
    Position({ x=64, y=64 }),
    Contained({ x=10, y=10, width=110, height=110 }),
    Size({ width = 4, height = 4 }),
    Renderable({ borderColor = 8 })
  )

  local cameraEntity = world.createEntity(
    {},
    Position({ x = 50, y = 50 }),
    Contained({ x=10, y=10, width=110, height=110 }),
    -- Normally your camera would be the size of the screen. For this example,
    -- we're showing a smaller version
    Size({ width = 40, height = 40 }),
    -- For debug purposes, we want to render an outline for the camera
    Renderable({ borderColor = 12 })
  )

  local cameraInnerEntity = world.createEntity(
    {},
    RelativePosition({ x = 10, y = 10, parent = cameraEntity }),
    Size({ width = 20, height = 20 }),
    -- For debug purposes, we want to render an outline for the inner box of the
    -- camera
    Renderable({ borderColor = 15 })
  )

  -- Add the Follower component to the camera. This defines how the camera
  -- follows the player.
  cameraEntity += Follower({ following = playerEntity, within = cameraInnerEntity })
end

---------------------
--[[ ECS SYSTEMS ]]--

-- A System for handling input. In this example, we only have a single entity
-- which matches the filter { Position, Player }, so this System could be
-- replaced with a regular function.
-- But, as our world grows, we may want more than one player which responds to
-- user input. All that's required is to call `world.createEntity` with at least
-- the `Player` & `Position` components, then this System will automatically
-- detect it and run the function.
local move = world.createSystem({ Position, Player }, function(entity, tDiff)
  if (btn(0)) then entity[Position].x -= entity[Player].moveSpeedX * tDiff end
  if (btn(1)) then entity[Position].x += entity[Player].moveSpeedX * tDiff end
  if (btn(2)) then entity[Position].y -= entity[Player].moveSpeedY * tDiff end
  if (btn(3)) then entity[Position].y += entity[Player].moveSpeedY * tDiff end
end)

-- Ensure entities stay within their container (usually the world map)
local containEntities = world.createSystem({ Position, Size, Contained }, function(entity)
  local container = entity[Contained]
  local pos = entity[Position]
  pos.x = mid(
    container.x,
    pos.x,
    container.x + container.width - entity[Size].width
  )
  pos.y = mid(
    container.y,
    pos.y,
    container.y + container.height - entity[Size].height
  )
end)

-- Very naive rendering in this example. As complexity rises, it makes sense to
-- create Components for each type of renderable, and the System which actually
-- does the rendering.
local drawRenderables = world.createSystem({ Position, Renderable, Size }, function(entity)
  rect(
    entity[Position].x,
    entity[Position].y,
    entity[Position].x + entity[Size].width - 1,
    entity[Position].y + entity[Size].height - 1,
    entity[Renderable].borderColor
  )
end)

-- For debug purposes, we're using this system only to render the inner box of
-- the camera
local drawRelativeRenderables = world.createSystem({ RelativePosition, Renderable, Size }, function(entity)
  local xOffset = entity[RelativePosition].parent[Position].x
  local yOffset = entity[RelativePosition].parent[Position].y
  rect(
    xOffset + entity[RelativePosition].x,
    yOffset + entity[RelativePosition].y,
    xOffset + entity[RelativePosition].x + entity[Size].width - 1,
    yOffset + entity[RelativePosition].y + entity[Size].height - 1,
    entity[Renderable].borderColor
  )
end)

-- The method to ensure one entity follows along with another entity.
-- Depends on the followed entity having a Position & Size Component
local follow = world.createSystem({ Position, Follower }, function(entity)
  local withinPos = entity[Follower].within[RelativePosition]
  local withinBox = entity[Follower].within[Size]
  local followingPos = entity[Follower].following[Position]
  local followingBox = entity[Follower].following[Size]
  local pos = entity[Position]

  pos.x = mid(
    pos.x + (followingPos.x - (pos.x + withinPos.x)),
    pos.x,
    pos.x + ((followingPos.x + followingBox.width) - ((pos.x + withinPos.x) + withinBox.width))
  )

  pos.y = mid(
    pos.y + (followingPos.y - (pos.y + withinPos.y)),
    pos.y,
    pos.y + ((followingPos.y + followingBox.height) - ((pos.y + withinPos.y) + withinBox.height))
  )
end)

--[[ END ECS SYSTEMS ]]--
-------------------------

---------------------
--[[ PICO8 LOOPS ]]--

local lastTickTime = time()
function _update60()
  local tickTime = time()
  local tDiff = tickTime - lastTickTime
  -- Important to call .update() at the start of every loop, before any Systems
  world.update()
  -- The parameters passed in here will appear as the second argument in the
  -- System's function
  move(tDiff)
  follow()
  containEntities()
  lastTickTime = tickTime
end

function _draw()
  cls(1)
  drawRenderables()
  drawRelativeRenderables()
  print("  move", 2, 2, 7)
  print("⬅️➡️⬆️⬇️ ", 2, 10, 7)
end

--[[ END PICO8 LOOPS ]]--
-------------------------
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111117771177171717771111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111117771717171717111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111117171717171717711111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111117171717177717111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111117171771117117771111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1117777711d77777ddd77777ddd77777dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd11111111
11777117717711777177717771771117711111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
11771117717711177177111771771117711111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
11777117717711777177111771777177711111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1117777711d777771117777711177777111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111cccccccccccccccccccccccccccccccccccccccc1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c11111111111111111111111111111111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c11111111111111111111111111111111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c11111111111111111111111111111111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c11111111111111111111111111111111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c11111111111111111111111111111111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c11111111111111111111111111111111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c11111111111111111111111111111111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c11111111111111111111111111111111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c11111111111111111111111111111111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c111111111ffffffffffffffffffff111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c111111111f111111111111111111f111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c111111111f111111111111111111f111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c111111111f111111111111111111f111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c111111111f111111111111111111f111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c111111111f111111111111111111f111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c111111111f111111111111111111f111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c111111111f111111111111111111f111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c111111111f111111111111111111f111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c111111111f111111111111111111f111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c111111111f111111111111111111f111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c111111111f111111111111111111f111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c111111111f111111111111111888f111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c111111111f111111111111111811f111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c111111111f111111111111111811f111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c111111111f111111111111111888f111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c111111111f111111111111111111f111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c111111111f111111111111111111f111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c111111111f111111111111111111f111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c111111111ffffffffffffffffffff111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c11111111111111111111111111111111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c11111111111111111111111111111111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c11111111111111111111111111111111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c11111111111111111111111111111111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c11111111111111111111111111111111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c11111111111111111111111111111111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c11111111111111111111111111111111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c11111111111111111111111111111111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111c11111111111111111111111111111111111111c1111111111111111111111111d11111111
1111111111d1111111111111111111111111111111111111111111cccccccccccccccccccccccccccccccccccccccc1111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111d111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111d11111111
1111111111dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd11111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111


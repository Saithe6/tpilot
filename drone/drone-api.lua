local tor = require("lib/tortise")
local commands = {}
---the id of the computer that the drone should listen for commands from
commands.CENTRAL_COMMAND = 19
---the protocal the drone should listen on
commands.PROTOCOL = "saithe.drone."..assert(os.getComputerLabel())
---the threshold where the turtle should enter fuel conservation mode
commands.fuelThreshold = 500
commands.ignoreFuelThreshold = false

local function equip(tool)
  local tools = {
    modem = "computercraft:wireless_modem_normal",
    geo = "advancedperipherals:geo_scanner",
    pickaxe = "minecraft:diamond_pickaxe",
  }
  for i = 1,16 do
    if turtle.getItemDetail(i) ~= nil and turtle.getItemDetail(i).name == tools[tool] then
      turtle.select(i)
      turtle.equipRight()
      break
    end
  end
  if tool == "modem" then rednet.open("right") end
end

local function scan()
  equip("geo")
  return peripheral.call("right","scan",8)
end

local function respond(response)
  if not rednet.isOpen("right") then equip("modem") end
  assert(rednet.send(commands.CENTRAL_COMMAND,response,commands.PROTOCOL))
end

local function receive()
  local id,msg
  repeat
    id,msg = rednet.receive(commands.PROTOCOL)
  until id == commands.CENTRAL_COMMAND
  return msg
end

local function updatePosition()
  if not rednet.isOpen("right") then equip("modem") end
  local x,y,z = gps.locate(0.5)
  tor.position = {x = x,y = y,z = z}
end

local function tortiseErrCheck(ok)
  local errcode = commands.ERROR_CODES.okay
  if not ok then
    errcode = commands.ERROR_CODES.tortise
  end
  return errcode
end

local function dirCheck(dir,nilValid,...)
  local validDirs = {...}
  if dir == nil and nilValid then return true end
  for _,v in ipairs(validDirs) do
    if v == dir then return true end
  end
  respond({errcode = commands.ERROR_CODES.tortise,result = dir.." isn't a valid turn direction"})
  return false
end

---@enum
commands.ERROR_CODES = {
  okay = 0, -- everything is okay, no errors
  tortise = 1, -- tortise threw an error
  fuelThreshold = 2, -- fuel is below threshold
  nilMessage = 3, -- received a nil message
  invalidArgs = 4, -- args are determined to be invalid
  subshellError = 5, -- and error occured in a subshell
}

function commands.fetch(updateFacing)
  updatePosition()
  if updateFacing then tor.updateFacing() end
  local scanResult,errmsg = scan()
  if not scanResult then scanResult = errmsg end
  respond({errcode = commands.ERROR_CODES.okay,result = {
    facing = tor.facing,
    fuel = turtle.getFuelLevel(),
    fuelLimit = turtle.getFuelLimit(),
    position = tor.position,
    scan = scanResult,
  }})
end

function commands.orient(dir)
  local ok,result = pcall(tor.orient,dir)
  respond({errcode = tortiseErrCheck(ok),result = result})
end

function commands.turn(dir)
  if dirCheck(dir,false,"left","right") then
    local ok,result = tor.turn(dir)
    respond({errcode = tortiseErrCheck(ok),result = result})
  end
end

function commands.detect(dir)
  if dirCheck(dir,true,"up","down","forward") then
    local ok,result = tor.turn(dir)
    respond({errcode = tortiseErrCheck(ok),result = result})
  end
end

function commands.inspect(dir)
  if dirCheck(dir,true,"up","down","forward") then
    local blockPresent,blockInfo  = tor.inspect()
    respond({errcode = commands.ERROR_CODES.okay,result = {blockPresent,blockInfo}})
  end
end

function commands.dig(dir)
  if dirCheck(dir,true,"up","down","forward") then
    equip("pickaxe")
    local blockBroken,errmsg = tor.dig()
    respond({errcode = commands.ERROR_CODES.okay,result = {blockBroken,errmsg}})
  end
end

function commands.place(dir,text)
  if dirCheck(dir,true,"up","down","forward") then
    local ok,result = tor.place(dir,text)
    respond({errcode = tortiseErrCheck(ok),result = result})
  end
end

function commands.drop(dir,count)
  if dirCheck(dir,true,"up","down","forward") then
    local ok,result = tor.drop(dir,count)
    respond({errcode = tortiseErrCheck(ok),result = result})
  end
end

function commands.compare(dir)
  if dirCheck(dir,true,"up","down","forward") then
    local areSame = tor.compare(dir)
    respond({errcode = commands.ERROR_CODES.okay,result = areSame})
  end
end

function commands.checkDenylist(blockId)
  respond({errcode = commands.ERROR_CODES.okay,result = tor.checkDenylist(blockId)})
end

local function moveDrone(dist,dir,mine)
  local movementFunc = mine and tor.mine or tor.move
  if turtle.getFuelLevel() < commands.fuelThreshold then
    respond({errcode = commands.ERROR_CODES.fuelThreshold,result = "fuel is below threshold"})
  else
    local ok,result = pcall(movementFunc,dist,dir)
    respond({errcode = tortiseErrCheck(ok),result = result})
  end
end
function commands.move(dist,dir)
  moveDrone(dist,dir,false)
end
function commands.mine(dist,dir)
  moveDrone(dist,dir,true)
end

local function vecMoveDrone(x,y,z,mine)
  local movementFunc = mine and tor.vecMine or tor.vecMove
  if turtle.getFuelLevel() < commands.fuelThreshold then
    respond({errcode = commands.ERROR_CODES.fuelThreshold,result = "fuel is below threshold"})
  else
    local ok,result = pcall(movementFunc,x,y,z)
    respond({errcode = tortiseErrCheck(ok),result = result})
  end
end
function commands.vecMove(x,y,z)
  vecMoveDrone(x,y,z,false)
end
function commands.vecMine(x,y,z)
  vecMoveDrone(x,y,z,true)
end

function commands.placePeripheral()
  tor.placePeripheral()
end

function commands.forceMineSet(val)
  if val == nil then val = false end
  if type(val) == "boolean" then
    tor.forceMine = val
    respond({errcode = commands.ERROR_CODES.okay})
  else
    respond({errcode = commands.ERROR_CODES.invalidArgs,result = "forceMine can only be a boolean"})
  end
end

function commands.forceMineGet()
  respond({errcode = commands.ERROR_CODES.okay,result = tor.forceMine})
end

function commands.ignoreFuelThresholdSet(val)
  if val == nil then val = false end
  if type(val) == "boolean" then
    commands.ignoreFuelThreshold = val
    respond({errcode = commands.ERROR_CODES.okay})
  else
    respond({errcode = commands.ERROR_CODES.invalidArgs,result = "ignoreFuelThreshold can only be a boolean"})
  end
end

function commands.ignoreFuelThresholdGet()
  respond({errcode = commands.ERROR_CODES.okay,result = commands.ignoreFuelThreshold})
end

function commands.fuelThresholdSet(val)
  if type(val) == "number" and val > 0 then
    commands.fuelThreshold = val
    respond({errcode = commands.ERROR_CODES.okay})
  else
    respond({errcode = commands.ERROR_CODES.invalidArgs,result = "fuelThreshold can only be a number greater than 0"})
  end
end

function commands.fuelThresholdGet()
  respond({errcode = commands.ERROR_CODES.okay,result = commands.fuelThreshold})
end

function commands.shellRun(path,...)
  local args = {...}
  -- TODO: input validations on args
  local ok,interupted = parallel.waitForAny(
    function()
      return shell.run(path,table.unpack(args)),false
    end,
    function()
      local id,msg
      repeat
        id,msg = receive()
      until msg == "SIGTERM"
    end
  )
  respond({errcode = ok and commands.ERROR_CODES.okay or commands.ERROR_CODES.subshellError})
end

return commands,respond,receive

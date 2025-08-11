local commands,respond,receive = require("lib/drone-api")

local function main()
  while true do
    local msg = receive()
    if msg == nil or msg.cmd == nil then
      respond({errcode = commands.ERROR_CODES.nilMessage})
    else
      print(msg.cmd)
      commands[msg.cmd](table.unpack(msg.args))
    end
  end
end
main()

require "class"

memory.usememorydomain("WRAM")

Game = class(function(game)
	game.marioX = 0
	game.marioY = 0
	game.infos = {}
	game.marioStatus = "small"
	game.hadBonus = false
	game.hasBeenHit = false
	game.boxRadius = 6
	game.inputSize = (game.boxRadius * 2 + 1) * (game.boxRadius * 2 + 1)	
	game.maxMarioLevelX = 4824
	game.buttonNames = {
		"A",
		"B",
		"X",
		"Y",
		"Up",
		"Down",
		"Left",
		"Right"
	}
	game.outputSize = #game.buttonNames
end)

function Game:clear()
	self:clearJoypad()
	self.hadBonus = false
	self.hasBeenHit = false
end

function Game:clearJoypad()
	controller = {}
	for b = 1, #self.buttonNames do
		controller["P1 " .. self.buttonNames[b]] = false
	end
	joypad.set(controller)
end

function Game:setJoypad(outputs)
	if #outputs ~= #self.buttonNames then
		error("Invalid outputs and joypad definition : " .. #outputs .. " and " .. #self.buttonNames)
	end
	controller = {}
	for i = 1, #self.buttonNames do
		if outputs[i] > 0 then
			controller["P1 " .. self.buttonNames[i]] = true
		else
			controller["P1 " .. self.buttonNames[i]] = false
		end
	end
	joypad.set(controller)
end
			
function Game:setPositions()
	self.marioX = memory.read_s16_le(0x94)
	self.marioY = memory.read_s16_le(0x96)
end

function Game:getSprites()
	local sprites = {}
	for slot = 0, 11 do
		local status = memory.readbyte(0x14C8 + slot)
		if status ~= 0 then
			spritex = memory.readbyte(0xE4 + slot) + memory.readbyte(0x14E0 + slot) * 256
			spritey = memory.readbyte(0xD8 + slot) + memory.readbyte(0x14D4 + slot) * 256
			sprites[#sprites+1] = {["x"]=spritex, ["y"]=spritey}
		end
	end		

	return sprites
end

function Game:checkHit()
	local status = memory.readbyte(0x19)
	local result = false
	if status == 0 then
		if self.hadBonus then
			self.hasBeenHit = true
		end
		self.hadBonus = false
		self.marioStatus = "small";
	end
	if status == 1 then
		self.hadBonus = true
		self.marioStatus = "big";
	end
	if status == 2 then
		self.hadBonus = true
		self.marioStatus = "cape";
	end
	if status == 3 then
		self.hadBonus = true
		self.marioStatus = "fire";
	end
end

function Game:getExtendedSprites()
	local extended = {}
	for slot = 0, 11 do
		local number = memory.readbyte(0x170B + slot)
		if number ~= 0 then
			spritex = memory.readbyte(0x171F + slot) + memory.readbyte(0x1733 + slot) * 256
			spritey = memory.readbyte(0x1715 + slot) + memory.readbyte(0x1729 + slot) * 256
			extended[#extended+1] = {["x"]=spritex, ["y"]=spritey}
		end
	end		
	
	return extended
end

function Game:getTile(dx, dy)
	local x = math.floor((self.marioX + dx + 8) / 16)
	local y = math.floor((self.marioY + dy) / 16)
	local addr = 0x1C800 + math.floor(x/0x10)*0x1B0 + y*0x10 + x%0x10;	
	return memory.readbyte(addr)
--	tiles[#tiles+1] = tile
--	return tile + .0

end

function Game:setInfos()
	self:setPositions()	
	sprites = self:getSprites()
	extended = self:getExtendedSprites()	
	
	local infos = {}
--	local tiles = {}
	local distx = 0
	local disty = 0
	
	for dy =- self.boxRadius * 16, self.boxRadius * 16, 16 do
		for dx =- self.boxRadius * 16, self.boxRadius * 16, 16 do
			infos[#infos+1] = 0
			tile = self:getTile(dx, dy)
			if tile == 1 then
				infos[#infos] = 1 + .0
			end
			
			for i = 1,#sprites do
				distx = math.abs(sprites[i]["x"] - (self.marioX + dx))
				disty = math.abs(sprites[i]["y"] - (self.marioY + dy))
				if distx <= 8 and disty <= 8 then
					infos[#infos] = -1 + .0
				end
			end
 
			for i = 1,#extended do
				distx = math.abs(extended[i]["x"] - (self.marioX + dx))
				disty = math.abs(extended[i]["y"] - (self.marioY + dy))
				if distx < 8 and disty < 8 then
					infos[#infos] = -1 + .0
				end
			end
		end
	end
	
	self.infos = infos
	return infos
end

function Game:getTimer()
	return memory.read_u8(0xF31) * 100 + memory.read_u8(0xF32) * 10 + memory.read_u8(0xF33)
end
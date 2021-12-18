require "genome"
require "network"
require "neat_utils"
require "mutation"
require "pool"
require "game"

local json = require("json")
memory.usememorydomain("WRAM")
local outputs = {0,0,0,0,0,0,0,0}
local filename = "level1.State"

function initializeRun()
	decreaseFitness = false
	savestate.load(filename);
	game:clear()
	game.frame = 0
	local genome = pool:getCurrentGenome()
	genome.network = Network()
	genome.network:generate(genome)
end

function evaluateGenome(genome)
	outputs = genome.network:evaluate(genome, game.infos)
	game:setJoypad(outputs)
end

function nextGenomeToRun(pool)
	while pool:getCurrentGenome().fitness ~= -1 do
		pool:nextGenome()
	end
end

function loadPoolFromFile(filename)
	pool:loadFromFile("genomes/" .. filename)
	pool.currentSpecies = 1
	pool.currentGenome = 1
	nextGenomeToRun(pool)
end

game = Game()
game:setInfos()

decreaseFitness = false
frame = 0
fitness = 0
marioStartX = game.marioX
maxMarioX = marioStartX
timeOutBonus = 0
timeOutInitial = 60
timeOut = timeOutInitial
maxxFitness = 0
pool = Pool(300)
pool:initialize(#game.infos, #game.buttonNames)
--loadPoolFromFile("lastpool.poo")
--pool:resetFitnesses()

initializeRun()
local backgroundColor = 0xFFFFFFFF

while true do
	gui.drawBox(0, 0, 300, 26, backgroundColor, backgroundColor)
	game:setInfos()
	local genome = pool:getCurrentGenome()
	if frame % 5 == 0 then
		evaluateGenome(genome)
	end
	game:setJoypad(outputs)
	game:checkHit()
	if timeOut <= 0 then
		fitness = math.max(0, maxMarioX - marioStartX - frame / 4)
		if maxMarioX >= game.maxMarioLevelX then
			fitness = fitness + 10000
		end
		if game.hasBeenHit then
			fitness = fitness - 200
		end
		timeOut = timeOutInitial
		timeOutBonus = 0
		maxMarioX = 0
		frame = 0
		genome.fitness = fitness
		console.log("Generation = " .. pool.generation .. " species = " .. pool.currentSpecies .. " Fitness = " .. fitness)
		nextGenomeToRun(pool)
		initializeRun()		
	elseif maxMarioX < game.marioX then
		maxMarioX = game.marioX
		timeOutBonus = (maxMarioX - marioStartX) / 4
		timeOut = timeOutInitial + timeOutBonus		
		frame = frame + 1
	end
	local progress = pool:getProgess()
	gui.drawText(0, 0, "Gen " .. pool.generation .. " species " .. pool.currentSpecies .. " genome " .. pool.currentGenome .. 
		" (" .. math.floor(progress[1] / progress[2] * 100) .. "%)", 0xFF000000, 11)
	local displayFitness = math.floor(maxMarioX - marioStartX - frame / 4)
	if game.hasBeenHit and not decreaseFitness then
		decreaseFitness = true
		displayFitness = displayFitness - 200
	end
	gui.drawText(0, 12, "Fitness: " .. math.max(0, displayFitness), 0xFF000000, 11)
	gui.drawText(100, 12, "Max Fitness: " .. math.floor(pool.maxFitness), 0xFF000000, 11)
	timeOut = timeOut - 1
	emu.frameadvance()
end
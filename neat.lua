require "genome"
require "network"
require "neat_utils"
require "mutation"
require "pool"
local json = require("json")

local genomeDirectory = "genomes/"

function evaluate(pool)
	local maxFitness = 0
	local generation = 1
	local result = {}
	while maxFitness ~= 1600 and generation < 30 do
		pool:saveToFile(genomeDirectory .. "pool" .. pool.generation .. ".poo")
		result = evaluateGeneration(pool)
		maxFitness = result.maxFitness
		pool:newGeneration()		
		local genomesCount = 0
		for i = 1, #pool.species do
			genomesCount = genomesCount + #pool.species[i].genomes
		end
		generation = generation + 1
	end
	console.log("Generation : " .. generation)
	console.log("Fitness = " .. result.bestGenome.fitness)
	pool:saveToFile(genomeDirectory .. "pool.poo")
	result.bestGenome:saveToFile(genomeDirectory .. "genomeG" .. pool.generation .. ".gen")
end

function evaluateGeneration(pool)
	local maxFitness = 0
	local bestGenome = {}
	local result = {}
	for i = 1, #pool.species do
		local species = pool.species[i]
		for j = 1, #species.genomes do
			local fitness = 0
			local genome = species.genomes[j]
			local network = Network()
			local inputs = {0, 0}
			network:generate(genome)
			local outputs = network:evaluate(genome, inputs)
			if outputs[1] < 0 then
				fitness = fitness + 10
			end
			inputs = {0, 1}
			outputs = network:evaluate(genome, inputs)
			if outputs[1] > 0 then
				fitness = fitness + 10
			end
			inputs = {1, 0}
			outputs = network:evaluate(genome, inputs)
			if outputs[1] > 0 then
				fitness = fitness + 10
			end
			inputs = {1, 1}
			outputs = network:evaluate(genome, inputs)
			if outputs[1] < 0 then
				fitness = fitness + 10
			end
			genome.fitness = fitness * fitness
			if genome.fitness > maxFitness then
				maxFitness = genome.fitness
				bestGenome = genome
			end
			genome.network = network
		end
	end
	result.maxFitness = maxFitness
	result.bestGenome = bestGenome
	return result
end

function executeBest(filename)
	local genome = Genome()
	genome:loadFromFile(filename)
	local network = Network()
	local inputs = {0, 0}
	network:generate(genome)
	local outputs = network:evaluate(genome, inputs)
	if outputs[1] < 0 then
		console.log("false")
	else
		console.log("true")
	end	
	inputs = {0, 1}
	outputs = network:evaluate(genome, inputs)
	if outputs[1] < 0 then
		console.log("false")
	else
		console.log("true")
	end	
	inputs = {1, 0}
	outputs = network:evaluate(genome, inputs)
	if outputs[1] < 0 then
		console.log("false")
	else
		console.log("true")
	end
	inputs = {1, 1}
	outputs = network:evaluate(genome, inputs)
	if outputs[1] < 0 then
		console.log("false")
	else
		console.log("true")
	end
end

function evolve()
	local pool = Pool(150)
	pool:initialize(2, 1)
	evaluate(pool)
end

function testNetwork(inputs, network)
	outputs = network:evaluate(genome, inputs)
	if outputs[1] < 0 then
		console.log("false")
	else
		console.log("true")
	end
end

function evaluateNetwork(inputs, network, genome, fitness)
	local outputs = network:evaluate(genome, inputs)
	if outputs[1] < 0 then
		fitness = fitness + 10
	end
	return fitness
end

function test(func, ...)
	return func(...)
end

function truc(machin)
	machin = machin + 10
	return machin
end
--[[
local pool = Pool(3)
pool:initialize(2, 1)
for i = 1, #pool.species do
	local species = pool.species[i]
	for j = 1, #species.genomes do
		local genome = species.genomes[j]
		local network = Network()
		network:generate(genome)
	end
end
console.log("-----------------------")
pool:newGeneration()
for i = 1, #pool.species do
	local species = pool.species[i]
	for j = 1, #species.genomes do
		local genome = species.genomes[j]
		local network = Network()
		network:generate(genome)
	end
end
console.log("-----------------------")
pool:newGeneration()
for i = 1, #pool.species do
	local species = pool.species[i]
	for j = 1, #species.genomes do
		local genome = species.genomes[j]
		local network = Network()
		network:generate(genome)
	end
end
--]]
--local var = 15
--var = truc(var)
--console.log(var)
--str = test(call, "caca")
--console.log(str)
evolve()
--local p = Pool()
--p:loadFromFile(genomeDirectory .. "pool.poo")
--p:saveToFile(genomeDirectory .. "pool_back.poo")

--executeBest("genomes/genomeG11.gen")

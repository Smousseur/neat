require "genome"
require "network"
require "neat_utils"
require "mutation"
require "pool"
local json = require("json")

function evaluate(pool)
	local maxFitness = 0
	local generation = 1
	local result = {}
	while maxFitness ~= 1600 do
		result = evaluateGeneration(pool)
		maxFitness = result.maxFitness
		pool:newGeneration()
		generation = generation + 1
	end
	console.log("Generation : " .. generation)
	console.log("Fitness = " .. result.bestGenome.fitness)
	result.bestGenome:saveToFile("bestGenome.gen")
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
			if outputs[1] < 0.5 then
				fitness = fitness + 10
			end
			inputs = {0, 1}
			local outputs = network:evaluate(genome, inputs)
			if outputs[1] > 0.5 then
				fitness = fitness + 10
			end
			inputs = {1, 0}
			local outputs = network:evaluate(genome, inputs)
			if outputs[1] > 0.5 then
				fitness = fitness + 10
			end
			inputs = {1, 1}
			local outputs = network:evaluate(genome, inputs)
			if outputs[1] < 0.5 then
				fitness = fitness + 10
			end
			genome.fitness = fitness * fitness
			if genome.fitness > maxFitness then
				maxFitness = genome.fitness
				bestGenome = genome
			end
		end
	end
	result.maxFitness = maxFitness
	result.bestGenome = bestGenome
	return result
end

function executeBest()
	local genome = Genome()
	genome:loadFromFile("bestGenome.gen")
	local network = Network()
	local inputs = {0, 0}
	network:generate(genome)
	local outputs = network:evaluate(genome, inputs)
	if outputs[1] < 0.5 then
		console.log("false")
	else
		console.log("true")
	end	
	inputs = {0, 1}
	outputs = network:evaluate(genome, inputs)
	if outputs[1] < 0.5 then
		console.log("false")
	else
		console.log("true")
	end	
	inputs = {1, 0}
	outputs = network:evaluate(genome, inputs)
	if outputs[1] < 0.5 then
		console.log("false")
	else
		console.log("true")
	end
	inputs = {1, 1}
	outputs = network:evaluate(genome, inputs)
	if outputs[1] < 0.5 then
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

evolve()
executeBest()

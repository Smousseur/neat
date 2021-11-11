require "class"
local json = require("json")

local deltaDisjoint = 2.0
local deltaExcess = 2.0
local deltaWeights = 0.4
local deltaThreshold = 1.0
local staleSpecies = 15
local crossoverChance = 0.75

Species = class(function(species)
			species.genomes = {}
			species.topFitness = 0
			species.staleness = 0
			species.averageFitness = 0			
		end)
		
Pool = class(function(pool, population)
			pool.species = {}
			pool.generation = 0
			pool.currentSpecies = 1
			pool.currentGenome = 1
			pool.maxFitness = 0		
			pool.population = population
			pool.inputCount = 0
			pool.outputCount = 0
		end)

function Pool:addGenome(genome)
	for _, species in pairs(self.species) do
		if #species.genomes > 0 then
			local representGenome = species.genomes[math.random(1, #species.genomes)]
			local diff = representGenome:compare(genome)
			local delta = (deltaExcess * diff.excessCount + deltaDisjoint * diff.disjointCount) / diff.maxGenomeLen + deltaWeights * diff.averageWeight
			if delta < deltaThreshold then
				table.insert(species.genomes, genome)
				return
			end
		end
	end
	newSpecies = Species()
	table.insert(newSpecies.genomes, genome)
	table.insert(self.species, newSpecies)
end

function Pool:rankAllGenomes()
	local allGenomes = {}
	for _, species in pairs(self.species) do
		tableAddAll(allGenomes, species.genomes)
	end
	table.sort(allGenomes, function (left, right)
		return left.fitness < right.fitness
	end)
	for i = 1, #allGenomes do
		allGenomes[i].globalRank = i
	end
	return allGenomes[#allGenomes]
end

function Pool:computeFitnesses()
	for _, species in pairs(self.species) do
		species:computeFitnesses()
	end
end

function Species:computeFitnesses()
	local topFitness = 0
	local globalRank = 0
	for _, genome in pairs(self.genomes) do
		if genome.fitness > topFitness then
			topFitness = genome.fitness			
		end
		globalRank = globalRank + genome.globalRank
	end
	self.topFitness = topFitness
	if #self.genomes > 0 then
		self.averageFitness = globalRank / #self.genomes
	end
end

function Species:sort()
	table.sort(self.genomes, function (left, right)
		return left.fitness > right.fitness
	end)
end

function Species:createChild(pool)
	local child = Genome()
	if math.random() < crossoverChance then
		local parent1 = self.genomes[math.random(1, #self.genomes)]
		local parent2 = self.genomes[math.random(1, #self.genomes)]
		child = parent1:crossover(parent2)
	else
		local parent = self.genomes[math.random(1, #self.genomes)]
		child:copyFrom(parent)
	end
	child:mutate()
	child:assureCoherence(pool.inputCount, pool.outputCount)
	return child
end

function Pool:cullSpecies(cutToOne)
	for s = 1,#self.species do
		local species = self.species[s]
		species:sort()
		local remaining = math.ceil(#species.genomes / 2)
		if cutToOne then
			remaining = 1
		end
		while #species.genomes > remaining do
			table.remove(species.genomes)
		end		
	end
end

function Pool:removeStaleSpecies()
	local survived = {} 
	for s = 1,#self.species do
		local species = self.species[s]
		species:sort()		
		if species.genomes[1].fitness > species.topFitness then
			species.topFitness = species.genomes[1].fitness
			species.staleness = 0
		else
			species.staleness = species.staleness + 1
		end
		if species.staleness < staleSpecies or species.topFitness >= self.maxFitness then
			table.insert(survived, species)
		end
	end
	self.species = survived
end

function Pool:removeWeakSpecies()
	local survived = {}
 
	local sum = self:totalAverageFitness()
	for s = 1,#self.species do
		local species = self.species[s]
		local breed = math.floor(species.averageFitness / sum * self.population)
		if breed >= 1 then
			table.insert(survived, species)
		end
	end
 
	self.species = survived
end

function Pool:totalAverageFitness()
	local total = 0
	for s = 1,#self.species do
		local species = self.species[s]
		total = total + species.averageFitness
	end
 
	return total
end

function Pool:initialize(inputCount, outputCount)
	self.inputCount = inputCount
	self.outputCount = outputCount
	for i = 1, self.population do
		local genome = Genome()
		genome:initialize(inputCount, outputCount)
		self:addGenome(genome)
	end
end

function Pool:newGeneration()
	self:cullSpecies(false)
	self:rankAllGenomes()
	self:removeStaleSpecies()
	self:rankAllGenomes()
	self:computeFitnesses()
	self:removeWeakSpecies()
	local sum = self:totalAverageFitness()
	local children = {}
	for s = 1,#self.species do
		local species = self.species[s]
		local childrenToCreate = math.floor(species.averageFitness / sum * self.population) - 1
		for i = 1, childrenToCreate do
			table.insert(children, species:createChild(self))
		end
	end
	self:cullSpecies(true)
	for i = #children, self.population do
		local species = self.species[math.random(1, #self.species)]
		table.insert(children, species:createChild(self))		
	end
	
	for i = 1, #children do
		local child = children[i]
		self:addGenome(child)
	end
	
	self.generation = self.generation + 1
end

function Pool:print()
	console.log(json.encode(self))
end

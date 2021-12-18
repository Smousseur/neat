require "class"
local json = require("json")

local deltaDisjoint = 2.0
local deltaExcess = 2.0
local deltaWeights = 0.4
local deltaThreshold = 0.5
local staleSpecies = 15
local crossoverChance = 0.75

local genomeDirectory = "genomes/"

Species = class(function(species)
	species.genomes = {}
	species.topFitness = 0
	species.staleness = 0
	species.averageFitness = 0
	species.fitness = 0
end)
		
Pool = class(function(pool, population)
	pool.species = {}
	pool.game = {}
	pool.generation = 1
	pool.currentSpecies = 1
	pool.currentGenome = 1
	pool.maxFitness = 0		
	pool.population = population
	pool.inputCount = 0
	pool.outputCount = 0
end)

function Pool:nextGenome()
	self.currentGenome = self.currentGenome + 1
	if self.currentGenome > #self.species[self.currentSpecies].genomes then
		self.currentGenome = 1
		self.currentSpecies = self.currentSpecies + 1
		if self.currentSpecies > #self.species then
			self:generateReport()
			self:newGeneration()
			self.currentSpecies = 1
		end
	end
end

function Pool:generateReport(bestGenome)
	local poolReport = Pool()
	poolReport:copyFrom(self)
	local bestGenome = poolReport:rankAllGenomes()
	bestGenome:saveToFile(genomeDirectory .. "genomeG" .. self.generation .. ".gen")
	poolReport:rankAllGenomes()
	poolReport:computeFitnesses()
	poolReport:printResume(genomeDirectory .. "poolResume" .. self.generation .. ".res")
	poolReport:saveToFile(genomeDirectory .. "pool-" .. self.generation .. ".poo")	
end

function Pool:getCurrentGenome()
	local species = self.species[self.currentSpecies]
	local genome = species.genomes[self.currentGenome]
	return genome
end

function Pool:getProgess()
	local total = 0
	local tested = 0
	for _, species in pairs(self.species) do
		for _, genome in pairs(species.genomes) do
			total = total + 1
			if genome.fitness ~= -1 then
				tested = tested + 1
			end
		end
	end
	return {tested, total}
end

function Pool:addGenome(genome)
	local foundSpecies = false
	for _, species in pairs(self.species) do
		if #species.genomes > 0 then
			local representGenome = species.genomes[math.random(1, #species.genomes)]
			if genome:sameSpecies(representGenome) then
				table.insert(species.genomes, genome)
				return
			end
		end
	end
	newSpecies = Species()
	table.insert(newSpecies.genomes, genome)
	table.insert(self.species, newSpecies)
end

function Pool:addToNewSpecies(genome)
	newSpecies = Species()
	table.insert(newSpecies.genomes, genome)
	table.insert(self.species, newSpecies)
end

function Genome:sameSpecies(genome)
	local disjoints = self:disjoint(genome) * deltaDisjoint
	local weights = self:weights(genome) * deltaWeights
	return disjoints + weights < deltaThreshold
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
	self.maxFitness = allGenomes[#allGenomes].fitness
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
	local fitness = 0
	for _, genome in pairs(self.genomes) do
		if genome.fitness > topFitness then
			topFitness = genome.fitness			
		end
		fitness = fitness + genome.fitness
		globalRank = globalRank + genome.globalRank
	end
	self.topFitness = topFitness
	self.fitness = fitness / #self.genomes
	if #self.genomes > 0 then
		self.averageFitness = globalRank / #self.genomes
	end
end

function Species:sort()
	table.sort(self.genomes, function (left, right)
		return left.fitness > right.fitness
	end)
end

function Pool:getGenomesCount()
	local genomesCount = 0
	for i = 1, #self.species do
		genomesCount = genomesCount + #self.species[i].genomes
	end
	return genomesCount
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
	child.fitness = -1.0
	child:checkGenes()
	child:mutate()
	child:checkGenes()
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

function Pool:getFitness()
	local total = 0
	for s = 1,#self.species do
		local species = self.species[s]
		total = total + species.fitness
	end
 
	return total / #self.species
end

function Pool:initialize(inputCount, outputCount)
	self.inputCount = inputCount
	self.outputCount = outputCount
	for i = 1, self.population do
		local genome = Genome()
		genome:initialize(inputCount, outputCount)
		self:addToNewSpecies(genome)
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
	for s = 1, #self.species do
		local species = self.species[s]
		local childrenToCreate = math.floor(species.averageFitness / sum * self.population) - 1
		for i = 1, childrenToCreate do
			table.insert(children, species:createChild(self))
		end
	end
	self:cullSpecies(true)
	while #children + #self.species < self.population do
		local species = self.species[math.random(1, #self.species)]
		table.insert(children, species:createChild(self))		
	end
	
	for i = 1, #children do
		local child = children[i]
		self:addGenome(child)
	end
	
	self.generation = self.generation + 1
end

function Pool:printResume(filename)
	local file = io.open(filename, "a")
	file:write("Generation " .. self.generation .. "\n")
	local avg = self:totalAverageFitness() / #self.species
	file:write("Average rank = " .. avg .. "\n")	
	file:write("Top fitness = " .. self.maxFitness .. "\n")	
	file:write("Average fitness = " .. self:getFitness() .. "\n")	
	for s = 1,#self.species do
		local species = self.species[s]
		file:write("Species " .. s .. "\n")	
		file:write("	Genomes count = " .. #species.genomes .. "\n")	
		file:write("	Top fitness = " .. species.topFitness .. "\n")	
		file:write("	Staleness = " .. species.staleness .. "\n")	
		file:write("	Average rank = " .. species.averageFitness .. "\n")	
		file:write("	Average fitness = " .. species.fitness .. "\n")			
	end
	file:write("------------------------------------------------------\n\n")
	file:close()
end

function Pool:print()
	console.log(json.encode(self))
end

function Species:copyFrom(species)
	for i = 1, #species.genomes do
		local g = Genome()
		g:copyFrom(species.genomes[i])
		table.insert(self.genomes, g)
	end
	self.topFitness = species.topFitness
	self.staleness = species.staleness
	self.averageFitness = species.averageFitness
	self.fitness = species.fitness
end

function Pool:copyFrom(pool)
	for i = 1, #pool.species do
		local s = Species()
		s:copyFrom(pool.species[i])
		table.insert(self.species, s)
	end
	self.game = pool.game
	self.generation = pool.generation
	self.currentSpecies = pool.currentSpecies
	self.currentGenome = pool.currentGenome
	self.maxFitness = pool.maxFitness
	self.population = pool.population
	self.inputCount = pool.inputCount
	self.outputCount = pool.outputCount
end

function Species:saveToFile(filename)
	local file = io.open(filename, "w")
	local speciesToSave = Species()
	speciesToSave:copyFrom(self)
	file:write(json.encode(speciesToSave))
	file:close()	
end

function Species:loadFromContent(content)
	local species = json.decode(content)
	self:copyFrom(species)	
end

function Pool:saveToFile(filename)
	local file = io.open(filename, "w")
	local poolToSave = Pool()
	poolToSave:copyFrom(self)
	file:write(json.encode(poolToSave))
	file:close()	
end

function Pool:loadFromFile(filename)
	local file = io.open(filename, "r")
	local content = file:read("*all")
	local pool = json.decode(content)
	self:copyFrom(pool)
	file:close()
end

function Pool:logDiff(diff, disjoint)
	local file = io.open("genomes/diff.log", "a")
	file:write(diff .. ", " .. disjoint .. "\n")
	file:close()
end

function Pool:resetFitnesses()
	for _, species in pairs(self.species) do
		for _, genome in pairs(species.genomes) do
			if genome.fitness == pool.maxFitness then
				genome.fitness = -1
			else
				genome.fitness = 0
			end
		end
	end
end

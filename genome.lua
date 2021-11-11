require "class"
require "math"
local json = require("json")

Gene = class(function(gene, genome, nodeType)
			gene.id = genome:getNextGeneId()
			gene.type = nodeType
		end)

function Gene:print()
	console.log(self.innovationId)
end

function Gene:copyFrom(gene)
	self.id = gene.id
	self.type = gene.type
end

ConnectionGene = class(function(gene, genome, nodeIn, nodeOut, weight)
			gene.nodeIn = nodeIn
			gene.nodeOut = nodeOut
			gene.weight = weight
			gene.innovationId = genome:getNextInnovationId()
			gene.active = true
		end)
function ConnectionGene:copyFrom(gene)	
	self.nodeIn = gene.nodeIn
	self.nodeOut = gene.nodeOut
	self.weight = gene.weight
	self.innovationId = gene.innovationId
	self.active = gene.active
end		

function ConnectionGene:activate(active)
	self.active = active
end
		
Genome = class(function(genome)
			genome.genes = {}
			genome.connectionGenes = {}
			genome.fitness = 0.0
			genome.geneInnovation = 1
			genome.connectionInnovation = 1
			genome.globalRank = 0
		end)
		
function Genome:copyFrom(genome)
	for i = 1, #genome.genes do
		local gene = Gene(genome)
		gene:copyFrom(genome.genes[i])
		self.genes[#self.genes+1] = gene
	end
	for i = 1, #genome.connectionGenes do
		local gene = ConnectionGene(genome)
		gene:copyFrom(genome.connectionGenes[i])
		self.connectionGenes[#self.connectionGenes+1] = gene
	end
	self.fitness = genome.fitness
	self.geneInnovation = genome.geneInnovation
	self.connectionInnovation = genome.connectionInnovation
	self.globalRank = genome.globalRank	
end

function Genome:isConnectionExists(nodeIn, nodeOut)
	local result = false
	for _, gene in pairs(self.connectionGenes) do
		if nodeIn == gene.nodeIn.id and nodeOut == gene.nodeOut.id then
			result = true
			break
		end
	end
	return result
end

function Genome:isGeneExists(gene)
	local result = false
	for _, g in pairs(self.genes) do
		if g.id == gene.id then
			result = true
			break
		end
	end
	return result
end
		
function Genome:addGene(gene)
	table.insert(self.genes, gene)
end		

function Genome:addConnectionGene(gene)
	table.insert(self.connectionGenes, gene)
end		

function Genome:sortByInnovation()
	table.sort(self.connectionGenes, function (left, right)
		return left.innovationId < right.innovationId
	end)
	table.sort(self.genes, function (left, right)
		return left.id < right.id
	end)
end

function Genome:sortByNodeOut()
	table.sort(self.connectionGenes, function (left, right)
		local lNodeOut = left.nodeOut
		local rNodeOut = right.nodeOut
		local lNodeIn = left.nodeIn
		local rNodeIn = right.nodeIn
		if (lNodeIn.type ~= "Sensor" and rNodeIn.type == "Sensor") then
			return false
		elseif (lNodeIn.type == "Sensor" and rNodeIn.type ~= "Sensor") then
			return true
		end
		if (lNodeOut.type ~= "Output" and rNodeOut.type == "Output") then
			return true
		elseif (lNodeOut.type == "Output" and rNodeOut.type ~= "Output") then
			return false
		else 
			return (left.nodeOut.id < right.nodeOut.id)
		end
	end)
end

function Genome:compare(genome)
	local result = {}
	local matchs = {}
	local disjoints = {}
	local excess = {}
	local matchCount = 0
	local disjointCount = 0
	local excessCount = 0
	local genes = {}
	local weightDifference = 0
	self:sortByInnovation()
	genome:sortByInnovation()
	local len1 = #self.connectionGenes
	local len2 = #genome.connectionGenes
	
	local maxGenomeLen = math.max(len1, len2)
	local i1 = 1
	local i2 = 1
	for i = 1, maxGenomeLen do
		if (i1 <= len1 and i2 <= len2) then
			local c1 = self.connectionGenes[i1]
			local c2 = genome.connectionGenes[i2]
			if c1.innovationId == c2.innovationId then
				matchCount = matchCount + 1
				weightDifference = weightDifference + math.abs(c1.weight - c2.weight)
				if math.random() > 0.5 then					
					matchs[#matchs+1] = c1
				else
					matchs[#matchs+1] = c2
				end
				i1 = i1 + 1
				i2 = i2 + 1
			elseif c1.innovationId > c2.innovationId then
				disjointCount = disjointCount + 1
				if genome.fitness >= self.fitness then
					disjoints[#disjoints+1] = c2
				end
				i2 = i2 + 1				
			elseif c1.innovationId < c2.innovationId then
				disjointCount = disjointCount + 1
				if self.fitness >= genome.fitness then
					disjoints[#disjoints+1] = c1
				end
				i1 = i1 + 1				
			end
		end
		if i1 > len1 then
			excessCount = excessCount + 1
			if genome.fitness >= self.fitness then
				excess[#excess+1] = genome.connectionGenes[i2]
			end
			i2 = i2 + 1
		elseif i2 > len2 then
			excessCount = excessCount + 1
			if self.fitness >= genome.fitness then
				excess[#excess+1] = self.connectionGenes[i1]
			end
			i1 = i1 + 1
		end
	end
	result.matchs = matchs
	result.disjoints = disjoints
	result.excess = excess
	result.matchCount = matchCount
	result.disjointCount = disjointCount
	result.excessCount = excessCount
	result.maxGenomeLen = maxGenomeLen
	result.averageWeight = weightDifference / matchCount
	return result
end

function Genome:crossover(parent2)
	child = Genome()
	local diff = self:compare(parent2)
	local allGenes = {}
	for _, gene in pairs(diff.matchs) do
		local newGene = ConnectionGene(child)
		newGene:copyFrom(gene)
		table.insert(child.connectionGenes, newGene)
		table.insert(allGenes, gene)
	end
	for _, gene in pairs(diff.disjoints) do
		local newGene = ConnectionGene(child)
		newGene:copyFrom(gene)
		table.insert(child.connectionGenes, newGene)
		table.insert(allGenes, gene)
	end
	for _, gene in pairs(diff.excess) do
		local newGene = ConnectionGene(child)
		newGene:copyFrom(gene)
		table.insert(child.connectionGenes, newGene)
		table.insert(allGenes, gene)
	end
	for _, gene in pairs(allGenes) do
		if not child:isGeneExists(gene.nodeIn) then
			local newGene = Gene(child)			
			newGene:copyFrom(gene.nodeIn)
			table.insert(child.genes, newGene)
		end
		if not child:isGeneExists(gene.nodeOut) then
			local newGene = Gene(child)			
			newGene:copyFrom(gene.nodeOut)
			table.insert(child.genes, newGene)
		end
	end
	child:sortByInnovation()
	return child
end

function Genome:assureCoherence(inputsCount, outputsCount)
	local inputs = {}
	local outputs = {}
	for _, connection in pairs(self.connectionGenes) do
		if connection.nodeIn.type == "Sensor" then
			if inputs[connection.nodeIn.id] == nil then
				inputs[connection.nodeIn.id] = connection
			elseif not inputs[connection.nodeIn.id].active then
				inputs[connection.nodeIn.id] = connection
			end
		elseif connection.nodeOut.type == "Output" then
		end
	end
	for _, input in pairs(inputs) do
		input.active = true
	end
end

function Genome:hasConnectionInArray(array, connection)
	local result = false
	for _, c in pairs(array) do
		if c.innovationId == connection.innovationId then
			result = true
			break
		end
	end
	return result
end

function Genome:isGeneExists(geneToTest)
	result = false
	for _, gene in pairs(self.genes) do
		if gene.id == geneToTest.id then
			result = true
			break
		end
	end
	return result
end

function Genome:getNextInnovationId()
	local result = self.connectionInnovation
	self.connectionInnovation = self.connectionInnovation + 1
	return result
end

function Genome:getNextGeneId()
	local result = self.geneInnovation
	self.geneInnovation = self.geneInnovation + 1
	return result
end

function printDiff(diff)
	console.log("Matchs")
	for i = 1, #diff.matchs do
		console.log(diff.matchs[i])
	end
	console.log("Disjoints")
	for i = 1, #diff.disjoints do
		console.log(diff.disjoints[i])
	end
	console.log("Excess")
	for i = 1, #diff.excess do
		console.log(diff.excess[i])
	end	
end

function Genome:getGenesFromType(geneType)
	local genes = {}
	for i = 1, #self.genes do
		local gene = self.genes[i]
		if gene.type == geneType then
			table.insert(genes, gene)
		end
	end
	return genes
end

function Genome:initialize(inputsCount, outputsCount)
	for i = 1, inputsCount do
		local gene = Gene(self , "Sensor")
		self:addGene(gene)
	end
	for i = 1, outputsCount do
		local gene = Gene(self , "Output")
		self:addGene(gene)
	end
	local inputs = self:getGenesFromType("Sensor")
	local outputs = self:getGenesFromType("Output")
	
	for i = 1, #inputs do
		local input = inputs[i]
		for j = 1, #outputs do
			local output = outputs[j]
			local connection = ConnectionGene(self, input, output, math.random() * 2 - 1)
			self:addConnectionGene(connection)
		end
	end
	local bias = Gene(self, "Bias")
	self:addGene(bias)
	for j = 1, #outputs do
		local output = outputs[j]
		local connectionBias = ConnectionGene(self, bias, output, 1)
		self:addConnectionGene(connectionBias)
	end
--	self:mutate()
end

function Genome:print()
	console.log("Genes count = " .. #self.genes)
	console.log("Connections count = " .. #self.connectionGenes)
	console.log(json.encode(self))
end

function Genome:saveToFile(filename)
	local file = io.open(filename, "w")
	file:write(json.encode(self))	
	file:close()
end

function Genome:loadFromFile(filename)
	local file = io.open(filename, "r")
	local content = file:read("*all")
	local genome = json.decode(content)	
	for i = 1, #genome.genes do
		local gene = Gene(self)
		gene:copyFrom(genome.genes[i])
		self.genes[#self.genes+1] = gene
	end
	for i = 1, #genome.connectionGenes do
		local gene = ConnectionGene(self)
		gene:copyFrom(genome.connectionGenes[i])
		self.connectionGenes[#self.connectionGenes+1] = gene
	end
	self.fitness = genome.fitness
	self.geneInnovation = genome.geneInnovation
	self.connectionInnovation = genome.connectionInnovation
	self.globalRank = genome.globalRank	

	file:close()
end
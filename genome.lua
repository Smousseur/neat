require "class"
require "math"
local json = require("json")

weightConnectionsChance = 0.25
perturbChance = 0.90
crossoverChance = 0.75
linkMutationChance = 2.0
nodeMutationChance = 0.5
biasMutationChance = 0.4
stepSize = 0.1
disableMutationChance = 0.9
enableMutationChance = 0.2

Gene = class(function(gene, genome, nodeType)
	if genome ~= nil then
		gene.id = genome:getNextGeneId()
	else
		gene.id = -1
	end
	gene.type = nodeType
end)

ConnectionGene = class(function(gene, genome, nodeIn, nodeOut, weight)
	gene.nodeIn = nodeIn
	gene.nodeOut = nodeOut
	gene.weight = weight
	if genome ~= nil then
		gene.innovationId = genome:getNextInnovationId()
	else
		gene.innovationId = -1
	end
	gene.active = true
end)

Genome = class(function(genome)
	genome.genes = {}
	genome.connectionGenes = {}
	genome.network = {}
	genome.fitness = -1.0
	genome.geneInnovation = 1
	genome.connectionInnovation = 1
	genome.globalRank = 0
	genome.mutationRates = {}
	genome.mutationRates["weights"] = weightConnectionsChance
	genome.mutationRates["link"] = linkMutationChance
	genome.mutationRates["bias"] = biasMutationChance
	genome.mutationRates["node"] = nodeMutationChance
	genome.mutationRates["enable"] = enableMutationChance
	genome.mutationRates["disable"] = disableMutationChance
	genome.mutationRates["step"] = stepSize	
end)

function Gene:print()
	console.log(self.innovationId)
end

function Gene:copyFrom(gene)
	self.id = gene.id
	self.type = gene.type
end

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
				
function Genome:copyFrom(genome)
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
	self.mutationRates["weights"] = genome.mutationRates["weights"]
	self.mutationRates["link"] = genome.mutationRates["link"]
	self.mutationRates["bias"] = genome.mutationRates["bias"]
	self.mutationRates["node"] = genome.mutationRates["node"]
	self.mutationRates["enable"] = genome.mutationRates["enable"]
	self.mutationRates["disable"] = genome.mutationRates["disable"]
	self.mutationRates["step"] = genome.mutationRates["step"]
	
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

function Genome:hasBias(gene)
	local result = false
	for i = 1, #self.connectionGenes do
		local connection = self.connectionGenes[i]
		if connection.nodeOut.id == gene.id and connection.nodeIn.type == "Bias" then
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
		end
		if connection.nodeOut.type == "Output" then
			if outputs[connection.nodeOut.id] == nil then
				outputs[connection.nodeOut.id] = connection
			elseif not outputs[connection.nodeOut.id].active then
				outputs[connection.nodeOut.id] = connection
			end
		end
	end
	for _, input in pairs(inputs) do
		input.active = true
	end
	for _, output in pairs(outputs) do
		output.active = true
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
	local gene = Gene(self, "Bias")
	self:addGene(gene)
	for i = 1, outputsCount do
		local gene = Gene(self , "Output")
		self:addGene(gene)
	end
	self:mutate()
end

function Genome:getBias()
	for i = 1, #self.genes do
		local gene = self.genes[i]
		if gene.type == "Bias" then
			return gene
		end
	end
end

function Genome:print()
	console.log("Genes count = " .. #self.genes)
	console.log("Connections count = " .. #self.connectionGenes)
	console.log(json.encode(self))
end

function Genome:saveToFile(filename)
	local file = io.open(filename, "w")
	local genomeToSave = Genome()
	genomeToSave:copyFrom(self)
--	genomeToSave.network = self.network
	genomeToSave.network = {}
	file:write(json.encode(genomeToSave))
	file:close()
end

function Genome:loadFromFile(filename)
	local file = io.open(filename, "r")
	local content = file:read("*all")
	self:loadFromContent(content)
	file:close()
end

function Genome:loadFromContent(content)
	local genome = json.decode(content)
	self:copyFrom(genome)
end

function Genome:checkGenes()
	local genes = {}
	for i = 1, #self.genes do
		local found = false
		for j = 1, #genes do
			if genes[j].id == self.genes[i].id then
				console.log(json.encode(self.genes))
				console.log(json.encode(self.connectionGenes))
				print(debug.traceback())
				error("Invalid genes definition")
			end
		end
		table.insert(genes, self.genes[i])
	end
end
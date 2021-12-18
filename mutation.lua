require "neat_utils"
local json = require("json")

function Genome:mutate()
	for mutation, rate in pairs(self.mutationRates) do
		if math.random(1,2) == 1 then
			self.mutationRates[mutation] = 0.9586 * rate
		else
			self.mutationRates[mutation] = 1.0551 * rate
		end
	end

	if math.random() < self.mutationRates["weights"] then
		self:mutateWeight()
	end
	
	local p = self.mutationRates["node"]	
	while p > 0 do
		if math.random() < p then
			self:mutateAddNode()
		end
		p = p - 1
	end
	p = self.mutationRates["link"]	
	while p > 0 do
		if math.random() < p then
			self:mutateAddConnection()
		end
		p = p - 1
	end
	p = self.mutationRates["bias"]	
	while p > 0 do
		if math.random() < p then
			self:addBiasConnection()
		end
		p = p - 1
	end
	p = self.mutationRates["disable"]	
	while p > 0 do
		if math.random() < p then
			self:mutateToggleActivation(false)
		end
		p = p - 1
	end
	p = self.mutationRates["enable"]	
	while p > 0 do
		if math.random() < p then
			self:mutateToggleActivation(true)
		end
		p = p - 1
	end
end

function Genome:mutateWeight()
local step = self.mutationRates["step"]
	for i = 1, #self.connectionGenes do
		local gene = self.connectionGenes[i]
		if math.random() < perturbChance then
			gene.weight = gene.weight + math.random() * stepSize * 2 - stepSize
		else
			gene.weight = math.random() * 4 - 2
		end
	end
end

function Genome:getMutationConnectionInputGene()
	local genes = {}
	for _, gene in pairs(self.genes) do
		if gene.type == "Sensor" or gene.type == "Hidden" or gene.type == "Bias" then
			genes[#genes + 1] = gene
		end
	end
	return genes[math.random(1, #genes)]
end

function Genome:getMutationConnectionOutputGene()
	local genes = {}
	for _, gene in pairs(self.genes) do
		if gene.type == "Output" or gene.type == "Hidden" then
			genes[#genes + 1] = gene
		end
	end
	return genes[math.random(1, #genes)]
end

function Genome:getGeneById(geneId)
	local result = nil
	for _, gene in pairs(self.genes) do
		if gene.id == geneId then
			result = gene
			break
		end
	end
	return result
end

function Genome:getConnection(geneIn, geneOut)
	local result = nil
	for i = 1, #self.connectionGenes do
		local connection = self.connectionGenes[i]
		if connection.nodeIn.id == geneIn.id and connection.nodeOut.id == geneOut.id then
			result = connection
			break
		end
	end
	return result
end

function Genome:mutateAddNode()
	if #self.connectionGenes == 0 then
		return
	end
	local connection = self.connectionGenes[math.random(1, #self.connectionGenes)]
	if not connection.active then
		return
	end
	local hidden = Gene(self, "Hidden")
	self:addGene(hidden)
	connection.active = false
	local connection1 = ConnectionGene(self)
	local innovationId = connection1.innovationId
	connection1:copyFrom(connection)
	connection1.active = true
	connection1.nodeOut = hidden
	connection1.weight = 1.0
	connection1.innovationId = innovationId
	self:addConnectionGene(connection1)
	local connection2 = ConnectionGene(self)
	innovationId = connection2.innovationId
	connection2:copyFrom(connection)
	connection2.nodeIn = hidden
	connection2.active = true
	connection2.innovationId = innovationId
	self:addConnectionGene(connection2)	
end

function Genome:mutateAddConnection()
	local newGeneIn = self:getMutationConnectionInputGene()
	local newGeneOut = self:getMutationConnectionOutputGene()
	local newWeight = math.random() * 4 - 2
	if newGeneIn.id ~= newGeneOut.id and not self:isConnectionExists(newGeneIn.id, newGeneOut.id) then
		local newConnection = ConnectionGene(self, newGeneIn, newGeneOut, newWeight)		
		self:addConnectionGene(newConnection)
	end
end

function Genome:addBiasConnection()
	local newGeneOut = self:getMutationConnectionOutputGene()
	local bias = self:getBias()
	if bias == nil then
		console.log("No Bias gene")
		return
	end
	local newWeight = math.random() * 4 - 2
	local newConnection = ConnectionGene(self, bias, newGeneOut, newWeight)	
	self:addConnectionGene(newConnection)	
end

function Genome:mutateToggleActivation(enable)
	local genes = {}
	for _, gene in pairs(self.connectionGenes) do
		if gene.nodeIn == nil then 	
			console.log(json.encode(self))
		end
		if gene.nodeIn.type ~= "Sensor" and gene.nodeIn.type ~= "Bias" and gene.nodeIn.active == not enable then 
			genes[#genes + 1] = gene
		end
	end
	if #genes == 0 then
		return
	end
	local geneToToggle = genes[math.random(1, #genes)]
	geneToToggle.active = not geneToToggle.active
end

function Genome:crossover(genome)
	local moreFitGenome = self
	local lessFitGenome = genome
	if genome.fitness > moreFitGenome.fitness then
		moreFitGenome = genome
		lessFitGenome = self
	end	
	local child = Genome()
	local lessFitInno = {}
	for i = 1, #lessFitGenome.connectionGenes do
		local c = lessFitGenome.connectionGenes[i]
		lessFitInno[c.innovationId] = c
	end
	
	for i = 1, #moreFitGenome.connectionGenes do
		local moreFitC = moreFitGenome.connectionGenes[i]
		local lessFitC = lessFitInno[moreFitC.innovationId]
		local childConnection = ConnectionGene(child)
		if lessFitC ~= nil and math.random(2) == 1 and lessFitC.active then
			childConnection:copyFrom(lessFitC)
		else
			childConnection:copyFrom(moreFitC)
		end
		table.insert(child.connectionGenes, childConnection)
	end
	for mutation, rate in pairs(moreFitGenome.mutationRates) do
		child.mutationRates[mutation] = rate
	end
	child.geneInnovation = math.max(moreFitGenome.geneInnovation, lessFitGenome.geneInnovation)
	child.connectionInnovation = math.max(moreFitGenome.connectionInnovation, lessFitGenome.connectionInnovation)
	child:createGenes(moreFitGenome)
	return child
end

function Genome:createGenes(parent)
	local inputGenes = parent:getGenesFromType("Sensor")
	local outputGenes = parent:getGenesFromType("Output")
	for i = 1, #inputGenes do
		local inputG = inputGenes[i]
		gene = Gene(self)
		gene:copyFrom(inputG)
		table.insert(self.genes, gene)
	end
	local newBias = Gene(self, "Bias")
	newBias:copyFrom(parent:getBias())
	table.insert(self.genes, newBias)
	for i = 1, #outputGenes do
		local outputG = outputGenes[i]
		gene = Gene(self)
		gene:copyFrom(outputG)
		table.insert(self.genes, gene)
	end
	for i = 1, #self.connectionGenes do
		local connection = self.connectionGenes[i]
		if not self:isGeneExists(connection.nodeIn) then
			local newGene = Gene(self)			
			newGene:copyFrom(connection.nodeIn)
			table.insert(self.genes, newGene)
		end
		if not self:isGeneExists(connection.nodeOut) then
			local newGene = Gene(self)			
			newGene:copyFrom(connection.nodeOut)
			table.insert(self.genes, newGene)
		end
	end
end

function Genome:disjoint(genome)
	local disjoints = 0
	local selfI = {}
	for i = 1, #self.connectionGenes do
		local c = self.connectionGenes[i]
		selfI[c.innovationId] = c
	end
	local genomeI = {}
	for i = 1, #genome.connectionGenes do
		local c = genome.connectionGenes[i]
		genomeI[c.innovationId] = c
	end
	
	for i = 1, #self.connectionGenes do
		local c = self.connectionGenes[i]
		if genomeI[c.innovationId] == nil then
			disjoints = disjoints + 1
		end
	end
	for i = 1, #genome.connectionGenes do
		local c = genome.connectionGenes[i]
		if selfI[c.innovationId] == nil then
			disjoints = disjoints + 1
		end
	end
	return disjoints / math.max(#selfI, #genomeI)
end

function Genome:weights(genome)
	local genomeI = {}
	for i = 1, #genome.connectionGenes do
		local c = genome.connectionGenes[i]
		genomeI[c.innovationId] = c
	end
	local sum = 0
	local matches = 0
	for i = 1, #self.connectionGenes do
		local c = self.connectionGenes[i]
		local genomeC = genomeI[c.innovationId]
		if genomeC ~= nil then
			sum = sum + math.abs(c.weight - genomeC.weight)
			matches = matches + 1
		end
	end
	return sum / matches
end
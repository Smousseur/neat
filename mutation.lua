require "neat_utils"

weightConnectionsChance = 0.25
perturbChance = 0.90
crossoverChance = 0.75
linkMutationChance = 2.0
nodeMutationChance = 0.50
biasMutationChance = 0.40
stepSize = 0.1
disableMutationChance = 0.4
enableMutationChance = 0.2

function Genome:mutate()
	if math.random() < weightConnectionsChance then
		self:mutateWeight()
	end
	self:mutateAddConnection()
	if math.random() < 0.5 then
		self:mutateAddConnection()
	end
	if math.random() < nodeMutationChance then
		self:mutateAddNode()
	end
	if math.random() < disableMutationChance then
		self:mutateToggleActivation(false)
	end
	if math.random() < enableMutationChance then
		self:mutateToggleActivation(true)
	end
end

function Genome:mutateWeight()
	for i = 1, #self.connectionGenes do
		local gene = self.connectionGenes[i]
		if math.random() < perturbChance then
			gene.weight = gene.weight + math.random() * stepSize * 2 - stepSize
		end
	end
end

function Genome:getMutationConnectionInputGene()
	local genes = {}
	for _, gene in pairs(self.genes) do
		if gene.type == "Sensor" or gene.type == "Hidden" then
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

function Genome:mutateAddNode()
	local connection = self.connectionGenes[math.random(1, #self.connectionGenes)]	
	if not connection.active or connection.nodeIn.type == "Bias" then
		return
	end
	connection.active = false
	local newGene = Gene(self, "Hidden")
	self:addGene(newGene)
	local connection1 = ConnectionGene(self)
	connection1.nodeIn = Gene(self)
	connection1.nodeIn:copyFrom(connection.nodeIn)	
	connection1.nodeOut = newGene
	connection1.weight = 1.0
	local connection2 = ConnectionGene(self)
	connection2.nodeIn = newGene
	connection2.nodeOut = Gene(self)
	connection2.nodeOut:copyFrom(connection.nodeOut)
	connection2.weight = connection.weight
	self:addConnectionGene(connection1)
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

function Genome:mutateToggleActivation(enable)
	local genes = {}
	for _, gene in pairs(self.connectionGenes) do
		if gene.nodeIn.type ~= "Sensor" and gene.nodeIn.type ~= "Bias" and gene.active == not enable then 
			genes[#genes + 1] = gene
		end
	end
	if #genes == 0 then
		return
	end
	local geneToToggle = genes[math.random(1, #genes)]
	geneToToggle.active = not geneToToggle.active
end

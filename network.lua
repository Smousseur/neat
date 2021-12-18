require "class"
require "neat_utils"
local json = require("json")

Neuron = class(function(neuron, gene)
	neuron.incoming = {}			
	neuron.bias = false
	neuron.value = 0.0;
	neuron.gene = gene
	neuron.biasInputs = {}
end)

Network = class(function(network)
	network.neurons = {}
end)

function Neuron:copyFrom(neuron)
	self.incoming = neuron.incoming
	self.value = neuron.value
	self.bias = neuron.bias
	self.gene = neuron.gene
	self.biasInputs = neuron.biasInputs
end

function Network:reset()
	self.neurons = {}
end

function Network:isGeneExists(gene)
	local result = false
	for _, neuron in pairs(self.neurons) do
		if neuron.gene.id == gene.id then
			result = true
			break
		end
	end	
	return result
end

function Network:getNeuronByGene(gene)
	local result = nil
	for i = 1, #self.neurons do
		local neuron = self.neurons[i]
		if neuron.gene.id == gene.id then
			result = neuron
			break
		end
	end
	if result == nil then
--		console.log("not found " .. gene.id)
	end
	return result
end

function Network:generate(genome)
	genome:sortByNodeOut()
	for i = 1, #genome.connectionGenes do
		local connection = genome.connectionGenes[i]
		if connection.active then
			local neuronIn = self:getNeuronByGene(connection.nodeIn)
			if neuronIn == nil then
				local neuronIn = Neuron(connection.nodeIn)
				if connection.nodeIn.type == "Bias" then
					neuronIn.bias = true
				end
				table.insert(self.neurons, neuronIn)
			end
			local neuronOut = self:getNeuronByGene(connection.nodeOut)
			if neuronOut == nil then
				neuronOut = Neuron(connection.nodeOut)
				table.insert(self.neurons, neuronOut)
			end
			table.insert(neuronOut.incoming, connection)
		end
	end
	local geneSensors = genome:getGenesFromType("Sensor")
	local geneOutputs = genome:getGenesFromType("Output")
	
	for i = 1, #geneSensors do
		local neuron = self:getNeuronByGene(geneSensors[i])
		if neuron == nil then
			local neuron = Neuron(geneSensors[i])
			table.insert(self.neurons, neuron)
		end
	end
	for i = 1, #geneOutputs do
		local neuron = self:getNeuronByGene(geneOutputs[i])
		if neuron == nil then
			local neuron = Neuron(geneOutputs[i])
			table.insert(self.neurons, neuron)
		end
	end
	table.sort(self.neurons, function (a, b)
		return (a.gene.id < b.gene.id)
	end)	
end

function Network:getNeuronsByType(geneType)
	local results = {}
	for _, neuron in pairs(self.neurons) do
		if neuron.gene.type == geneType then
			table.insert(results, neuron)
		end
	end
	return results
end

function Network:getNodeFromGeneout(geneOut)	
	for _, neuron in pairs(self.neurons) do
		for _, incoming in pairs(neuron.incoming) do
			if incoming.nodeOut.id == geneOut.id then
				return neuron
			end
		end
	end
end

function Network:getInputNodes()
	local inputs = {} 
	for i = 1, #self.neurons do
		local neuron = self.neurons[i]
		if neuron.gene.type == "Sensor" then
			table.insert(inputs, neuron)
		end
	end
	return inputs
end

function Network:evaluateBias(neuron, inputs)
	local value = 0
	if neuron.bias then
		for i = 1, #inputs do
			value = value + inputs[i]
		end
	end
	return fsigmoid(value, 4.9)
end

function Network:sortToEvaluate()
	table.sort(self.neurons, function (a, b)
		if a.gene.type == "Output" then
			return false
		end
		if b.gene.type == "Output" then
			return true
		end		
		return (a.gene.id < b.gene.id)
	end)
end

function Network:evaluate(genome, inputs)
--	console.log(json.encode(genome))
	genome:sortByNodeOut()
	self:sortToEvaluate()
	local inputNodes = self:getInputNodes()
	if #inputs ~= #inputNodes then
		console.log(#inputs)
		console.log(#inputNodes)
		genome:print()
--		self:print()
		error("Invalid network input definition")
	end
	for i = 1, #inputs do
		local neuron = inputNodes[i]
		neuron.value = inputs[i]
	end
	for i = 1, #self.neurons  do
		local neuron = self.neurons[i]
		if neuron.bias then
			neuron.value = 1
		elseif #neuron.incoming > 0 then
			local sum = 0
			for j = 1, #neuron.incoming do
				local incoming = neuron.incoming[j]
				local incomingNeuron = self:getNeuronByGene(incoming.nodeIn)
				sum = sum + incoming.weight * incomingNeuron.value
			end
			neuron.value = sigmoid(sum)
		end
	end
	local outputs = {}
	for idx, gene in pairs(genome.genes) do
		if gene.type == "Output" then
			local neuronOut = self:getNeuronByGene(gene)			
			outputs[#outputs+1] = neuronOut.value
		end
	end
	return outputs
end

function Network:print()
	console.log(json.encode(self))
end
require "class"
require "neat_utils"
local json = require("json")

Neuron = class(function(neuron, gene)
			neuron.incoming = {}			
			neuron.bias = false
			neuron.value = 0.0;
			neuron.gene = gene
		end)

function Neuron:copyFrom(neuron)
	self.incoming = neuron.incoming
	self.value = neuron.value
	self.bias = neuron.bias
end

Network = class(function(network)
			network.neurons = {}
		end)

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

function Network:evaluate(genome, inputs)
	local inputNodes = self:getInputNodes()
	if #inputs ~= #inputNodes then
		genome:print()
		self:print()
		error("Invalid network input definition")
	end
	local i = 1
	for _, neuron in pairs(inputNodes) do
		if neuron.bias then
			neuron.value = fsigmoid(1, 4.9)
		else
			neuron.value = inputs[i]
		end
		i = i + 1
	end
	for j = 1, #self.neurons  do
		local neuron = self.neurons[j]
		if #neuron.incoming > 0 then
			local sum = 0
			for _, incoming in pairs(neuron.incoming) do
				local incomingNeuron = self:getNeuronByGene(incoming.nodeIn)
				sum = sum + incoming.weight * incomingNeuron.value
			end
			neuron.value = fsigmoid(sum, 4.9)
		end
	end
	local outputs = {}
	for idx, gene in pairs(genome.genes) do
		if gene.type == "Output" then
			local neuronOut = self:getNodeFromGeneout(gene)
			outputs[#outputs+1] = neuronOut.value
		end
	end
	return outputs
end

function Network:print()
	console.log(json.encode(self))
end
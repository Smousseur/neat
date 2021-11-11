require "math"

-- slope = 4.9
function fsigmoid(activeSum, slope)
	return (1/(1+(math.exp(-(slope*activeSum)))))
end

function fsigmoidNormalized(activeSum, slope)
	return 2 * fsigmoid(activeSum, slope) - 1
end

function split(input, separator)
	if separator == nil then
		separator = "%s"
	end
	local t = {}
	for str in string.gmatch(input, "([^"..separator.."]+)") do
		table.insert(t, str)
	end
	return t
end

function tableAddAll(table1, table2)
	for _,v in ipairs(table2) do 
		table.insert(table1, v)
	end	
end
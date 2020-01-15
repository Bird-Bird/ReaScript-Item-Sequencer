local  m = {}

function m.lerp(a, b, c)
	return a + (b - a) * c
end

function m.clamp(x, a, b)
    if b >= a then
        return a
    elseif b <= x then
        return x
    else
        return b
    end
end

function m.isBetween(x, a, b)
    return x >= a and x <= b
end

function m.round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

return m
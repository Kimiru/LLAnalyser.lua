-- CLASSES
-- SYMBOLETOKEN
SymboleToken = {type = '', value = 0, line = 0, column = 0}

function SymboleToken:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    o.value = o.value or o.type
    o.line = 0
    o.column = 0

    return o
end

function SymboleToken:dump() print(dump(self)) end

-- SYMBOLEREADER
SymboleReader = {
    regex = '',
    tokenGenerator = function(str) SymboleToken:new(str) end
}

function SymboleReader:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    o.tokenGenerator = o.tokenGenerator or
                           function(str) SymboleToken:new(str) end

    return o
end

function SymboleReader.skipCarriageReturn()
    return SymboleReader:new{
        regex = '\n',
        tokenGenerator = function() return nil end
    }
end

function SymboleReader.skipSpacing()
    return SymboleReader:new{
        regex = '%s',
        tokenGenerator = function() return nil end
    }
end

function SymboleReader.floatWithExponent(type)
    return SymboleReader:new{
        regex = '([-+]?%d*[.]?%d+)(?:[eE]([-+]?%d+))?',
        tokenGenerator = function(str)
            return SymboleToken:new{type = type, value = tonumber(str)}
        end
    }
end

function SymboleReader.idString(type)
    return SymboleReader:new{
        regex = '[a-zA-Z0-9][_a-zA-Z0-9]*',
        tokenGenerator = function(str)
            return SymboleToken:new{type = type, value = tonumber(str)}
        end
    }
end

function SymboleReader:dump() print(dump(self)) end

-- FUNCTIONS

function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

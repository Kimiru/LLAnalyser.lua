-- CLASSES
-- SET
Set = {values = {}}

function Set:new(array)

    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.values = {}

    if array then for i, v in ipairs(array) do o:add(v) end end

    return o

end

function Set:has(value) return self.values[value] == true end

function Set:add(value) self.values[value] = true end

function Set:delete(value) if self:has(value) then self.values[value] = nil end end

function Set:merge(set) for k, v in pairs(set.values) do self:add(k) end end

function Set:list()
    local list = {}
    for k in pairs(self.values) do table.insert(list, k) end
    return list
end

function Set:it() return pairs(self.values) end

function Set:size()

    local count = 0

    for k, v in pairs(self.values) do count = count + 1 end

    return count

end

function Set:clone() return Set:new(self:list()) end

-- SYMBOLETOKEN
SymboleToken = {type = '', value = 0, line = 0, column = 0}

function SymboleToken:new(type, value)
    o = {}
    setmetatable(o, self)
    self.__index = self

    o.type = type
    o.value = value or type
    o.line = 0
    o.column = 0

    return o
end

function SymboleToken:dump() print(dump(self)) end

-- SYMBOLEREADER
SymboleReader = {
    regex = '',
    tokenGenerator = function(str) return SymboleToken:new(str) end
}

function SymboleReader:new(regex, generator)
    o = {}
    setmetatable(o, self)
    self.__index = self

    o.regex = ('^' .. regex) or ''
    o.tokenGenerator = generator or
                           function(str) return SymboleToken:new(str) end

    return o
end

function SymboleReader.skipCarriageReturn()
    return SymboleReader:new('\n', function() return nil end)
end

function SymboleReader.skipSpacing()
    return SymboleReader:new('%s', function() return nil end)
end

-- type = string
function SymboleReader.floatWithoutExponent(type)
    return SymboleReader:new('[-+]?%d*[.]?%d+', function(str)
        return SymboleToken:new(type, tonumber(str))
    end)
end

-- type = string
function SymboleReader.idString(type)
    return SymboleReader:new('[a-zA-Z0-9][_a-zA-Z0-9]*', function(str)
        return SymboleToken:new(type, tonumber(str))
    end)
end

function SymboleReader:dump() print(dump(self)) end

-- RULE
Rule = {nonTerminal = 'string', symboles = {}, action = nil}

-- o = {nonTerminal=string, symboles={...strings}, action=function}
function Rule:new(nonTerminal, symboles, action)

    o = {}
    setmetatable(o, self)
    self.__index = self

    o.nonTerminal = nonTerminal or 'string'
    o.symboles = symboles or {}
    o.action = action or function() return nil end

    return o

end

function Rule.array(...) return {...} end

function Rule:toString()
    res = self.nonTerminal .. ' -> '
    if (#self.symboles ~= 0) then
        for k, v in ipairs(self.symboles) do res = res .. v end
    else
        res = res .. 'epsilon'
    end

    return res
end

function Rule:dump() print(dump(self)) end

-- ASASTEP
ASAStep = {type = 'string', value = nil, token = nil, children = {}, rule = nil}

-- o = {type=string}
function ASAStep:new(type)

    o = {}
    setmetatable(o, self)
    self.__index = self

    o.type = type
    o.value = nil
    o.token = nil
    o.children = {}
    o.rule = nil

    return o

end

function ASAStep:flatten()

    local args = {}

    for i, child in ipairs(self.children) do
        local flat = child:flatten()
        table.insert(args, flat)
    end

    local res
    if self.rule ~= nil then
        res = self.rule.action(table.unpack(args))
    else
        res = self.value
    end

    if res == nil then res = 'nil' end

    return res

end

-- LLANALYSER

LLAnalyser = {
    symboleReaders = {},
    terminals = {},
    nonTerminals = {},
    rules = {}
}

function LLAnalyser:new()

    o = {}
    setmetatable(o, self)
    self.__index = self

    o.symboleReaders = {}
    o.terminals = Set:new()
    o.nonTerminals = Set:new()
    o.rules = {}

    o.terminals:add('EOF')
    o.nonTerminals:add('S')

    o.rules = {}
    o.rules['S'] = {}

    return o

end

function LLAnalyser:addSymboleReader(...)

    args = table.pack(...)
    for i, sr in ipairs(args) do table.insert(self.symboleReaders, sr) end

end

function LLAnalyser:addTerminal(...)
    args = table.pack(...)
    for i, t in ipairs(args) do
        if t == 'nil' then
            error('"nil" is a reserved keyword for the LLA')
        end
        if self.nonTerminals:has(t) then
            error('Conflict: ' .. t .. ' is already a non-terminal')
        end
        self.terminals:add(t)
    end
end

function LLAnalyser:addRule(...)
    args = table.pack(...)
    for i, rule in ipairs(args) do
        if rule.nonTerminal == 'nil' then
            error('"nil" is a reserved keyword for the LLA')
        end
        if self.terminals:has(rule.nonTerminal) then
            error('Conflict: ' .. rule.nonTerminal .. ' is already a terminal')
        end
        if not self.nonTerminals:has(rule.nonTerminal) then
            self.nonTerminals:add(rule.nonTerminal)
            self.rules[rule.nonTerminal] = {}
        end
        table.insert(self.rules[rule.nonTerminal], rule)
    end
end

function LLAnalyser:getSymboleTokens(input)
    local tokenList = {}

    local lastIndex = 0
    local currentIndex = 1

    local line = 1
    local column = 1

    while input ~= nil and currentIndex < #input + 1 do
        if currentIndex == lastIndex then
            lastIndex = currentIndex
            currentIndex = currentIndex + 1
            while currentIndex < #input + 1 do
                local result = self:findToken(input, currentIndex)
                if not result then
                    currentIndex = currentIndex + 1
                else
                    break
                end
            end
            local unknownPart = input:sub(lastIndex, currentIndex)
            error('Cannot progress during tokens splicing, line ' .. line ..
                      ' column ' .. column .. ', unknown character(s): "' ..
                      unknownPart .. '"')
        end
        lastIndex = currentIndex
        local result = self:findToken(input, currentIndex)
        if not result then goto continue_input end

        line = line + result.lineBreak
        if result.lineBreak > 0 then column = 1 end
        column = column + result.column
        currentIndex = currentIndex + result.length

        if result.symboleToken then
            result.symboleToken.line = line
            result.symboleToken.column = column
            table.insert(tokenList, result.symboleToken)
        end

        ::continue_input::
        -- print(currentIndex, lastIndex)
    end

    local eof = SymboleToken:new('EOF')
    eof.line = line
    eof.column = column
    table.insert(tokenList, eof)

    return tokenList

end

function LLAnalyser:findToken(input, index)
    str = input:sub(index)
    for i, sr in ipairs(self.symboleReaders) do
        local regexExecutionResult = string.match(str, sr.regex)
        if regexExecutionResult then
            local symboleToken = sr.tokenGenerator(regexExecutionResult)
            local lineBreak = 0
            local column = 0

            for ci = 1, #regexExecutionResult do
                local c = regexExecutionResult:sub(ci, ci)
                if c == '\n' then
                    lineBreak = lineBreak + 1
                    column = 0
                else
                    column = column + 1
                end
            end

            return {
                symboleToken = symboleToken,
                lineBreak = lineBreak,
                column = column,
                length = #regexExecutionResult
            }
        end
    end
    return nil
end

function LLAnalyser:getAnalysisTable()
    local analysisTable = {}
    for nt in self.nonTerminals:it() do analysisTable[nt] = {} end

    for _, rules in pairs(self.rules) do
        for _, rule in pairs(rules) do
            local firsts = self:first(rule.symboles[1])

            for terminal, _ in firsts:it() do
                if terminal ~= 'nil' then
                    if analysisTable[rule.nonTerminal][terminal] == nil then
                        analysisTable[rule.nonTerminal][terminal] = rule
                    else
                        error('AnalysisTable Conflict: Incompatible rules\n' ..
                                  analysisTable[rule.nonTerminal][terminal]:toString() ..
                                  ': ' .. table.concat(
                                  self:first(
                                      analysisTable[rule.nonTerminal][terminal]
                                          .symboles[0] or nil):list(), ', ') ..
                                  '\n' .. rule:toString() .. ': ' ..
                                  table.concat(firsts:list(), ', '))
                    end
                else
                    local follows = self:follow(rule.nonTerminal)

                    for follow_terminal in follows:it() do
                        if analysisTable[rule.nonTerminal][follow_terminal] ==
                            nil then
                            analysisTable[rule.nonTerminal][follow_terminal] =
                                rule
                        else
                            error(
                                'AnalysisTable Conflict: Incompatible rules\n' ..
                                    analysisTable[rule.nonTerminal][follow_terminal]:toString() ..
                                    ': ' ..
                                    table.concat(
                                        self:first(
                                            analysisTable[rule.nonTerminal][follow_terminal]
                                                .symboles[0] or nil):list(),
                                        ', ') .. '\n' .. rule:toString() .. ': ' ..
                                    table.concat(firsts:list(), ', '))
                        end
                    end
                end
            end
        end
    end
    return analysisTable
end

function LLAnalyser:first(s, ignore)
    ignore = ignore or Set:new()

    if ignore:has(s) then return Set:new() end
    if s == nil then return Set:new({'nil'}) end
    if self.terminals:has(s) then return Set:new({s}) end
    if self.nonTerminals:has(s) then
        ignore:add(s)

        local set = Set:new()

        for _, rule in ipairs(self.rules[s]) do
            if #rule.symboles > 0 then
                local firsts = self:first(rule.symboles[1], ignore)
                set:merge(firsts)
            else
                set:add('nil')
            end
        end

        if set:size() == 0 then set:add('nil') end

        return set

    end

    error('Unknown symbole: "' .. s ..
              '" it is neither a terminal nor a non-terminal')

end

function LLAnalyser:follow(s, ignore)
    ignore = ignore or Set:new()

    if ignore:has(s) then return Set:new() end
    if self.nonTerminals:has(s) then
        ignore:add(s)
        local set = Set:new()
        if s == 'S' then set:add('EOF') end

        for _, rules in pairs(self.rules) do
            for _, rule in pairs(rules) do
                if contains(rule.symboles, s) then
                    local index = indexOf(rule.symboles, s)
                    while index < #rule.symboles do
                        local firsts = self:first(rule.symboles[index + 1])

                        for first in firsts:it() do
                            if first ~= 'nil' then
                                set:add(first)
                            end
                        end
                        if contains(firsts:list(), 'nil') then
                            index = index + 1
                        else
                            break
                        end
                    end

                    if index == #rule.symboles then
                        local follows = self:follow(rule.nonTerminal, ignore)
                        set:merge(follows)
                    end
                end
            end
        end
        return set
    end

    error('Unknown symbole: "' .. s .. '" it is not a non-terminal')
end

function LLAnalyser:parse(input)
    local symboleTokens = self:getSymboleTokens(input)
    local analysisTable = self:getAnalysisTable()

    local EOF = ASAStep:new('EOF')
    local S = ASAStep:new('S')
    table.insert(EOF.children, 1, S)

    local stack = {S, EOF}
    while #stack ~= 0 do
        local headSymbole = symboleTokens[1]
        table.remove(symboleTokens, 1)

        local headStack = stack[1]
        table.remove(stack, 1)

        if self.nonTerminals:has(headStack.type) then
            local rule = analysisTable[headStack.type][headSymbole.type]

            if not rule then
                error('Unexpected symbole at line ' .. headSymbole.line ..
                          ' column ' .. headSymbole.column .. ': "' ..
                          headSymbole.value '" while parsing rule for ' ..
                          headStack.type)
            end

            for i = #rule.symboles, 1, -1 do
                local symbole = rule.symboles[i]
                local asas = ASAStep:new(symbole)
                headStack.rule = rule
                table.insert(headStack.children, 1, asas)
                table.insert(stack, 1, asas)

            end

            table.insert(symboleTokens, 1, headSymbole)

        else
            if self.terminals:has(headStack.type) then
                if headStack.type ~= headSymbole.type then
                    error('Unexpected symbole at line ' .. headSymbole.line ..
                              ' column ' .. headSymbole.column .. ': "' ..
                              headSymbole.value '" while parsing rule for ' ..
                              headStack.type)
                end
                headStack.value = headSymbole.value
            end
        end

    end
    return S
end

-- FUNCTIONS

-- o = any
function dump(so)

    if so == nil then return 'nil' end

    local kset = {}

    kset[so] = true

    local function sdump(o)

        if type(o) == 'table' then
            local s = '{ '
            local list = {}
            for k, v in pairs(o) do
                if not kset[v] then
                    if type(v) == 'table' then
                        kset[tostring(v)] = true
                    end

                    if type(k) ~= 'number' then
                        k = '"' .. tostring(k) .. '"'
                    end
                    local str = '[' .. k .. '] = ' .. sdump(v)
                    table.insert(list, str)
                end
            end
            s = s .. table.concat(list, ', ')
            return s .. ' }'
        else
            return tostring(o)
        end
    end

    return sdump(so)
end

function contains(list, x)
    for _, v in pairs(list) do if v == x then return true end end
    return false
end

indexOf = function(tab, value)
    for index, val in ipairs(tab) do if value == val then return index end end
    return 0
end

return {
    dump = dump,
    Set = Set,
    SymboleToken = SymboleToken,
    SymboleReader = SymboleReader,
    Rule = Rule,
    ASAStep = ASAStep,
    LLAnalyser = LLAnalyser
}

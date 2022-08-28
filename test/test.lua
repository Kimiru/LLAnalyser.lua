local LLA = require('src.LLAnalyser')

function merge(t1, t2)
    for k, v in ipairs(t2) do table.insert(t1, v) end
    return t1
end

local lla = LLA.LLAnalyser:new()

lla:addSymboleReader(LLA.SymboleReader:new('[+]'), LLA.SymboleReader:new('[-]'),
                     LLA.SymboleReader:new('[*]'), LLA.SymboleReader:new('[/]'),
                     LLA.SymboleReader:new('[()]'),
                     LLA.SymboleReader:new('[)]'),
                     LLA.SymboleReader.floatWithoutExponent('nbr'),
                     LLA.SymboleReader.skipSpacing(),
                     LLA.SymboleReader.skipCarriageReturn())

lla:addTerminal('nbr', '+', '-', '*', '/', '(', ')')

lla:addRule(LLA.Rule:new('S', {'E'}, function(str) return str end),
            LLA.Rule:new('E', {'T', 'Ep'}, function(t, ep)
    if ep == 'nil' then return t end
    return {op = 'o+o', value = merge({t}, ep)}
end), LLA.Rule:new('Ep', {'+', 'T', 'Ep'}, function(_, t, ep)
    if ep == 'nil' then return {t} end
    return merge({t}, ep)
end), LLA.Rule:new('Ep', {'-', 'T', 'Ep'}, function(_, t, ep)
    if ep == 'nil' then return {{op = '-o', value = t}} end
    return merge({{op = '-o', value = t}}, ep)
end), LLA.Rule:new('Ep', {}), LLA.Rule:new('T', {'F', 'Tp'}, function(f, tp)
    if tp == 'nil' then return f end
    return {op = 'o*o', value = merge({f}, tp)}
end), LLA.Rule:new('Tp', {'*', 'F', 'Tp'}, function(_, f, tp)
    if tp == 'nil' then return {f} end
    return merge({f}, tp)
end), LLA.Rule:new('Tp', {'/', 'F', 'Tp'}, function(_, f, tp)
    if tp == 'nil' then return {{op = '1/o', value = f}} end
    return merge({{op = '1/o', value = f}}, tp)
end), LLA.Rule:new('Tp', {}), LLA.Rule:new('F', {'nbr'}, function(o)
    return {op = 'nbr', value = o}
end), LLA.Rule:new('F', {'-', 'F'},
                   function(_, f) return {op = '-o', value = f} end),
            LLA.Rule:new('F', {'(', 'E', ')'}, function(_, e) return e end))

local ast = lla:parse('1+3')
local flat = ast:flatten()

print(dump(flat))

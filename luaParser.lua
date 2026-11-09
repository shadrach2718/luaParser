luaParsing = {}
local luaParsingLocal = {}
--Two namespaces so that all local functions can be made global by removing the above local keyword, not really necessary but it is convinent

local hashtagTokenCat12 = token.new(string.byte("#"), 12)
local hashtagTokenCat6 = token.new(string.byte("#"), 6)
local openBracketToken = token.new(string.byte("["), 12)
local closeBracketToken = token.new(string.byte("]"), 12)
local openBraceToken = token.new(string.byte("{"), 1)
local closeBraceToken = token.new(string.byte("}"), 2)
local starToken = token.new(string.byte("*"), 12)
local boolTrueToken = token.create("BooleanTrue")
local boolFalseToken = token.create("BooleanFalse")
local novalToken = token.create("NoValue")

luaParsing.argSpecDefTable = {
    m = {true, 0, openBraceToken, closeBraceToken},
    r = {true, 2},
    o = {false, 0, openBracketToken, closeBracketToken},
    d = {false, 2},
    s = {false, 1},
    t = {false, 1}
}

luaParsing.argSpecParseInfo = {}

luaParsing.macroCallTokens = {}







--Creates all of the variables that will have unchanging values no matter when/where the macro is called and therefore only have to be evaluated once. stores everything relevant in global variables for use when the in-doc macro is called
function luaParsing.argSpec(tokenNameIntVer, argSpecString)
    luaParsingLocal.preParseInputTable(tokenNameIntVer, luaParsingLocal.stringInputParse(argSpecString))
    luaParsing.macroCallTokens[tokenNameIntVer] = token.create(tokenNameIntVer)
end








--converts the input argument specification string into a much more useable table
function luaParsingLocal.stringInputParse(strInput)
    local returnTable = {}
    local currentEntry = 0
    local ignoreNextIncrement = false
    local delimCount = 0
    -- the only delimiters that have impacts are {}, as all others should always be immediately followed by a matching close delim with no non-space chars in between


    for char in strInput:gmatch(".") do

        if char == " " and delimCount == 0 then
            goto endOfStrParseLoop
        end


        if char == "{" then
            delimCount = delimCount + 1

        elseif char == "}" then
            delimCount = delimCount - 1

        elseif char == "!" then
            currentEntry = currentEntry + 1
            ignoreNextIncrement = true

        elseif string.match(char, "^%a$") ~= nil and delimCount == 0 and ignoreNextIncrement == false then
            currentEntry = currentEntry + 1

        elseif ignoreNextIncrement == true then
            ignoreNextIncrement = false
        end


        if returnTable[currentEntry] == nil then 
            returnTable[currentEntry] = char
        else
            returnTable[currentEntry] = returnTable[currentEntry] .. char
        end
        ::endOfStrParseLoop::
    end

    return returnTable
end








--evaluates user-provided default values, does the same style of checking/storing references to the main parsing loops so that the defaults can be cleanly assigned if necessary
function luaParsingLocal.getDefault(broadArgType, inputTableElement)
    --somewhat a force of habit from expl3 to put most var initializations at the top of a function, but its also much neater and prevents scoping issues in the functions that use labels and goto statements
    local defaultTable = {}
    local defaultRefs = {}
    local defaultRefString = ""
    local trackRef = false
    local strDefault = inputTableElement:sub(broadArgType + 3, -2)

    strDefault = strDefault:gsub("##", "#")


    for char in strDefault:gmatch(".") do

        if trackRef == true and char:match("^%d$") ~= nil then
            defaultRefString = defaultRefString .. char
            goto endOfDefaultLoop
        elseif trackRef == true then
            table.insert(defaultRefs, tonumber(defaultRefString))
            defaultRefString = ""
            trackRef = false
        end

        if char == "#" then
            trackRef = true
            table.insert(defaultTable, hashtagTokenCat12)
        else
            table.insert(defaultTable, token.create(string.byte(char)))
        end

        ::endOfDefaultLoop::
    end

    if trackRef == true then
        table.insert(defaultRefs, tonumber(defaultRefString))
    end

    return defaultTable, defaultRefs
end








--generates the arguments for the main parsing functions and a closure of those arguments and the parsing functions themselves
function luaParsingLocal.preParseInputTable(tokenNameToCall, inputTable)
    luaParsing.argSpecParseInfo[tokenNameToCall] = {}
    local nArgsTotal = #inputTable

    for argParseNum=1, nArgsTotal do
        --initializations in the loop so that the closure gets the correct local vals
        local argSpecInfo = {}
        local argSpecInfoChar = ""
        local parseForSingleToken = false
        local currentDelimOpen = openBraceToken
        local currentDelimClose = closeBraceToken
        local tokenPresence = starToken
        local defaultValTable = {}
        local tempParseInfo = nil
        local defaultRefTable = {}
        local spacesEnabled = true

        argSpecInfoChar = inputTable[argParseNum]:sub(1,1)

        if argSpecInfoChar == "!" then
            spacesEnabled = false
            inputTable[argParseNum] = inputTable[argParseNum]:sub(2)
            argSpecInfoChar = inputTable[argParseNum]:sub(1,1)
        end

        argSpecInfo = luaParsing.argSpecDefTable[argSpecInfoChar:lower()]
        if argSpecInfo == nil then
            tex.error("Your argument specification for #" .. argParseNum .. "is not accepted by this program")
            error("Invalid argument specification code")
        end

        local mandatoryBool = argSpecInfo[1]
        local broadArgType = argSpecInfo[2]
        parseForSingleToken = false
        
        if broadArgType == 2 then
            currentDelimOpen = token.create(string.byte(inputTable[argParseNum]:sub(2,2)))
            currentDelimClose = token.create(string.byte(inputTable[argParseNum]:sub(3,3)))
        elseif broadArgType == 1 then
            parseForSingleToken = true
            if argSpecInfoChar == "s" then
                tokenPresence = starToken
            else
                tokenPresence =  token.create(string.byte(inputTable[argParseNum]:sub(2,2)))
            end
        else
            currentDelimOpen, currentDelimClose = argSpecInfo[3], argSpecInfo[4]
        end


        if string.match(argSpecInfoChar, "%u") then
            defaultValTable, defaultRefTable = luaParsingLocal.getDefault(broadArgType, inputTable[argParseNum])
        end

        --This is honestly my favorite feature in lua
        if parseForSingleToken then
            tempParseInfo = function() return luaParsingLocal.argParsingLoopSingleToken(tokenPresence, spacesEnabled) end
        else
            tempParseInfo = function() return luaParsingLocal.mainArgParsingLoop(argParseNum, currentDelimOpen, currentDelimClose, defaultValTable, defaultRefTable, mandatoryBool, spacesEnabled) end
        end


        

        table.insert(luaParsing.argSpecParseInfo[tokenNameToCall], tempParseInfo)
    end
end








--Main function, runs whenever the in-doc macro is called. "absorbs" the macro and its arguments, and puts the internal version of the macro in its place
function luaParsing.parse(tokenNameToCall, argSpecString)

    --Creates global variables if this is the first invocation of .parse for that token name
    if luaParsing.macroCallTokens[tokenNameToCall] == nil then
        luaParsing.argSpec(tokenNameToCall, argSpecString)
    end

    local parseInfo = luaParsing.argSpecParseInfo[tokenNameToCall]
    local gatheredTable = {}
    local refTable = {}
    local nArgsTotal = #parseInfo
    local tokenPresence = nil
    local spacesEnabled = nil
    local tempTable = {}

    for argParseNum=1, nArgsTotal do
        tempTable = {parseInfo[argParseNum]()}

        table.insert(gatheredTable, tempTable[1])
        table.insert(refTable, tempTable[2])
    end


    local evaluationOrderReversed = luaParsingLocal.traceRefPath(refTable)
    local evaluationOrder = {}
    for i, val in ipairs(evaluationOrderReversed) do
        evaluationOrder[val] = i
    end


    local finalTable = luaParsingLocal.finalTableGeneration(gatheredTable, evaluationOrder, refTable, tokenNameToCall)
    
    token.put_next(finalTable)
end








--takes the table of token tables representing each arg, "expands" references to other args, and returns the final token table to be inserted
function luaParsingLocal.finalTableGeneration(gatheredTable, evalOrder, refTable, tokenNameToCall)
    local gatheredTablePostRef = {}
    local finalTable = {}

    for _, i in ipairs(evalOrder) do
        if next(refTable[i]) ~= nil then
            gatheredTablePostRef[i] = {}

            for k=1, #gatheredTable[i] do
                if gatheredTable[i][k] == hashtagTokenCat12 then

                    for _, j in ipairs(gatheredTablePostRef[refTable[i][1]]) do
                        table.insert(gatheredTablePostRef[i], j)
                    end
                    table.remove(refTable[i], 1)

                else
                    table.insert(gatheredTablePostRef[i], gatheredTable[i][k])
                end
            end
        else
            gatheredTablePostRef[i] = gatheredTable[i]
        end
    end


    for i=1, #gatheredTablePostRef do

        table.insert(finalTable, openBraceToken)
        for _, gatherTok in ipairs(gatheredTablePostRef[i]) do
            table.insert(finalTable, gatherTok)
        end
        table.insert(finalTable, closeBraceToken)

    end

    table.insert(finalTable, 1, luaParsing.macroCallTokens[tokenNameToCall])
    return finalTable
end







--figures out the order to expand argument references (for example, if argument 1 is written in terms of argument 2, argument 2 must be evaluated first). counts the "layer" of each argument (the layer of argument #k means that at least k-1 args must be evaluated first. a layer of 1 means that the argument is completely independent and contains no references) and from there creates an order of expansion. if none of the arguments in a macro with n arguments reference to other arguments, it will return {n, n-1,..., 1}, although any random permutation would work perfectly
--note that here, i am using "expansion" to refer to replacing "#", corresponding to a ref table value of 1, with the token table that represents argument 1. nothing in this parser actually expands arguments in the traditional TeX sense, as it never replaces a provided token with its macro expansion, but i couldnt think of a better word
function luaParsingLocal.traceRefPath(refTable)
    local pathTraced = {}
    local pathLayer = {}
    local pathInProgress = {}
    local pathLayerAdjustCount = {}

    for i=1, #refTable do
        pathInProgress[i] = false
        pathLayerAdjustCount[i] = -1

        if next(refTable[i]) == nil then
            pathTraced[i] = true
            pathLayer[i] = 1
        else
            pathTraced[i] = false
            pathLayer[i] = 0
        end
    end



    --defined in the traceRefPath body so that pathTraced, pathInProgress, and pathLayer act as "global" variables to the function, allowing it to check if an argument has already been traced to prevent extra calculation or if there are cyclical argument references
    local function recursiveTrace(n)
        local trackLargeLayer = 0
        local tempInt = 0

        for _, j in ipairs(n) do
            if not pathTraced[j] then
                if pathInProgress[j] then
                    tex.error("Infinite loop detected when referencing other macro arguments")
                    error("Infinite loop when recursively tracing")
                end
                pathInProgress[j] = true
                tempInt = recursiveTrace(refTable[j])
                pathTraced[j] = true
                pathLayer[j] = tempInt
            else
                tempInt = pathLayer[j]
            end
            trackLargeLayer = (tempInt >= trackLargeLayer) and tempInt or trackLargeLayer
        end
        return 1 + trackLargeLayer
    end


    for i=1, #refTable do
        if not pathTraced[i] then
            pathInProgress[i] = true
            pathLayer[i] = recursiveTrace(refTable[i])
            pathTraced[i] = true
        end
    end
    

    --adjusting for duplicate layers so that every element gets assigned a unique order of expansion
    for _, layer in ipairs(pathLayer) do
        pathLayerAdjustCount[layer] = pathLayerAdjustCount[layer] + 1
    end

    local cumSum = 0
    for i, layer in ipairs(pathLayerAdjustCount) do
        cumSum = cumSum + layer
        pathLayerAdjustCount[i] = cumSum
    end

    for i, layer in ipairs(pathLayer) do
        pathLayer[i] = pathLayer[i] + pathLayerAdjustCount[layer]
        pathLayerAdjustCount[layer] = pathLayerAdjustCount[layer] - 1
    end

    return pathLayer
end








--loop to scan for a single token (for arg specs s and t)
function luaParsingLocal.argParsingLoopSingleToken(singleToken, spacesEnabled)
    local auxGatheredTable = {}
    local currentToken = nil
    local currentCmd = nil
    local collectedTokens = {}

    --because only one non-spacing token needs to be found, there is no overarching while or repeat loop
    ::startOfLoopSingleToken::

    currentToken = token.get_next()
    table.insert(collectedTokens, currentToken)
    currentCmd = currentToken.command

    if currentCmd == 10 and spacesEnabled then
        goto startOfLoopSingleToken
    end

    if currentCmd == singleToken.command and currentToken.mode == singleToken.mode then
        auxGatheredTable = {boolTrueToken}
    else
        auxGatheredTable = {boolFalseToken}
        token.put_next(collectedTokens)
    end

    return auxGatheredTable, {}

end








--loop to scan for a multi-token argument (for arg specs m, o, r, and d)
function luaParsingLocal.mainArgParsingLoop(currentArgNum, delimOpen, delimClose, defaultValTable, defaultRefTable, mandatoryBool, spacesEnabled)
    local delimCount = 0
    local auxGatheredTable = {}
    local refTable = {}
    local currentToken = nil
    local currentCmd = nil
    local collectedTokens = {}
    local trackRef = false

    repeat
        ::startOfLoop:: --for spaces only, as spaces before arguments would not increment the delim counter and would therefore end the loop early

        currentToken = token.get_next()
        table.insert(collectedTokens, currentToken)
        currentCmd = currentToken.command

        if currentCmd == 10 and delimCount == 0 and spacesEnabled then --pass
            goto startOfLoop
        end



        if trackRef and (currentToken.mode >= 48 and currentToken.mode < 58) then
            refTable[#refTable] = 10 * refTable[#refTable] + currentToken.mode - 48
            goto endOfLoop
        elseif trackRef then
            trackRef = false
        end
        
        if currentToken == hashtagTokenCat6 then
            table.insert(refTable, 0)
            currentToken = hashtagTokenCat12
            trackRef = true -- no going to the end, as the position of the # will show where to insert the referenced arg.
        elseif currentToken == delimOpen then
            delimCount = delimCount + 1
            if delimCount == 1 then
                goto endOfLoop --realistically this could be startOfLoop and the next goto could just jump out of the loop entirely, but just to be safe, im choosing to keep all labels and gotos in the same loop body 
                -- or replace the other "goto endOfLoop"s with a return statement, but i generally prefer to have one main return statement and only implement auxiliary ones if absolutely necessary
            end
        elseif currentToken == delimClose then
            delimCount = delimCount - 1
            if delimCount == 0 then
                goto endOfLoop
            end
            
        elseif not mandatoryBool and delimCount == 0 and next(defaultValTable) ~= nil then
            -- have to "copy" the table so that auxGatheredTable and refTable dont point to the default values
            -- took a while + claude's help to debug this one :/
            for i, v in ipairs(defaultValTable) do
                auxGatheredTable[i] = v
            end
            for i, v in ipairs(defaultRefTable) do
                refTable[i] = v
            end 

            token.put_next(collectedTokens)
            goto endOfLoop
        elseif delimCount == 0 and mandatoryBool then
            tex.error("No proper argument delimeters found for argument #" .. currentArgNum ..", please check your input")
        elseif delimCount == 0 then
            auxGatheredTable = {novalToken}
            token.put_next(collectedTokens)
            goto endOfLoop
        end

        table.insert(auxGatheredTable, currentToken)

        ::endOfLoop::
    until delimCount == 0

    return auxGatheredTable, refTable
end
/*

 _      _           _                                   _  _      _         _
| |__  | |__       (_) ___   ___   _ __  __   __  __ _ | |(_)  __| |  __ _ | |_   ___   _ __
| '_ \ | '_ \      | |/ __| / _ \ | '_ \ \ \ / / / _` || || | / _` | / _` || __| / _ \ | '__|
| | | || |_) | _   | |\__ \| (_) || | | | \ V / | (_| || || || (_| || (_| || |_ | (_) || |
|_| |_||_.__/ (_) _/ ||___/ \___/ |_| |_|  \_/   \__,_||_||_| \__,_| \__,_| \__| \___/ |_|
                 |__/

    Released to Public Domain.
    --------------------------------------------------------------------------------------
*/

#include "hbclass.ch"

class JSONValidator

    data aErrors as array
    data aOnlyCheck as array

    data cSchema as character

    data hSchema as hash
    data hJSONData as hash

    data lHasError as logical
    data lOnlyCheck as logical

    method New(cSchema as character) constructor

    method AddError(cError)

    method CheckArray(aValues as array,hSchema as hash,cPath as character) as logical
    method CheckEnum(xValue as anytype,aEnum as array,cPath as character) as logical
    method CheckNumber(nValue as numeric,hSchema as hash,cPath as character) as logical
    method CheckPattern(cValue as character,cPattern as character,cPath as character) as logical
    method CheckRequired(hData as hash,aRequired as array,cPath as character) as logical
    method CheckType(xValue as anytype,xType as anytype,cPath as character) as logical

    method Reset(cSchema as character) as logical

    method SetSchema(cSchema as character) as logical

    method Validate(cJSONData as character) as logical
    method ValidateObject(xData as anytype,hSchema as hash,cPath as character) as logical

endclass

method New(cSchema as character) class JSONValidator
    self:aErrors:={}
    self:aOnlyCheck:={}
    self:lHasError:=(!self:SetSchema(cSchema))
    self:lOnlyCheck:=.F.
    if (self:lHasError)
        self:AddError("Invalid JSON schema provided")
    endif
    return(self)

method procedure AddError(cError) class JSONValidator
    if (!self:lOnlyCheck)
        aAdd(self:aErrors,cError)
    else
        aAdd(self:aOnlyCheck,cError)
    endif
    return

method CheckArray(aValues as array,hSchema as hash,cPath as character) class JSONValidator

    local cItemPath as character

    local lValid as logical:=.T.
    local lContains as logical:=hb_HHasKey(hSchema,"contains")
    local lOnlyCheck:=self:lOnlyCheck
    local lUniqueItems as logical:=(hb_HHasKey(hSchema,"uniqueItems").and.hSchema["uniqueItems"])

    local hUniqueItems as hash

    local nItem as numeric
    local nItems as numeric:=Len(aValues)
    local nContainsCount as numeric:=0

    hb_Default(@cPath,"root")

    if (lUniqueItems)
        hUniqueItems:={=>}
    endif

    for nItem:=1 to nItems
        cItemPath:=(cPath+".item("+hb_NToC(nItem)+")")
        if (!self:ValidateObject(aValues[nItem],hSchema["items"],cItemPath))
            lValid:=.F.
        endif
        if (lContains)
            self:lOnlyCheck:=.T.
            if (self:ValidateObject(aValues[nItem],hSchema["contains"],cItemPath))
                nContainsCount++
            endif
            self:lOnlyCheck:=lOnlyCheck
        endif
        if ((lUniqueItems).and.(lValid))
            if (;
                aScan(;
                     aValues;
                    ,{|x,y|;
                        if(hb_HHasKey(hUniqueItems,y),hUniqueItems[y],hb_HSet(hUniqueItems,y,hb_JSONEncode(x))[y]);
                        ==;
                        if(hb_HHasKey(hUniqueItems,nItem),hUniqueItems[nItem],hb_HSet(hUniqueItems,nItem,hb_JSONEncode(aValues[nItem]))[nItem]);
                    };
                    ,nItem+1;
                )!=0;
            )
                lValid:=.F.
                self:AddError("Array at "+cPath+" contains duplicate items. All items must be unique as per schema 'uniqueItems' requirement.")
            endif
        endif
    next nItem

    if (lContains)
        // Additional checks after iteration
        nContainsCount:=Max(nContainsCount-=Len(self:aOnlyCheck),0)
        aSize(self:aOnlyCheck,0)
        if ((hb_HHasKey(hSchema,"minContains").and.(nContainsCount<hSchema["minContains"])))
            lValid:=.F.
            self:AddError("Array at "+cPath+" has too few items satisfying 'contains'. Found: "+hb_NToC(nContainsCount))
        elseif (nContainsCount<1)  // Default: at least 1 item
            lValid:=.F.
            self:AddError("Array at "+cPath+" does not contain at least one item satisfying 'contains'.")
        endif
        if (hb_HHasKey(hSchema,"maxContains").and.(nContainsCount>hSchema["maxContains"]))
            lValid:=.F.
            self:AddError("Array at "+cPath+" has too many items satisfying 'contains'. Found: "+hb_NToC(nContainsCount))
        endif
    endif

    if (hb_HHasKey(hSchema,"minItems"))
        if (nItems<hSchema["minItems"])
            lValid:=.F.
            self:AddError("Array at "+cPath+" has too few items. Found: "+hb_NToC(nItems)+", Minimum: "+hb_NToC(hSchema["minItems"]))
        endif
    endif

    if (hb_HHasKey(hSchema,"maxItems"))
        if (nItems>hSchema["maxItems"])
            lValid:=.F.
            self:AddError("Array at "+cPath+" has too many items. Found: "+hb_NToC(nItems)+", Maximum: "+hb_NToC(hSchema["maxItems"]))
        endif
    endif

    return(lValid)

method CheckEnum(xValue as anytype,aEnum as array,cPath as character) class JSONValidator
    local cValue as character:=hb_JSONEncode(xValue)
    local cEnums as character:=hb_JSONEncode(aEnum)
    local lValid as logical:=(cValue$cEnums)
    if (!lValid)
        self:AddError("Invalid enum value at "+cPath+". Value: "+cValue+", Allowed values: "+cEnums)
    endif
    return(lValid)

method CheckNumber(nValue as numeric,hSchema as hash,cPath as character) class JSONValidator

    local cType as character:=hSchema["type"]

    local lValid as logical:=.T.

    local nTempN as numeric

    // Check the basic type
    if (cType=="integer")
        nTempN:=Int(nValue)
        lValid:=((nValue-nTempN)==0)
        if (!lValid)
            self:AddError("Type mismatch at " + cPath + ". Expected: " + cType + ", Found: number")
        endif
    elseif ((cType!="number").and.(cType!="integer"))
        lValid:=.F.
        self:AddError("Type mismatch at "+cPath+". Expected: "+cType+", Found: number")
    endif

    // Check multipleOf, if present
    if ((lValid).and.(hb_HHasKey(hSchema,"multipleOf")))
        nTempN:=(nValue/hSchema["multipleOf"])
        // Check if the result is 'almost' integer (tolerance for floating-point errors)
        lValid:=(Abs(nTempN-Round(nTempN,0))<0.0000001)  // epsilon = 1e-7
        if (!lValid)
            self:AddError("Value "+hb_JSONEncode(nValue)+" at "+cPath+" is not a multiple of "+hb_JSONEncode(hSchema["multipleOf"]))
        endif
    endif

    // Check minimum, if present
    if ((lValid).and.(hb_HHasKey(hSchema,"minimum")))
        if (nValue < hSchema["minimum"])
            lValid:=.F.
            self:AddError("Value "+hb_JSONEncode(nValue)+" at "+cPath+" is smaller than minimum: "+hb_JSONEncode(hSchema["minimum"]))
        endif
    endif

    // Check maximum, if present
    if ((lValid).and.(hb_HHasKey(hSchema,"maximum")))
        if (nValue > hSchema["maximum"])
            lValid:=.F.
            self:AddError("Value "+hb_JSONEncode(nValue)+" at "+cPath+" is bigger than maximum: "+hb_JSONEncode(hSchema["maximum"]))
        endif
    endif

    // Check exclusiveMinimum, if present
    if ((lValid).and.(hb_HHasKey(hSchema,"exclusiveMinimum")))
        if (nValue<=hSchema["exclusiveMinimum"])
            lValid:=.F.
            self:AddError("Value "+hb_JSONEncode(nValue)+" at "+cPath+" is smaller than or equal to exclusiveMinimum: "+hb_JSONEncode(hSchema["exclusiveMinimum"]))
        endif
    endif

    // Check exclusiveMaximum, if present
    if ((lValid).and.(hb_HHasKey(hSchema,"exclusiveMaximum")))
        if (nValue>=hSchema["exclusiveMaximum"])
            lValid:=.F.
            self:AddError("Value "+hb_JSONEncode(nValue)+" at "+cPath+" is bigger than or equal to exclusiveMaximum: "+hb_JSONEncode(hSchema["exclusiveMaximum"]))
        endif
    endif

    return(lValid)

method CheckPattern(cValue as character,cPattern as character,cPath as character) class JSONValidator

    local lValid as logical

    hb_Default(@cPath,"root")

    lValid:=__regexMatch(cValue,cPattern)
    if (!lValid)
        self:AddError("Pattern mismatch at "+cPath+". Value: '"+cValue+"' does not match pattern: '"+cPattern+"'")
    endif

    return(lValid)

method CheckRequired(hData as hash,aRequired as array,cPath as character) class JSONValidator

    local cProperty as character

    local lValid as logical:=.T.

    local nProperty as numeric

    hb_Default(@cPath,"root")

    begin sequence

        if (ValType(hData)!="H")
            lValid:=.F.
            self:AddError("Expected an object at "+cPath+" to check required properties")
            break
        endif

        for nProperty:=1 to Len(aRequired)
            cProperty:=aRequired[nProperty]
            if (!hb_HHasKey(hData,cProperty))
                lValid:=.F.
                self:AddError("Required property missing at "+cPath+"."+cProperty)
            endif
        next

    end sequence

    return(lValid)

method CheckType(xValue as anytype,xType as anytype,cPath as character) class JSONValidator

    local cType as character
    local cValueType as character:=ValType(xValue)

    local lResult as logical:=.F.

    cType:=ValType(xType)
    if (cType=="C")
        // Tipo único
        cType:=xType
        switch Lower(cType)
            case "string"
                lResult:=(cValueType=="C")
                exit
            case "number"
            case "integer"
                lResult:=(cValueType=="N")
                exit
            case "boolean"
                lResult:=(cValueType=="L")
                exit
            case "object"
                lResult:=(cValueType=="H")
                exit
            case "array"
                lResult:=(cValueType=="A")
                exit
            case "null"
                lResult:=(cValueType=="U")
                exit
        end switch
        if (!lResult)
            self:AddError("Type mismatch at "+cPath+". Expected: "+cType+", Found: "+__HB2JSON(cValueType))
        endif
    elseif (cType=="A")
        // Array de tipos
        cType:=hb_JSONEncode(xType)
        cValueType:=__HB2JSON(cValueType)
        lResult:=(cValueType$cType)
        if (!lResult)
            self:AddError( "Type mismatch at "+cPath+". Expected: one of: "+cType+", Found: "+cValueType)
        endif
    else
        // Tipo inválido para cType
        self:AddError( "Invalid type specification at "+cPath+". Expected string or array of strings, Got "+__HB2JSON(cType))
        lResult:=.F.
    endif

    return(lResult)

method Reset(cSchema as character) class JSONValidator
    hb_default(@cSchema,self:cSchema)
return(self:SetSchema(cSchema))

method SetSchema(cSchema as character) class JSONValidator
    aSize(self:aErrors,0)
    aSize(self:aOnlyCheck,0)
    self:cSchema:=cSchema
    self:hSchema:=hb_JSONDecode(self:cSchema)
    self:lOnlyCheck:=.F.
    self:lHasError:=(ValType(self:hSchema)!="H")
return (!self:lHasError)

method Validate(cJSONData as character) class JSONValidator
    begin sequence
        self:hJSONData:=hb_JSONDecode(cJSONData)
        if (self:hJSONData==NIL)
            self:AddError("Invalid JSON data provided")
            break
        endif
        self:ValidateObject(self:hJSONData,self:hSchema,"root")
    end sequence
    self:lHasError:=(!Empty(self:aErrors))
    return (!self:lHasError)

method ValidateObject(xData as anytype,hSchema as hash,cPath as character) class JSONValidator

    local aRequired as array

    local cType as character
    local cDataType as character
    local cProperty as character
    local cPropertyPath as character

    local hProperties as hash

    local lValid as logical

    local xType as anytype

    hb_Default(@cPath,"root")

    begin sequence

        if (hb_HHasKey(hSchema,"type"))
            xType:=hSchema["type"]
            lValid:=self:CheckType(xData,xType,cPath)
            if (!lValid)
                break
            endif
        endif

        if (hb_HHasKey(hSchema,"enum"))
            self:CheckEnum(xData,hSchema["enum"],cPath)
        endif

        if (valtype(xType)=="C")
            cType:=xType
            switch Lower(cType)
                case "array"
                    if (hb_HHasKey(hSchema,"items"))
                        self:CheckArray(xData,hSchema,cPath)
                    endif
                    exit
                case "string"
                    if (hb_HHasKey(hSchema,"pattern"))
                        self:CheckPattern(xData,hSchema["pattern"],cPath)
                    endif
                    exit
                case "object"
                    exit
                case "integer"
                case "number"
                    self:CheckNumber(xData,hSchema,cPath)
                    exit
            end switch
        endif

        cDataType:=valtype(xData)
        if (cDataType!="H")
            break
        endif

        if (hb_HHasKey(hSchema,"required"))
            aRequired:=hSchema["required"]
            self:CheckRequired(xData,aRequired,cPath)
        endif

        if (hb_HHasKey(hSchema,"properties"))
            hProperties:=hSchema["properties"]
            for each cProperty in hb_HKeys(hProperties)
                if (hb_HHasKey(xData,cProperty))
                    cPropertyPath:=(cPath+"."+cProperty)
                    if (hb_HHasKey(hProperties[cProperty],"type"))
                        xType:=hProperties[cProperty]["type"]
                        self:CheckType(xData[cProperty],xType,cPropertyPath)
                        if (hb_HHasKey(hProperties[cProperty],"enum"))
                            self:CheckEnum(xData[cProperty],hProperties[cProperty]["enum"],cPropertyPath)
                        endif
                        if (valtype(xType)=="C")
                            cType:=xType
                            switch Lower(cType)
                                case "array"
                                    if (hb_HHasKey(hProperties[cProperty],"items"))
                                        self:CheckArray(xData[cProperty],hProperties[cProperty],cPropertyPath)
                                    endif
                                    exit
                                case "string"
                                    if (hb_HHasKey(hProperties[cProperty],"pattern"))
                                        self:CheckPattern(xData[cProperty],hProperties[cProperty]["pattern"],cPropertyPath)
                                    endif
                                    exit
                                case "object"
                                    self:ValidateObject(xData[cProperty],hProperties[cProperty],cPropertyPath)
                                    exit
                                case "integer"
                                case "number"
                                    self:CheckNumber(xData[cProperty],hProperties[cProperty],cPropertyPath)
                                    exit
                            end switch
                        endif
                    endif
                endif
            next each //cProperty
        endif

    end sequence

    self:lHasError:=(!Empty(self:aErrors))

    return (!self:lHasError)

static function __HB2JSON(cType as character)
    local cResult as character
    switch Upper(cType)
        case "C"
            cResult:="string"
            exit
        case "N"
            cResult:="number"
            exit
        case "I"
            cResult:="integer"
            exit
        case "L"
            cResult:="boolean"
            exit
        case "H"
            cResult:="object"
            exit
        case "A"
            cResult:="array"
            exit
        case "U"
            cResult:="null"
            exit
        otherwise
            cResult:="unknown"
    end switch

    return(cResult)

static function __regexMatch(cString as character,cPattern as character)

    local aMatch as array

    local lMatch as logical

    local pRegex as pointer:=hb_regexComp(cPattern,.T./* case-sensitive */,.F./* no multiline */)

    aMatch:=hb_regex(pRegex,cString,.T./* case-sensitive */)
    lMatch:=(!Empty(aMatch))

    return(lMatch)

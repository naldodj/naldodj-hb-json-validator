/*

   _                                      _  _      _         _                    _         _
  (_) ___   ___   _ __     __   __  __ _ | |(_)  __| |  __ _ | |_   ___   _ __    | |_  ___ | |_
  | |/ __| / _ \ | '_ \    \ \ / / / _` || || | / _` | / _` || __| / _ \ | '__|   | __|/ __|| __|
  | |\__ \| (_) || | | |    \ V / | (_| || || || (_| || (_| || |_ | (_) || |      | |_ \__ \| |_
 _/ ||___/ \___/ |_| |_|     \_/   \__,_||_||_| \__,_| \__,_| \__| \___/ |_|       \__||___/ \__|
|__/

    Example usage with valid and invalid test cases.

    Released to Public Domain.
    --------------------------------------------------------------------------------------
*/

REQUEST HB_CODEPAGE_UTF8EX

memvar cSchema,cFunName

procedure Main()

    CLS

    hb_cdpSelect("UTF8")
    hb_cdpSelect("UTF8EX")

    #ifdef __ALT_D__    // Compile with -b -D__ALT_D__
        AltD(1)         // Enables the debugger. Press F5 to continue.
        AltD()          // Invokes the debugger
    #endif

    Execute()

return

static procedure Execute()

    local aTests as array
    local aColors as array
    local aFunTst as array

    local cJSON as character

    local lValid as logical

    local i as numeric
    local nTest as numeric
    local nTestCount as numeric:=0

    local oJSONValidator as object

    private cSchema as character
    private cFunName as character

    aFunTst:=Array(0)
    aAdd(aFunTst,{@getTst01(),"getTst01",.F.})
    aAdd(aFunTst,{@getTst02(),"getTst02",.F.})
    aAdd(aFunTst,{@getTst03(),"getTst03",.F.})
    aAdd(aFunTst,{@getTst04(),"getTst04",.F.})
    aAdd(aFunTst,{@getTst05(),"getTst05",.F.})
    aAdd(aFunTst,{@getTst06(),"getTst06",.F.})
    aAdd(aFunTst,{@getTst07(),"getTst07",.F.})
    aAdd(aFunTst,{@getTst08(),"getTst08",.F.})
    aAdd(aFunTst,{@getTst09(),"getTst09",.F.})
    aAdd(aFunTst,{@getTst10(),"getTst10",.F.})
    aAdd(aFunTst,{@getTst11(),"getTst11",.F.})

    aColors:=getColors(Len(aFunTst))

    oJSONValidator:=JSONValidator():New("")
    oJSONValidator:SetFastMode(.F.)

    for i:=1 to Len(aFunTst)

        aTests:=hb_execFromArray(aFunTst[i][1])

        oJSONValidator:SetSchema(cSchema)

        lValid:=(!oJSONValidator:HasError())

        if (lValid)
            SetColor("g+/n")
            QOut("Result: Valid Schema!")
            SetColor("")
        else
            SetColor("r+/n")
            QOut("Result: Invalid JSON Schema. Errors found:")
            SetColor("")
            aEval(oJSONValidator:GetErros(),{|x| QOut("  "+x)})
        endif

        QOut(Replicate("=",80))

        // Run each test case
        for nTest:=1 to Len(aTests)

            nTestCount++

            SetColor(aColors[i])
            QOut("=== Test "+hb_NToC(nTestCount)+" ("+cFunName+"): "+aTests[nTest][1]+" ===")
            SetColor("") /* Reset color to default */

            cJSON:=aTests[nTest][2]
            lValid:=oJSONValidator:Validate(cJSON)

            if (lValid)
                SetColor("g+/n")
                QOut("Result: Valid JSON!")
                SetColor("")
            else
                SetColor("r+/n")
                QOut("Result: Invalid JSON. Errors found:")
                SetColor("")
                aEval(oJSONValidator:GetErros(),{|x| QOut("  "+x)})
            endif

            oJSONValidator:Reset()

            // Verify expected outcome
            aFunTst[i][3]:=(lValid==aTests[nTest][3])
            if (aFunTst[i][3])
                SetColor("g+/n")
                QOut("Test passed: Expected "+if(aTests[nTest][3],"valid","invalid")+", got "+if(lValid,"valid","invalid"))
                SetColor("")
            else
                SetColor("r+/n")
                QOut("Test failed: Expected "+if(aTests[nTest][3],"valid","invalid")+", got "+if(lValid,"valid","invalid"))
                SetColor("")
            endif

            QOut("")

        next nTest

    next i

    QOut(Replicate("=",80))

    for i:=1 to Len(aFunTst)
        // Verify expected outcome
        lValid:=aFunTst[i][3]
        if (lValid)
            SetColor("g+/n")
            QOut("("+aFunTst[i][2]+"): passed")
            SetColor("")
        else
            SetColor("r+/n")
            QOut("("+aFunTst[i][2]+"): failed")
            SetColor("")
        endif
    next i

    return

static function getColors(nTests as numeric)

    local aColors as array:=Array(nTests)
    local aColorBase as array:={"N","B","G","BG","R","RB","GR","W"}

    local i as numeric

    for i:=1 to nTests
        aColors[i]:="W+/"+aColorBase[(i-1)%8+1]
    next i

    return(aColors)

static function DateDiffYear(dDate1 as date, dDate2 as date)

    local nMonth1 as numeric
    local nMonth2 as numeric
    local nYearDiff as numeric

    nMonth1:=((Year(dDate1)*12)+Month(dDate1))
    nMonth2:=((Year(dDate2)*12)+Month(dDate2))
    nYearDiff:=((nMonth1-nMonth2)-1)
    if (Day(dDate1)>=Day(dDate2))
        ++nYearDiff
    endif
    nYearDiff/=12
    nYearDiff:=Int(nYearDiff)

    return(nYearDiff)

#include "./json_validator_tst_01.prg"
#include "./json_validator_tst_02.prg"
#include "./json_validator_tst_03.prg"
#include "./json_validator_tst_04.prg"
#include "./json_validator_tst_05.prg"
#include "./json_validator_tst_06.prg"
#include "./json_validator_tst_07.prg"
#include "./json_validator_tst_08.prg"
#include "./json_validator_tst_09.prg"
#include "./json_validator_tst_10.prg"
#include "./json_validator_tst_11.prg"

LOCAL loJSON,loResult,lcAuth,lcData,lcUser,lcPass,lcToken,lcLang,lnButton

*--- Create JSON Parser
loJSON = newobject("JSON","json.prg")

*--- Result object
loResult = createobject("EMPTY")

*--- Get the authorization HTTP header
lcAuth = Request.Authorization

if empty(lcAuth)
	*--- Authorization HTTP header is missing
	addproperty(loResult,"login","nok")
	addproperty(loResult,"token","")
else
	*--- Basic authorization
	if left(upper(lcAuth),5) = "BASIC"
		*--- Extract username and password
		lcAuth = substr(lcAuth,7)
		lcData = strconv(lcAuth,14)
		lcUser = left( lcData , at(":",lcData)-1)
		lcPass = substr( lcData , at(":",lcData)+1)

		*--- Check username and password
		if lcUser = "en" and lcPass = "en01"
			*--- Success, create token and load user options
			lcToken  = CreateGUID()
			lcLang   = "EN"
			lnButton = 1
		endif
	endif

	if empty(lcToken)
		*--- No user or password
		addproperty(loResult,"login","nok")
		addproperty(loResult,"token","")
	else
		*--- Set properties to rename
		dimension loJSON.PropertyAlias[1,2]
		loJSON.PropertyAlias[1,1] = 'leftmenu' && VFP Object name
		loJSON.PropertyAlias[1,2] = 'menu'	 && JSON Object name

		*--- Login ok, create menu
		addproperty(loResult,"login","ok")
		addproperty(loResult,"token",lcToken)
		addproperty(loResult,"language",lcLang)
		addproperty(loResult,"appname","Demo")
		addproperty(loResult,"buttoncorner",lnButton)
		addproperty(loResult,"infopages","https://aboservice.be/handleiding/")
		addproperty(loResult,"key",513)

		*--- Company info
		addproperty(loResult,"company[1]")
		loResult.Company[1] = createobject("EMPTY")
		addproperty(loResult.company[1],"dossier","000")
		addproperty(loResult.company[1],"naam","BOA demo company")

		*--- Left menu options
		addproperty(loResult,"leftmenu[2]") && This correct property name should be "menu", but VFP dont accept an array property with name "menu[2]"
		loResult.LeftMenu[1] = createobject("EMPTY")
		addproperty(loResult.LeftMenu[1],"title","Customers")
		addproperty(loResult.LeftMenu[1],"endpoint","/customers")
		addproperty(loResult.LeftMenu[1],"pagetype","tabgrid")
		addproperty(loResult.LeftMenu[1],"hidefilter",.F.)
		addproperty(loResult.LeftMenu[1],"position","top")
		addproperty(loResult.LeftMenu[1],"groupable",.F.)
		addproperty(loResult.LeftMenu[1],"hidefilterrow",.F.)
		addproperty(loResult.LeftMenu[1],"icon","n")
		addproperty(loResult.LeftMenu[1],"id","customers")
		addproperty(loResult.LeftMenu[1],"buttons[6]")
		loResult.LeftMenu[1].buttons[1] = "add"
		loResult.LeftMenu[1].buttons[2] = "delete"
		loResult.LeftMenu[1].buttons[3] = "edit"
		loResult.LeftMenu[1].buttons[4] = "exit"
		loResult.LeftMenu[1].buttons[5] = "print"
		loResult.LeftMenu[1].buttons[6] = "export"
		addproperty(loResult.LeftMenu[1],"onclick",createobject("EMPTY"))
		addproperty(loResult.LeftMenu[1].OnClick,"endpoint","/customers/form")
		addproperty(loResult.LeftMenu[1].OnClick,"pagetype","tabform")
		addproperty(loResult.LeftMenu[1].OnClick,"buttons[7]")
		loResult.LeftMenu[1].OnClick.Buttons[1] = "delete"
		loResult.LeftMenu[1].OnClick.Buttons[2] = "add"
		loResult.LeftMenu[1].OnClick.Buttons[3] = "save"
		loResult.LeftMenu[1].OnClick.Buttons[4] = "list"
		loResult.LeftMenu[1].OnClick.Buttons[5] = "previous"
		loResult.LeftMenu[1].OnClick.Buttons[6] = "next"
		loResult.LeftMenu[1].OnClick.Buttons[7] = "exit"

		loResult.LeftMenu[2] = createobject("EMPTY")
		addproperty(loResult.LeftMenu[2],"title","Files")
		addproperty(loResult.LeftMenu[2],"icon","+")
		addproperty(loResult.LeftMenu[2],"id","")
		addproperty(loResult.LeftMenu[2],"submenu[2]")

		loResult.LeftMenu[2].SubMenu[1] = createobject("EMPTY")
		addproperty(loResult.LeftMenu[2].SubMenu[1],"title","Zip codes")
		addproperty(loResult.LeftMenu[2].SubMenu[1],"endpoint","/postnrs")
		addproperty(loResult.LeftMenu[2].SubMenu[1],"pagetype","grid")
		addproperty(loResult.LeftMenu[2].SubMenu[1],"hidefilter",.F.)
		addproperty(loResult.LeftMenu[2].SubMenu[1],"position","top")
		addproperty(loResult.LeftMenu[2].SubMenu[1],"groupable",.F.)
		addproperty(loResult.LeftMenu[2].SubMenu[1],"hidefilterrow",.F.)
		addproperty(loResult.LeftMenu[2].SubMenu[1],"id","zipcodes")
		addproperty(loResult.LeftMenu[2].SubMenu[1],"buttons[6]")
		loResult.LeftMenu[2].SubMenu[1].Buttons[1] = "add"
		loResult.LeftMenu[2].SubMenu[1].Buttons[2] = "delete"
		loResult.LeftMenu[2].SubMenu[1].Buttons[3] = "edit"
		loResult.LeftMenu[2].SubMenu[1].Buttons[4] = "exit"
		loResult.LeftMenu[2].SubMenu[1].Buttons[5] = "print"
		loResult.LeftMenu[2].SubMenu[1].Buttons[6] = "export"
		addproperty(loResult.LeftMenu[2].SubMenu[1],"onclick",createobject("EMPTY"))
		addproperty(loResult.LeftMenu[2].SubMenu[1].OnClick,"endpoint","/postnrs/${id}")
		addproperty(loResult.LeftMenu[2].SubMenu[1].OnClick,"pagetype","form")
		addproperty(loResult.LeftMenu[2].SubMenu[1].OnClick,"buttons[6]")
		loResult.LeftMenu[2].SubMenu[1].OnClick.Buttons[1] = "add"
		loResult.LeftMenu[2].SubMenu[1].OnClick.Buttons[2] = "save"
		loResult.LeftMenu[2].SubMenu[1].OnClick.Buttons[3] = "list"
		loResult.LeftMenu[2].SubMenu[1].OnClick.Buttons[4] = "previous"
		loResult.LeftMenu[2].SubMenu[1].OnClick.Buttons[5] = "next"
		loResult.LeftMenu[2].SubMenu[1].OnClick.Buttons[6] = "exit"

		loResult.LeftMenu[2].SubMenu[2] = createobject("EMPTY")
		addproperty(loResult.LeftMenu[2].SubMenu[2],"title","Country codes")
		addproperty(loResult.LeftMenu[2].SubMenu[2],"endpoint","/landcodes?key=*")
		addproperty(loResult.LeftMenu[2].SubMenu[2],"pagetype","grid")
		addproperty(loResult.LeftMenu[2].SubMenu[2],"hidefilter",.T.)
		addproperty(loResult.LeftMenu[2].SubMenu[2],"position","top")
		addproperty(loResult.LeftMenu[2].SubMenu[2],"groupable",.F.)
		addproperty(loResult.LeftMenu[2].SubMenu[2],"hidefilterrow",.T.)
		addproperty(loResult.LeftMenu[2].SubMenu[2],"id","countrycodes")
		addproperty(loResult.LeftMenu[2].SubMenu[2],"buttons[5]")
		loResult.LeftMenu[2].SubMenu[2].Buttons[1] = "add"
		loResult.LeftMenu[2].SubMenu[2].Buttons[2] = "delete"
		loResult.LeftMenu[2].SubMenu[2].Buttons[3] = "edit"
		loResult.LeftMenu[2].SubMenu[2].Buttons[4] = "exit"
		loResult.LeftMenu[2].SubMenu[2].Buttons[5] = "export"
		addproperty(loResult.LeftMenu[2].SubMenu[2],"onclick",createobject("EMPTY"))
		addproperty(loResult.LeftMenu[2].SubMenu[2].OnClick,"endpoint","/landcodes/${id}")
		addproperty(loResult.LeftMenu[2].SubMenu[2].OnClick,"pagetype","modalform")
		addproperty(loResult.LeftMenu[2].SubMenu[2].OnClick,"pagesize","lg")
		addproperty(loResult.LeftMenu[2].SubMenu[2].OnClick,"buttons[5]")
		loResult.LeftMenu[2].SubMenu[2].OnClick.Buttons[1] = "save"
		loResult.LeftMenu[2].SubMenu[2].OnClick.Buttons[2] = "previous"
		loResult.LeftMenu[2].SubMenu[2].OnClick.Buttons[3] = "next"
		loResult.LeftMenu[2].SubMenu[2].OnClick.Buttons[4] = "exit"
		loResult.LeftMenu[2].SubMenu[2].OnClick.Buttons[5] = "list"

		*--- Top menu options
		addproperty(loResult,"topmenu[5]")

		loResult.TopMenu[1] = createobject("EMPTY")
		addproperty(loResult.TopMenu[1],"title","Project demo")
		addproperty(loResult.TopMenu[1],"endpoint","/projects")
		addproperty(loResult.TopMenu[1],"itemid","EON")
		addproperty(loResult.TopMenu[1],"pagetype","kanban")
		addproperty(loResult.TopMenu[1],"id","kanbaneon")
		addproperty(loResult.TopMenu[1],"buttons[4]")
		loResult.TopMenu[1].buttons[1] = "add"
		loResult.TopMenu[1].buttons[2] = "exit"
		loResult.TopMenu[1].buttons[3] = "edit"
		loResult.TopMenu[1].buttons[4] = "delete"
		addproperty(loResult.TopMenu[1],"onclick",createobject("EMPTY"))
		addproperty(loResult.TopMenu[1].OnClick,"endpoint","/projdata")
		addproperty(loResult.TopMenu[1].OnClick,"pagetype","modalform")
		addproperty(loResult.TopMenu[1].OnClick,"pagesize","lg")
		addproperty(loResult.TopMenu[1].OnClick,"buttons[2]")
		loResult.TopMenu[1].OnClick.Buttons[1] = "save"
		loResult.TopMenu[1].OnClick.Buttons[2] = "exit"

		loResult.TopMenu[2] = createobject("EMPTY")
		addproperty(loResult.TopMenu[2],"title","Project demo modal")
		addproperty(loResult.TopMenu[2],"endpoint","/projects")
		addproperty(loResult.TopMenu[2],"itemid","EON")
		addproperty(loResult.TopMenu[2],"pagetype","modalkanban")
		addproperty(loResult.TopMenu[2],"pagesize","lg")
		addproperty(loResult.TopMenu[2],"id","kanbanmodal")
		addproperty(loResult.TopMenu[2],"buttons[2]")
		loResult.TopMenu[2].buttons[1] = "add"
		loResult.TopMenu[2].buttons[2] = "exit"
		addproperty(loResult.TopMenu[2],"onclick",createobject("EMPTY"))
		addproperty(loResult.TopMenu[2].OnClick,"endpoint","/projdata")
		addproperty(loResult.TopMenu[2].OnClick,"pagetype","modalform")
		addproperty(loResult.TopMenu[2].OnClick,"pagesize","xl")
		addproperty(loResult.TopMenu[2].OnClick,"buttons[2]")
		loResult.TopMenu[2].OnClick.Buttons[1] = "save"
		loResult.TopMenu[2].OnClick.Buttons[2] = "exit"

		loResult.TopMenu[3] = createobject("EMPTY")
		addproperty(loResult.TopMenu[3],"title","Sheduler demo")
		addproperty(loResult.TopMenu[3],"endpoint","/calendar")
		addproperty(loResult.TopMenu[3],"pagetype","sheduler")
		addproperty(loResult.TopMenu[3],"typeview","week")
		addproperty(loResult.TopMenu[3],"id","sheduler")
		addproperty(loResult.TopMenu[3],"buttons[2]")
		loResult.TopMenu[3].buttons[1] = "add"
		loResult.TopMenu[3].buttons[2] = "exit"
		addproperty(loResult.TopMenu[3],"onclick",createobject("EMPTY"))
		addproperty(loResult.TopMenu[3].OnClick,"endpoint","/calendar")
		addproperty(loResult.TopMenu[3].OnClick,"buttons[2]")
		loResult.TopMenu[3].OnClick.Buttons[1] = "save"
		loResult.TopMenu[3].OnClick.Buttons[2] = "exit"

		loResult.TopMenu[4] = createobject("EMPTY")
		addproperty(loResult.TopMenu[4],"title","Timeline")
		addproperty(loResult.TopMenu[4],"endpoint","/calendar")
		addproperty(loResult.TopMenu[4],"pagetype","timeline")
		addproperty(loResult.TopMenu[4],"typeview","day")
		addproperty(loResult.TopMenu[4],"id","timeline")
		addproperty(loResult.TopMenu[4],"buttons[2]")
		loResult.TopMenu[4].buttons[1] = "add"
		loResult.TopMenu[4].buttons[2] = "exit"
		addproperty(loResult.TopMenu[4],"onclick",createobject("EMPTY"))
		addproperty(loResult.TopMenu[4].OnClick,"endpoint","/calendar")
		addproperty(loResult.TopMenu[4].OnClick,"pagetype","form")
		addproperty(loResult.TopMenu[4].OnClick,"buttons[2]")
		loResult.TopMenu[4].OnClick.Buttons[1] = "save"
		loResult.TopMenu[4].OnClick.Buttons[2] = "exit"

		loResult.TopMenu[5] = createobject("EMPTY")
		addproperty(loResult.TopMenu[5],"title","Device info")
		addproperty(loResult.TopMenu[5],"pagetype","deviceinfo")
		addproperty(loResult.TopMenu[5],"id","deviceinfo")
		addproperty(loResult.TopMenu[5],"buttons[1]")
		loResult.TopMenu[5].buttons[1] = "exit"
	endif
endif

*--- Generate JSON
Response.Content      = loJSON.Stringify(@loResult)
Response.Content_Type = "application/json; charset=utf8"

*--- Release System and JSON Parser object
release loJSON

*--- Release class
clear class json

************************************************************************
FUNCTION CreateGUID
************************************************************************
* wwapi::CreateGUID
********************
***    Author: Rick Strahl, West Wind Technologies
***            http://www.west-wind.com/
***  Modified: 01/26/98
***  Function: Creates a globally unique identifier using Win32
***            COM services. The vlaue is guaranteed to be unique
***    Format: {9F47F480-9641-11D1-A3D0-00600889F23B}
***            if llRaw .T. binary string is returned
***    Return: GUID as a string or "" if the function failed 
*************************************************************************
LPARAMETERS llRaw
LOCAL lcStruc_GUID, lcGUID, lnSize

DECLARE INTEGER CoCreateGuid ;
  IN Ole32.dll ;
  STRING @lcGUIDStruc
  
DECLARE INTEGER StringFromGUID2 ;
  IN Ole32.dll ;
  STRING cGUIDStruc, ;
  STRING @cGUID, ;
  LONG nSize
  
*** Simulate GUID strcuture with a string
lcStruc_GUID = REPLICATE(" ",16) 
lcGUID = REPLICATE(" ",80)
lnSize = LEN(lcGUID) / 2
IF CoCreateGuid(@lcStruc_GUID) # 0
   RETURN ""
ENDIF

IF llRaw
   RETURN lcStruc_GUID
ENDIF   

*** Now convert the structure to the GUID string
IF StringFromGUID2(lcStruc_GUID,@lcGuid,lnSize) = 0
  RETURN ""
ENDIF

*** String is UniCode so we must convert to ANSI
RETURN  StrConv(LEFT(lcGUID,76),6)
* Eof CreateGUID
LOCAL loJSON,loResult

*--- Check user logued
if type("Request.Cookies.SID") = "O" AND !empty(Request.Cookies.SID.Value)
  *--- Locate session
  use data\sessions
  locate for session = Request.Cookies.SID.Value

  *--- User logued
  if !eof()
    cSeller = sessions.seller
  else
    *--- User not logued, delete cookie
    HTTP.SetCookie("SID","",datetime()-86400,,"/")

	*--- Send Error
	HTTP.SendError("200","Login required","Login required","You must be logued.")
    
    return
  endif
else
	*--- Send Error
	HTTP.SendError("200","Login required","Login required","You must be logued.")

    return
endif

*--- Create System Object
System = newobject("oSystem","main.prg")

*--- Create JSON Parser
loJSON = newobject("JSON","json.prg")

*--- No items
loResult = ""

do case
case Request.Method = "GET"
	*--- Open database
	open database dst

    *--- Connect
    if System.Connect()
	    *--- Open users table and locate user
	    select 0
	    System.Use("dst!estados por sigla","estados")

		if !eof()
			*--- Add items array
			dimension loResult[reccount()]

			*--- Fill array with records as objects
			scan
				scatter name loResult[recno()]
			endscan
		endif
	endif
endcase

*--- Generate JSON
Response.Content      = loJSON.Stringify(@loResult)
Response.Content_Type = "application/json; charset=utf8"

*--- Release System and JSON Parser object
release System,loJSON

*--- Release class
clear class json
clear class main
LOCAL loJSON,loData,laResult,loResult

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

*--- Create JSON Parser
loJSON = newobject("JSON","json.prg")

*--- Result object
loResult = createobject("EMPTY")

do case
case Request.Method = "GET"
	*--- SQL statement to get all groups
	SELECT id, name FROM groups ORDER BY id INTO CURSOR result

	laResult = ""
	
	if !eof()
		*--- Add array of nodes
		DIMENSION laResult(reccount())

		*--- Add group nodes
		select result
		scan
			*--- Create object from node record
			scatter name laResult[recno()]
		endscan
	endif
	
	*--- Generate JSON
	Response.Content     = loJSON.Stringify(@laResult)
	Response.Content_Type = "application/json; charset=utf8"

	*--- Release JSON Parser object
	release loJSON

	*--- Release JSON Parser class
	clear class json

	return
endcase

*--- Generate JSON
Response.Content     = loJSON.Stringify(loResult)
Response.Content_Type = "application/json; charset=utf8"

*--- Release JSON Parser object
release loJSON

*--- Release JSON Parser class
clear class json
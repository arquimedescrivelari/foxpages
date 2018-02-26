LOCAL loJSON,loData,loResult

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

*--- Store number
SQLStore = "0001"

do case
case Request.Method = "GET"
	*--- Check new order
	if !empty(Request.ID)
		*--- Open database
		open database icv

	    *--- Connect
	    if System.Connect()
			*--- Open client view
			SQLCode = Request.ID
			System.Use("icv!itens do pedido de venda por código","itens")
		
			if !eof()
				*--- Add items array
				dimension loResult[reccount()]

				*--- Fill array with records as objects
				scan
					scatter name loResult[recno()]
				endscan
			endif
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
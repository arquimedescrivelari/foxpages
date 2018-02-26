LOCAL loJSON,loResult,lcOrder

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
	lcOrder = ""

	*--- ID and sort order
	do case
	case !empty(Request.Query_String)
		*--- Sort param
		lcOrder = strextract(Request.Query_String,"sort(",")")

		*--- ID Value
		Request.ID = substr(Request.ID,1,at("&",Request.ID)-1)
	case "&" $ Request.ID
		*--- Sort param
		lcOrder = strextract(Request.ID,"sort(",")")

		*--- ID Value
		Request.ID = substr(Request.ID,1,at("&",Request.ID)-1)
	endcase
	
	*--- Select
	do case
	case empty(lcOrder) OR lcOrder = "+pe_nome"
		lcOrder = "pe_nome"
	case lcOrder = "-pe_nome"
		lcOrder = "pe_nome descending"
	case lcOrder = "+cf_contato"
		lcOrder = "cf_contato"
	case lcOrder = "-cf_contato"
		lcOrder = "cf_contato descending"
	case lcOrder = "+ed_tel_loc"
		lcOrder = "ed_tel_loc"
	case lcOrder = "-ed_tel_loc"
		lcOrder = "ed_tel_loc descending"
	case lcOrder = "+pe_email"
		lcOrder = "pe_email"
	case lcOrder = "-pe_email"
		lcOrder = "pe_email descending"
	endcase

	*--- Open database
	open database icv

    *--- Connect
    if System.Connect()
	    *--- Open users table and locate user
	    SQLFraven = cSeller
	    SQLGrupo  = transform(val(Request.ID),"@L 99")
	    if SQLGrupo = "00"
		    use "clientes por vendedor sem grupo" alias clientes
	    else
		    use "clientes por vendedor" alias clientes
		endif
		
		*--- Sort
		select * from clientes order by &lcOrder into cursor clientes

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
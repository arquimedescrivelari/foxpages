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
	case lcOrder = "+pe_pedido"
		lcOrder = "pe_pedido"
	case empty(lcOrder) OR lcOrder = "-pe_pedido"
		lcOrder = "pe_pedido descending"
	case lcOrder = "+pe_data"
		lcOrder = "pe_data"
	case lcOrder = "-pe_data"
		lcOrder = "pe_data descending"
	case lcOrder = "+pe_receb"
		lcOrder = "pe_receb"
	case lcOrder = "-pe_receb"
		lcOrder = "pe_receb descending"
	case lcOrder = "+pe_valor"
		lcOrder = "pe_valort"
	case lcOrder = "-pe_valor"
		lcOrder = "pe_valort descending"
	case lcOrder = "+pe_sitdes"
		lcOrder = "pe_sitdes"
	case lcOrder = "-pe_sitdes"
		lcOrder = "pe_sitdes descending"
	endcase

	if !empty(Request.ID)
		*--- Open database
		open database icv

	    *--- Connect
	    if System.Connect()
		    *--- Open users table and locate user
		    SQLClifor = Request.ID
		    use "pedidos de venda por cliente" alias pedidos

			if !eof()
				DIMENSION gPvSituac(8) && Situação do pedido de venda
				gPvSituac[1] = "ABERTO   "
				gPvSituac[2] = "FECHADO  "
				gPvSituac[3] = "FATURANDO"
				gPvSituac[4] = "FATURADO "
				gPvSituac[5] = "CANCELADO"
				gPvSituac[6] = "APROVANDO"
				gPvSituac[7] = "APROVADO "
				gPvSituac[8] = "REPROVADO"

				DIMENSION gMdReceb(7) && Modo de recebimento
				gMdReceb[1] = "DINHEIRO         "
				gMdReceb[2] = "CHEQUE           "
				gMdReceb[3] = "BOLETO           "
				gMdReceb[4] = "CARTÃO DE CRÉDITO"
				gMdReceb[5] = "CARTÃO DE DÉBITO "
				gMdReceb[6] = "DEPÓSITO         "
				gMdReceb[7] = "NÃO DEFINIDO     "

				*--- Descriptions
				select pedidos
				replace all pe_sitdes with array("gPvSituac",pe_situac,10),;
							pe_receb  with array("gMdReceb",pe_mreceb,20)

				*--- Sort
				select * from pedidos order by &lcOrder into cursor pedidos

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
Response.Content     = loJSON.Stringify(@loResult)
Response.Content_Type = "application/json; charset=utf8"

*--- Release System and JSON Parser object
release System,loJSON

*--- Release class
clear class json
clear class main

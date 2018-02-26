LOCAL loJSON,loResult,lcOrder

*--- Check user logued
if type("Request.Cookies.SID") = "O" AND !empty(Request.Cookies.SID.Value)
  *--- Locate session
  use data\sessions
  locate for session = Request.Cookies.SID.Value

  *--- User logued
  if !eof()
    cSeller   = sessions.seller
    cUserName = sessions.username
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

	*--- Order
	do case
	case lcOrder = "+ti_contr"
		lcOrder = "ti_contr"
	case empty(lcOrder) OR lcOrder = "-ti_contr"
		lcOrder = "ti_contr descending"
	case lcOrder = "+ti_parc"
		lcOrder = "ti_parc"
	case lcOrder = "-ti_parc"
		lcOrder = "ti_parc descending"
	case lcOrder = "+ti_vcto"
		lcOrder = "ti_vcto"
	case lcOrder = "-ti_vcto"
		lcOrder = "ti_vcto descending"
	case lcOrder = "+ti_valor"
		lcOrder = "ti_valor"
	case lcOrder = "-ti_valor"
		lcOrder = "ti_valor descending"
	case lcOrder = "+vl_debit"
		lcOrder = "vl_debit"
	case lcOrder = "-vl_debit"
		lcOrder = "vl_debit descending"
	endcase

	if !empty(Request.ID)
		*--- Open database
		open database ifn
		
	    *--- Connect
	    if System.Connect()
		    *--- Open users table and locate user
		    SQLPess = Request.ID
		    SQLDtIni = date()-180
		    SQLDtFim = date()
			use "títulos a receber" alias bills
			
			if !eof()
				select bills
				scan
					lTi_desc1 = 0
					lTi_desc2 = 0
					lTi_desc3 = 0
					lTi_corr  = 0
					lTi_multa = 0
					lTi_pg_vlr = 0
					
					Ti_Corr(date())
					
					replace vl_desc  with lTi_desc1+lTi_desc2+lTi_desc3
					replace vl_multa with lTi_multa
					replace vl_corr  with lTi_corr
					replace vl_debit with lTi_pg_vlr
				endscan

				*--- Sort
				select ti_contr, ti_parc, ti_vcto, ti_valor, vl_desc, vl_multa, vl_corr, vl_debit from bills order by &lcOrder into cursor bills

				*--- Add items array
				dimension loResult[reccount()]

				*--- Fill array with records as objects
				scan
					scatter name loResult[recno()]
				endscan
			endif
		endif

		*--- Log
		strtofile(ttoc(datetime())+" - "+Request.Remote_Address+":"+Request.Remote_Port+" - bills.fxp - User: "+alltrim(cUserName)+" - ID: "+Request.ID+chr(13)+chr(10),HTML.Directory+"representantes.txt",1)
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

*--- Functions
PROCEDURE Ti_Corr
LPARAMETERS lCor_Pg_Dt
LOCAL lnFimSemana,lnCtrl,lnCtrl2

*--- Se o vencimento for no fim de semana, altera-lo para segunda-feira
lnFimSemana = 0
do case
case dow(ti_vcto) = 7 && Sábado
	lnFimSemana = 2
case dow(ti_vcto) = 1 && Domingo
	lnFimSemana = 1
endcase

*--- Dias em atraso
lTi_dias = lCor_Pg_Dt - (ti_vcto + lnFimSemana)

*--- Variaveis de retorno
lTi_desc1 = 0
lTi_desc2 = 0
lTi_desc3 = 0
lTi_multa = 0
lTi_corr  = 0

*--- Calculo de descontos
lnCtrl2 = 0
dimension laDesc[1]

for lnCtrl = 1 to 3
	lcBoDesc  = "Ti_desc"+str(lnCtrl,1)
	lcBoDescV = "Ti_desc"+str(lnCtrl,1)+"v"
	if !empty(evaluate(lcBoDesc)) OR !empty(evaluate(lcBoDescV))
		lnCtrl2 = lnCtrl2 + 1
		dimension laDesc[lnCtrl2,2]

		laDesc[lnCtrl2,1] = evaluate(lcBoDescv)
		laDesc[lnCtrl2,2] = evaluate(lcBoDesc)
	endif
next

if lnCtrl2 > 0
	asort(laDesc)

	lTi_desc1  = 0
	lTi_desc1v = 0
	for lnCtrl = 1 to lnCtrl2
		lTi_desc1 = lTi_desc1 + laDesc[lnCtrl,2]
		lTi_desc1v = laDesc[lnCtrl,1]
		
		if lnCtrl < lnCtrl2 AND lTi_desc1v = laDesc[lnCtrl+1,1]
			loop
		endif

		if lTi_dias <= lTi_desc1v
			exit
		endif
		
		lTi_desc1 = 0
		lTi_desc1v = 0
	next
endif

*--- Calculo de multa
if lTi_dias > ti_multav
	if empty(ti_pro_ds) 
		*--- Não é multa pro-rata
		lTi_multa = ti_multa
	else
		*--- Multa pro-rata
		if lTi_dias >= ti_pro_ds
			lTi_multa = ti_multa
		else
			lTi_multa = (ti_multa / ti_pro_ds) * lTi_dias
		endif
	endif
endif

*--- Calculo de correção
if lTi_dias > ti_corrv
	lTi_corr  = (ti_corr * lTi_dias)
endif

*--- Valor total a receber
lTi_pg_vlr = ti_valor+lTi_multa+lTi_corr-lTi_desc1-lTi_desc2-lTi_desc3

*--- Se o valor a receber for negativo, zera-lo
if lTi_pg_vlr < 0
   lTi_pg_vlr = 0
endif

return .T.
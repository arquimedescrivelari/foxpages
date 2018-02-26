LOCAL loJSON,loData,loResult,llNew,llDelete

*--- Check user logued
if type("Request.Cookies.SID") = "O" AND !empty(Request.Cookies.SID.Value)
  *--- Locate session
  use data\sessions
  locate for session = Request.Cookies.SID.Value

  *--- User logued
  if !eof()
    cSeller = sessions.seller
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

*--- Result object
loResult = createobject("EMPTY")

*--- Store number
SQLStore = "0001"

do case
case Request.Method = "GET"
	*--- No items
	loResult = ""

	*--- Open database
	open database icv

    *--- Connect
    if System.Connect()
		*--- Open client view
		SQLCode = Request.ID
		System.Use("icv!pedido de venda por código","pedido")
	
		if !eof()
			*--- Fill records as objects
			select pedido
			scatter name loResult memo
		endif

		*--- Log
		strtofile(ttoc(datetime())+" - "+Request.Remote_Address+":"+Request.Remote_Port+" - order.fxp - User: "+alltrim(cUserName)+" - GET ID: "+Request.ID+chr(13)+chr(10),HTML.Directory+"representantes.txt",1)
	endif
case Request.Method = "PUT"
    *--- Parse JSON
	lojSON.Parse(Request.Content,,@loData)

	*--- Open database
	open database icv

	*--- Check connection
	if !System.Connect()
		addproperty(loResult,"success",.F.)
		addproperty(loResult,"error","Erro: Não foi possível se conectar ao banco de dados.")
	else
		*--- Update
		
		*--- Seller
		SQLCode = cSeller
		System.Use("icv!vendedor","",0)

		*--- Customer
		SQLCode = loData.pe_clifor
		System.Use("icv!cliente","",0)
		
		*-- Default prices table
		System.Use("ies!tabela de preços padrão","tabela",0)
		
		*--- Order
		System.Use("icv!pedido de venda por código","pedido",0,.T.)
		
		*--- Order items
		System.Use("icv!itens do pedido de venda por código","itens",0,.T.)

		select itens
		cursorsetprop("Buffering",5)

		if type("loData.pe_codigo") = "C" AND loData.pe_codigo = "new"
			llNew = .T.
			
			*--- Append new order
			select pedido
			System.Append()

			*--- Update order object codes
			loData.pe_codigo = pe_codigo
			loData.pe_pedido = transform(newcode("pe_pv0001v"),"@L 99999999")
		else
			*--- Query order
			SQLCode = loData.pe_codigo
			select pedido
			requery()

			*--- Query items
			select itens
			requery()
		endif
		
		*--- For security reasons this data must be fixed
		addproperty(loData,"pe_tpcv","0020")
		addproperty(loData,"pe_tabpr",tabela.tp_codigo)
		addproperty(loData,"pe_fraven",vendedor.fr_codigo)
		addproperty(loData,"pe_fr_com",iif(empty(cliente.cf_comis),vendedor.fr_comis,cliente.cf_comis))
		
		try
			*--- Update order data
			select pedido
			gather name loData memo
			
			*--- Update items data
			select itens
			for each loItem in loData.Itens
				*--- Locate item
				locate for pi_codigo = loItem.pi_codigo

				*--- Append new items
				if eof()
					System.Append()
					
					loItem.pi_codigo = pi_codigo
					loItem.pi_pedido = pi_pedido
				endif

				*--- Update item data
				gather name loItem
			next

			*--- Remove deleted items
			select itens
			scan
				llDelete = .T.
				for each loItem in loData.Itens
					if loItem.pi_codigo = pi_codigo
						llDelete = .F.
						exit
					endif
				next

				if llDelete
					System.Delete()
				endif
			endscan

			*--- Start transaction
			System.BeginTransaction()

			*--- Save order
			select pedido
			System.Save()
			
			*--- Save items
			select itens
			System.Save(.T.)

			*--- End transaction
			System.EndTransaction()

			addproperty(loResult,"success",.T.)
			if llNew
				addproperty(loResult,"new_order",pedido.pe_pedido)
			endif

			*--- Log
			strtofile(ttoc(datetime())+" - "+Request.Remote_Address+":"+Request.Remote_Port+" - order.fxp - User: "+alltrim(cUserName)+" - PUT ID: "+upper(Request.ID)+" - SUCESSO"+chr(13)+chr(10),HTML.Directory+"representantes.txt",1)
		catch to oException
			*--- Rollback
			System.Rollback()

			*--- Revert order
			select pedido
			System.Revert()

			*--- Revert items
			select itens
			System.Revert(.T.)

			lcMessage = strtran(oException.Message,chr(10),'<BR>')

			addproperty(loResult,"success",.F.)
			addproperty(loResult,"error","Erro: "+lcMessage)

			*--- Log
			strtofile(ttoc(datetime())+" - "+Request.Remote_Address+":"+Request.Remote_Port+" - order.fxp - User: "+alltrim(cUserName)+" - PUT ID: "+upper(Request.ID)+" - FALHA: "+lcMessage+chr(13)+chr(10),HTML.Directory+"representantes.txt",1)
		endtry
    endif
case Request.Method = "DELETE"
	*--- Open database
	open database icv

	*--- Check connection
	if !System.Connect()
		addproperty(loResult,"success",.F.)
		addproperty(loResult,"error","Erro: Não foi possível se conectar ao banco de dados.")
	else
		*--- Update
		System.Use("icv!pedido de venda por código","pedido",0,.T.)
		System.Use("icv!itens do pedido de venda por código","itens",0,.T.)

		select itens
		cursorsetprop("Buffering",5)

		*--- Query order
		SQLCode = Request.ID
		select pedido
		requery()

		*--- Query items
		select itens
		requery()
		
		try
			*--- Start transaction
			System.BeginTransaction()

			*--- Save items
			select itens
			if !System.Delete(.T.)
				error "Pedido não pode ser excluído."
			endif
			
			*--- Save order
			select pedido
			if !System.Delete()
				error "Pedido não pode ser excluído."
			endif
			
			*--- End transaction
			System.EndTransaction()

			addproperty(loResult,"success",.T.)

			*--- Log
			strtofile(ttoc(datetime())+" - "+Request.Remote_Address+":"+Request.Remote_Port+" - order.fxp - User: "+alltrim(cUserName)+" - DELETE ID: "+Request.ID+" - SUCESSO"+chr(13)+chr(10),HTML.Directory+"representantes.txt",1)
		catch to oException
			*--- Rollback
			System.Rollback()

			*--- Revert order
			select pedido
			System.Revert()

			*--- Revert items
			select itens
			System.Revert(.T.)

			lcMessage = strtran(oException.Message,chr(10),'<BR>')

			addproperty(loResult,"success",.F.)
			addproperty(loResult,"error","Erro: "+lcMessage)

			*--- Log
			strtofile(ttoc(datetime())+" - "+Request.Remote_Address+":"+Request.Remote_Port+" - order.fxp - User: "+alltrim(cUserName)+" - DELETE ID: "+Request.ID+" - FALHA: "+lcMessage+chr(13)+chr(10),HTML.Directory+"representantes.txt",1)
		endtry
    endif
endcase

*--- Generate JSON
Response.Content     = loJSON.Stringify(loResult)
Response.Content_Type = "application/json; charset=utf8"

*--- Release System and JSON Parser object
release System,loJSON

*--- Release class
clear class json
clear class main
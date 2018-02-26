LOCAL loJSON,loData,loResult,llNew,lcMessage

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

do case
case Request.Method = "GET"
	*--- Open database
	open database icv

    *--- Connect
    if System.Connect()
		*--- Open client view
		SQLCode = Request.ID
		System.Use("icv!cliente por código","cliente")
	
		if !eof()
			*--- Fill records as objects
			select cliente
			scatter name loResult memo
			
			loResult.cf_grupo = val(cf_grupo)
		endif

		*--- Log
		strtofile(ttoc(datetime())+" - "+Request.Remote_Address+":"+Request.Remote_Port+" - client.fxp - User: "+alltrim(cUserName)+" - GET ID: "+Request.ID+chr(13)+chr(10),HTML.Directory+"representantes.txt",1)
	endif
case Request.Method = "PUT"
	*--- Insert/Update
	lojSON.Parse(Request.Content,,@loData)

	*--- Values conversions
	loData.pe_tipo  = val(loData.pe_tipo)
	loData.pe_cnpj  = strtran(loData.pe_cnpj,"./-")
	loData.ed_cep   = strtran(loData.ed_cep,"-")
	loData.cf_grupo = transform(val(loData.cf_grupo),"@L 99")

	*--- Open database
	open database icv
	open database ist

	*--- Check connection
	if !System.Connect()
		addproperty(loResult,"success",.F.)
		addproperty(loResult,"error","Erro: Não foi possível se conectar ao banco de dados.")
	else
		System.Use("ist!endereço de cobrança","cobrança",0,.T.)
		System.Use("ist!endereço de entrega","entrega",0,.T.)
		System.Use("ist!endereço","endereço",0,.T.)
		System.Use("ist!endereço","endereço",0,.T.)
		System.Use("ist!pessoas e empresas","pessoa",0,.T.)
		System.Use("icv!cliente","cliente",0,.T.)

		*--- Insert
		if type("loData.cf_codigo") = "C" AND loData.cf_codigo = "new"
			llNew = .T.
			
			set database to ist
			select endereço
			System.Append()
			
			select pessoa
			System.Append()
			replace pe_ender with endereço.ed_codigo

			set database to icv
			select cliente
			System.Append()
			replace cf_pess   with pessoa.pe_codigo
			replace cf_fraven with cSeller

			loData.cf_codigo = cf_codigo
		else
			SQLCode = loData.cf_codigo
			select cliente
			requery()

			SQLCode = cliente.cf_pess
			select pessoa
			requery()

			SQLCode = pessoa.pe_ender
			select endereço
			requery()

			if !empty(pessoa.pe_enderc)
				SQLCode = pessoa.pe_enderc
				select cobrança
				requery()
			endif

			if !empty(pessoa.pe_endere)
				SQLCode = pessoa.pe_endere
				select entrega
				requery()
			endif
		endif

		*--- Update
		try
			if eof("cobrança") AND !empty(loData.ec_lograd)
				set database to ist
				select cobrança
				System.Append()
	
				select pessoa
				replace pe_enderc with cobrança.ec_codigo
			endif

			if eof("entrega") AND !empty(loData.ee_lograd)
				set database to ist
				select entrega
				System.Append()
	
				select pessoa
				replace pe_endere with entrega.ee_codigo
			endif

			*--- Update/delete bill to address
			if !eof("cobrança")
				select cobrança
				if empty(loData.ec_lograd)
					select pessoa
					replace pe_enderc with ""
				else
					gather name loData
				endif
			endif
			
			*--- Update/delete deliver to address
			if !eof("entrega")
				select entrega
				if empty(loData.ee_lograd)
					select pessoa
					replace pe_endere with ""
				else
					gather name loData
				endif
			endif
			
			*--- Update address data
			select endereço
			gather name loData

			*--- Add person
			select pessoa
			gather name loData

			*--- Add client
			select cliente
			gather name loData memo

			*--- Start transaction
			System.BeginTransaction()

			*--- Save bill to address
			select cobrança
			if !empty(pessoa.pe_enderc)
				System.Save()
			endif

			*--- Save deliver to address
			select entrega
			if !empty(pessoa.pe_endere)
				System.Save()
			endif
			
			*--- Save address
			select endereço
			System.Save()

			*--- Save person
			select pessoa
			System.Save()

			*--- Save custommer
			select cliente
			System.Save()

			*--- Try to delete bill to address
			select cobrança
			if empty(pessoa.pe_enderc) AND !eof()
				if !System.Delete()
					System.Revert()
				endif
			endif

			*--- Try to delete deliver to address
			select entrega
			if empty(pessoa.pe_endere) AND !eof()
				if !System.Delete()
					System.Revert()
				endif
			endif
			
			*--- End transaction
			System.EndTransaction()

			addproperty(loResult,"success",.T.)
			if llNew
				addproperty(loResult,"new_client",cliente.cf_codigo)
			endif

			*--- Log
			strtofile(ttoc(datetime())+" - "+Request.Remote_Address+":"+Request.Remote_Port+" - client.fxp - User: "+alltrim(cUserName)+" - PUT ID: "+upper(Request.ID)+" - SUCESSO"+chr(13)+chr(10),HTML.Directory+"representantes.txt",1)
		catch to oException
			*--- Rollback
			System.Rollback()

			*--- Revert bill to address
			select cobrança
			System.Revert()

			*--- Revert deliver to address
			select entrega
			System.Revert()

			*--- Revert addresss
			select endereço
			System.Revert()

			*--- Revert person
			select pessoa
			System.Revert()

			*--- Revert custommer
			select cliente
			System.Revert()

		    do case
			case "stender_ed_estado_fkey" $ oException.Message
				lcMessage = "Estado informado inválido."
			otherwise
				lcMessage = oException.Message
			endcase

			addproperty(loResult,"success",.F.)
			addproperty(loResult,"error","Erro: "+lcMessage)

			*--- Log
			strtofile(ttoc(datetime())+" - "+Request.Remote_Address+":"+Request.Remote_Port+" - client.fxp - User: "+alltrim(cUserName)+" - PUT ID: "+Request.ID+" - FALHA"+chr(13)+chr(10)+lcMessage+chr(13)+chr(10),HTML.Directory+"representantes.txt",1)
		endtry
    endif
case Request.Method = "POST"
	*--- Move client
	lojSON.Parse(Request.Content,,@loData)

	*--- Open database
	open database icv

	*--- Check connection
	if !System.Connect()
		addproperty(loResult,"success",.F.)
		addproperty(loResult,"error","Erro: Não foi possível se conectar ao banco de dados.")
	else
		System.Use("icv!cliente","cliente",0,.T.)

		SQLCode = loData.move_client_id
		select cliente
		requery()

		*--- Move client
		try
			*--- Update client group
			select cliente
			replace cf_grupo with transform(val(loData.move_client_group),"@L 99")

			*--- Start transaction
			System.BeginTransaction()

			*--- Save custommer
			select cliente
			System.Save()
			
			*--- End transaction
			System.EndTransaction()

			addproperty(loResult,"success",.T.)

			*--- Log
			strtofile(ttoc(datetime())+" - "+Request.Remote_Address+":"+Request.Remote_Port+" - client.fxp - User: "+alltrim(cUserName)+" - POST ID: "+loData.move_client_id+" - SUCESSO"+chr(13)+chr(10),HTML.Directory+"representantes.txt",1)
		catch to oException
			*--- Rollback
			System.Rollback()

			*--- Revert custommer
			select cliente
			System.Revert()

			lcMessage = message()

			addproperty(loResult,"success",.F.)
			addproperty(loResult,"error",lcMessage)

			*--- Log
			strtofile(ttoc(datetime())+" - "+Request.Remote_Address+":"+Request.Remote_Port+" - client.fxp - User: "+alltrim(cUserName)+" - PUT ID: "+loData.move_client_id+" - FALHA"+chr(13)+chr(10)+lcMessage+chr(13)+chr(10),HTML.Directory+"representantes.txt",1)
		endtry
    endif
case Request.Method = "DELETE"
	*--- Open database
	open database icv
	open database ist

	*--- Check connection
	if !System.Connect()
		addproperty(loResult,"success",.F.)
		addproperty(loResult,"error","Erro: Não foi possível se conectar ao banco de dados.")
	else
		*--- Delete
		SQLCode = Request.ID
		System.Use("icv!cliente","cliente",0)

		SQLCode = cliente.cf_pess
		System.Use("ist!pessoas e empresas","pessoa",0)
		
		SQLCode = pessoa.pe_ender
		System.Use("ist!endereço","endereço",0)

		SQLCode = pessoa.pe_endere
		System.Use("ist!endereço de entrega","entrega",0)

		SQLCode = pessoa.pe_enderc
		System.Use("ist!endereço de cobrança","cobrança",0)

		try
			*--- Start transaction
			System.BeginTransaction()

			*--- Delete client
			select cliente
			if !System.Delete()
				error "Cliente não pode ser excluído."
			endif

			*--- Delete person
			select pessoa
			if !System.Delete()
				System.Revert()
			else
				*--- Delete address
				if !eof("endereço")
					select endereço
					if !System.Delete()
						System.Revert()
					endif
				endif
	
				*--- Delete deliver to address
				if !eof("entrega")
					select entrega
					if !System.Delete()
						System.Revert()
					endif
				endif
				
				*--- Delete bill to address
				if !eof("cobrança")
					select cobrança
					if !System.Delete()
						System.Revert()
					endif
				endif
			endif

			*--- End transaction
			System.EndTransaction()

			addproperty(loResult,"success",.T.)

			*--- Log
			strtofile(ttoc(datetime())+" - "+Request.Remote_Address+":"+Request.Remote_Port+" - client.fxp - User: "+alltrim(cUserName)+" - DELETE ID: "+Request.ID+" - SUCESSO"+chr(13)+chr(10),HTML.Directory+"representantes.txt",1)
		catch to oException
			*--- Revert bill to address
			select cobrança
			System.Revert()

			*--- Revert deliver to address
			select entrega
			System.Revert()

			*--- Revert addresss
			select endereço
			System.Revert()

			*--- Revert person
			select pessoa
			System.Revert()

			*--- Revert custommer
			select cliente
			System.Revert()

			*--- Rollback
			System.Rollback()

			lcMessage = oException.Message
		
			addproperty(loResult,"success",.F.)
			addproperty(loResult,"error",lcMessage)

			*--- Log
			strtofile(ttoc(datetime())+" - "+Request.Remote_Address+":"+Request.Remote_Port+" - client.fxp - User: "+alltrim(cUserName)+" - DELETE ID: "+Request.ID+" - FALHA: "+lcMessage+chr(13)+chr(10),HTML.Directory+"representantes.txt",1)
		endtry
	endif
endcase

*--- Generate JSON
Response.Content      = loJSON.Stringify(loResult)
Response.Content_Type = "application/json; charset=utf8"

*--- Release System and JSON Parser object
release System,loJSON

*--- Release class
clear class json
clear class main
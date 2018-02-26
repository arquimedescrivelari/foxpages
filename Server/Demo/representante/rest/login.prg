LOCAL loJSON,loResult,lcUserName,lcPassword,lcKeepConn,lcSession

*--- Create System Object
System = newobject("oSystem","main.prg")

*--- Create JSON Parser
loJSON = newobject("JSON","json.prg")

*--- Result object
loResult = createobject("EMPTY")

do case
case Request.Method = "GET"
	lcUserName = lower(strconv(substr(Request.ID,1,at("&",Request.ID)-1),14))
	lcPassword = strconv(strextract(Request.ID,"&","&"),14)
	lcKeepConn = substr(Request.ID,rat("&",Request.ID)+1)

    *--- Open database
    open database ist
   
    *--- Connect
    if !System.Connect()
		*--- Log
		strtofile(ttoc(datetime())+" - "+Request.Remote_Address+":"+Request.Remote_Port+" - login.fpx - "+alltrim(lcUserName)+chr(13)+chr(10),HTML.Directory+"representantes.txt",1)

	    addproperty(loResult,"success",.F.)	
	else
		*--- Open users table and locate user
		SQLEmail = padr(lcUserName,60)
		use "pessoa por email" alias pessoa
		
		*--- Locate the user by password
		locate for pe_senha == padr(lcPassword,15)
	 
		*--- Verify user password
		if !isnull(fr_codigo) AND !empty(lcUserName) AND !empty(lcPassword) AND pe_senha = lcPassword
			addproperty(loResult,"success",.T.)	
	
			*--- Define session
			cSession = substr(sys(2015),3)

			*--- Define user
			cUserName = pe_email
			cCustomer = iif(isnull(cf_codigo),"",cf_codigo)
			cSeller   = iif(isnull(fr_codigo),"",fr_codigo)

			*--- Set cookie
			HTTP.SetCookie("SID",cSession,iif(lcKeepConn = 'true',{^2030-01-01 00:00:00},{}),,"/")
	
			*--- Add session ID to sessions
			use data\sessions
			append blank
			replace session  with cSession
			replace username with cUserName
			replace customer with cCustomer
			replace seller   with cSeller
				
			*--- Log
			strtofile(ttoc(datetime())+" - "+Request.Remote_Address+":"+Request.Remote_Port+" - login.fpx - "+lcUserName+" - SUCESSO"+chr(13)+chr(10),HTML.Directory+"representantes.txt",1)
		else
			addproperty(loResult,"success",.F.)	

			*--- Log
			strtofile(ttoc(datetime())+" - "+Request.Remote_Address+":"+Request.Remote_Port+" - login.fpx - "+lcUserName+" - NEGADO"+chr(13)+chr(10),HTML.Directory+"representantes.txt",1)
		endif
	endif
	
	*--- Generate JSON
	Response.Content = loJSON.Stringify(loResult)
endcase

*--- Release System and JSON Parser object
release System,loJSON

*--- Release class
clear class json
clear class main
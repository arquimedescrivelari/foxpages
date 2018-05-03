#INCLUDE foxpages.h

******************************************************************************************
* WebServer class
***********
DEFINE CLASS WebServer AS CUSTOM
	*--- Request container objects
	ADD OBJECT Request AS Request && Request properties container

	*--- Response container objects
	ADD OBJECT Response AS Response && Response properties container

	*--- Internal properties
	Directory = ""
	HasError  = .F.
	SiteID    = ""
	SiteIndex = "index.fxp"

	*--- Mime formats
	Mime = chrtran(filetostr("data\mime.txt"),CRLF,"")+"|"

	PROCEDURE Init()
		*--- Debug log
		This.Parent.Log.Add(2,"Webserver.Init")
	ENDPROC

	PROCEDURE Destroy()
		*--- Release parser object
		This.RemoveObject("Parser")

		*--- Debug log
		This.Parent.Log.Add(2,"Webserver.Destroy")
	ENDPROC

	PROCEDURE Error(nError,cMethod,nLine)
		This.Parent.Log.Add(0,"Webserver.Error","Method: "+proper(m.cMethod)+CRLF+"Message: "+message())
	ENDPROC

	PROCEDURE Process()
	LOCAL llBadRequest,lnLength,ldFile
		do case
		case This.Parent.Type = "HTTP"
			*--- Determine the size of request
			m.lnLength  = at(HEADER_DELIMITER,This.Parent.Receiving)+3+val(strextract(This.Parent.Receiving,"Content-Length: ",CRLF))

			*--- Request
			m.lcRequest = substr(This.Parent.Receiving,1,m.lnLength)

			*--- Create HTTP Processor
			This.NewObject("Parser","HTTPProtocol","core\http.fxp")

			*--- Process received data
			if !This.Parser.Process(m.lcRequest)
				return .F.
			endif
		
			*--- Remove request
			This.Parent.Receiving = substr(This.Parent.Receiving,m.lnLength+1)
		case This.Parent.Type = "FCGI"
			m.lcRequest = This.Parent.Receiving

			*--- Create FCGI Processor
			This.NewObject("Parser","FCGIProtocol","core\fcgi.fxp")

			*--- Process received data
			if !This.Parser.Process(m.lcRequest)
				return .F.
			endif

			*--- Clear request
			This.Parent.Receiving = ""
		endcase

		*--- Debug log
		This.Parent.Log.Add(2,"Webserver.Process")

		*--- Check method
		if !inlist(This.Request.Method,"GET","POST","PUT","DELETE","HEAD","OPTIONS")
			m.llBadRequest = .T.
		endif

		*--- Check protocol
		if left(This.Request.Server_Protocol,4) # "HTTP"
			m.llBadRequest = .T.
		endif

		*--- Servers MUST report a 400 Bad Request error if a HTTP/1.1 request does not include a Host request-header
		if This.Request.Server_Protocol > "HTTP/1.0" AND empty(This.Request.Host)
			m.llBadRequest = .T.
		endif

		*--- Bad request
		if m.llBadRequest
			This.SendError("400","Bad Request","Bad Request")
			return .T.
		endif
		
		*--- Working directory
		if empty(This.Request.Document_Root)
			*--- Open sites table
			if !used("sites")
				use data\sites in 0
			endif

			*--- Locate host in sites table and define working directory
			select sites
			locate for server = This.Parent.ServerID AND (hostname = This.Request.Host OR hostname = "*")

			if !eof()
				do case
				case !empty(sites.directory)
					*--- Site found
					This.SiteID    = sites.id
					This.SiteIndex = alltrim(sites.index)
					This.Directory = alltrim(sites.directory)
				case !empty(sites.redirect)
					*--- Redirect
					This.Redirect(alltrim(sites.redirect)+This.Request.Request_URI,.T.)

					*--- Send redirect
					This.SendResponse()

					return .T.
				endcase
			endif

			*--- Host not found
			if empty(This.Directory)
				This.SendError("404","Not Found","Not Found")
				return .T.
			endif
		else
			*--- Defined by DOCUMENT_ROOT header (Fast CGI)
			This.Directory = This.Request.Document_Root
		endif

		*--- Convert \ to / and remove the last /
		This.Directory = rtrim(chrtran(This.Directory,"\","/"),"/")

		*--- Cookies
		if !empty(This.Request.Cookie)
			This.GetCookies()
		endif

		*--- Get variables
		if This.Request.Content_Type = "application/x-www-form-urlencoded"
			do case
			case !empty(This.Request.Content)
				This.GetVariables(This.Request.Content)
			case !empty(This.Request.Query_String)
				This.GetVariables(This.Request.Query_String)
			endcase
		endif

		*--- Check authorization
		if !This.Authorize()
			return .T.
		endif

		do case
		case "application/json" $ This.Request.Accept AND justext(This.Request.Document_URI) # "json" && REST Request
			*--- Requested method
			if !inlist(This.Request.Method,"GET","POST","PUT","DELETE","HEAD","OPTIONS")
			    This.SendError("501","Not implemented","Not implemented","Opss... This method is not implemented...")
				return .T.
			endif

			do case
			case This.Request.Method = "OPTIONS"
				This.Response.Status_Code        = "200"
				This.Response.Status_Description = "OK"
				This.Response.Allow              = "GET,POST,PUT,DELETE,HEAD,OPTIONS"
				This.Response.Content_Type       = "httpd/unix-directory"
			otherwise
				*--- Verify if URI exists
				if !file(This.Directory+This.Request.Document_URI+".fxp") AND !file(This.Directory+This.Request.Document_URI+".prg")
					*--- If URI don't exists perhaps it's the ID
					This.Request.ID  = substr(This.Request.Document_URI,rat("/",This.Request.Document_URI)+1)
					This.Request.Document_URI = substr(This.Request.Document_URI,1,rat("/",This.Request.Document_URI)-1)

					*--- Verify if URI exists
					if !file(This.Directory+This.Request.Document_URI+".fxp") AND !file(This.Directory+This.Request.Document_URI+".prg")
						This.SendError("404","Not Found","Not Found")
						return .T.
					endif
				endif

				*--- Close any open table
				close databases all

				*--- Create REST Processor object
				This.NewObject("REST","RESTProcessor","core\rest.fxp")

				*--- Process
				This.HasError = !This.REST.Process(This.Request.Document_URI)

				*--- Release HTML Processor object
				This.RemoveObject("REST")
			endcase
		otherwise
			*--- Requested method
			if !inlist(This.Request.Method,"GET","POST","HEAD","OPTIONS")
			    This.SendError("501","Not implemented","Not implemented","Opss... This method is not implemented...")
				return .T.
			endif

			do case
			case This.Request.Method = "OPTIONS"
				This.Response.Status_Code        = "200"
				This.Response.Status_Description = "OK"
				This.Response.Allow              = "GET,POST,HEAD,OPTIONS"
				This.Response.Content_Type       = "httpd/unix-directory"
			otherwise
				*--- URI points to a folder, send index
				do case
				case right(This.Request.Document_URI,1) = "/" 
					This.Request.Document_URI = This.Request.Document_URI+This.SiteIndex
				case empty(justext(This.Request.Document_URI)) AND directory(This.Directory+This.Request.Document_URI)
					This.Request.Document_URI = This.Request.Document_URI+"/"+This.SiteIndex
				endcase

				*--- FXP Pages or Unknown HTML Pages
				if justext(This.Request.Document_URI) = "fxp" OR ;
				  (justext(This.Request.Document_URI) = "html" AND !file(This.Directory+This.Request.Document_URI))
					*--- Close any open table
					close databases all

					*--- Create HTML Processor object
					This.NewObject("HTML","HTMLProcessor","core\html.fxp")

					*--- Process
					This.HasError = !This.HTML.Process(This.Request.Document_URI)

					*--- Release HTML Processor object
					This.RemoveObject("HTML")
				else
					*--- URI not found
					if !file(This.Directory+This.Request.Document_URI)
						This.SendError("404","Not Found","Not Found")
						return .T.
					endif

					*--- Get file time and convert to GMT
					m.ldFile = dt2utc(fdate(This.Directory+This.Request.Document_URI,1))

					*--- Check If Modified
					if !empty(This.Request.If_Modified_Since) AND m.ldFile = This.FullDate(This.Request.If_Modified_Since)
						*--- Dont send file
						This.Response.Status_Code        = "304"
						This.Response.Status_Description = "Not Modified"
					else
						*--- Send file
						This.Response.Status_Code        = "200"
						This.Response.Status_Description = "OK"

						*--- Read file
						This.Response.FileName = This.Directory+This.Request.Document_URI

						*--- Define MIME format
						This.Response.Content_Type = strextract(This.Mime,"|"+justext(This.Request.Document_URI)+"|","|")

						if empty(This.Response.Content_Type)
							This.Response.Content_Type = "application/octet-stream"
						endif

						*--- Send cache information
						This.Response.Last_Modified = m.ldFile
					endif
				endif
			endcase
		endcase

		*--- Success!
		if !This.HasError
			*--- Send data
			This.SendResponse()
		endif
	ENDPROC

	PROCEDURE Authorize()
	LOCAL llAuthorized,lcData,lcUserName,lcPassword,lcRealm,lcNonce,lcURI,lcResponse,lcA1,lcA2,lcResult
		*--- Don't allow ..
		if ".." = This.Request.Request_URI
			This.SendError("403","Forbidden","Forbidden","Opss... You can't accesss this resource...")
			return .F.
	    endif

		*--- Open realms table
		if !used("realms")
			use data\realms in 0
		endif

		*--- Locate the realm 
		select realms
		locate for site = This.SiteID AND (directory = padr(justpath(This.Request.Document_URI),100) OR (subfolders AND justpath(This.Request.Document_URI) = alltrim(directory)))

		*--- Directory requires authorization
		if !empty(realms.type)
			*--- Debug log
			This.Parent.Log.Add(2,"Webserver.Authorize")

			*--- Not authorized
			m.llAuthorized = .F.

			*--- Authorization information
			if !empty(This.Request.Authorization)
				do case
				case realms.type = "Basic"
					*--- Authorization information
					m.lcData     = strconv(substr(This.Request.Authorization,7),14)
					m.lcUserName = substr(m.lcData,1,at(":",m.lcData)-1)
					m.lcPassword = substr(m.lcData,at(":",m.lcData)+1)

					*--- Query user password
					SELECT password ;
						FROM data\realmuser ;
						INNER JOIN data\users ON realmuser.user = users.id ;
						WHERE realmuser.realm = realms.id  AND ;
							  users.username = m.lcUserName ;
						INTO CURSOR user

					*--- Verify password
					select user
					if !empty(m.lcPassword) AND m.lcPassword == alltrim(user.password)
						m.llAuthorized = .T.
					endif

					*--- Close user query
					use
				case realms.type = "Digest"
					*--- Authorization information
					m.lcUserName = strextract(This.Request.Authorization,[username="],["])
					m.lcRealm    = strextract(This.Request.Authorization,[realm="],["])
					m.lcNonce    = strextract(This.Request.Authorization,[nonce="],["])
					m.lcURI      = strextract(This.Request.Authorization,[uri="],["])
					m.lcResponse = strextract(This.Request.Authorization,[response="],["])

					*--- Check same realm
					if m.lcRealm = alltrim(realms.realm)
						*--- Query user password
						SELECT password ;
							FROM data\realmuser ;
							INNER JOIN data\users ON realmuser.user = users.id ;
							WHERE realmuser.realm = realms.id  AND ;
								  users.username = m.lcUserName ;
							INTO CURSOR user

						*--- Password
						m.lcPassword = alltrim(user.password)

						*--- Close user query
						select user
						use

						*--- Don't accept empty passwords
						if !empty(m.lcPassword)
							*--- Digest authentication
							m.lcA1 = lower(strconv(hash(m.lcUserName+":"+m.lcRealm+":"+m.lcPassword,5),15))
							m.lcA2 = lower(strconv(hash(This.Request.Method+':'+m.lcURI,5),15))
							m.lcResult = lower(strconv(hash(m.lcA1+":"+m.lcNonce+":"+m.lcA2,5),15))

							*--- Verify access
							if m.lcResult = m.lcResponse
								m.llAuthorized = .T.
							endif
						endif
					endif
				endcase
			endif

			*--- No authorization
			if !m.llAuthorized
				*--- Check if this realm should ask for username and password
				if realms.ask
					*--- User authorization response header
					This.Response.Status_Code        = "401"
					This.Response.Status_Description = "Unauthorized"
					do case
					case realms.type = "Basic"
						This.Response.Authenticate = 'Basic'+;
													 ' realm="'+alltrim(realms.realm)+'"'
					case realms.type = "Digest"
						This.Response.Authenticate = 'Digest'+;
													 ' realm="'+alltrim(realms.realm)+'",'+;
													 ' algorithm=MD5,'+;
													 ' nonce="'+lower(strconv(hash(ttoc(datetime())+":"+sys(2015),5),15))+'"'
					endcase
				else
					*--- Don't ask for password
					This.Response.Status_Code        = "403"
					This.Response.Status_Description = "Forbidden"
				endif

				*--- Send authorization requistion
				This.SendResponse()

				return .F.
			endif

			return .T.
		endif
	ENDPROC

	PROCEDURE Redirect(URI AS String,Permanent AS Boolean)
		*--- Debug log
		This.Parent.Log.Add(2,"Webserver.Redirect")

		*--- Permanent or temporary redirection
		if m.Permanent
			This.Response.Status_Code        = "301"
			This.Response.Status_Description = "Moved Permanently"
		else
			This.Response.Status_Code        = "302"
			This.Response.Status_Description = "Found"
		endif

		*--- Redirect MUST send new location and close connection
		This.Response.Connection = "close"
		This.Response.Location   = m.URI
	ENDPROC

	PROCEDURE SendError(Code AS String,Text AS String,Title AS String,Message AS String)
		This.Response.Status_Code        = m.Code
		This.Response.Status_Description = m.Text

		do case
		case !empty(Message) AND "text/html" $ This.Request.Accept 
			This.Response.OutPut      = "<HTML>"+;
										 "<TITLE>"+m.Title+"</TITLE>"+;
										 "<BODY>"+"<H3>"+m.Title+"</H3>"+;
										 "<P>"+m.Message+"</P>"+;
										 "<P><EM>FOX_PAGES_VERSION</EM></P>"+;
										 "</BODY></HTML>"
			This.Response.Content_Type = "text/html"
		case !empty(Message) AND "application/json" $ This.Request.Accept
			This.Response.OutPut      = [{"statusCode": "]+m.Code+[", ]+;
										 ["statusDescription": "]+m.Text+[", ]+;
										 ["title": "]+m.Title+[", ]+;
										 ["message": ]+iif(m.Message = ["],m.Message,["]+m.Message+["])+[}]
			This.Response.Content_Type = "application/json"
		endcase

		*--- Send error
		This.SendResponse()
	ENDPROC

	PROCEDURE SendResponse()
	LOCAL Cookie
		*--- Content
		if !empty(This.Response.Content)
			This.Response.OutPut = This.Response.Content
		endif

		*--- Compression
		if "deflate" $ This.Request.Accept_Encoding AND !empty(This.Response.OutPut) AND !(justext(This.Request.Document_URI) $ ";gif;jpg;png;")
			This.Response.OutPut          = zipstring(This.Response.OutPut)
			This.Response.Content_Encoding = iif("Trident" $ This.Request.User_Agent,"gzip","deflate")
		endif

		*--- HTTP header
		This.Response.Header = "HTTP/1.1 "+This.Response.Status_Code+" "+This.Response.Status_Description+CRLF
		
		*--- Allow
		if !empty(This.Response.Allow)
			This.Response.Header = This.Response.Header + "Allow: "+alltrim(This.Response.Allow)+CRLF
		endif

		*--- Authenticate
		if !empty(This.Response.Authenticate)
			This.Response.Header = This.Response.Header + "WWW-Authenticate: "+alltrim(This.Response.Authenticate)+CRLF
		endif

		*--- Connection
		if This.Parent.KeepAlive = 1 AND This.Response.Connection == "keep-alive" AND !This.Parent.Queued
			This.Response.Header = This.Response.Header + "Connection: keep-alive"+CRLF
			This.Parent.IsClosing = .F.
		else
			This.Response.Header = This.Response.Header + "Connection: close"+CRLF
			This.Parent.IsClosing = .T.
		endif

		*--- Cache-control
		if !empty(This.Response.Cache_Control)
			This.Response.Header = This.Response.Header + "Cache-Control: "+alltrim(This.Response.Cache_Control)+CRLF
		else
			if This.Response.Status_Code = "200"
				do case
				case inlist(justext(This.Request.Document_URI),"gif","jpg","png")
					*--- 30 days cache
					This.Response.Header = This.Response.Header + "Cache-Control: max-age=2592000"+CRLF
				endcase
			endif
		endif

		*--- Content-Disposition
		if !empty(This.Response.Content_Disposition)
			This.Response.Header = This.Response.Header + "Content-Disposition: "+alltrim(This.Response.Content_Disposition)+CRLF
		endif

		*--- Content-Encoding
		if !empty(This.Response.Content_Encoding)
			This.Response.Header = This.Response.Header + "Content-Encoding: "+This.Response.Content_Encoding+CRLF
		endif

		*--- Content-Range
		if !empty(This.Response.Content_Range)
			This.Response.Header = This.Response.Header + "Content-Range: "+This.Response.Content_Range+CRLF
		endif

		*--- Chuked transfer encoding
		if This.Parent.Type = "HTTP" AND This.Parent.Chunked = 1 AND This.Response.Status_Code = "200" AND This.Request.Server_Protocol > "HTTP/1.0"
			This.Response.Transfer_Encoding = "chunked"
		endif

		*--- Content-Length
		if This.Response.Transfer_Encoding # "chunked"
			if !empty(This.Response.FileName)
				This.Response.Header = This.Response.Header + "Content-Length: "+alltrim(str(GetFileSize(This.Response.FileName)))+CRLF
			else
				This.Response.Header = This.Response.Header + "Content-Length: "+alltrim(str(len(This.Response.OutPut)))+CRLF
			endif
		endif

		*--- Content-Type
		if !empty(This.Response.Content_Type)
			This.Response.Header = This.Response.Header + "Content-Type: "+This.Response.Content_Type+CRLF
		endif

		*--- Date
		if This.Response.Status_Code = "200"
			This.Response.Header = This.Response.Header + "Date: "+This.FullDate(GetSystemTime(.T.))+CRLF
		endif

		*--- Expires
		if !empty(This.Response.Expires)
			do case
			case type("This.Response.Expires") = "N"
				This.Response.Header = This.Response.Header + "Expires: "+alltrim(str(This.Response.Expires))+CRLF
			case type("This.Response.Expires") = "T"
				This.Response.Header = This.Response.Header + "Expires: "+This.FullDate(This.Response.Expires)+CRLF
			endcase
		endif

		*--- Last-Modified
		if !empty(This.Response.Last_Modified)
			This.Response.Header = This.Response.Header + "Last-Modified: "+This.FullDate(This.Response.Last_Modified)+CRLF
		endif

		*--- Location
		if !empty(This.Response.Location)
			This.Response.Header = This.Response.Header + "Location: "+This.Response.Location+CRLF
		endif

		*--- Pragma
		if !empty(This.Response.Pragma)
			This.Response.Header = This.Response.Header + "Pragma: "+This.Response.Pragma+CRLF
		endif

		*--- Transfer_Encoding
		if !empty(This.Response.Transfer_Encoding)
			This.Response.Header = This.Response.Header + "Transfer-Encoding: "+This.Response.Transfer_Encoding+CRLF
		endif

		*--- Vary
		if !empty(This.Response.Vary)
			This.Response.Header = This.Response.Header + "Vary: "+This.Response.Vary+CRLF
		endif

		*--- Cookies
		if inlist(This.Response.Status_Code,"200","301","302")
			for each m.Cookie in This.Response.SettingCookies.Objects
				if !isnull(m.Cookie.Value)
					*--- Name and value
					This.Response.Header = This.Response.Header + "Set-Cookie: "+m.Cookie.Name+"="+m.Cookie.Value+";"

					*--- Expires
					if !empty(m.Cookie.Expires)
						This.Response.Header = This.Response.Header + " Expires="+This.FullDate(m.Cookie.Expires)+";"
					endif

					*--- Max-Age
					if m.Cookie.MaxAge >= 0
						This.Response.Header = This.Response.Header + " Max-Age="+alltrim(str(m.Cookie.MaxAge))+";"
					endif

					*--- Path
					if !isnull(m.Cookie.Path)
						This.Response.Header = This.Response.Header + " Path="+m.Cookie.Path+";"
					endif

					*--- HTTPOnly
					if m.Cookie.HTTPOnly
						This.Response.Header = This.Response.Header + " HTTPOnly;"
					endif

					*--- Secure
					if m.Cookie.Secure
						This.Response.Header = This.Response.Header + " Secure;"
					endif

					This.Response.Header = This.Response.Header + CRLF
				endif
			next
		endif

		*--- Server
		This.Response.Header = This.Response.Header + "Server: "+This.Request.Server_Software+" FXP/2.0.0"

		*--- Delimiter
		This.Response.Header = This.Response.Header + HEADER_DELIMITER

		*--- Store bytes sent
		This.Response.Bytes = len(This.Response.Header)

		*--- Send data
		This.Parser.Send()
	ENDPROC

	PROCEDURE SetCookie(Name AS String,Value AS String,Expires AS DateTime,MaxAge AS Integer,Path AS String,HTTPOnly AS Boolean,Secure AS Boolean)
	LOCAL lnCookies
		*--- Remove existing cookie
		if type("This.Request.Cookies."+m.Name) = "O"
			This.Request.Cookies.RemoveObject(m.Name)
		endif

		*--- Check if expired
		if empty(m.Expires) OR m.Expires > datetime() OR !empty(m.MaxAge) AND m.MaxAge > 0
			This.Request.Cookies.AddObject(m.Name,"Cookie",m.Value)
		endif

		This.Response.SettingCookies.AddObject(m.Name,"Cookie",m.Value,m.Expires,m.MaxAge,m.Path,m.HTTPOnly,m.Secure)
	ENDPROC

	PROCEDURE GetCookies()
	LOCAL lnLine,lcLine,lcName,lcValue,lcRemaining
		m.lcCookies = This.Request.Cookie

		*--- Debug log
		This.Parent.Log.Add(2,"Webserver.GetCookies")

		*--- Add an extra ";"
		if right(m.lcCookies,1) # ";"
			m.lcCookies = m.lcCookies + ";"
		endif

		*--- Create cookies objects
		do while ";" $ m.lcCookies
			m.lcName  = substr(m.lcCookies,1,at("=",m.lcCookies)-1)
			m.lcValue = substr(m.lcCookies,at("=",m.lcCookies)+1,at(";",m.lcCookies)-at("=",m.lcCookies)-1)

			m.lcCookies  = ltrim(substr(m.lcCookies,at(";",m.lcCookies)+1))

			*--- Change invalid cookie name
			m.lcName = This.ParseName(m.lcName)

			if type("This.Request.Cookies."+m.lcName) = "U"
				This.Request.Cookies.AddObject(m.lcName,"Cookie",m.lcValue)
			endif
		enddo
	ENDPROC

	PROCEDURE GetVariables(Variables AS String)
	LOCAL lnLine,lcLine,lcName,lcValue
		if empty(m.Variables)
			return .T.
		endif

		*--- Debug log
		This.Parent.Log.Add(2,"Webserver.GetVariables")

		*--- Transform "&" into lines
		m.Variables = strtran(m.Variables,"&",CRLF)

		*--- Create variables objects
		for m.lnLine = 1 to memlines(m.Variables)
			m.lcLine = mline(m.Variables,m.lnLine)

			*--- Check if it's a variable
			if !("=" $ m.lcLine)
				loop
			endif

			*--- Variable name and value
			m.lcName  = alltrim(substr(m.lcLine,1,at("=",m.lcLine)-1))
			m.lcValue = This.URLDecode(substr(m.lcLine,at("=",m.lcLine)+1),.T.)

			*--- Change invalid variable name
			m.lcName = This.ParseName(m.lcName)

			*--- Add variable object
			This.Request.Variables.AddObject(m.lcName,"Variable",m.lcValue)
		next
	ENDPROC

	PROCEDURE FullDate(FullDate AS Variant)
		*--- Verify if is DateTime
		do case
		case type("m.FullDate") = "C"
			return ctot(substr(m.FullDate,13,4)+"-"+;
				   transform(occurs(",",substr([,Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec],1,at(substr(m.FullDate,9,3),[,Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec])-1)),"@L 99")+"-"+;
				   substr(m.FullDate,6,2)+"T"+substr(m.FullDate,18,8))
		case type("m.FullDate") = "T"
			*--- Return HTTP FullDate
			return substr([,Sun,Mon,Tue,Wed,Thu,Fri,Sat,],at([,],[,Sun,Mon,Tue,Wed,Thu,Fri,Sat,],dow(m.FullDate))+1,4)+" "+;
			       transform(day(m.FullDate),"@L 99")+" "+;
			       substr([,Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec"],at([,],[,Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec],month(m.FullDate))+1,3)+" "+;
			       transform(year(m.FullDate),"@L 9999")+" "+;
			       transform(hour(m.FullDate),"@L 99")+":"+transform(minute(m.FullDate),"@L 99")+":"+transform(sec(m.FullDate),"@L 99")+" GMT"
		otherwise
			return ""
		endcase
	ENDPROC

	PROCEDURE URLEncode(Source AS String, Plus AS Boolean)
	LOCAL lcResult,lcChar,lnChar

		m.lcResult = ""
		for m.lnChar = 1 to len(m.Source)
			m.lcChar = substr(m.Source,m.lnChar,1)

			do case
			case upper(m.lcChar) $ "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.~-_"
				m.lcResult = m.lcResult + m.lcChar
				loop
			case m.lcChar = "%"
				m.lcResult = m.lcResult + "%25"
				loop
			case m.lcChar = " " AND m.Plus
				m.lcResult = m.lcResult + "+"
				loop
			endcase

			m.lcResult = m.lcResult + "%"+right(transform(asc(m.lcChar),"@0"),2)
		next

		return m.lcResult
	ENDPROC

	PROCEDURE URLDecode(Source AS String, Plus AS Boolean)
	LOCAL lcResult,lcChar,lnChar

		m.lcResult = ""
		for m.lnChar = 1 to len(m.Source)
			m.lcChar = substr(m.Source,m.lnChar,1)

			do case
			case m.lcChar = "+" AND m.Plus
				m.lcResult = m.lcResult + " "
				loop
			case m.lcChar # "%"
				m.lcResult = m.lcResult + m.lcChar
				loop
			endcase

			m.lcResult = m.lcResult + chr(evaluate("0x"+substr(m.Source,m.lnChar+1,2)))
			m.lnChar = m.lnChar + 2
		next

		return m.lcResult
	ENDPROC

	HIDDEN PROCEDURE ParseName(Name AS String)
	LOCAL lnDig,lcDig,lcResult
		*--- Remove invalid characters from name string
		m.lcResult = ""
		for m.lnDig = 1 to len(m.Name)
			m.lcDig = substr(m.Name,m.lnDig,1)
			if isalpha(m.lcDig) OR isdigit(m.lcDig) OR inlist(m.lcDig,"_")
				m.lcResult = m.lcResult + m.lcDig
			endif
		next

		*--- Add _ to name string starting with numeric digit
		if isdigit(left(m.lcResult,1))
			m.lcResult= "_"+m.lcResult
		endif
		
		return m.lcResult
	ENDPROC
ENDDEFINE

******************************************************************************************
* Request class
***************
DEFINE CLASS Request AS CUSTOM
	*--- Hide class properties
	HIDDEN BaseClass,ClassLibrary,Class,Comment,ControlCount,Controls,Height,HelpContextID,Left,Objects,Parent,ParentClass,Picture,Tag,Top,WhatsThisHelpID,Width

	*--- Request properties
	Accept					= ""
	Accept_Encoding			= ""
	Authorization			= ""
	Connection				= ""
	Content					= ""
	Content_Length			= ""
	Content_Type			= ""
	Cookie					= ""
	Data					= ""
	Document_Root			= ""
	Document_URI			= ""
	Gateway_Interface		= ""
	Host					= ""
	ID						= ""
	If_Modified_Since		= ""
	Method					= ""
	Query_String			= ""
	Range					= ""
	Referer					= ""
	Remote_Address			= ""
	Remote_Port				= ""
	ReqID					= 0
	Request_Scheme			= ""
	Request_URI				= ""
	Role					= 0
	Script_Name				= ""
	Script_FileName 		= ""
	Server_Address			= ""
	Server_Name				= ""
	Server_Port				= ""
	Server_Protocol			= ""
	Server_Software			= ""
	Type					= 0
	User_Agent				= ""

	*--- Resquest objects
	ADD OBJECT Cookies   AS Cookies && Cookies container object
	ADD OBJECT Variables AS Variables && Variables container object

	PROCEDURE Error(nError,cMethod,nLine)
		*--- Debug log
		This.Parent.Parent.Log.Add(0,"Webserver.Request.Error","Method: "+proper(m.cMethod)+CRLF+"Message: "+message())
	ENDPROC
ENDDEFINE

******************************************************************************************
* Response class
***************
DEFINE CLASS Response AS CUSTOM
	*--- Hide class properties
	HIDDEN BaseClass,ClassLibrary,Class,Comment,ControlCount,Controls,Height,HelpContextID,Left,Objects,Parent,ParentClass,Picture,Tag,Top,WhatsThisHelpID,Width

	*--- Response properties
	Allow				= ""
	Authenticate		= ""
	Bytes				= 0
	Cache_Control		= ""
	Connection			= ""
	Content				= ""
	Content_Disposition	= ""
	Content_Encoding	= ""
	Content_Range		= ""
	Content_Type		= ""
	Expires				= {}
	FileName			= ""
	Header				= ""
	Last_Modified		= {}
	Location			= ""
	Output				= ""
	Pragma				= ""
	Status_Code			= ""
	Status_Description	= ""
	Transfer_Encoding	= ""
	Vary				= ""

	*--- Resquest objects
	ADD OBJECT SettingCookies AS CUSTOM && Sending cookies container object
ENDDEFINE

******************************************************************************************
* Cookies class
***************
DEFINE CLASS Cookie AS CUSTOM
	*--- Hide class properties
	HIDDEN BaseClass,Class,ClassLibrary,Comment,ControlCount,Controls,Height,HelpContextID,Left,Objects,Parent,ParentClass,Picture,Tag,Top,WhatsThisHelpID,Width

*	Name     = ""    && Cookie name
	Value    = NULL  && Value of the cookie
	Expires  = {}    && Expiration datetime of the cookie
	MaxAge   = -1    && MaxAge of the Cookie
	Path     = NULL  && Path of the cookie
	HTTPOnly = .F.   && HTTP Protocol only cookie
	Secure   = .F.   && Secure connections only cookie

	PROCEDURE Init(Value AS String, Expires AS DateTime, MaxAge AS Integer, Path AS String, HTTPOnly AS Boolean, Secure AS Boolean)
		This.Value  = m.Value
		if type("Expires") = "T"
			This.Expires = m.Expires
		endif
		if type("MaxAge") = "N"
			This.MaxAge = m.MaxAge
		endif
		if type("Path") = "C"
			This.Path = m.Path
		endif
		This.HTTPOnly = m.HTTPOnly
		This.Secure = m.Secure
	ENDPROC
ENDDEFINE

******************************************************************************************
* Cookies class
***************
DEFINE CLASS Cookies AS CUSTOM
	*--- Hide class properties
	HIDDEN BaseClass,Class,ClassLibrary,Comment,ControlCount,Controls,Height,HelpContextID,Left,Objects,Parent,ParentClass,Picture,Tag,Top,WhatsThisHelpID,Width
ENDDEFINE

******************************************************************************************
* Variables class
*****************
DEFINE CLASS Variable AS CUSTOM
	*--- Hide class properties
	HIDDEN BaseClass,Class,ClassLibrary,Comment,ControlCount,Controls,Height,HelpContextID,Left,Objects,Parent,ParentClass,Picture,Tag,Top,WhatsThisHelpID,Width

*	Name = ""  && Variable name
	Value = "" && Variable value (always as character)

	PROCEDURE Init(Value AS Variant)
		This.Value = m.Value
	ENDPROC
ENDDEFINE

******************************************************************************************
* Variables class
*****************
DEFINE CLASS Variables AS CUSTOM
	*--- Hide class properties
	HIDDEN BaseClass,Class,ClassLibrary,Comment,ControlCount,Controls,Height,HelpContextID,Left,Objects,Parent,ParentClass,Picture,Tag,Top,WhatsThisHelpID,Width
ENDDEFINE
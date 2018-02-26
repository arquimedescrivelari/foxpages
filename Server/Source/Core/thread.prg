#INCLUDE foxpages.h

******************************************************************************************
* Thread Class
**************
DEFINE CLASS Thread AS CUSTOM OLEPUBLIC
	*--- Properties
	Bandwidth			= 0	
	CallBack			= NULL
	CertificateName		= ""
	CertificateStore	= ""
	CertificatePassword = ""
	Chunked				= 0
	Compression         = 0
	IsClosing			= .F.
	KeepAlive			= 0
	LogRequests			= 0
	LogLevel			= 0
	Type				= ""
	Queued				= .F.
	Password            = ""
	Receiving			= ""
	Compression         = 0
	RemoteHost			= ""
	RemotePort			= 0
	Secure				= 0
	ServerID			= ""
	ServerName			= ""
	StartMode			= 0
	ThreadIndex			= 0

	HIDDEN PROCEDURE Init()
		*--- Put ActiveX events in queue.
		_VFP.AutoYield = .F.

		*--- Declare
		DECLARE Sleep IN Win32API INTEGER

		*--- Sets
		set deleted on
		set exclusive off
		set memowidth to 8192
		set sysformats on

		*--- Load FLL
		#IFDEF X64
			set library to bin64\vfp2c32.fll
		#ELSE
			set library to bin\vfp2c32t.fll,bin\vfpcompression.fll,bin\vfpencryption.fll
		#ENDIF

		*--- Create socket
		This.NewObject("Socket","Socket","core\socket.fxp")

		*--- Log object
		This.NewObject("Log","Log","core\log.fxp")
	ENDPROC

	HIDDEN PROCEDURE Destroy()
		*--- Debug log
*		This.Log.Add(1,"Destroy")
	ENDPROC

	PROCEDURE Error(nError,cMethod,nLine)
		This.Log.Add(0,"Error","Method: "+proper(m.cMethod)+CRLF+"Message: "+message())
	ENDPROC

	PROCEDURE Accept(Handle AS Integer)
	LOCAL lnReturn
		*--- Clear buffer
		This.Receiving = ""

		*--- Reset Log
		This.Log.Reset()

		*--- Debug log
		This.Log.Add(1,"Accept")

		*--- Secure conections
		if This.Secure = 1
			This.Socket.CertificateName     = This.CertificateName
			This.Socket.CertificateStore    = This.CertificateStore
			This.Socket.CertificatePassword = This.CertificatePassword
			This.Socket.Secure              = .T.
		endif

		m.lnReturn = This.Socket.Accept(m.Handle)
			
		*--- Connection error
		if lnReturn # 0
			*--- Debug log
			This.Log.Add(0,"ConnectionError","Error code: "+alltrim(str(m.lnReturn)))
		endif
	ENDPROC

	PROCEDURE Reject()
		*--- Debug log
		This.Log.Add(1,"Reject")

		*---- Reject connection
		This.Socket.Reject()
	ENDPROC

	PROCEDURE Disconnect()
		*--- Debug log
		This.Log.Add(1,"Disconnect")

		*--- Disconnect socket		
		This.Socket.Disconnect()
		
*!*			if inlist(This.Type,"TUNNEL","TUNNEX") AND type("This.Tunnel") = "O"
*!*				*--- Diconnect tunnel
*!*				This.Tunnel.Disconnect()
*!*				
*!*				*--- Remove Tunnel object
*!*				This.RemoveObject("Tunnel")
*!*			endif

		*--- Update ThreadState to disconnected
		This.CallBack.ThreadState = 0
		This.CallBack.LastUse = datetime()
	ENDPROC

	PROCEDURE Process(Request AS String)
	LOCAL lcHeader,lcAccept,lcHost,lcURI
		*--- Reset log
		This.Log.Reset()

		*--- Debug log
		This.Log.Add(1,"Process")

		This.Receiving = This.Receiving + m.Request

		do case
		case This.Type = "HTTP" OR This.Type = "FCGI"
			*--- Update ThreadState to in use
			This.CallBack.ThreadState = 2
			This.CallBack.LastUse = datetime()

			do case
			case This.Type = "HTTP" && Hypertext Transport Protocol
				*--- Incomplete request
				if !(HEADER_DELIMITER $ This.Receiving)
					return .T.
				endif

				*--- Request header
				m.lcHeader = substr(This.Receiving,1,at(HEADER_DELIMITER,This.Receiving)+3)

				*--- Request can be received in multiple packets
				if val(strextract(m.lcHeader,"Content-Length: ",CRLF))+len(m.lcHeader) > len(This.Receiving)
					return .T.
				endif

				*--- Get request values
				m.lcAccept = strextract(m.lcHeader,"Accept: ",CRLF)
				m.lcHost   = strextract(m.lcHeader,"Host: ",CRLF)
				m.lcURI    = strextract(m.lcHeader," "," HTTP/")

				*--- Extract Query_String
				if '?' $ m.lcURI
				    m.lcURI = substr(m.lcURI,1,at('?',m.lcURI)-1)
				else
				    m.lcURI = m.lcURI
				endif

				*--- No URI, send index page
				if right(m.lcURI,1) = "/"
					*--- Open sites table
					if !used("sites")
						use data\sites in 0
					endif

					*--- Locate host in sites table and define index page
					select sites
					locate for server = This.ServerID AND (hostname = m.lcHost OR hostname = "*")

				    m.lcURI = m.lcURI + alltrim(sites.index)
				endif
			case This.Type = "FCGI" && FastCGI Protocol
				*--- Incomplete request, wait next read event. FastCGI requests must end with a empty FCGI_STDIN record.
				if right(This.Receiving,8) # bintoc(FCGI_VERSION_1,"1S")+bintoc(FCGI_STDIN,"1S") OR right(This.Receiving,4) # bintoc(0,"2S")+bintoc(0,"1S")
					return .T.
				endif

				*--- Get request values
				m.lcAccept = substr(This.Receiving,at("HTTP_ACCEPT",This.Receiving)+11,ctobin(chr(0)+substr(This.Receiving,at("HTTP_ACCEPT",This.Receiving)-1,1),"S"))
				m.lcHost   = substr(This.Receiving,at("HTTP_HOST",This.Receiving)+9,ctobin(chr(0)+substr(This.Receiving,at("HTTP_HOST",This.Receiving)-1,1),"S"))
				m.lcURI    = substr(This.Receiving,at("DOCUMENT_URI",This.Receiving)+12,ctobin(chr(0)+substr(This.Receiving,at("DOCUMENT_URI",This.Receiving)-1,1),"S"))
			endcase
			
			*--- Open gateways table
			if !used("gateways")
				use data\gateways in 0
			endif

			*--- Locate host in gateways table
			select gateways
			locate for server = This.ServerID AND (hostname = m.lcHost OR hostname = "*") AND (alltrim(uri) $ m.lcURI OR uri = "*")

			if !eof()
				*--- Create Gateway Processor
				This.NewObject("Gateway","Gateway","core\gateway.fxp")

				*--- Set Gateway properties
				This.Gateway.Directory  = alltrim(gateways.directory)
				This.Gateway.Protocol   = alltrim(gateways.protocol)
				This.Gateway.RemoteHost = alltrim(gateways.host)
				This.Gateway.RemotePort = gateways.port
				
				*--- Process received data
				This.Gateway.Process()
			else
				*--- On development mode requests must be queued to avoid conflicts when debbuging
				if This.StartMode = 0 AND (justext(m.lcURI) = "fxp" OR "application/json" $ m.lcAccept)
					*--- This is a FXP or REST request, put in queue
					This.Queued = .T.
				else
					*--- Don't queue
					This.Continue()
				endif
			endif
		case This.Type = "TUNNEL" && Tunnel Entry Points
			if type("This.Tunnel") # "O"
				*--- Create Tunnel object
				This.NewObject("Tunnel","Tunnel","core\tunnel.fxp")

				*--- Set tunnel properties
				This.Tunnel.RemoteHost  = This.RemoteHost
				This.Tunnel.RemotePort  = This.RemotePort
				This.Tunnel.Compression = This.Compression
				This.Tunnel.Password    = This.Password
			endif

			*--- Send request
			This.Tunnel.Send(This.Receiving)

			*--- Clear buffer
			This.Receiving = ""

			return
		case This.Type = "TUNNEX" && Tunnel Exit Points
			if type("This.Tunnel") # "O"
				*--- Create Tunnel object
				This.NewObject("Tunnel","Tunnel","core\tunnel.fxp")

				*--- Set tunnel properties
				This.Tunnel.RemoteHost  = This.RemoteHost
				This.Tunnel.RemotePort  = This.RemotePort
				This.Tunnel.Compression = This.Compression
				This.Tunnel.Password    = This.Password
			endif

			*--- Send request
			This.Tunnel.Receive(This.Receiving)

			*--- Clear buffer
			This.Receiving = ""

			return
		otherwise
			*--- Unknow yype, disconnect
			This.Disconnect()

			return
		endcase
	ENDPROC

	PROCEDURE Continue()
	LOCAL llProcess,lcMethod,lcHTTP
		*--- Continue processing, multiple requests (Pipelining)
		m.llProcess = .T.

		do while !empty(This.Receiving) AND m.llProcess
			*--- Create WebServer Processor
			This.NewObject("WebServer","WebServer","core\webserver.fxp")

			*--- Process received data
			m.llProcess = This.WebServer.Process()

			*--- Release WebServer Processor
			This.RemoveObject("WebServer")

			*--- Reset log
			This.Log.Reset()

			*--- Ignore aditional requests if not keeping connection alive
			if This.IsClosing
				exit
			endif
		enddo

		*--- Update ThreadState to connected
		This.CallBack.ThreadState = 1
		This.CallBack.LastUse = datetime()

		*--- Disconnet
		if This.IsClosing
			This.Disconnect()
		endif
	ENDPROC

	HIDDEN BaseClass,ClassLibrary,Class,Comment,ControlCount,Controls,Height,HelpContextID,Left,Objects,Parent,ParentClass,Picture,Tag,Top,WhatsThisHelpID,Width

	HIDDEN PROCEDURE ReadExpression()
	HIDDEN PROCEDURE ReadMethod()
	HIDDEN PROCEDURE ResetToDefault()
	HIDDEN PROCEDURE SaveAsClass()
	HIDDEN PROCEDURE ShowWhatsThis()
	HIDDEN PROCEDURE WriteExpression()
	HIDDEN PROCEDURE WriteMethod()
ENDDEFINE

******************************************************************************************
* Thread interface class
************************
DEFINE CLASS ThreadInterface AS CUSTOM
	*--- Last datetime thread was used
	LastUse = datetime()

	*--- Thread state
	* 0 - Disconnected
	* 1 - Connected
	* 2 - In Use
	* 3 - Disconnecting
	ThreadState = 1
ENDDEFINE
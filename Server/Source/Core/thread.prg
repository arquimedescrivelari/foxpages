#INCLUDE foxpages.h

******************************************************************************************
* Thread Class
**************
DEFINE CLASS Thread AS CUSTOM OLEPUBLIC
	*--- Properties
	Bandwidth			= 0
	Buffer				= ""
	ServerInterface		= NULL
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
	ENDPROC

	PROCEDURE Error(nError,cMethod,nLine)
		This.Log.Add(0,"Error","Method: "+proper(m.cMethod)+CRLF+"Message: "+message())
	ENDPROC

	PROCEDURE Accept(Handle AS Integer)
	LOCAL lnReturn
		*--- Clear buffer
		This.Buffer = ""

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

		*--- Update ThreadState to disconnected
		This.ServerInterface.ThreadState = 0
		This.ServerInterface.LastUse = datetime()
	ENDPROC

	PROCEDURE Process(Request AS String)
	LOCAL lcHeader,lcAccept,lcHost,lcURI
		*--- Reset log
		This.Log.Reset()

		*--- Debug log
		This.Log.Add(1,"Process")

		*--- Concatenate buffer data
		This.Buffer = This.Buffer + m.Request

		do case
		case This.Type = "HTTP" OR This.Type = "FCGI"
			do case
			case This.Type = "HTTP" && Hypertext Transport Protocol
				*--- Incomplete request
				if !(HEADER_DELIMITER $ This.Buffer)
					return .T.
				endif

				*--- Request header
				m.lcHeader = substr(This.Buffer,1,at(HEADER_DELIMITER,This.Buffer)+3)

				*--- Request can be received in multiple packets
				if val(strextract(m.lcHeader,"Content-Length: ",CRLF))+len(m.lcHeader) > len(This.Buffer)
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
				if right(This.Buffer,8) # UInt2Bin(FCGI_VERSION_1,1)+UInt2Bin(FCGI_STDIN,1) OR right(This.Buffer,4) # UInt2Bin(0,2)+UInt2Bin(0,1)
					return .T.
				endif

				*--- Get request values
				m.lcAccept = substr(This.Buffer,at("HTTP_ACCEPT",This.Buffer)+11,Bin2UInt(substr(This.Buffer,at("HTTP_ACCEPT",This.Buffer)-1,1)))
				m.lcHost   = substr(This.Buffer,at("HTTP_HOST",This.Buffer)+9,Bin2UInt(substr(This.Buffer,at("HTTP_HOST",This.Buffer)-1,1)))
				m.lcURI    = substr(This.Buffer,at("DOCUMENT_URI",This.Buffer)+12,Bin2UInt(substr(This.Buffer,at("DOCUMENT_URI",This.Buffer)-1,1)))
			endcase

			*--- Update ThreadState to in use
			This.ServerInterface.ThreadState = 2
			This.ServerInterface.LastUse = datetime()

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

			*--- Send buffer data
			This.Tunnel.Send(This.Buffer)

			*--- Clear buffer
			This.Buffer = ""
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

			*--- Send buffer data
			This.Tunnel.Receive(This.Buffer)

			*--- Clear buffer
			This.Buffer = ""
		otherwise
			*--- Unknow type, disconnect
			This.Disconnect()
		endcase
	ENDPROC

	PROCEDURE Continue()
	LOCAL llProcess,lcMethod,lcHTTP
		*--- Continue processing, multiple requests (Pipelining)
		m.llProcess = .T.
		do while !empty(This.Buffer) AND m.llProcess
			*--- Create Web Processor
			This.NewObject("Web","Web","core\web.fxp")

			*--- Process received data
			m.llProcess = This.Web.Process()

			*--- Release Web Processor
			This.RemoveObject("Web")

			*--- Reset log
			This.Log.Reset()

			*--- Ignore aditional requests if not keeping connection alive
			if This.IsClosing
				exit
			endif
		enddo

		*--- Update ThreadState to connected
		This.ServerInterface.ThreadState = 1
		This.ServerInterface.LastUse = datetime()

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

*--- Returns an Unsigned Integer from a Binary String
FUNCTION Bin2UInt(Binary AS String)
LOCAL lnLenght,lnByte,lcBinary
	*--- Binary data length
	m.lnLength = len(m.Binary)

	*--- Reverses the binary expression
	m.lcBinary = ""
	for m.lnByte = 1 to m.lnLength
		m.lcBinary = substr(m.Binary,m.lnByte,1) + m.lcBinary
	next

	*--- Convert using VFP2C32 functions
	do case
	case m.lnLength = 1
		return Str2UShort(m.lcBinary)
	case m.lnLength = 2
		return Str2UShort(m.lcBinary)
	case m.lnLength = 4
		return Str2ULong(m.lcBinary)
	case m.lnLength = 8
		return Str2UInt64(m.lcBinary)
	otherwise
		error 11
		return 0
	endcase
ENDFUNC

*--- Returns an Binary String from an Unsigned Integer
FUNCTION UInt2Bin(Value AS String, Length AS Integer)
LOCAL lcBinary,lcReturn,lnByte
	*--- Convert using VFP2C32 functions
	do case
	case m.Length = 1
		return left(UShort2Str(m.Value),1)
	case m.Length = 2
		m.lcBinary = UShort2Str(m.Value)
	case m.Length = 4
		m.lcBinary = ULong2Str(m.Value)
	case m.Length = 8
		m.lcBinary = UInt642Str(m.Value)
	otherwise
		error 11
		return ""
	endcase

	*--- Reverses the binary expression
	m.lcReturn= ""
	for m.lnByte = 1 to m.Length
		m.lcReturn = substr(m.lcBinary,m.lnByte,1) + m.lcReturn
	next

	return m.lcReturn
ENDFUNC
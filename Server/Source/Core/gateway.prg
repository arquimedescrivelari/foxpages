#INCLUDE foxpages.h

******************************************************************************************
* Gateway class
***********
DEFINE CLASS Gateway AS CUSTOM
	*--- Request container objects
	ADD OBJECT Request AS Request && Request properties container

	*--- Response container objects
	ADD OBJECT Response AS Response && Response properties container

	*--- Properties
	Directory  = ""
	Protocol   = ""
	RemoteHost = ""
	RemotePort = 0

	PROCEDURE Init()
		*--- Debug log
		This.Parent.Log.Add(2,"Gateway.Init")
	ENDPROC

	PROCEDURE Destroy()
		*--- Remove FCGI Object
		This.Parent.Log.Add(2,"Gateway.FCGI.Destroy")
		This.RemoveObject("FCGI")
		
		*--- Remove Parser object		
		This.RemoveObject("Parser")

		*--- Debug log
		This.Parent.Log.Add(2,"Gateway.Destroy")
		
		*--- Update ThreadState to connected
		This.Parent.CallBack.ThreadState = 1
		This.Parent.CallBack.LastUse = datetime()
	ENDPROC

	PROCEDURE Error(nError,cMethod,nLine)
		This.Parent.Log.Add(0,"Gateway.Error","Method: "+proper(m.cMethod)+CRLF+"Message: "+message())
	ENDPROC

	PROCEDURE Process()
	LOCAL lcRequest,lnLength
		do case
		case This.Parent.Type = "HTTP"
			*--- Determine the size of request
			m.lnLength  = at(HEADER_DELIMITER,This.Parent.Buffer)+3+val(strextract(This.Parent.Buffer,"Content-Length: ",CRLF))

			*--- Request
			m.lcRequest = substr(This.Parent.Buffer,1,m.lnLength)

			*--- Create HTTP Processor
			if type("This.Parser") # "O"
				This.NewObject("Parser","HTTPProtocol","core\http.fxp")
			endif

			*--- Parse received data
			if !This.Parser.Process(m.lcRequest)
				return .F.
			endif

			*--- Remove request from buffer
			This.Parent.Buffer = substr(This.Parent.Buffer,m.lnLength+1)
		case This.Parent.Type = "FCGI"
			*--- Request
			m.lcRequest = This.Parent.Buffer

			*--- Create FCGI Processor
			if type("This.Parser") # "O"
				This.NewObject("Parser","FCGIProtocol","core\fcgi.fxp")
			endif

			*--- Parse received data
			if !This.Parser.Process(m.lcRequest)
				return .F.
			endif

			*--- Clear buffer
			This.Parent.Buffer = ""
		endcase

		*--- Convert \ to / and remove the last /
		This.Directory = rtrim(chrtran(This.Directory,"\","/"),"/")

		*--- Request parameters
		This.Request.Document_Root     = This.Directory
		This.Request.Script_Name       = This.Request.Document_URI
		This.Request.Script_FileName   = This.Request.Document_Root+This.Request.Script_Name

		This.Request.Gateway_Interface = "CGI/1.1"

		*--- Debug log
		This.Parent.Log.Add(2,"Gateway.Process","Document_Root: "+This.Request.Document_Root+CRLF+;
												"Script_Name: "+This.Request.Script_Name+CRLF+;
												"Script_FileName: "+This.Request.Script_FileName)

		do case
		case This.Protocol = "FCGI"
			*--- Create FCGI Gateway
			if type("This.FCGI") # "O"
				This.NewObject("FCGI","FCGIGateway","core\fcgi.fxp")
			endif

			*--- Connect
			if !This.FCGI.IsConnected
				This.FCGI.Connect(This.RemoteHost,This.RemotePort)
			endif

			*--- Process request
			This.FCGI.Process()
		endcase
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
	Script_FileName			= ""
	Server_Address			= ""
	Server_Name				= ""
	Server_Port				= ""
	Server_Protocol         = ""
	Server_Software			= ""
	Type					= 0
	User_Agent				= ""
ENDDEFINE

******************************************************************************************
* Response class
***************
DEFINE CLASS Response AS CUSTOM
	*--- Hide class properties
	HIDDEN BaseClass,ClassLibrary,Class,Comment,ControlCount,Controls,Height,HelpContextID,Left,Objects,Parent,ParentClass,Picture,Tag,Top,WhatsThisHelpID,Width

	*--- Response properties
	Bytes				= 0
	Connection          = ""
	Header				= ""
	Status_Code			= ""
ENDDEFINE
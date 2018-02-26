#INCLUDE foxpages.h

*--- Set startup directory
cStartDir = substr(sys(16),1,rat("\",sys(16),2))
set default to (cStartDir)

*--- Create server
PUBLIC FPService
FPService = createobject("Service")
*FPService = createobject("FPService.Service")

FPService.Start()

set step on

FPService.Stop()

RELEASE FPService

******************************************************************************************
* Service Class
***************
DEFINE CLASS Service AS CUSTOM OLEPUBLIC

	PROCEDURE Init(Param1, Param2)
		cStartDir = strextract(sys(16),"INIT ","FPSERVICE.DLL")
		set default to (cStartDir)

		*--- Sets
		set safety off
		set exclusive off

		*--- Set libraries
		*--- Load FLL
		#IFDEF X64
			set library to bin64\vfp2c32.fll
		#ELSE
			set library to bin\vfp2c32t.fll
		#ENDIF
	ENDPROC

	PROCEDURE Start()
	LOCAL lcServer,loObject
		*--- Open servers table
		use data\servers

		*--- Add servers
		scan
			*--- Ignore disabled servers
			if servers.state = 0
				loop
			endif

			*--- Add Server
			m.lcServer = "SERVER_"+alltrim(servers.id)

			*--- Create server container variable				
			PUBLIC (m.lcServer)

			*--- Create server object
			m.loObject = createthreadobject("FPServer.Server")
			STORE m.loObject TO (m.lcServer)

			*--- Set ID
			m.loObject.ServerID = alltrim(servers.id)

			*--- Set Name
			m.loObject.ServerName = alltrim(servers.name)

			*--- Set type
			m.loObject.Type = servers.type

			*--- Set bandwidth
			m.loObject.Bandwidth = servers.bandwidth

			*--- Set KeepAlive
			m.loObject.KeepAlive = servers.keepalive

			*--- Set chunked transfer encoding
			m.loObject.Chunked = servers.chunked

			*--- Set LogRequests
			m.loObject.LogRequests = servers.logrequests

			*--- Set LogLevel
			m.loObject.LogLevel = servers.loglevel

			*--- Set tunnel remote host
			m.loObject.RemoteHost = alltrim(servers.remotehost)

			*--- Set tunnel remote port
			m.loObject.RemotePort = servers.remoteport

			*--- Set tunnel password
			m.loObject.Password = servers.password

			*--- Set tunnel compression
			m.loObject.Compression = servers.compression

			*--- Set Secure
			m.loObject.Secure = servers.secure

			*--- Set CertificateName
			m.loObject.CertificateName = alltrim(servers.certificatename)

			*--- Set CertificateStore
			m.loObject.CertificateStore = alltrim(servers.certificatestore)

			*--- Set CertificatePassword
			m.loObject.CertificatePassword = alltrim(servers.certificatepassword)

			*--- Start server
			m.loObject.Start()

			*--- Start listenner
			m.loObject.Listen(alltrim(servers.ip),servers.port)
		endscan

		*--- Close servers table
		use
	ENDPROC

	PROCEDURE Stop()
	LOCAL lcServer,loObject
		*--- Open servers table
		use data\servers

		*--- Stop and Remove Server
		select servers
		scan
			*--- Ignore disabled servers
			if servers.state = 0
				loop
			endif

			*--- Add Server
			m.lcServer = "SERVER_"+alltrim(servers.id)

			*--- Server object
			m.loObject = evaluate(m.lcServer)

			*--- Stop Listen
			m.loObject.StopListen()

			*--- Stop
			m.loObject.Stop()

			*--- Release
			RELEASE (m.lcServer)
		endscan

		*--- Close servers table
		use
	ENDPROC

	PROCEDURE Timer()
	LOCAL lcServer,loObject
	
		*--- Open servers table
		use data\servers

		*--- Server timer event
		scan
			*--- Ignore disabled servers
			if servers.state = 0
				loop
			endif

			*--- Add Server
			m.lcServer = "SERVER_"+alltrim(servers.id)

			*--- Server object
			m.loObject = evaluate(m.lcServer)

			*--- Stop Listen
			m.loObject.Timer()
		endscan

		*--- Close servers table
		use
	ENDPROC

	PROCEDURE Destroy()
	ENDPROC

	PROCEDURE Error(nError, cMethod, nLine)
		strtofile("Service.Error() - "+cMethod+": "+message()+CRLF,"server.log",1)
	ENDPROC

	HIDDEN BaseClass
	HIDDEN ClassLibrary
	HIDDEN Class
	HIDDEN Comment
	HIDDEN ControlCount
	HIDDEN Controls
	HIDDEN Height
	HIDDEN HelpContextID
	HIDDEN ParentClass
	HIDDEN Picture
	HIDDEN Tag
	HIDDEN WhatsThisHelpID
	HIDDEN Width
	
	HIDDEN PROCEDURE AddObject(cName As String, cClass As String, cOLEClass As String, aInit1 As Variant) As Variant
	HIDDEN PROCEDURE AddProperty(cPropertyName As String, vNewValue As Variant, nVisibility As String)
	HIDDEN PROCEDURE NewObject(cName As String, cClass As String, cModule As String, cInApplication As String, cOLEClass As String, aInit1 As Variant) As Variant
	HIDDEN PROCEDURE ReadExpression(cPropertyName As String) As Variant
	HIDDEN PROCEDURE ReadMethod(cMethod As String) As Variant
	HIDDEN PROCEDURE RemoveObject(cObjectName As String) As Variant
	HIDDEN PROCEDURE ResetToDefault(cProperty As Long) As Variant
	HIDDEN PROCEDURE SaveAsClass(cClassLibName As String, cClassName As String, cDescription As String) As Variant
	HIDDEN PROCEDURE ShowWhatsThis() As Variant
	HIDDEN PROCEDURE WriteExpression(cPropertyName As String, cExpression As String) As Variant
	HIDDEN PROCEDURE WriteMethod(cMethodName As String, cMethodText As String, lCreateMethod As String, nVisibility As String, cDescription As String) As Variant
ENDDEFINE
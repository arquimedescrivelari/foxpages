#INCLUDE foxpages.h

******************************************************************************************
* Server Class
**************
DEFINE CLASS Server AS CUSTOM OLEPUBLIC
	*--- Server ID
	ServerID = ""

	*--- Server name
	ServerName = ""

	*--- Server type
	*--- HTTP
	*--- FCGI
	*--- TUNNEL
	*--- TUNNEX
	Type = ""

	*--- Connection bandwidth in kilobytes (Don't work in development mode)
	* 0 - Disabled
	* 10 - 10 kbps
	* 100 - 100 kbps
	* 1000 - 1 mbps
	Bandwidth = 0

	*--- Chunked Transfer Encoding
	* 0 - Disabled
	* 1 - Enabled
	Chunked = 0

	*--- KeepAlive connections
	* 0 - Disabled
	* 1 - Enabled
	KeepAlive = 1

	*--- Requests log
	* 0 - Disabled
	* 1 - Enabled
	LogRequests = 0

	*--- Processing log level
	* 0 - Disabled - Errors are always logued
	* 1 - Server
	* 2 - Server and Thread
	* 3 - Server, Thread and Processes
	LogLevel = 0

	*--- Tunnel remote host
	RemoteHost = ""

	*--- Tunnel remote port
	RemotePort = 0

	*--- Tunnel password
	Password = ""

	*--- Tunnel compression
	* 0 - Disabled
	* 1 - Enabled
	Compression = 1

	*--- Reuse threads
	* 0 - No (Causes memory leak)
	* 1 - Yes
	ReUse = 1

	*--- Server state
	* 0 - Stoped
	* 1 - Started
	* 2 - Not listenning
	* 3 - Listenning
	State = 0

	*--- Server StartMode
	* 0 - SingleThreaded
	* 1 - MultiThreaded
	StartMode = 1

	*--- Secure conections SSL
	* 0 - Disabled
	* 1 - Enabled
	Secure = 0

	*--- Certificate common name (CN)
	CertificateName = ""

	*--- Certificate store
	* MY - Personal store
	* CA - Certification Authority store
	* ROOT - Root Certification Authorities store
	* Complete certificate path and file name. Must be in PFX format.
	CertificateStore = ""

	*--- Certificate password
	CertificatePassword = ""

	*--- Threads counter
	Threads = 0

	HIDDEN PROCEDURE Init()
	LOCAL lcStartDir
		*--- Put ActiveX events in queue.
		_VFP.AutoYield = .F.

		*--- Start directory
		if _VFP.StartMode = 0
			*--- Interactive
			m.lcStartDir = strextract(sys(16),"INIT ","CORE\SERVER.FXP")
		else
			*--- DLL
			m.lcStartDir = strextract(sys(16),"INIT ","FPSERVER.DLL")
		endif

		*--- Verify start directory
		if !empty(m.lcStartDir)
			*--- Set default directory
			set default to (m.lcStartDir)
		endif

		*--- Sets
		set exclusive off
		set safety off
		set sysformats on

		*--- Development mode
		if _VFP.StartMode = 0
			*--- Create queue processing timer
			This.NewObject("ServerProc","ServerProc")
		endif

		*--- Load FLL
		#IFDEF X64
			set library to bin64\vfp2c32.fll
		#ELSE
			set library to bin\vfp2c32t.fll
		#ENDIF

		*--- Log object
		This.NewObject("Log","Log","core\log.fxp")
	ENDPROC

	HIDDEN PROCEDURE Destroy()
		*--- Debug log
		This.Log.Add(1,"Destroy")

		*--- Development mode
		if _VFP.StartMode = 0
			*--- Delete log files
			delete file logs\*.*
		endif
	ENDPROC

	PROCEDURE Error(nError,cMethod,nLine)
		This.Log.Add(0,"Error","Method: "+proper(m.cMethod)+CRLF+"Message: "+message())
	ENDPROC

	PROCEDURE Start()
		*--- Log info
		This.Log.Server = This.ServerID
		This.Log.Thread = "0000"

		*--- Debug log
		This.Log.Add(1,"Start")

		*--- Server started
		This.State = 1

		*--- Create listenner
		This.Newobject("Listenner","Socket","core\socket.fxp")

		*--- Initialize
		#IFNDEF USEFREEVERSION
			This.Listenner.SocketWrench.Initialize(CSWSOCK_LICENSE_KEY)
		#ENDIF
	ENDPROC

	PROCEDURE Listen(IP AS String,Port AS Integer)
		*--- Debug log
		This.Log.Add(1,"Listen")

		*--- Server listenning
		This.State = 3

		*--- Start listenner
		return This.Listenner.Listen(m.IP,m.Port)
	ENDPROC

	PROCEDURE StopListen()
		*--- Debug log
		This.Log.Add(1,"StopListen")

		*--- Server not listenning
		This.State = 2

		*--- Stop listenner
		return This.Listenner.Disconnect()
	ENDPROC

	PROCEDURE Stop()
	LOCAL lnThread
		*--- Debug log
		This.Log.Add(1,"Stop")

		*--- Server stoped
		This.State = 0

		*--- Remove connections
		for m.lnThread = This.Threads to 1 step -1
			*--- Verify if exist
			if type("Thread"+alltrim(str(m.lnThread))) = "O"
				*--- Remove threads objects
				RELEASE ("Thread"+alltrim(str(m.lnThread)))
				RELEASE ("ThreadInterface"+alltrim(str(m.lnThread)))
			endif
		next

		*--- Uninitialize
		#IFNDEF USEFREEVERSION
			This.Listenner.SocketWrench.Uninitialize()
		#ENDIF

		*--- Remove listenner object
		This.RemoveObject("Listenner")
	ENDPROC

	PROCEDURE Accept(Handle AS Integer)
	LOCAL loThread,lnReturn
		*--- Add new thread
		m.loThread = This.AddThread()

		*--- Set thread properties
		m.loThread.Bandwidth   = This.Bandwidth
		m.loThread.Chunked     = This.Chunked
		m.loThread.KeepAlive   = This.KeepAlive
		m.loThread.LogRequests = This.LogRequests
		m.loThread.LogLevel    = This.LogLevel
		m.loThread.Type        = This.Type

		*--- Set tunnel properties
		m.loThread.RemoteHost  = This.RemoteHost
		m.loThread.RemotePort  = This.RemotePort
		m.loThread.Password    = This.Password
		m.loThread.Compression = This.Compression

		*--- Secure conections
		if This.Secure = 1
			m.loThread.Secure              = 1
			m.loThread.CertificateName     = This.CertificateName
			m.loThread.CertificateStore    = This.CertificateStore
			m.loThread.CertificatePassword = This.CertificatePassword
		endif

		if This.State = 3
			*--- Accept the connection
			m.loThread.Accept(m.Handle)
		else
			*--- Reject the connection
			m.loThread.Reject()
		endif
	ENDPROC

	HIDDEN PROCEDURE AddThread()
	LOCAL lnThread,loThread,loThreadInterface
		*--- Search first avaliable thread
		for m.lnThread = 1 to This.Threads
			*--- Reuse threads
			if This.ReUse = 0
				*--- Verify thread object exist
				if type("Thread"+alltrim(str(m.lnThread))) = "U"
					*--- Thread does not exist
					exit
				endif
			else
				*--- Verify if thread exist
				if type("ThreadInterface"+alltrim(str(m.lnThread))) = "O"
					*--- Verify thread state
					m.loThreadInterface = evaluate("ThreadInterface"+alltrim(str(m.lnThread)))
					if m.loThreadInterface.ThreadState = 0
						m.loThreadInterface.LastUse = datetime()
						m.loThreadInterface.ThreadState = 1

						*--- Thread not in use
						return evaluate("Thread"+alltrim(str(m.lnThread)))
					endif
				else
					*--- No avaliable thread, add new thread
					exit
				endif
			endif
		next

		*--- Check start mode
		if This.StartMode = 0
			*--- Create thread
			m.loThread = newobject("Thread","core\thread.fxp")
		else
			*--- Create thread in a new thread
			m.loThread = createthreadobject("FPServer.Thread")
		endif

		*--- Create thread interface
		m.loThreadInterface = newobject("ThreadInterface","core\thread.fxp")

		*--- Set Callback
		m.loThread.CallBack = m.loThreadInterface

		*--- Set thread properties
		m.loThread.ServerID    = This.ServerID
		m.loThread.ServerName  = This.ServerName
		m.loThread.StartMode   = This.StartMode
		m.loThread.ThreadIndex = m.lnThread

		*--- Save max threads
		This.Threads = max(This.Threads,m.lnThread)

		PUBLIC ("Thread"+alltrim(str(m.lnThread)))
		PUBLIC ("ThreadInterface"+alltrim(str(m.lnThread)))

		STORE m.loThread TO ("Thread"+alltrim(str(m.lnThread)))
		STORE m.loThreadInterface TO ("ThreadInterface"+alltrim(str(m.lnThread)))

		*--- Return new thread
		return m.loThread
	ENDPROC

	PROCEDURE Timer()
	LOCAL lnThread,loThread
		*--- Process all threads
		for m.lnThread = 1 to This.Threads
			*--- Verify if exist
			if type("ThreadInterface"+alltrim(str(m.lnThread))) = "O"
				*--- Thread interface object
				m.loThread = evaluate("ThreadInterface"+alltrim(str(m.lnThread)))

				*--- Verify connections state
				do case
				case m.loThread.ThreadState = 0 AND This.ReUse = 0
					*--- Remove disconnected threads objects
					RELEASE ("Thread"+alltrim(str(m.lnThread)))
					RELEASE ("ThreadInterface"+alltrim(str(m.lnThread)))
				case m.loThread.ThreadState = 1 AND datetime()-m.loThread.LastUse > 30
					*--- Disconnect when idle for 30 seconds
					m.loThread.ThreadState = 3

					m.loThread = evaluate("Thread"+alltrim(str(m.lnThread)))
					m.loThread.Disconnect()
				endcase
			endif
		next
	ENDPROC

	HIDDEN PROCEDURE CertificateStore_Assign(vNewVal)
		*--- Add full path to certificate file
		if justext(vNewVal) = "pfx"
			vNewVal = sys(5)+sys(2003)+"\certificates\"+vNewVal
		endif

		This.CertificateStore = m.vNewVal
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
* Server queue processor class
*
* Used ONLY in development mode
*******************************
DEFINE CLASS ServerProc AS TIMER

	Interval = 200
	Enabled  = .T.

	PROCEDURE Timer()
	LOCAL lnThread,loThread
		*--- Process queued requests
		for m.lnThread = 1 to This.Parent.Threads
			*--- If exist
			if type("Thread"+alltrim(str(m.lnThread))+".Queued") = "L"
				*--- Thread interface object
				m.loThread = evaluate("Thread"+alltrim(str(m.lnThread)))

				*--- If in queue
				if m.loThread.Queued
					*--- No longer in queue
					m.loThread.Queued = .F.

					*--- Disable timmer
					This.Enabled = .F.

					*--- Process
					m.loThread.Continue()

					*--- Enable timmer
					This.Enabled = .T.
				endif
			endif
		next
	ENDPROC
ENDDEFINE
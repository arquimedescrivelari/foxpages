#INCLUDE foxpages.h

******************************************************************************************
* Socket Class
**************
DEFINE CLASS Socket AS CUSTOM
	*--- Properties
	Blocking			= .F.
	CertificateName		= ""
	CertificateStore	= ""
	CertificatePassword = ""
	HostAddress			= ""
	HostName			= ""
	IsClosed			= .F.
	IsConnected			= .F.
	IsReadable			= .F.
	IsWritable			= .F.
	LocalAddress		= ""
	LocalPort			= 0
	PeerAddress			= ""
	PeerPort			= 0
	RemotePort			= 0
	Secure				= .F.
	State				= 0

	HIDDEN PROCEDURE Init()
		*--- Add SocketWrench object
		This.AddProperty("SocketWrench",createobject(CSWSOCK_CONTROL))

		*--- Add SocketInterface object
		This.AddObject("SocketWrenchInterface","SocketWrenchInterface")

		*--- Bind events
		EVENTHANDLER(This.SocketWrench,This.SocketWrenchInterface)

		*--- Set connection properties
		This.SocketWrench.Blocking = .F.
		This.SocketWrench.Protocol = 6

		*--- Disable Nagle Algorithm
		This.SocketWrench.NoDelay = .T.
	ENDPROC

	PROCEDURE Error(nError,cMethod,nLine)
	LOCAL lcMessage,lnSize,lnCtrl
		m.lcMessage = "Message: "+alltrim(str(m.nError))+" - "+message()+;
					iif(This.Parent.Parent.StartMode = 0,CRLF+"Code: "+message(1),"")

		m.lcMessage = m.lcMessage+CRLF+CRLF+"Call Stack:"
		m.lnSize = astackinfo(Stack)
		for m.lnCtrl = (m.lnSize-1) to 2 step -1
			m.lcMessage = m.lcMessage+CRLF+alltrim(str(stack[m.lnCtrl,1]-1))+") "+stack[m.lnCtrl,2]+" ("+stack[m.lnCtrl,3]+","+alltrim(str(stack[m.lnCtrl,5]))+")"
		next

		strtofile(m.lcMessage+CRLF+CRLF,"logs\socket.log")
	ENDPROC

	PROCEDURE Listen(IP AS String,Port AS Integer)
		*--- Listen for connections
		return This.SocketWrench.Listen(m.IP,m.Port) = 0
	ENDPROC

	PROCEDURE Accept(Handle AS Integer)
		*--- Accept connection
		return This.SocketWrench.Accept(m.Handle)
	ENDPROC

	PROCEDURE Reject()
		*---- Reject connection
		return This.SocketWrench.Reject() = 0
	ENDPROC

	PROCEDURE Connect(Host AS Character, Port AS Integer)
	LOCAL lcHost,llHost,lnCtrl
		*--- Determine if host is a hostname or hostaddress
		m.lcHost = chrtran(m.Host,".","")
		m.llHost = .F.
		for lnCtrl = 1 to len(m.lcHost)
			if !isdigit(substr(m.lcHost,m.lnCtrl,1))
				m.llHost = .T.
				exit
			endif
		next

		if m.llHost
			This.SocketWrench.HostName = m.Host
		else
			This.SocketWrench.HostAddress = m.Host
		endif
		This.SocketWrench.RemotePort  = m.Port

		*--- Connect
		return This.SocketWrench.Connect() = 0
	ENDPROC

	PROCEDURE Disconnect()
		return This.SocketWrench.Disconnect() = 0
	ENDPROC

	PROCEDURE Read()
	LOCAL lcBuffer
		*--- Wait to read
		do while !This.IsReadable
			*--- Check connection
			if !This.SocketWrench.IsConnected
				This.Parent.Disconnect()
				return .F.
			endif

			sleep(10)
		enddo

		*--- Read buffer
		m.lcBuffer = ""
		This.SocketWrench.Read(@m.lcBuffer)
		
		*--- Process request
		This.Parent.Process(m.lcBuffer)
	ENDPROC

	PROCEDURE Write(Data AS String)
		*--- Check socket is busy
		do while !This.SocketWrench.IsWritable
			*--- Check connection
			if !This.SocketWrench.IsConnected
				This.Parent.Disconnect()
				return .F.
			endif

			*--- Wait 10 miliseconds
			sleep(10)
		enddo

		return This.SocketWrench.Write(Data) # -1
	ENDPROC

	PROCEDURE OnAccept(Handle)
		This.Parent.Accept(m.Handle)
	ENDPROC

	PROCEDURE OnCancel()
	ENDPROC

	PROCEDURE OnConnect()
	ENDPROC

	PROCEDURE OnDisconnect()
		This.Parent.Disconnect()
	ENDPROC

	PROCEDURE OnError(ErrorCode,Description)
	LOCAL lcMessage,lnSize,lnCtrl
		*--- Connection errors
		if m.ErrorCode = 10053 OR m.ErrorCode = 10054 OR m.ErrorCode = 10057
			This.Parent.Disconnect()
			return
		endif

		*--- Call stack
		m.lcMessage = "Call Stack: "+CRLF
		m.lnSize = astackinfo(Stack)
		for m.lnCtrl = (m.lnSize-1) to 1 step -1
			m.lcMessage = m.lcMessage+alltrim(str(stack[m.lnCtrl,1]))+") "+chrtran(stack[m.lnCtrl,2],[\"],[/'])+" ("+stack[m.lnCtrl,3]+[,]+alltrim(str(stack[m.lnCtrl,5]))+")"+CRLF
		next

		*--- Log
		strtofile(alltrim(str(m.ErrorCode))+" - "+m.Description+CRLF+m.lcMessage+CRLF+CRLF,"logs\socket.log")
	ENDPROC

	PROCEDURE OnProgress(BytesTotal,BytesCopied,Percent)
	ENDPROC

	PROCEDURE OnRead()
		This.Read()
	ENDPROC

	PROCEDURE OnTimeout()
	ENDPROC

	PROCEDURE OnTimer()
	ENDPROC

	PROCEDURE OnWrite()
	ENDPROC

	*--- Properties access
	HIDDEN PROCEDURE IsClosed_Access()
		return This.SocketWrench.IsClosed
	ENDPROC

	HIDDEN PROCEDURE IsConnected_Access()
		return This.SocketWrench.Connected
	ENDPROC

	HIDDEN PROCEDURE IsReadable_Access()
		return This.SocketWrench.IsReadable
	ENDPROC

	HIDDEN PROCEDURE IsWritable_Access()
		return This.SocketWrench.IsWritable
	ENDPROC

	HIDDEN PROCEDURE LocalAddress_Access()
		return This.SocketWrench.LocalAddress
	ENDPROC

	HIDDEN PROCEDURE LocalPort_Access()
		return This.SocketWrench.LocalPort
	ENDPROC

	HIDDEN PROCEDURE PeerAddress_Access()
		return This.SocketWrench.PeerAddress
	ENDPROC

	HIDDEN PROCEDURE PeerPort_Access()
		return This.SocketWrench.PeerPort
	ENDPROC

	HIDDEN PROCEDURE State_Access()
		return This.SocketWrench.State
	ENDPROC

	*--- Properties assign
	HIDDEN PROCEDURE Blocking_Assign(vNewVal)
		This.Blocking = m.vNewVal
		This.SocketWrench.Blocking = m.vNewVal
	ENDPROC

	HIDDEN PROCEDURE CertificateName_Assign(vNewVal)
		This.CertificateName = m.vNewVal
		This.SocketWrench.CertificateName = m.vNewVal
	ENDPROC

	HIDDEN PROCEDURE CertificateStore_Assign(vNewVal)
		This.CertificateStore = m.vNewVal
		This.SocketWrench.CertificateStore = m.vNewVal
	ENDPROC

	HIDDEN PROCEDURE CertificatePassword_Assign(vNewVal)
		This.CertificatePassword = m.vNewVal
		This.SocketWrench.CertificatePassword = m.vNewVal
	ENDPROC

	HIDDEN PROCEDURE HostAddress_Assign(vNewVal)
		This.HostAddress = m.vNewVal
		This.SocketWrench.HostAddress = m.vNewVal
	ENDPROC

	HIDDEN PROCEDURE HostName_Assign(vNewVal)
		This.HostName = m.vNewVal
		This.SocketWrench.HostName = m.vNewVal
	ENDPROC

	HIDDEN PROCEDURE LocalAddress_Assign(vNewVal)
		This.LocalAddress = m.vNewVal
		This.SocketWrench.LocalAddress = m.vNewVal
	ENDPROC

	HIDDEN PROCEDURE LocalPort_Assign(vNewVal)
		This.LocalPort = m.vNewVal
		This.SocketWrench.LocalPort = m.vNewVal
	ENDPROC

	HIDDEN PROCEDURE RemotePort_Assign(vNewVal)
		This.RemotePort = m.vNewVal
		This.SocketWrench.RemotePort = m.vNewVal
	ENDPROC

	HIDDEN PROCEDURE Secure_Assign(vNewVal)
		This.Secure = m.vNewVal
		This.SocketWrench.Secure = m.vNewVal
	ENDPROC
ENDDEFINE

******************************************************************************************
* SocketWrench interface class
******************************
DEFINE CLASS SocketWrenchInterface AS CUSTOM
IMPLEMENTS _iSocketWrenchEvents IN CSWSOCK_CONTROL

	PROCEDURE _iSocketWrenchEvents_OnAccept(Handle)
		This.Parent.OnAccept(m.Handle)
	ENDPROC

	PROCEDURE _iSocketWrenchEvents_OnCancel()
		This.Parent.OnCancel()
	ENDPROC

	PROCEDURE _iSocketWrenchEvents_OnConnect()
		This.Parent.OnConnect()
	ENDPROC

	PROCEDURE _iSocketWrenchEvents_OnDisconnect()
		This.Parent.OnDisconnect()
	ENDPROC

	PROCEDURE _iSocketWrenchEvents_OnError(ErrorCode, Description)
		This.Parent.OnError(m.ErrorCode, m.Description)
	ENDPROC

	PROCEDURE _iSocketWrenchEvents_OnProgress(BytesTotal, BytesCopied, Percent)
		This.Parent.OnProgress(m.BytesTotal, m.BytesCopied, m.Percent)
	ENDPROC

	PROCEDURE _iSocketWrenchEvents_OnRead()
		This.Parent.OnRead()
	ENDPROC

	PROCEDURE _iSocketWrenchEvents_OnTimeout()
		This.Parent.OnTimeout()
	ENDPROC

	PROCEDURE _iSocketWrenchEvents_OnTimer()
		This.Parent.OnTimer()
	ENDPROC

	PROCEDURE _iSocketWrenchEvents_OnWrite()
		This.Parent.OnWrite()
	ENDPROC
ENDDEFINE
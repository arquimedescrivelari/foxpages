#INCLUDE foxpages.h

******************************************************************************************
* Tunnel Class
**************
DEFINE CLASS Tunnel AS Socket OF core\socket.prg

	Compression = 0
	Password    = ""
	RemoteHost  = ""
	RemotePort  = 0

	PROCEDURE Init()
		*--- Debug log
		This.Parent.Log.Add(2,"Tunnel.Init")
		
		dodefault()
	ENDPROC

	PROCEDURE Destroy()
		*--- Debug log
		This.Parent.Log.Add(2,"Tunnel.Destroy")
	ENDPROC

	PROCEDURE OnDisconnect()
		*--- Debug log
		This.Parent.Log.Add(1,"Tunnel.Disconnect")

		*--- Disconnect socket		
		This.Disconnect()
	ENDPROC

	PROCEDURE Send(Data)
		*--- Debug log
		This.Parent.Log.Add(2,"Tunnel.Send")

		*--- Connect
		if !This.IsConnected
			This.Connect(This.RemoteHost,This.RemotePort)
		endif
		
		*--- Compress
		if !empty(This.Compression)
			m.Data = zipstring(m.Data)
		endif

		*--- Encrypt
		if len(alltrim(This.Password)) = 32
			m.Data = encrypt(m.Data,This.Password)
		endif

		*--- Send data
		This.Write(m.Data)
	ENDPROC

	PROCEDURE Receive(Data)
		*--- Debug log
		This.Parent.Log.Add(2,"Tunnel.Receive")

		*--- Connect
		if !This.IsConnected
			This.Connect(This.RemoteHost,This.RemotePort)
		endif

		*--- Decrypt
		if len(alltrim(This.Password)) = 32
			m.Data = decrypt(m.Data,This.Password)
		endif

		*--- Decompress
		if !empty(This.Compression)
			m.Data = unzipstring(m.Data)
		endif

		*--- Send request
		This.Write(m.Data)
	ENDPROC

	PROCEDURE Read()
	LOCAL lcBuffer
		*--- Debug log
		This.Parent.Log.Add(2,"Tunnel.Respond")

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

		*--- Send response
		This.Parent.Socket.Write(m.lcBuffer)
	ENDPROC
ENDDEFINE
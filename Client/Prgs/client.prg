#INCLUDE client.h

******************************************************************************************
* SMTP Class
************
DEFINE CLASS SMTP AS Base OLEPUBLIC
	*--- Connection properties
	Hostname      = ""  && Hostname of SMTP Server
	Port          = 25  && optional by default 25
	Username      = ""  && ESMTP Login
	Password      = ""  && ESMTP Password

	*--- Recipients properties
	From          = ""  && Email of the sender
	From_Name     = ""  && Optional Name of the sender
	To            = ""  && Emails of the recipients. Multi-recipients separated by ";"
	To_Name       = ""  && Names of the recipients. Multi-recipients separated by ";"
	CC            = ""  && Emails of Contacts in Copy. Multi-recipients separated by ";"
	CC_Name       = ""  && Names of the Contacts in Copy. Multi-recipients separated by ";"
	CCI           = ""  && Emails of the contacts in invisible copy. Multi-recipients separated by ";"
	ReplyTo       = ""  && Reply email
	ReplyTo_Name  = ""  && Reply name (Default From_Name)
	Bad_Emails    = ""  && This property receive recipients emails rejected by the SMTP Server

	*--- Message properties
	Attachment    = ""  && Fullpath name of file in attachment. Multi-files separated by ";"
	CodePage      = "iso-8859-1"
	Encoding      = "quoted-printable"
	Helo          = ""  && optional: name/ip address of the sender in HELO SMTP command
	Message       = ""  && Email text message
	MessageHTML   = ""  && Email with HTML message
	Notification  = .F. && Ask recipient reading(?)
	Priority      = ""  && Email Piority   1=High 3=Normal (Default) 5=Low
	Subject       = ""  && Email subject

	*--- Error property
	ErrorMsg      = ""
	
	*--- Email log properties
	LogEmail      = .F. && Log email?
	EmailFile     = ""  && Optional: name of eml file

	*--- Internal properties
	Data          = ""  && Internal use
	ReceivedData  = ""  && Internal use
	LogLevel      = 0
	LogFile       = "smtp.log"
	Timeout       = 30
	Version       = "1.0"

		
	PROCEDURE Send()
		LOCAL lcRecipients
		LOCAL ARRAY laAttachment[1,2]
		LOCAL lcAttachment,lnAttachment,lcFile,lcFileData,lnCtrl,lcExt
		LOCAL lcTemp,lcBlock,lnHandle
		LOCAL lcMixedBoundary,lcAlternativeBoundary
		LOCAL lnData,lcData

		*--- Log
		if This.LogLevel > 0
			strtofile("SMTP.Start()"+CRLF,This.LogFile,1)
		endif
		
		*--- Check HOSTNAME
		if empty(This.Hostname)
			This.ErrorMsg = MSG_ERR01_MISSING_SMTP_HOST
			strtofile(This.ErrorMsg+CRLF,This.LogFile,1)
			return .F.
		endif

		*--- Check FROM
		if empty(This.From)
			This.ErrorMsg = MSG_ERR02_MISSING_FROM
			strtofile(This.ErrorMsg+CRLF,This.LogFile,1)
			return .F.
		endif

		*--- Check TO
		if empty(This.To)
			This.ErrorMsg = MSG_ERR03_MISSING_TO
			strtofile(This.ErrorMsg+CRLF,This.LogFile,1)
			return .F.
		endif

		*--- Replace recipients delimiter
		for lnCtrl = 1 to len(INTERNAL_SEPARATORS)
			This.To = strtran(This.To,substr(INTERNAL_SEPARATORS,lnCtrl,1),INTERNAL_DELIMITER)
			This.To_Name = strtran(This.To_Name,substr(INTERNAL_SEPARATORS,lnCtrl,1),INTERNAL_DELIMITER)
			This.CC = strtran(This.CC,substr(INTERNAL_SEPARATORS,lnCtrl,1),INTERNAL_DELIMITER)
			This.CC_Name = strtran(This.CC_Name,substr(INTERNAL_SEPARATORS,lnCtrl,1),INTERNAL_DELIMITER)
			This.CCI = strtran(This.CCI,substr(INTERNAL_SEPARATORS,lnCtrl,1),INTERNAL_DELIMITER)
		next

		*--- Define ReplyTo_Name
		if (!empty(This.ReplyTo)) and empty(This.ReplyTo_Name)
			if empty(This.From_Name)
				This.ReplyTo_Name = This.ReplyTo
			else
				This.ReplyTo_Name = This.From_Name
			endif
		endif

		*--- Define From_Name
		if empty(This.From_Name)
			if empty(This.ReplyTo_Name)
				This.From_Name = This.From
			else
				This.From_Name = This.ReplyTo_Name
			endif
		endif

		*--- Define To_Name
		if empty(This.To_Name)
			This.To_Name = This.To
		endif

		*--- Define CC_Name
		if empty(This.CC_Name)
			This.CC_Name = This.CC
		endif

		This.From_Name = strtran(This.From_Name,")","\)")
		This.From_Name = strtran(This.From_Name,"(","\(")
		This.To_Name = strtran(This.To_Name,")","\)")
		This.To_Name = strtran(This.To_Name,"(","\(")
		This.CC_Name = strtran(This.CC_Name,")","\)")
		This.CC_Name = strtran(This.CC_Name,"(","\(")
		This.ReplyTo_Name = strtran(This.ReplyTo_Name,")","\)")
		This.ReplyTo_Name = strtran(This.ReplyTo_Name,"(","\(")

		if empty(This.Data)
			*--- Date
			This.Data = This.Data+"Date: "+This.FullDate(GetSystemTime(.T.))+CRLF
			
			*--- Reply To
			if !empty(This.ReplyTo)
				This.Data = This.Data+'Reply-To: '+This.FormatDataEmail(This.ReplyTo,This.ReplyTo_Name,.T.)+CRLF
			endif

			*--- From
			This.Data = This.Data+'From: '+This.FormatDataEmail(This.From,This.From_Name,.T.)+CRLF

			*--- To
			This.Data = This.Data+'To: '+This.FormatDataEmail(This.To,This.To_Name)+CRLF

			*--- CC
			if !empty(This.CC)
				This.Data = This.Data+'Cc: '+This.FormatDataEmail(This.CC,This.CC_Name)+CRLF
			endif

			*--- Subject
			if !empty(This.Subject)
				This.Data = This.Data+"Subject: "+This.String2Iso8859(This.Subject)+CRLF
			endif

			*--- Replace attachments delimiter
			for lnCtrl = 1 to len(INTERNAL_SEPARATORS)
				This.Attachment = alltrim(strtran(This.Attachment,substr(INTERNAL_SEPARATORS,lnCtrl,1),INTERNAL_DELIMITER))
			next

			*--- Remove last delimiters
			do while right(This.Attachment,1) == INTERNAL_DELIMITER
				This.Attachment = left(This.Attachment,len(This.Attachment)-1)
			enddo

			*--- Check attachments and insert a delimiter
			if empty(This.Attachment)
				lcAttachment = ""
			else
				lcAttachment = This.Attachment+INTERNAL_DELIMITER
			endif

			*--- Load attachments to property array
			lnAttachment = 0
			do while INTERNAL_DELIMITER $ lcAttachment and !empty(lcAttachment)
				lcFile = alltrim(left(lcAttachment,at(INTERNAL_DELIMITER,lcAttachment)-1))

				do while right(lcFile,1) = "\"
					lcFile = left(lcFile,len(lcFile)-1)
				enddo

				if file(lcFile)
					strtofile("Attachment : "+lcFile+CRLF,This.LogFile,1)
					lnAttachment = lnAttachment+1

					dimension laAttachment[lnAttachment,2]
					laAttachment[lnAttachment,1] = substr(lcFile,rat("\",lcFile)+1)
					lcFileData = strconv(filetostr(lcFile),13)

					lcTemp = getenv("Temp")+"\"+This.Rand()+".txt"
					strtofile(lcFileData,lcTemp,.F.)
					lnHandle = fopen(lcTemp)
					lcBlock = ""
					do while !feof(lnHandle)
						lcBlock = lcBlock+fgets(lnHandle,76)+CRLF
					enddo
					fclose(lnHandle)
					erase (lcTemp)
					laAttachment[lnAttachment,2] = lcBlock
					lcBlock = ""
				else
					This.ErrorMsg = This.ErrorMsg+MSG_ERR06_FILE_NOFOUND+"("+lcFile+")"
					strtofile(This.ErrorMsg+CRLF,This.LogFile,1)
					return .F.
				endif

				lcAttachment = substr(lcAttachment,at(INTERNAL_DELIMITER,lcAttachment)+1)
			enddo

			*--- Message boudaries
			lcMixedBoundary       = replicate("-",12)+This.Rand()+This.Rand()+This.Rand()
			lcAlternativeBoundary = replicate("-",12)+This.Rand()+This.Rand()+This.Rand()

			*--- Message begin
			This.Data = This.Data+"MIME-Version: 1.0"+CRLF

			*--- Determine parts of message
			llMixed       = .F.
			llMessage     = .F.
			llAlternative = .F.
			if !empty(lnAttachment)
				*--- More then one attachment
				if lnAttachment > 1
					llMixed = .T.
				endif

				*--- Has text or html message
				if !empty(This.Message) OR !empty(This.MessageHTML)
					llMixed   = .T.
					llMessage = .T.
					*--- Has text and html message
					if !empty(This.Message) AND !empty(This.MessageHTML)
						llAlternative = .T.
					endif
				endif
			else
				*--- Has text or html message
				if !empty(This.Message) OR !empty(This.MessageHTML)
					llMessage = .T.
					*--- Has text and html message
					if !empty(This.Message) AND !empty(This.MessageHTML)
						llAlternative = .T.
					endif
				endif
			endif

			*--- If message has attachments it must be a multipart/mixed message
			if llMixed
				This.Data = This.Data+"Content-Type: multipart/mixed;"+CRLF+chr(9)+'boundary="'+lcMixedBoundary+'"'+CRLF
				This.Data_Header()
				This.Data = This.Data+CRLF+"This is a multi-part message in MIME format."+CRLF+CRLF

				if llMessage
					This.Data = This.Data+"--"+lcMixedBoundary+CRLF
				endif
			endif

			*--- If message has text and html it must be a multipart/alternative message
			if llAlternative
				This.Data = This.Data+"Content-Type: multipart/alternative;"+CRLF+chr(9)+'boundary="'+lcAlternativeBoundary+'"'+CRLF

				if llMixed
					This.Data = This.Data+CRLF
				else
					This.Data_Header()
					This.Data = This.Data+CRLF+"This is a multi-part message in MIME format."+CRLF+CRLF
				endif

				This.Data = This.Data+"--"+lcAlternativeBoundary+CRLF
			endif

			*--- Text message
			if !empty(This.Message)
				This.Data = This.Data+"Content-Type: text/plain;"+CRLF+space(8)+'charset="'+This.CodePage+'"'+CRLF
				This.Data = This.Data+"Content-Transfer-Encoding: "+This.Encoding+CRLF

				if !llMixed AND !llAlternative
					This.Data_Header()
				endif

				do case
				case upper(alltrim(This.Encoding)) == "QUOTED-PRINTABLE"
					This.Data = This.Data+CRLF+This.EncodeTextQuotedPrintable(This.Message)
				otherwise
					This.Data = This.Data+CRLF+This.Message
				endcase

				This.Data = This.Data+CRLF

				if llAlternative
					This.Data = This.Data+"--"+lcAlternativeBoundary+CRLF
				endif
			endif

			*--- HTML message
			if !empty(This.MessageHTML)
				This.Data = This.Data+"Content-Type: text/html;"+CRLF+space(8)+'charset="'+This.CodePage+'"'+CRLF
				This.Data = This.Data+"Content-Transfer-Encoding: "+This.Encoding+CRLF

				if !llMixed AND !llAlternative
					This.Data_Header()
				endif

				This.Data = This.Data+CRLF+'<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">'+CRLF

				do case
				case upper(alltrim(This.Encoding)) == "QUOTED-PRINTABLE"
					This.Data = This.Data+This.EncodeTextQuotedPrintable(This.MessageHTML)
				otherwise
					This.Data = This.Data+This.MessageHTML
				endcase

				This.Data = This.Data+CRLF+CRLF

				if llAlternative
					This.Data = This.Data+"--"+lcAlternativeBoundary+"--"+CRLF
				endif
			endif

			This.Data = strtran(This.Data,CRLF+"."+CRLF,CRLF+"."+chr(0)+CRLF)

			*--- Attachments
			if lnAttachment > 0
				for lnCtrl = 1 to lnAttachment
					*--- Multipart/Mixed attachment
					if llMixed
						This.Data = This.Data+CRLF+"--"+lcMixedBoundary+CRLF
					endif

					*--- Define MIME format
					lcExt = lower(substr(laAttachment[lnCtrl,1],rat(".",laAttachment[lnCtrl,1])))
					do case
					case lcExt = ".jpg" or lcExt = ".jpeg"
						This.Data = This.Data+"Content-Type: image/jpeg;"
					case lcExt = ".bmp"
						This.Data = This.Data+"Content-Type: image/bmp;"
					case lcExt = ".gif"
						This.Data = This.Data+"Content-Type: image/gif;"
					case lcExt = ".wav"
						This.Data = This.Data+"Content-Type: audio/x-wav;"
					case lcExt = ".mht" or lcExt = ".mhtm" or lcExt = ".htm" or lcExt = ".html"
						This.Data = This.Data+"Content-Type: text/html;"
					case lcExt = ".pdf"
						This.Data = This.Data+"Content-Type: application/pdf;"
					otherwise
						This.Data = This.Data+"Content-Type: application/octet-stream;"
					endcase
					This.Data = This.Data+CRLF+space(8)+'name="'+laAttachment[lnCtrl,1]+'"'+CRLF
					This.Data = This.Data+"Content-Transfer-Encoding: base64"+CRLF
					This.Data = This.Data+"Content-Disposition: attachment;"
					This.Data = This.Data+CRLF+space(8)+'filename="'+laAttachment[lnCtrl,1]+'"'+CRLF

					*--- Only one attachment without any message
					if !llMixed
						This.Data_Header()
					endif

					*--- Attachment data
					lcData = This.Data+CRLF
					for lnData = 1 to len(laAttachment[lnCtrl,2]) step 1024*1024
						lcData = lcData+substr(laAttachment[lnCtrl,2],lnData,1024*1024)
					next

					This.Data = lcData
					lcData = ""
				next

				if llMixed
					This.Data = This.Data+CRLF+"--"+lcMixedBoundary+"--"+CRLF
				endif
			endif
		endif

		*--- Connect to the server
		if This.LogLevel > 0 
			strtofile("SMTP.Connect("+This.Hostname+","+alltrim(str(This.Port))+")"+CRLF,This.LogFile,1)
		endif

		*--- Error checking
		llError = .F.

		*--- Connect
		if !This.Connect(This.Hostname,This.Port)
			*--- Connection fail
			This.ErrorMsg = MSG_ERR04_UNREACHABLE_HOST
			strtofile(This.ErrorMsg+CRLF,This.LogFile,1)

			llError = .T.
		endif

		*--- Receive server name
		if !llError AND This.Receive() <> "220"
			This.ErrorMsg = MSG_ERR05_NOREPLY_HOST
			strtofile(This.ErrorMsg+CRLF,This.LogFile,1)

			llError = .T.
		endif

		if !llError
			*--- SMTP Helo
			if empty(This.Helo)
				This.Helo = "10"+"."+alltrim(str(int(rand()*255),3,0))+"."+alltrim(str(int(rand()*255),3,0))+"."+alltrim(str(int(rand()*255),3,0))
			endif
				
			if empty(This.Username)
				*--- Send SMTP HELO
				This.Write("HELO "+This.Helo+CRLF)
			
				if This.Receive() <> "250"
					llError = .T.
				endif
			else
				*--- Send SMTP EHLO
				if !llError
					This.Write("EHLO "+This.Helo+CRLF)

					if This.Receive() <> "250"
						llError = .T.
					endif
				endif
				
				*--- Start TLS secure connection
				if !llError AND "STARTTLS" $ This.ReceivedData
					This.Write("STARTTLS"+CRLF)
					
					if This.Receive() <> "220"
						llError = .T.
					else
						This.Socket.Secure = .T.
					endif
				endif

				*--- Start Login
				if !llError
					This.Write("AUTH LOGIN"+CRLF)
					if This.Receive() <> "334"
						llError = .T.
					endif
				endif
				
				*--- Send username
				if !llError
					This.Write(strconv(This.Username,13)+CRLF)

					if This.Receive() <> "334"
						llError = .T.
					endif
				endif
				
				*--- Send password
				if !llError
					This.Write(strconv(This.Password,13)+CRLF)

					if This.Receive() <> "235"
						llError = .T.
					endif
				endif
			endif
		endif

		*--- Authenticated
		if !llError
			*--- Recipients
			lcRecipients = This.To+INTERNAL_DELIMITER
			if !empty(This.CC)
				lcRecipients = lcRecipients+This.CC+INTERNAL_DELIMITER
			endif
			if !empty(This.CCI)
				lcRecipients = lcRecipients+This.CCI+INTERNAL_DELIMITER
			endif

			*--- MAIL FROM
			This.Write("MAIL FROM: <"+This.From+">"+CRLF)
			
			if This.Receive() <> "250"
				llError = .T.
			endif

			*--- Send emails to recipients
			if !llError
				This.Bad_Emails = ""

				liNbEmails = 0

				do while INTERNAL_DELIMITER $ lcRecipients and !empty(lcRecipients)
					lcTo = alltrim(left(lcRecipients,at(INTERNAL_DELIMITER,lcRecipients)-1))

					if !empty(lcTo)
						*--- RCPT TO
						This.Write("RCPT TO: <"+lcTo+">"+CRLF)

						if This.Receive() <> "250"
							llError = .T.
						endif

						liNbEmails = liNbEmails+1
					else
						This.Bad_Emails = This.Bad_Emails+lcTo+INTERNAL_DELIMITER
						strtofile("WARNING : Email <"+lcTo+"> "+MSG_ERR16_EMAIL_REJECTED+CRLF,This.LogFile,1)
					endif
					
					lcRecipients = substr(lcRecipients,at(INTERNAL_DELIMITER,lcRecipients)+1)
				enddo
			endif

			if liNbEmails == 0
				llError = .T.
				This.ErrorMsg = MSG_ERR16_EMAIL_REJECTED
				strtofile(This.ErrorMsg+CRLF,This.LogFile,1)
			endif
		endif

		*--- DATA
		if !llError
			This.Write("DATA"+CRLF)

			if This.Receive() <> "354"
				llError = .T.
			endif
		endif

		*--- Email data
		if !llError
			for lnCtrl = 1 to len(This.Data) step 1000
				lsData = substr(This.Data, lnCtrl, 1000)

				llError = !This.Write(lsData)

				if llError
					exit
				endif
			next
		endif

		*--- Email delimiter
		if !llError
			This.Write(CRLF+"."+CRLF)

			if This.Receive() <> "250"
				llError = .T.
			endif

			if llError
				This.ErrorMsg = MSG_ERR17_MESSAGE_REJECTED
				strtofile(This.ErrorMsg+CRLF,This.LogFile,1)
			endif
		endif

		*--- End
		if !llError
			This.Write("QUIT"+CRLF)
		endif

		*--- Connect to the server
		if This.LogLevel > 0 
			strtofile("SMTP.Disconnect()"+CRLF,This.LogFile,1)
		endif

		*--- Disconnect
		This.Disconnect()

		*--- Log sent email
		if This.LogEmail
			This.LogSentEmail()
		endif

		*--- Clear Data
		This.Data = ""

		return !llError
	ENDPROC

	HIDDEN PROCEDURE Receive() AS Boolean
	LOCAL ldStart
		*--- Receivment start time
		ldStart = datetime()
		
		*--- Wait response until timeout
		do while (datetime()-ldStart) < This.Timeout
			*--- Check data on socket
			if This.Socket.IsReadable
				*--- Data arraived, read
				This.Read()
			endif

			*--- Exit if data was received
			if !empty(This.ReceivedData)
				exit
			endif
			
			*--- Wait before next attempt to read
			sleep(50)
		enddo

		*--- Log
		if This.LogLevel > 0
			strtofile("SMTP.Receive()"+CRLF+This.ReceivedData,This.LogFile,1)
		endif
		
		return This.ReceivedData
	ENDPROC

	PROCEDURE Reset()
		*--- Connection properties
		This.Hostname      = ""
		This.Port          = 25
		This.Username      = ""
		This.Password      = ""

		*--- Recipients properties
		This.From          = ""
		This.From_Name     = ""
		This.To            = ""
		This.To_Name       = ""
		This.CC            = ""
		This.CC_Name       = ""
		This.CCI           = ""
		This.ReplyTo       = ""
		This.ReplyTo_Name  = ""
		This.Bad_Emails    = ""

		*--- Message properties
		This.Attachment    = ""
		This.CodePage      = "iso-8859-1"
		This.Encoding      = "quoted-printable"
		This.Helo          = "" 
		This.Message       = ""
		This.MessageHTML   = ""
		This.Notification  = .F.
		This.Priority      = ""
		This.Subject       = ""

		*--- Error property
		This.ErrorMsg      = ""

		*--- Internal properties
		This.Data          = ""
		This.ReceivedData  = ""

		*--- Email log properties
		This.LogEmail      = .F.
		This.EmailFile     = ""
	ENDPROC

	HIDDEN PROCEDURE Read() AS Boolean
		*--- Read data from socket
		This.ReceivedData = This.Socket.Read()
	ENDPROC

	HIDDEN PROCEDURE Write(Data AS Character) AS Boolean
		*--- Log
		if This.LogLevel > 0
			strtofile("SMTP.Write()"+CRLF+Data,This.LogFile,1)
		endif

		*--- Clear received data
		This.ReceivedData = ""
		
		*--- Write data to socket
		return This.Socket.Write(createbinary(Data))
	ENDPROC

	HIDDEN PROCEDURE Rand()
		return transform(rand(-1)*100000000,"@L 99999999")
	ENDPROC

	HIDDEN PROCEDURE Data_Header()
		do case
		case This.Priority = "1" or upper(This.Priority) = "HIGH"
			This.Data = This.Data+"X-Priority: 1"+CRLF
			This.Data = This.Data+"Importance: High"+CRLF
		case This.Priority = "5" or upper(This.Priority) = "LOW"
			This.Data = This.Data+"X-Priority: 5"+CRLF
		otherwise
			This.Priority = "3"
			This.Data = This.Data+"X-Priority: 3"+CRLF
		endcase

		This.Data = This.Data+"X-Mailer: Fox Pages SMTP "+This.Version+CRLF

		if This.Notification
			This.Data = This.Data+"Disposition-Notification-To: "+This.From+"<"+This.From+">"+CRLF
		endif
	ENDPROC

	HIDDEN PROCEDURE FormatDataEmail(p_adresse,p_name,p_no_Separators)
	LOCAL lcReturn,lcTo,lcToname,liNombreEmail,liNombreNom,lnCtrl,liDebut,liLong,lcEncode
		lcReturn = ""

		if !empty(p_adresse)
			if p_no_Separators
				if empty(p_name) or (p_name == p_adresse)
					lcReturn = "<"+p_adresse+">"
				else
					lcEncode = This.String2Iso8859(p_name)

					if lcEncode == p_name
						lcReturn = lcReturn+'"'+p_name+'"'+" <"+p_adresse+">"
					else
						lcReturn = lcReturn+lcEncode+" <"+p_adresse+">"
					endif
				endif
			else
				liNombreEmail = occurs(INTERNAL_DELIMITER,p_adresse)+1
				liNombreNom   = occurs(INTERNAL_DELIMITER,p_name)+1

				for lnCtrl = 1 to liNombreEmail
					liDebut = iif(lnCtrl=1,1,at(INTERNAL_DELIMITER,p_adresse,lnCtrl-1)+1)
					liLong  = iif(lnCtrl=liNombreEmail,len(p_adresse)-liDebut+1,at(INTERNAL_DELIMITER,p_adresse,lnCtrl)-liDebut)
					lcTo = alltrim(substr(p_adresse,liDebut,liLong))

					if lnCtrl <= liNombreNom
						liDebut = iif(lnCtrl=1,1,at(INTERNAL_DELIMITER,p_name,lnCtrl-1)+1)
						liLong  = iif(lnCtrl=liNombreNom,len(p_name)-liDebut+1,at(INTERNAL_DELIMITER,p_name,lnCtrl)-liDebut)
						lcToname = alltrim(substr(p_name,liDebut,liLong))
					else
						lcToname = ""
					endif

					lcReturn = lcReturn+iif(empty(lcReturn),"",", ")

					if empty(lcToname) or (lcToname == lcTo)
						lcReturn = lcReturn+"<"+lcTo+">"
					else
						lcEncode = This.String2Iso8859(lcToname)

						if lcEncode == lcToname
							lcReturn = lcReturn+'"'+lcToname+'"'+" <"+lcTo+">"
						else
							lcReturn = lcReturn+lcEncode+" <"+lcTo+">"
						endif
					endif
				next
			endif
		endif

		return lcReturn
	ENDPROC

	HIDDEN PROCEDURE EncodeTextQuotedPrintable(cTexte)
		LOCAL cEncode,nI,cChar,nJ,nLen
		LOCAL ARRAY aLignes(1)

		cEncode = ""
		for nI = 1 to alines(aLignes,cTexte)
			nLen = len(aLignes[nI])

			if nLen > 100
				for nJ = 1 to nLen step 100
					cEncode = cEncode+substr(aLignes[nI],nJ,100)

					if nLen - nJ >= 100
						cEncode = cEncode+chr(0)+chr(0)
					endif

					cEncode = cEncode+CRLF
				next
			else
				cEncode = cEncode+aLignes[nI]+CRLF
			endif
		next

		cEncode = strtran(cEncode,"=","=3D")
		cEncode = strtran(cEncode,chr(0)+chr(0)+CRLF,"="+CRLF)
		for nI = 1 to 255
			if between(nI,33,127) or inlist(nI,10,13,32)
				loop
			endif

			cEncode = strtran(cEncode,chr(nI),"="+right(transform(nI,"@0"),2))
		next

		cEncode = strtran(cEncode,CRLF+".",CRLF+"=2E")
		return cEncode
	ENDPROC

	HIDDEN PROCEDURE String2Iso8859(cString)
	LOCAL cEncode,nI,cChar,nAsc,useIso8859
		cEncode = ""
		cBuffer = ""
		useIso8859 = .F.

		for nI = 1 to len(cString)
			cChar = substr(cString,nI,1)
			nAsc = asc(cChar)

			do case
			case nAsc = 32
				cBuffer = cBuffer+"_"
			case nAsc < 32 or nAsc = 61 or nAsc > 126
				cBuffer = cBuffer+"="+right(transform(nAsc,"@0"),2)
				useIso8859 = .T.
			otherwise
				cBuffer = cBuffer+cChar
			endcase

			if len(cBuffer) >= 58
				cEncode = cEncode+iif(empty(cEncode),"",CRLF+chr(9))+"=?iso-8859-1?Q?"+cBuffer+"?="
				cBuffer = ""
			endif
		next

		if !empty(cBuffer)
			cEncode = cEncode+iif(empty(cEncode),"",CRLF+chr(9))+"=?iso-8859-1?Q?"+cBuffer+"?="
		endif

		if !useIso8859
			cEncode = cString
		endif

		return cEncode
	ENDPROC

	HIDDEN PROCEDURE LogSentEmail()
	LOCAL lnCtrl,lcFile
		if !empty(This.Data)
			if empty(This.EmailFile)
				lnCtrl = 1
				do while .T.
					This.EmailFile = "Send_"+dtos(date())+"_"+strtran(time(),":","")+"_"+alltrim(str(lnCtrl,3,0))+".eml"

					if file(addbs(alltrim(This.Directory))+This.EmailFile)
						lnCtrl = lnCtrl+1
					else
						exit
					endif
				enddo
			endif

			lcFile = This.Directory+This.EmailFile
			strtofile(This.Data,lcFile,.F.)
		endif
	ENDPROC

	HIDDEN PROCEDURE Destroy()
		if This.LogLevel > 0
			strtofile("SMTP.Destroy()"+CRLF,This.LogFile,1)
		endif
	ENDPROC

	HIDDEN BaseClass, ClassLibrary, Comment, ControlCount, Controls, Height, HelpContextID, Objects, ParentClass, Picture, Tag, WhatsThisHelpID, Width 

	HIDDEN PROCEDURE NewObject
	HIDDEN PROCEDURE ReadExpression
	HIDDEN PROCEDURE ReadMethod
	HIDDEN PROCEDURE RemoveObject
	HIDDEN PROCEDURE ResetToDefault
	HIDDEN PROCEDURE SaveAsClass
	HIDDEN PROCEDURE ShowWhatsThis
	HIDDEN PROCEDURE WriteExpression
	HIDDEN PROCEDURE WriteMethod
ENDDEFINE

******************************************************************************************
* HTTP Class
************
DEFINE CLASS HTTP AS Base OLEPUBLIC
	*--- Request container objects
	ADD OBJECT Request AS Request && Request properties container

	*--- Response container objects
	ADD OBJECT Response AS Response && Response properties container
	
	*--- HTTP Authentication properties
	Username       = ""
	Password       = ""

	Authenticated  = .F. && Conection authenticated
	Authenticating = .F. && Conection authenticating
	AuthNonce      = ""  && Server information for Digest autheticanting
	AuthRealm      = ""  && Realm
	AuthResponse   = ""  && Authentication response
	AuthType       = ""  && Authentication type: Basic or Digest
	HIDDEN AuthNonce, AuthRealm, AuthResponse, AuthType

	*--- Receiving data
	Header         = ""  && Received header
	Content        = ""  && Received content
	Received       = .F. && Content received
	HIDDEN Header, Content, Received

	*--- Chunked transfer encoding
	ChunkData      = "" && 
	ChunkSize      = 0  && 
	HIDDEN ChunkData, ChunkSize

	*--- Log file name
	LogFile  = "http.log"

	PROCEDURE Execute(URI AS Character)
	LOCAL lnCtrl,Header
		do while .T.
			*--- Log
			if This.LogLevel > 0
				strtofile("HTTP.Request()"+CRLF,This.LogFile,1)
			endif

			*--- HTTP request header
			*--- Method
			if empty(This.Request.Method)
				This.Request.Method = "GET"
			endif
			Header = This.Request.Method+" "
			
			*--- URI and QueryString
			if empty(This.Request.URI) AND empty(URI)
				This.Request.URI = "/"
			else
				if !empty(URI)
					This.Request.URI = alltrim(URI)
				endif
			endif
			Header = Header+alltrim(This.Request.URI)
			
			*--- QueryString
			if !empty(This.Request.QueryString)
				Header = Header+"?"+alltrim(This.Request.QueryString)
			endif

			*--- HTTP Version
			Header = Header+" HTTP/1.1"+CRLF

			*--- Accept
			if !empty(This.Request.Accept)
				Header = Header+"Accept: "+alltrim(This.Request.Accept)+CRLF
			endif

			*--- Accept-Encoding
			if !empty(This.Request.AcceptEncoding)
				Header = Header+"Accept-Encoding: "+alltrim(This.Request.AcceptEncoding)+CRLF
			endif

			*--- Accept-Language
			if !empty(This.Request.AcceptLanguage)
				Header = Header+"Accept-Language: "+alltrim(This.Request.AcceptLanguage)+CRLF
			endif

			*--- Authorization
			if This.Authenticated OR This.Authenticating
				*--- Authentication type
				do case
				case This.AuthType = "Basic"
					*--- Basic authentication
					Header = Header + "Authorization: Basic "+;
									  strconv(This.Username+":"+This.Password,13)+CRLF
				case This.AuthType = "Digest"
					*--- Digest authentication
					lcA1 = lower(strconv(hash(This.Username+":"+This.AuthRealm+":"+This.Password,5),15))
					lcA2 = lower(strconv(hash(This.Request.Method+':'+This.Request.URI,5),15))
					This.AuthResponse = lower(strconv(hash(lcA1+":"+This.AuthNonce+":"+lcA2,5),15))

					Header = Header + "Authorization: Digest "+;
									  [username="]+This.Username+[", ]+;
									  [realm="]+This.AuthRealm+[", ]+;
									  [nonce="]+This.AuthNonce+[", ]+;
									  [uri="]+This.Request.URI+[", ]+;
									  [response="]+This.AuthResponse+["]+CRLF
				endcase
			endif

			*--- CacheControl
			if !empty(This.Request.CacheControl)
				Header = Header+"Cache-Control: "+alltrim(This.Request.CacheControl)+CRLF
			endif

			*--- Connection
			if !empty(This.Request.Connection) AND This.Request.Connection = "keep-alive"
				Header = Header+"Connection: keep-alive"+CRLF
			else
				Header = Header+"Connection: close"+CRLF
			endif

			*--- Content-Length
			Header = Header+"Content-Length: "+alltrim(str(len(This.Request.Content)))+CRLF
			
			*--- Content-Type
			if !empty(This.Request.ContentType)
				Header = Header+"Content-Type: "+This.Request.ContentType+CRLF
			endif

			*--- Host
			if !empty(This.Request.Host)
				Header = Header+"Host: "+alltrim(This.Request.Host)+CRLF
			endif

			*--- Origin
			if !empty(This.Request.Origin)
				Header = Header+"Origin: "+alltrim(This.Request.Origin)+CRLF
			endif

			*--- Referer
			if !empty(This.Request.Referer)
				Header = Header+"Referer: "+alltrim(This.Request.Referer)+CRLF
			endif

			*--- User-Agent
			Header = Header+"User-Agent: "+alltrim(This.Request.UserAgent)+CRLF
			
			*--- Cookies
			for each oCookie in This.Response.Cookies.Objects
				if !isnull(oCookie.Value)
					*--- Name and value
					Header = Header+"Cookie: "+oCookie.Alias+"="+oCookie.Value+CRLF
				endif
			next

			*--- Delimiter
			Header = substr(Header,1,len(Header)-2)+HEADER_DELIMITER
			
			*--- Content
			Header = Header+This.Request.Content
			
			*--- Log
			if This.LogLevel > 0
				strtofile(left(Header,len(Header)-4)+CRLF,This.LogFile,1)
			endif

			*--- Reset response buffers			
			This.Content  = ""
			This.Header   = ""
			This.Received = .F.
			
			*--- Reset response properties
			This.Response.Reset()

			*--- Check if is busy
			for lnTry = 0 to 600
				do case
				case !This.Socket.IsConnected
					*--- Disconnection
					return .F.
				case This.Socket.IsWritable
					*--- Write
					exit
				endcase

				sleep(50)
			next

			if lnTry = 50
				return .F.
			endif

			*--- Send request
			if !This.Socket.Write(Header)
				return .F.
			endif

			*--- Wait response
			for lnCtrl = 1 to 600
				*--- Check data on socket
				do case
				case !This.Socket.IsConnected
					*--- Disconnection
					return .F.
				case This.Socket.IsReadable
					*--- Data arraived, read
					This.Receive()
				endcase
				
				if This.Received
					exit
				endif

				sleep(50)
			next
			
			if !This.Received
				return .F.
			endif
			
			*--- Check authorization required
			if This.Response.StatusCode = "401"
				do case
				case empty(This.Username) OR empty(This.Password)
					*--- Missing username and password
					return .F.
				case This.Authenticating
					*--- Not authenticated
					This.Authenticated  = .F.
					This.Authenticating = .F.

					*--- Request failed on authentication
					return .F.
				otherwise
					*--- Athorization data
					lcAthentication = This.Response.Authenticate

					*--- Authentication started
					This.Authenticating = .T.
					
					do case
					case "Basic" $ lcAthentication
						*--- Basic authentication
						This.AuthType  = "Basic"
						
						if This.Socket.IsConnected
							*--- Still connected, request again
							loop
						else
							*--- The connection was closed, connect and request again
							return .F.
						endif
					case "Digest" $ lcAthentication
						*--- Digest authentication
						This.AuthType  = "Digest"
						This.AuthRealm = strextract(lcAthentication,[realm="],["])
						This.AuthNonce = strextract(lcAthentication,[nonce="],["])
						
						if This.Socket.IsConnected
							*--- Still connected, request again
							loop
						else
							*--- The connection was cloed, connect and request again
							return .F.
						endif
					endcase
				endcase
			else
				*--- Authenticated
				if This.Authenticating
					This.Authenticated  = .T.
					This.Authenticating = .F.
				endif
			endif
			
			exit
		enddo

		*--- Reset request properties
		This.Request.Reset()

		*--- Request success
		return .T.
	ENDPROC

	HIDDEN PROCEDURE Receive() AS Boolean
	LOCAL lcBuffer,lcChunkSize
		*--- Read socket
		lcBuffer = This.Socket.Read()

		*--- Incomplete request
		if !(HEADER_DELIMITER $ lcBuffer) AND empty(This.Header)	
			return
		endif

		*--- HTTP Header
 		if empty(This.Header)
			This.Header = substr(lcBuffer,1,at(HEADER_DELIMITER,lcBuffer)+3)
		endif
		
		*--- Content can be received in multiples packets
		do case
		case "content-length:" $ lower(This.Header)
			*--- Content received
			This.Content = This.Content+lcBuffer

			*--- Check content lenght
			if val(strextract(This.Header,"Content-Length: ",CRLF)) > len(substr(This.Content,at(HEADER_DELIMITER,This.Content)+4))
				return
			endif
			
			*--- Received content
			This.Response.Header  = This.Header
			This.Response.Content = substr(This.Content,at(HEADER_DELIMITER,This.Content)+4)
		case "transfer-encoding: chunked" $ lower(This.Header)
			*--- First chunk
			if empty(This.ChunkSize)
				*--- Chunk size in hexadecimal
				lcChunkSize = strextract(lcBuffer,HEADER_DELIMITER,CRLF)

				*--- Convert chunk size to decimals
				This.ChunkSize = evaluate("0x"+lcChunkSize)

				*--- Store chunk data
				This.ChunkData = substr(lcBuffer,len(This.Header)+len(lcChunkSize)+3)
			else
				*--- Store chunk data
				This.ChunkData = This.ChunkData+lcBuffer
			endif
			
			*--- Check chunked data
			do while !empty(This.ChunkSize)
				*--- Check chunk data arrived
				if This.ChunkSize > len(This.ChunkData)
					*--- Wait next chunk data to arrive
					return
				else
					*--- Store content from chunks
					This.Content = This.Content+substr(This.ChunkData,1,This.ChunkSize)

					*--- New chunk size in hexadecimal
					lcChunkSize = strextract(substr(This.ChunkData,This.ChunkSize+1,10),CRLF,CRLF)

					*--- Remove already stored chunk data
					This.ChunkData = substr(This.ChunkData,This.ChunkSize+len(lcChunkSize)+5)

					*--- Convert new chunk size to decimals
					This.ChunkSize = evaluate("0x"+lcChunkSize)

					*--- Restart chunks checking
					loop
				endif

				*--- End of the chunks
				exit
			enddo
			
			*--- Clear chunk info
			This.ChunkData = ""
			This.ChunkSize = 0

			*--- Received data
			This.Response.Header  = This.Header
			This.Response.Content = This.Content
		otherwise
			*--- Content received
			This.Content = This.Content+lcBuffer

			*--- Check HTML delimiter
			if "<html" $ lower(This.Content) AND !("</html>" $ lower(This.Content))
				return
			endif

			*--- Received content
			This.Response.Header  = This.Header
			This.Response.Content = substr(This.Content,at(HEADER_DELIMITER,This.Content)+4)
		endcase
		
		*--- Get response properties
		This.Response.Version         = strextract(This.Header,"HTTP/"," ")
		This.Response.StatusCode      = strextract(This.Header,"HTTP/"+This.Response.Version+" "," ")
		This.Response.Authenticate    = strextract(This.Header,"WWW-Authenticate: ",CRLF)
		This.Response.CacheControl    = strextract(This.Header,"Cache-Control: ",CRLF)
		This.Response.Connection      = strextract(This.Header,"Connection: ",CRLF)
		This.Response.ContentEncoding = strextract(This.Header,"Content-Encoding: ",CRLF)
		This.Response.ContentLength   = strextract(This.Header,"Content-Length: ",CRLF)
		This.Response.ContentType     = strextract(This.Header,"Content-Type: ",CRLF)
		This.Response.Date            = strextract(This.Header,"Date: ",CRLF)
		This.Response.LastModified    = strextract(This.Header,"Last-Modified: ",CRLF)
		This.Response.Server          = strextract(This.Header,"Server: ",CRLF)

		*--- Cookies
		This.GetCookies("Set-Cookie: "+strextract(This.Header,"Set-Cookie: ",HEADER_DELIMITER))
		
		*--- Compression
		if This.Response.ContentEncoding = "deflate"
			This.Response.Content = UnzipString(This.Response.Content)
		endif
		
		*--- Disconnect
		if This.Response.Connection = "close"
			This.Disconnect()
		endif

		*--- Log
		if This.LogLevel > 0
			strtofile("HTTP.Receive()"+CRLF+left(This.Header,len(This.Header)-4)+CRLF,This.LogFile,1)
		endif
		
		*--- Clear receiving buffers
		This.Content = ""
		This.Header = ""
		
		*--- Content received
		This.Received = .T.
	ENDPROC

	HIDDEN PROCEDURE Write(Data AS Character) AS Boolean
		*--- Write socket
		return This.Socket.Write(createbinary(Data))
	ENDPROC

	HIDDEN PROCEDURE GetCookies(Data AS String)
	LOCAL lnLine,lcLine
		*--- Log
		if This.LogLevel > 0
			strtofile("HTTP.GetCookies()"+CRLF,This.LogFile,1)
		endif

		if empty(Data)
			return
		endif

		*--- Process cookies
		for lnLine = 1 to memlines(Data)
			lcLine = mline(Data,lnLine)

			*--- Filter cookies
			if lcLine = "Set-Cookie: "
				*--- Add an extra ";"
				lcLine = lcLine+";"

				*--- Create cookies objects
				Alias = strextract(lcLine,"Set-Cookie: ","=")
				Name  = chrtran(Alias,".","")
				Value = strextract(lcLine,"Set-Cookie: "+Alias+"=",";")
			
				if type("This.Response.Cookies."+Name) # "O"
					This.Response.Cookies.AddObject(Name,"Cookie",Alias,Value)
				else
					loCookie = evaluate("This.Response.Cookies."+Name)
					loCookie.Value = Value
				endif
			endif
		next
	ENDPROC

	HIDDEN BaseClass, ClassLibrary, Comment, ControlCount, Controls, Height, HelpContextID, Objects, ParentClass, Picture, Tag, WhatsThisHelpID, Width

	HIDDEN PROCEDURE NewObject
	HIDDEN PROCEDURE ReadExpression
	HIDDEN PROCEDURE ReadMethod
	HIDDEN PROCEDURE RemoveObject
	HIDDEN PROCEDURE ResetToDefault
	HIDDEN PROCEDURE SaveAsClass
	HIDDEN PROCEDURE ShowWhatsThis
	HIDDEN PROCEDURE WriteExpression
	HIDDEN PROCEDURE WriteMethod
ENDDEFINE

******************************************************************************************
* BASE Class
************
DEFINE CLASS Base AS CUSTOM
	*--- Set log level
	* 0 - Disable
	* 1 - Client
	* 2 - Client and Socket
	* 3 - Client, Socket and Data
	LogLevel = 0
	
	*--- Log file
	LogFile = ""
	
	*--- Work directory
	Directory = ""
	
	*--- Secure connection (SSL)
	Secure = .F.

	HIDDEN PROCEDURE Init()
		*--- Work directory
		if _VFP.StartMode = 0
			*--- Interactive
			This.Directory = strextract(sys(16),"INIT ","PRGS\CLIENT.FXP")
		else
			*--- DLL
			This.Directory = strextract(sys(16),"INIT ","FPCLIENT.DLL")
		endif

		This.LogFile = This.Directory+This.LogFile
		
		*--- Declare DLLs
		DECLARE Sleep IN Win32API;
		    INTEGER dwMilliseconds
		
		*--- Load libraries
		set library to ["]+This.Directory+"bin\vfp2c32t.fll"+["]
		set library to ["]+This.Directory+"bin\vfpcompression.fll"+["] additive
		set library to ["]+This.Directory+"bin\vfpencryption.fll"+["] additive

		*--- Sets
		set memowidth to 8192
	
		*--- Create socket
		This.AddProperty("Socket",createobject("Socket"))
		This.AddObject("SocketInterface","SocketInterface")
		
		*--- Set socket properties
		This.Socket.CallBack = This.SocketInterface
		
		This.Socket.LogLevel  = This.LogLevel
		This.Socket.LogFile   = This.LogFile
	ENDPROC

	HIDDEN PROCEDURE Error(nError, cMethod, nLine)
		strtofile("Base.Error() - Error: "+alltrim(str(nError))+CRLF+;
				  "              Method: "+cMethod+CRLF+;
				  "                Line: "+alltrim(str(nLine))+CRLF+;
				  message()+CRLF,This.LogFile,1)
	ENDPROC

	PROCEDURE Connect(Host AS Character, Port AS Integer)
	LOCAL lcHost,llHost,lnCtrl
		*--- Set connection properties
		This.Socket.Blocking = .T.
		This.Socket.Protocol = 6
		This.Socket.Secure   = This.Secure
		
		*--- Determine if host is a hostname or hostaddress
		lcHost = chrtran(Host,".","")
		llHost = .F.
		for lnCtrl = 1 to len(lcHost)
			if !isdigit(substr(lcHost,lnCtrl,1))
				llHost = .T.
				exit
			endif
		next
		
		if llHost
			This.Socket.HostName    = Host
		else
			This.Socket.HostAddress = Host
		endif
		This.Socket.RemotePort  = Port
		
		*--- Connect
		return This.Socket.Connect()
	ENDPROC

	PROCEDURE Disconnect()
		*--- Disconnect
		This.Socket.Disconnect()
	ENDPROC

	PROCEDURE FullDate(FullDate AS Variant)
		*--- Verify if is DateTime
		do case
		case type("FullDate") = "C"
			return ctot(substr(FullDate,13,4)+"-"+;
				   transform(occurs(",",substr([,Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec],1,at(substr(FullDate,9,3),[,Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec])-1)),"@L 99")+"-"+;
				   substr(FullDate,6,2)+"T"+substr(FullDate,18,8))
		case type("FullDate") = "T"
			*--- Return HTTP FullDate
			return substr([,Sun,Mon,Tue,Wed,Thu,Fri,Sat,],at([,],[,Sun,Mon,Tue,Wed,Thu,Fri,Sat,],dow(FullDate))+1,4)+" "+;
			       transform(day(FullDate),"@L 99")+" "+;
			       substr([,Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec"],at([,],[,Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec],month(FullDate))+1,3)+" "+;
			       transform(year(FullDate),"@L 9999")+" "+;
			       transform(hour(FullDate),"@L 99")+":"+transform(minute(FullDate),"@L 99")+":"+transform(sec(FullDate),"@L 99")+" GMT"
		otherwise
			return ""
		endcase
	ENDPROC

	PROCEDURE URLEscape(Source AS String, llPlus AS Boolean)
		LOCAL lcResult, lcChar, lnChar

		lcResult = ""
		for lnChar = 1 to len(Source)
			lcChar = substr(Source,lnChar,1)

			do case
			case upper(lcChar) $ "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.~-_"
				lcResult = lcResult + lcChar
				loop
			case lcChar = "%"
				lcResult = lcResult + "%25"
				loop
			case lcChar = " " AND llPlus
				lcResult = lcResult + "+"
				loop
			endcase

			lcResult = lcResult + "%"+right(transform(asc(lcChar),"@0"),2)
		next

		return lcResult
	ENDPROC

	PROCEDURE URLUnescape(Source AS String, llPlus AS Boolean)
		LOCAL lcResult, lcChar, lnChar

		lcResult = ""
		for lnChar = 1 to len(Source)
			lcChar = substr(Source,lnChar,1)

			do case
			case lcChar = "+" AND llPlus
				lcResult = lcResult + " "
				loop
			case lcChar # "%"
				lcResult = lcResult + lcChar
				loop
			endcase

			lcResult = lcResult + chr(evaluate("0x"+substr(Source,lnChar+1,2)))
			lnChar = lnChar + 2
		next

		return lcResult
	ENDPROC

	PROCEDURE HTMLDecode(lcString AS String)
	LOCAL lnIndex
		laEncoding = NULL
		This.HTMLArray()

		FOR lnIndex = 1 TO ALEN(laEncoding,1)
		    lcString = STRTRAN(lcString,laEncoding[lnIndex,3],laEncoding[lnIndex,1])
		NEXT
		RETURN lcString
	ENDPROC


	PROCEDURE HTMLEncode(lcString AS String)
	LOCAL lnIndex
		laEncoding = NULL
		This.HTMLArray()

		FOR lnIndex = 1 TO ALEN(laEncoding,1)
		    lcString = STRTRAN(lcString,laEncoding[lnIndex,1],laEncoding[lnIndex,3])
		NEXT
		RETURN lcString
	ENDPROC

	HIDDEN PROCEDURE HTMLArray()
		DIMENSION laEncoding[101,3]
		laEncoding[1,1] = ["]
		laEncoding[1,2] = "&#34;"
		laEncoding[1,3] = "&quot;"
		laEncoding[2,1] = [']
		laEncoding[2,2] = "&#39;"
		laEncoding[2,3] = "&apos;"
		laEncoding[3,1] = [&]
		laEncoding[3,2] = "&#38;"
		laEncoding[3,3] = "&amp;"
		laEncoding[4,1] = [<]
		laEncoding[4,2] = "&#60;"
		laEncoding[4,3] = "&lt;"
		laEncoding[5,1] = [>]
		laEncoding[5,2] = "&#62;"
		laEncoding[5,3] = "&gt;"
		laEncoding[6,1] = [ ]
		laEncoding[6,2] = "&#160;"
		laEncoding[6,3] = "&nbsp;"
		laEncoding[7,1] = [¡]
		laEncoding[7,2] = "&#161;"
		laEncoding[7,3] = "&iexcl;"
		laEncoding[8,1] = [¢]
		laEncoding[8,2] = "&#162;"
		laEncoding[8,3] = "&cent;"
		laEncoding[9,1] = [£]
		laEncoding[9,2] = "&#163;"
		laEncoding[9,3] = "&pound;"
		laEncoding[10,1] = [¤]
		laEncoding[10,2] = "&#164;"
		laEncoding[10,3] = "&curren;"
		laEncoding[11,1] = [¥]
		laEncoding[11,2] = "&#165;"
		laEncoding[11,3] = "&yen;"
		laEncoding[12,1] = [¦]
		laEncoding[12,2] = "&#166;"
		laEncoding[12,3] = "&brvbar;"
		laEncoding[13,1] = [§]
		laEncoding[13,2] = "&#167;"
		laEncoding[13,3] = "&sect;"
		laEncoding[14,1] = [¨]
		laEncoding[14,2] = "&#168;"
		laEncoding[14,3] = "&uml;"
		laEncoding[15,1] = [©]
		laEncoding[15,2] = "&#169;"
		laEncoding[15,3] = "&copy;"
		laEncoding[16,1] = [ª]
		laEncoding[16,2] = "&#170;"
		laEncoding[16,3] = "&ordf;"
		laEncoding[17,1] = [«]
		laEncoding[17,2] = "&#171;"
		laEncoding[17,3] = "&laquo;"
		laEncoding[18,1] = [¬]
		laEncoding[18,2] = "&#172;"
		laEncoding[18,3] = "&not;"
		laEncoding[19,1] = [­]
		laEncoding[19,2] = "&#173;"
		laEncoding[19,3] = "&shy;"
		laEncoding[20,1] = [®]
		laEncoding[20,2] = "&#174;"
		laEncoding[20,3] = "&reg;"
		laEncoding[21,1] = [¯]
		laEncoding[21,2] = "&#175;"
		laEncoding[21,3] = "&macr;"
		laEncoding[22,1] = [°]
		laEncoding[22,2] = "&#176;"
		laEncoding[22,3] = "&deg;"
		laEncoding[23,1] = [±]
		laEncoding[23,2] = "&#177;"
		laEncoding[23,3] = "&plusmn;"
		laEncoding[24,1] = [²]
		laEncoding[24,2] = "&#178;"
		laEncoding[24,3] = "&sup2;"
		laEncoding[25,1] = [³]
		laEncoding[25,2] = "&#179;"
		laEncoding[25,3] = "&sup3;"
		laEncoding[26,1] = [´]
		laEncoding[26,2] = "&#180;"
		laEncoding[26,3] = "&acute;"
		laEncoding[27,1] = [µ]
		laEncoding[27,2] = "&#181;"
		laEncoding[27,3] = "&micro;"
		laEncoding[28,1] = [¶]
		laEncoding[28,2] = "&#182;"
		laEncoding[28,3] = "&para;"
		laEncoding[29,1] = [·]
		laEncoding[29,2] = "&#183;"
		laEncoding[29,3] = "&middot;"
		laEncoding[30,1] = [¸]
		laEncoding[30,2] = "&#184;"
		laEncoding[30,3] = "&cedil;"
		laEncoding[31,1] = [¹]
		laEncoding[31,2] = "&#185;"
		laEncoding[31,3] = "&sup1;"
		laEncoding[32,1] = [º]
		laEncoding[32,2] = "&#186;"
		laEncoding[32,3] = "&ordm;"
		laEncoding[33,1] = [»]
		laEncoding[33,2] = "&#187;"
		laEncoding[33,3] = "&raquo;"
		laEncoding[34,1] = [¼]
		laEncoding[34,2] = "&#188;"
		laEncoding[34,3] = "&frac14;"
		laEncoding[35,1] = [½]
		laEncoding[35,2] = "&#189;"
		laEncoding[35,3] = "&frac12;"
		laEncoding[36,1] = [¾]
		laEncoding[36,2] = "&#190;"
		laEncoding[36,3] = "&frac34;"
		laEncoding[37,1] = [¿]
		laEncoding[37,2] = "&#191;"
		laEncoding[37,3] = "&iquest;"
		laEncoding[38,1] = [×]
		laEncoding[38,2] = "&#215;"
		laEncoding[38,3] = "&times;"
		laEncoding[39,1] = [÷]
		laEncoding[39,2] = "&#247;"
		laEncoding[39,3] = "&divide;"
		laEncoding[40,1] = [À]
		laEncoding[40,2] = "&#192;"
		laEncoding[40,3] = "&Agrave;"
		laEncoding[41,1] = [Á]
		laEncoding[41,2] = "&#193;"
		laEncoding[41,3] = "&Aacute;"
		laEncoding[42,1] = [Â]
		laEncoding[42,2] = "&#194;"
		laEncoding[42,3] = "&Acirc;"
		laEncoding[43,1] = [Ã]
		laEncoding[43,2] = "&#195;"
		laEncoding[43,3] = "&Atilde;"
		laEncoding[44,1] = [Ä]
		laEncoding[44,2] = "&#196;"
		laEncoding[44,3] = "&Auml;"
		laEncoding[45,1] = [Å]
		laEncoding[45,2] = "&#197;"
		laEncoding[45,3] = "&Aring;"
		laEncoding[46,1] = [Æ]
		laEncoding[46,2] = "&#198;"
		laEncoding[46,3] = "&AElig;"
		laEncoding[47,1] = [Ç]
		laEncoding[47,2] = "&#199;"
		laEncoding[47,3] = "&Ccedil;"
		laEncoding[48,1] = [È]
		laEncoding[48,2] = "&#200;"
		laEncoding[48,3] = "&Egrave;"
		laEncoding[49,1] = [É]
		laEncoding[49,2] = "&#201;"
		laEncoding[49,3] = "&Eacute;"
		laEncoding[50,1] = [Ê]
		laEncoding[50,2] = "&#202;"
		laEncoding[50,3] = "&Ecirc;"
		laEncoding[51,1] = [Ë]
		laEncoding[51,2] = "&#203;"
		laEncoding[51,3] = "&Euml;"
		laEncoding[52,1] = [Ì]
		laEncoding[52,2] = "&#204;"
		laEncoding[52,3] = "&Igrave;"
		laEncoding[53,1] = [Í]
		laEncoding[53,2] = "&#205;"
		laEncoding[53,3] = "&Iacute;"
		laEncoding[54,1] = [Î]
		laEncoding[54,2] = "&#206;"
		laEncoding[54,3] = "&Icirc;"
		laEncoding[55,1] = [Ï]
		laEncoding[55,2] = "&#207;"
		laEncoding[55,3] = "&Iuml;"
		laEncoding[56,1] = [Ð]
		laEncoding[56,2] = "&#208;"
		laEncoding[56,3] = "&ETH;"
		laEncoding[57,1] = [Ñ]
		laEncoding[57,2] = "&#209;"
		laEncoding[57,3] = "&Ntilde;"
		laEncoding[58,1] = [Ò]
		laEncoding[58,2] = "&#210;"
		laEncoding[58,3] = "&Ograve;"
		laEncoding[59,1] = [Ó]
		laEncoding[59,2] = "&#211;"
		laEncoding[59,3] = "&Oacute;"
		laEncoding[60,1] = [Ô]
		laEncoding[60,2] = "&#212;"
		laEncoding[60,3] = "&Ocirc;"
		laEncoding[61,1] = [Õ]
		laEncoding[61,2] = "&#213;"
		laEncoding[61,3] = "&Otilde;"
		laEncoding[62,1] = [Ö]
		laEncoding[62,2] = "&#214;"
		laEncoding[62,3] = "&Ouml;"
		laEncoding[63,1] = [Ø]
		laEncoding[63,2] = "&#216;"
		laEncoding[63,3] = "&Oslash;"
		laEncoding[64,1] = [Ù]
		laEncoding[64,2] = "&#217;"
		laEncoding[64,3] = "&Ugrave;"
		laEncoding[65,1] = [Ú]
		laEncoding[65,2] = "&#218;"
		laEncoding[65,3] = "&Uacute;"
		laEncoding[66,1] = [Û]
		laEncoding[66,2] = "&#219;"
		laEncoding[66,3] = "&Ucirc;"
		laEncoding[67,1] = [Ü]
		laEncoding[67,2] = "&#220;"
		laEncoding[67,3] = "&Uuml;"
		laEncoding[68,1] = [Ý]
		laEncoding[68,2] = "&#221;"
		laEncoding[68,3] = "&Yacute;"
		laEncoding[69,1] = [Þ]
		laEncoding[69,2] = "&#222;"
		laEncoding[69,3] = "&THORN;"
		laEncoding[70,1] = [ß]
		laEncoding[70,2] = "&#223;"
		laEncoding[70,3] = "&szlig;"
		laEncoding[71,1] = [à]
		laEncoding[71,2] = "&#224;"
		laEncoding[71,3] = "&agrave;"
		laEncoding[72,1] = [á]
		laEncoding[72,2] = "&#225;"
		laEncoding[72,3] = "&aacute;"
		laEncoding[73,1] = [â]
		laEncoding[73,2] = "&#226;"
		laEncoding[73,3] = "&acirc;"
		laEncoding[74,1] = [ã]
		laEncoding[74,2] = "&#227;"
		laEncoding[74,3] = "&atilde;"
		laEncoding[75,1] = [ä]
		laEncoding[75,2] = "&#228;"
		laEncoding[75,3] = "&auml;"
		laEncoding[76,1] = [å]
		laEncoding[76,2] = "&#229;"
		laEncoding[76,3] = "&aring;"
		laEncoding[77,1] = [æ]
		laEncoding[77,2] = "&#230;"
		laEncoding[77,3] = "&aelig;"
		laEncoding[78,1] = [ç]
		laEncoding[78,2] = "&#231;"
		laEncoding[78,3] = "&ccedil;"
		laEncoding[79,1] = [è]
		laEncoding[79,2] = "&#232;"
		laEncoding[79,3] = "&egrave;"
		laEncoding[80,1] = [é]
		laEncoding[80,2] = "&#233;"
		laEncoding[80,3] = "&eacute;"
		laEncoding[81,1] = [ê]
		laEncoding[81,2] = "&#234;"
		laEncoding[81,3] = "&ecirc;"
		laEncoding[82,1] = [ë]
		laEncoding[82,2] = "&#235;"
		laEncoding[82,3] = "&euml;"
		laEncoding[83,1] = [ì]
		laEncoding[83,2] = "&#236;"
		laEncoding[83,3] = "&igrave;"
		laEncoding[84,1] = [í]
		laEncoding[84,2] = "&#237;"
		laEncoding[84,3] = "&iacute;"
		laEncoding[85,1] = [î]
		laEncoding[85,2] = "&#238;"
		laEncoding[85,3] = "&icirc;"
		laEncoding[86,1] = [ï]
		laEncoding[86,2] = "&#239;"
		laEncoding[86,3] = "&iuml;"
		laEncoding[87,1] = [ð]
		laEncoding[87,2] = "&#240;"
		laEncoding[87,3] = "&eth;"
		laEncoding[88,1] = [ñ]
		laEncoding[88,2] = "&#241;"
		laEncoding[88,3] = "&ntilde;"
		laEncoding[89,1] = [ò]
		laEncoding[89,2] = "&#242;"
		laEncoding[89,3] = "&ograve;"
		laEncoding[90,1] = [ó]
		laEncoding[90,2] = "&#243;"
		laEncoding[90,3] = "&oacute;"
		laEncoding[91,1] = [ô]
		laEncoding[91,2] = "&#244;"
		laEncoding[91,3] = "&ocirc;"
		laEncoding[92,1] = [õ]
		laEncoding[92,2] = "&#245;"
		laEncoding[92,3] = "&otilde;"
		laEncoding[93,1] = [ö]
		laEncoding[93,2] = "&#246;"
		laEncoding[93,3] = "&ouml;"
		laEncoding[94,1] = [ø]
		laEncoding[94,2] = "&#248;"
		laEncoding[94,3] = "&oslash;"
		laEncoding[95,1] = [ù]
		laEncoding[95,2] = "&#249;"
		laEncoding[95,3] = "&ugrave;"
		laEncoding[96,1] = [ú]
		laEncoding[96,2] = "&#250;"
		laEncoding[96,3] = "&uacute;"
		laEncoding[97,1] = [û]
		laEncoding[97,2] = "&#251;"
		laEncoding[97,3] = "&ucirc;"
		laEncoding[98,1] = [ü]
		laEncoding[98,2] = "&#252;"
		laEncoding[98,3] = "&uuml;"
		laEncoding[99,1] = [ý]
		laEncoding[99,2] = "&#253;"
		laEncoding[99,3] = "&yacute;"
		laEncoding[100,1] = [þ]
		laEncoding[100,2] = "&#254;"
		laEncoding[100,3] = "&thorn;"
		laEncoding[101,1] = [ÿ]
		laEncoding[101,2] = "&#255;"
		laEncoding[101,3] = "&yuml;"
		
		return laEncoding
	ENDPROC
ENDDEFINE

******************************************************************************************
* Request class
***************
DEFINE CLASS Request AS CUSTOM
	*--- Request properties
	Accept             = "" && Accept:
	AcceptEncoding     = "" && Accept-Encoding:
	AcceptLanguage     = "" && Accept-Language:
	CacheControl       = "" && Cache-control:
	Connection         = "" && Connection:
	Content            = "" && Content: Sent/received from server
	ContentDisposition = "" && Content-Disposition:
	ContentEncoding    = "" && Content-Encoding:
	ContentLength      = "" && Content-Length:
	ContentType        = "" && Content-Type:
	Host               = "" && Host:
	IfModifiedSince    = "" && If-Modified-Since:
	Method             = "" && HTTP Method
	Origin             = "" && Origin:
	QueryString        = "" && '?' part of URI
	Referer            = "" && Referer:
	URI                = "" && Requested URI
	UserAgent          = "FoxPages Client/1.0.0 FXP/1.0.0" && User-Agent:
	
	PROCEDURE Reset()
		*--- Request properties
		This.Accept             = ""
		This.AcceptEncoding     = ""
		This.AcceptLanguage     = ""
		This.CacheControl       = ""
		This.Connection         = ""
		This.Content            = ""
		This.ContentDisposition = ""
		This.ContentEncoding    = ""
		This.ContentLength      = ""
		This.ContentType        = ""
		This.Host               = ""
		This.IfModifiedSince    = ""
		This.Method             = ""
		This.Origin             = ""
		This.QueryString        = ""
		This.Referer            = ""
		This.URI                = ""
		This.UserAgent          = "FoxPages Client/1.0.0 FXP/1.0.0"
	ENDPROC
ENDDEFINE

******************************************************************************************
* Response class
***************
DEFINE CLASS Response AS CUSTOM
	*--- Response properties
	Authenticate       = "" && WWW-Authenticate:
	CacheControl       = "" && Cache-control:
	Connection         = "" && Connection:
	Content            = "" && Content: Sent/received from server
	ContentDisposition = "" && Content-Disposition:
	ContentEncoding    = "" && Content-Encoding:
	ContentLength      = "" && Content-Length:
	ContentType        = "" && Content-Type:
	Date               = "" && Date:
	Expires            = {} && Expires:
	Header             = "" && Response header
	LastModified       = "" && Last-Modified:
	Location           = "" && Location:
	Server             = "" && Server name:
	StatusCode         = "" && Request status code
	Pragma             = "" && Pragma:
	Vary               = "" && Vary:
	Version            = "" && HTTP Version

	PROCEDURE Reset()
		Authenticate       = ""
		CacheControl       = ""
		Connection         = ""
		Content            = ""
		ContentDisposition = ""
		ContentEncoding    = ""
		ContentLength      = ""
		ContentType        = ""
		Date               = ""
		Expires            = {}
		Header             = ""
		LastModified       = ""
		Location           = ""
		Server             = ""
		StatusCode         = ""
		Pragma             = ""
		Vary               = ""
		Version            = ""
	ENDPROC
	
	ADD OBJECT Cookies   AS CUSTOM && Cookies container object
ENDDEFINE

******************************************************************************************
* Variables class
*****************
DEFINE CLASS Variable AS CUSTOM
*	Name = ""  && Variable name
	Value = "" && Variable value (always as character)

	PROCEDURE Init(Value AS String)
		This.Value = Value
	ENDPROC
ENDDEFINE

******************************************************************************************
* Cookies class
***************
DEFINE CLASS Cookie AS CUSTOM
*	Name     = ""    && Cookie name
	Alias    = ""    && Cookie alias
	Value    = NULL  && Value of the cookie
	Expires  = {}    && Expiration datetime of the cookie
	MaxAge   = -1    && MaxAge of the Cookie
	Path     = NULL  && Path of the cookie
	HTTPOnly = .F.   && HTTP Protocol only cookie
	Secure   = .F.   && Secure cookie (Can't use yet, works only with SSL/TLS connections)

	PROCEDURE Init(Alias AS String,Value AS String,Expires AS DateTime, MaxAge AS Integer,Path AS String,HTTPOnly AS Boolean,Secure AS Boolean)
		This.Alias  = Alias
		This.Value  = Value
		if type("Expires") = "T"
			This.Expires = Expires
		endif
		if type("MaxAge") = "N"
			This.MaxAge = MaxAge
		endif
		if type("Path") = "C"
			This.Path = Path
		endif
		This.HTTPOnly = HTTPOnly
		This.Secure = Secure
	ENDPROC
ENDDEFINE

******************************************************************************************
* Classe Socket
***************
DEFINE CLASS Socket AS CUSTOM
	*--- Propriedades
	Blocking        = .F.
	CallBack	    = NULL
	CertificateName = ""
	HostAddress     = ""
	HostName        = ""
	IsClosed        = .F.
	IsConnected     = .F.
	IsReadable      = .F.
	IsWritable      = .F.
	LocalPort       = 0
	LocalAddress    = ""
	LogLevel        = 0
	PeerAddress     = ""
	PeerPort        = 0
	Protocol        = 0
	RemotePort      = 0
	Secure          = .F.
	State           = 0
	LogFile         = ""
	
	*--- Inicialização
	HIDDEN PROCEDURE Init()
		This.AddProperty("SocketWrench",createobject(CSWSOCK_CONTROL))
		This.AddObject("SocketWrenchInterface","SocketWrenchInterface")
		
		EVENTHANDLER(This.SocketWrench,This.SocketWrenchInterface)
		
		*--- SocketWrench License
		This.SocketWrench.Initialize(CSWSOCK_LICENSE_KEY)

		*--- Disable Nagle Algorithm
		This.SocketWrench.NoDelay = .T.

		*--- Set to pass array by referency and to not convert to string
		COMARRAY(This.SocketWrench,1010)
	ENDPROC

	HIDDEN PROCEDURE Destroy()
		removeproperty(This,"SocketWrench")
	ENDPROC

	*--- Métodos
	PROCEDURE Accept(Handle AS Integer)
		if This.LogLevel > 1
			strtofile("Socket.Accept()"+CRLF,This.LogFile,1)
		endif
		return This.SocketWrench.Accept(Handle) = 0
	ENDPROC

	PROCEDURE Connect()
		if This.LogLevel > 1
			strtofile("Socket.Connect()"+CRLF,This.LogFile,1)
		endif
		return This.SocketWrench.Connect() = 0
	ENDPROC

	PROCEDURE Disconnect()
		if This.LogLevel > 1
			strtofile("Socket.Disconnect()"+CRLF,This.LogFile,1)
		endif
		return This.SocketWrench.Disconnect() = 0
	ENDPROC

	PROCEDURE Listen()
		if This.LogLevel > 1
			strtofile("Socket.Listen()"+CRLF,This.LogFile,1)
		endif
		return This.SocketWrench.Listen() = 0
	ENDPROC

	PROCEDURE Write(Data AS Character)
		if This.LogLevel > 1
			strtofile("Socket.Write()"+iif(This.LogLevel > 2,CRLF+Data,""),This.LogFile,1)
		endif
		return This.SocketWrench.Write(createbinary(Data)) # -1
	ENDPROC

	PROCEDURE Read()
	LOCAL laBuffer,lcBuffer,lnSize,lnByte
		*--- Wait to read
		do while !This.IsReadable
			*--- Check connection
			if !This.SocketWrench.IsConnected
				This.Parent.Disconnect()
				return .F.
			endif

			sleep(10)
		enddo

		*--- Create byte array buffer
		DIMENSION laBuffer[1024] AS Byte

		m.lcBuffer = ""
		do while This.IsReadable
			*--- Reset byte array
			m.laBuffer = 0

			*--- Read data to byte array
			m.lnSize = This.SocketWrench.Read(@m.laBuffer)

			*--- Check data was received
			if m.lnSize < 1
				exit
			endif

			*--- Convert byte array to string
			for m.lnByte = 1 to m.lnSize
				m.lcBuffer = m.lcBuffer + chr(m.laBuffer[m.lnByte])
			next
		enddo

		*--- Log
		if This.LogLevel > 1 AND !empty(lcBuffer)
			strtofile("Socket.Read()"+iif(This.LogLevel > 2,CRLF+lcBuffer,""),This.LogFile,1)
		endif

		*--- Return data
		return m.lcBuffer
	ENDPROC

	HIDDEN PROCEDURE Error(nError, cMethod, nLine)
		strtofile("Socket.Error() - "+cMethod+": "+message()+CRLF,This.LogFile,1)
	ENDPROC

	*--- Eventos
	PROCEDURE OnAccept(Handle)
		This.CallBack.OnAccept(Handle)
	ENDPROC

	PROCEDURE OnCancel()
		This.CallBack.OnCancel()
	ENDPROC

	PROCEDURE OnConnect()
		This.CallBack.OnConnect()
	ENDPROC

	PROCEDURE OnDisconnect()
		This.CallBack.OnDisconnect()
	ENDPROC

	PROCEDURE OnError(ErrorCode, Description)
		This.CallBack.OnError(ErrorCode, Description)
	ENDPROC

	PROCEDURE OnProgress(BytesTotal, BytesCopied, Percent)
		This.CallBack.OnProgress(BytesTotal, BytesCopied, Percent)
	ENDPROC

	PROCEDURE OnRead()
		strtofile("Socket.OnRead()"+CRLF,This.LogFile,1)
		This.CallBack.OnRead()
	ENDPROC

	PROCEDURE OnTimeout()
		This.CallBack.OnTimeout()
	ENDPROC

	PROCEDURE OnTimer()
		This.CallBack.OnTimer()
	ENDPROC

	PROCEDURE OnWrite()
		This.CallBack.OnWrite()
	ENDPROC

	*--- Acesso e alteração de propriedades

	HIDDEN PROCEDURE IsConnected_Access()
		This.IsConnected = This.SocketWrench.Connected
		return This.IsConnected
	ENDPROC

	HIDDEN PROCEDURE IsClosed_Access()
		This.IsClosed = This.SocketWrench.IsClosed
		return This.IsClosed
	ENDPROC

	HIDDEN PROCEDURE IsReadable_Access()
		This.IsReadable = This.SocketWrench.IsReadable
		return This.SocketWrench.IsReadable
	ENDPROC

	HIDDEN PROCEDURE IsWritable_Access()
		This.IsWritable = This.SocketWrench.IsWritable
		return This.IsWritable
	ENDPROC

	HIDDEN PROCEDURE PeerAddress_Access()
		return This.SocketWrench.PeerAddress
	ENDPROC
	
	HIDDEN PROCEDURE PeerPort_Access()
		return This.SocketWrench.PeerPort
	ENDPROC
	
	HIDDEN PROCEDURE State_Access()
		This.State = This.SocketWrench.State
		return This.SocketWrench.State
	ENDPROC
	
	HIDDEN PROCEDURE Blocking_Assign(vNewVal)
		This.Blocking = m.vNewVal
		This.SocketWrench.Blocking = m.vNewVal
	ENDPROC

	HIDDEN PROCEDURE CertificateName_Assign(vNewVal)
		This.CertificateName = m.vNewVal
		This.SocketWrench.CertificateName = m.vNewVal
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

	HIDDEN PROCEDURE Protocol_Assign(vNewVal)
		This.Protocol = m.vNewVal
		This.SocketWrench.Protocol = m.vNewVal
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
* Classe de eventos do Socket para os Clients
*********************************************
DEFINE CLASS SocketInterface AS CUSTOM
	PROCEDURE OnAccept(Handle AS Integer) AS Variant
	ENDPROC

	PROCEDURE OnCancel() AS Variant
	ENDPROC

	PROCEDURE OnConnect() AS Variant
	ENDPROC

	PROCEDURE OnDisconnect() AS Variant
		This.Parent.Disconnect()
	ENDPROC

	PROCEDURE OnError(ErrorCode AS Integer, Description AS STRING) AS Variant
	ENDPROC

	PROCEDURE OnProgress(BytesTotal AS Integer, BytesCopied AS Integer, Percent AS Integer) AS Variant
	ENDPROC

	PROCEDURE OnRead() AS Variant
	ENDPROC

	PROCEDURE OnTimeout() AS Variant
	ENDPROC

	PROCEDURE OnTimer() AS Variant
	ENDPROC

	PROCEDURE OnWrite() AS Variant
	ENDPROC
ENDDEFINE

******************************************************************************************
* Classe de interface do SocketWrench
*************************************
DEFINE CLASS SocketWrenchInterface AS CUSTOM
IMPLEMENTS _iSocketWrenchEvents IN CSWSOCK_CONTROL

	PROCEDURE Error(nError, cMethod, nLine)
		strtofile(cMethod+": "+message()+CRLF,This.Parent.LogFile,1)
	ENDPROC

	PROCEDURE _iSocketWrenchEvents_OnAccept(Handle)
		This.Parent.OnAccept(Handle)
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
		This.Parent.OnError(ErrorCode, Description)
	ENDPROC

	PROCEDURE _iSocketWrenchEvents_OnProgress(BytesTotal, BytesCopied, Percent)
		This.Parent.OnProgress(BytesTotal, BytesCopied, Percent)
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

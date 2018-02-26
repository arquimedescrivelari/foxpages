#INCLUDE foxpages.h

******************************************************************************************
* REST Processing class
***********************
DEFINE CLASS RESTProcessor AS SESSION
	*--- Error
	HasError = .F.

	*--- Work directory
	Directory = ""

	PROCEDURE Init()
		*--- Debug log
		This.Parent.Parent.Log.Add(3,"Webserver.REST.Init")

		*--- Sets
		set deleted on
		set exclusive off
		set memowidth to 8192
		set sysformats on
	ENDPROC

	PROCEDURE Destroy()
		*--- Debug log
		This.Parent.Parent.Log.Add(3,"Webserver.REST.Destroy")
	ENDPROC

	PROCEDURE Error(nError,cMethod,nLine)
	LOCAL lcMessage,lnSize,lnCtrl
		This.HasError = .T.

		m.lcMessage = ["]+alltrim(str(m.nError))+[ - ]+chrtran(message(),[\"],[/'])+[", ]+;
					iif(This.Parent.Parent.StartMode = 0,["lineCode": "]+chrtran(message(1),["],['])+[", ],[])

		m.lcMessage = m.lcMessage + '"callStack": {'
		m.lnSize = astackinfo(Stack)
		for m.lnCtrl = (m.lnSize-1) to 5 step -1
			m.lcMessage = m.lcMessage+["]+alltrim(str(stack[m.lnCtrl,1]-4))+[": "]+chrtran(stack[m.lnCtrl,2],[\"],[/'])+[ (]+stack[m.lnCtrl,3]+[,]+alltrim(str(stack[m.lnCtrl,5]))+[)", ]
		next

		m.lcMessage = substr(m.lcMessage,1,len(m.lcMessage)-2)+'}'

		*--- Debug log
		This.Parent.Parent.Log.Add(0,"Webserver.REST.Error",strtran(m.lcMessage,"\r\n",CRLF))

		*--- Send error
		This.Parent.SendError("500","Internal Server Error","Runtime Error",m.lcMessage)
	ENDPROC

	PROCEDURE Process(Target AS String)
	LOCAL lnDirs
		*--- Debug log
		This.Parent.Parent.Log.Add(3,"Webserver.REST.Process")

		*--- Work directory
		This.Directory = This.Parent.Directory

		*--- Target is a prg
		Target = This.Directory+Target

		*--- Compile program
		m.lcPRGFile = Target+".prg"							&& PRG file 
		m.lcFXPFile = strtran(m.lcPRGFile,".prg",".fxp")	&& FXP file 
		m.lcERRFile = strtran(m.lcPRGFile,".prg",".err")	&& ERR file 

		*--- Check file dates
		if file(m.lcPRGFile) AND (!file(m.lcFXPFile) OR fdate(m.lcPRGFile,1) > fdate(m.lcFXPFile,1))
			*--- Compile .prg file
			compile (m.lcPRGFile)
		endif

		*--- Check compilation erros
		if file(m.lcERRFile)
			*--- Delete files
			This.Parent.SendError("500","Internal Server Error","COMPILATION ERROR",["]+strtran(filetostr(m.lcERRFile),CRLF,"\r\n")+["])

			delete file (m.lcFXPFile)
			delete file (m.lcERRFile)

			return .F.
		endif

		*--- Add / to directory
		This.Directory = This.Directory+"/"

		*--- Set path directory
		set path to (This.Directory)
		for m.lnDirs = 3 to adir(aDirs,This.Directory+"*.*","D")
			if aDirs[m.lnDirs,5] = "....D"
				set path to (This.Directory+aDirs[m.lnDirs,1]) additive
			endif
		next

		*--- Set default properties
		This.Parent.Response.Status_Code        = "200"
		This.Parent.Response.Status_Description = "OK"
		This.Parent.Response.Content_Type       = "application/json"

		*--- Objects
		Socket   = This.Parent.Parent.Socket
		HTTP     = This.Parent
		HTML     = This
		Request  = This.Parent.Request
		Response = This.Parent.Response

		*--- Run program
		do (Target)

		*--- Release objects
		RELEASE Socket
		RELEASE HTTP
		RELEASE HTML
		RELEASE Request
		RELEASE Response

		*--- Reload FLLs
		#IFDEF X64
			set library to bin64\vfp2c32.fll
		#ELSE
			set library to bin\vfp2c32t.fll,bin\vfpcompression.fll,bin\vfpencryption.fll
		#ENDIF

		*--- Clear set procedure
		set procedure to

		*--- Clear set path
		set path to

		*--- Close any open connection
		sqldisconnect(0)

		*--- Close any open database
		close databases all

		*--- Remove FXP from cache
		clear program

		return !This.HasError
	ENDPROC
ENDDEFINE
DEFINE CLASS oSystem AS CUSTOM

Collate          = "GENERAL"
CompanyCode      = ""
ConnectionHandle = 0
RemoteData       = .F.
TransactionLevel = 0

PROCEDURE Init
ENDPROC

PROCEDURE Destroy
ENDPROC

********************************************************************************
PROCEDURE Connect()
********************************************************************************
	*--- Check if using remote data
	if This.RemoteData
		This.ConnectionHandle = 0

		*--- Connect
		This.ConnectionHandle = sqlconnect("amr",.T.)

		if This.ConnectionHandle > 0
			*--- Search_path
			sqlexec(This.ConnectionHandle,"SET search_path TO appexp,emp"+This.CompanyCode)
			
			return .T.
		else
			return .F.
		endif
	endif
ENDPROC

********************************************************************************
PROCEDURE Use
********************************************************************************
LPARAMETERS lcView,lcAlias,lnArea,llNoData
LOCAL llData,llArea,lcCommand,ldTime,llError
	ldTime  = datetime()
	llError = .T.

	*--- Determinar parametros
	llView  = pcount() >= 1
	llAlias = pcount() >= 2 AND type("lcAlias")  = "C" AND !empty(lcAlias)
	llArea  = pcount() >= 3 AND type("lnArea")   = "N" AND lnArea >= 0
	llData  = pcount() >= 4 AND type("llNoData") = "L" AND llNoData

	*--- Abrir view
	try
		lcCommand = "use"+iif(llView,' "'+alltrim(lcView)+'"',"")+;
					iif(llAlias," alias "+alltrim(lcAlias),"")+;
					iif(llData," nodata","")+;
					iif(llArea," in "+alltrim(str(lnArea)),"")
		&lcCommand

		llError = .F.
	catch
		llError = .T.
	endtry

	*--- Retornar o sucesso
	return !llError
ENDPROC

********************************************************************************
PROCEDURE BeginTransaction()
********************************************************************************
    if This.TransactionLevel = 0
        begin transaction
        if This.RemoteData
            sqlexec(This.ConnectionHandle,"BEGIN")
        endif
    endif

    This.TransactionLevel = This.TransactionLevel + 1
ENDPROC

********************************************************************************
PROCEDURE RollBack()
********************************************************************************
    if This.TransactionLevel > 0
		This.TransactionLevel = This.TransactionLevel - 1
		
        rollback
        if This.RemoteData
            sqlexec(This.ConnectionHandle,"ROLLBACK")
        endif
    endif
ENDPROC

********************************************************************************
PROCEDURE EndTransaction()
********************************************************************************
    if This.TransactionLevel > 0
	    This.TransactionLevel = This.TransactionLevel - 1

        end transaction
        if This.RemoteData
            sqlexec(This.ConnectionHandle,"COMMIT")
        endif
    endif
ENDPROC

********************************************************************************
PROCEDURE Append
********************************************************************************
LPARAMETERS lcAlias,llRunIntegration
LOCAL lcClass,leRecno

	*--- Determinar o alias
	lcAlias = iif(empty(lcAlias),Alias(),lcAlias)
	if !used(lcAlias)
	    return .F.
	endif

	*--- Adicionar o registro
	AppendSucess = .T.
	on error AppendSucess = .F.
	append blank
	on error

	return AppendSucess
ENDPROC

********************************************************************************
PROCEDURE Save
********************************************************************************
LPARAMETERS leParam1,leParam2
LOCAL lcAlias,llAll,lcClass,lnRecno,ldTime,llError

	llAll   = .F.
	lcAlias = ""

	do case
	case pcount() > 0
		do case
		case type("leParam1") = "C"
			lcAlias = leParam1
		case type("leParam1") = "L"
			llAll = leParam1
		endcase
	case pcount() > 1
		do case
		case type("leParam2") = "C"
			lcAlias = leParam2
		case type("leParam2") = "L"
			llAll = leParam2
		endcase
	endcase

	*--- Determinar o alias
	lcAlias = iif(empty(lcAlias),Alias(),lcAlias)
	if !used(lcAlias)
	    return .F.
	endif
	 
	*--- Selecionar a area
	select (lcAlias)

	*--- Atualizar dados
	llError = !tableupdate(iif(llAll,1,0))

	if llError
		error (strconv(message(),11))
	endif

	return !llError
ENDPROC

********************************************************************************
PROCEDURE Delete
********************************************************************************
LPARAMETERS leParam1,leParam2
LOCAL lcClass,lnRecno,ldTime,lcSavePoint,llError
	llAll   = .F.
	lcAlias = ""

	do case
	case pcount() > 0
		do case
		case type("leParam1") = "C"
			lcAlias = leParam1
		case type("leParam1") = "L"
			llAll = leParam1
		endcase
	case pcount() > 1
		do case
		case type("leParam2") = "C"
			lcAlias = leParam2
		case type("leParam2") = "L"
			llAll = leParam2
		endcase
	endcase

	*--- Determinar o alias
	lcAlias = iif(empty(lcAlias),Alias(),lcAlias)
	if !used(lcAlias)
	    return .F.
	endif

	*--- Selecionar a area
	select (lcAlias)

	*--- Se for um registro novo somente reverter
	if ("3" $ getfldstate(-1) OR "4" $ getfldstate(-1)) OR eof() OR bof()
	    return This.Revert()
	endif

	*--- Excluir os registros
	try
	    if llAll
	        delete all
	    else
	        delete
	    endif
	catch
	endtry

	*--- Atualizar dados
	llError = .T.

	if This.RemoteData AND This.TransactionLevel > 0
	    lcSavePoint = "SP"+sys(2015)
	    sqlexec(This.ConnectionHandle,"SAVEPOINT "+lcSavePoint)
	endif

	llError = !tableupdate(.T.,.F.)

	if llError
	   if This.RemoteData AND This.TransactionLevel > 0
	      sqlexec(This.ConnectionHandle,"ROLLBACK TO SAVEPOINT "+lcSavePoint)
	   endif
	else
	   if This.RemoteData AND This.TransactionLevel > 0
	      sqlexec(This.ConnectionHandle,"RELEASE SAVEPOINT "+lcSavePoint)
	   endif
	endif

	return !llError
ENDPROC

********************************************************************************
PROCEDURE Revert
********************************************************************************
LPARAMETERS leParam1,leParam2
LOCAL lcAlias,llAll

	do case
	case pcount() > 0
		do case
		case type("leParam1") = "C"
			lcAlias = leParam1
		case type("leParam1") = "L"
			llAll = leParam1
		endcase
	case pcount() > 1
		do case
		case type("leParam2") = "C"
			lcAlias = leParam2
		case type("leParam2") = "L"
			llAll = leParam2
		endcase
	endcase

	*--- Determinar o alias
	lcAlias = iif(empty(lcAlias),Alias(),lcAlias)
	if !used(lcAlias)
	    return .F.
	endif

	return tablerevert(llAll,lcAlias)
ENDPROC

********************************************************************************
PROCEDURE Run(lcClass,lcMethod,leParam1,leParam2,leParam3,leParam4,leParam5,;
							   leParam6,leParam7,leParam8,leParam9,leParam10,;
							   leParam11,leParam12,leParam13,leParam14,leParam15,;
							   leParam16,leParam17,leParam18,leParam19,leParam20,;
							   leParam21,leParam22,leParam23,leParam24,leParam25)
********************************************************************************
LOCAL leReturn,lnParams

	*--- Determinando o número de parâmetros
	lnParams = pcount()-2

	if (lnParams) < 0
		return NULL
	endif

	*--- Tentar adicionar a biblioteca de classes
	if !upper(lcClass+".fxp") $ upper(set("Procedure"))
		set procedure to (lcClass) additive
	endif

	*--- Tentar criar o objeto
	LOCAL (lcClass)
	&lcClass = createobject(lcClass+"_METHODS")
	
	*--- Tentar executar o método
	lcInstruc = lcClass+"."+lcMethod+"("+;
	iif(lnParams > 0, "@leParam1","")+;
	iif(lnParams > 1,",@leParam2","")+;
	iif(lnParams > 2,",@leParam3","")+;
	iif(lnParams > 3,",@leParam4","")+;
	iif(lnParams > 4,",@leParam5","")+;
	iif(lnParams > 5,",@leParam6","")+;
	iif(lnParams > 6,",@leParam7","")+;
	iif(lnParams > 7,",@leParam8","")+;
	iif(lnParams > 8,",@leParam9","")+;
	iif(lnParams > 9,",@leParam10","")+;
	iif(lnParams > 10,",@leParam11","")+;
	iif(lnParams > 11,",@leParam12","")+;
	iif(lnParams > 12,",@leParam13","")+;
	iif(lnParams > 13,",@leParam14","")+;
	iif(lnParams > 14,",@leParam15","")+;
	iif(lnParams > 15,",@leParam16","")+;
	iif(lnParams > 16,",@leParam17","")+;
	iif(lnParams > 17,",@leParam18","")+;
	iif(lnParams > 18,",@leParam19","")+;
	iif(lnParams > 19,",@leParam20","")+;
	iif(lnParams > 20,",@leParam21","")+;
	iif(lnParams > 21,",@leParam22","")+;
	iif(lnParams > 22,",@leParam23","")+;
	iif(lnParams > 23,",@leParam24","")+;
	iif(lnParams > 24,",@leParam25","")+")"

	leReturn = evaluate(lcInstruc)

	*--- Liberar o objeto e a biblioteca
	release (lcClass)

	*--- Verificar o retorno
	if isnull(leReturn)
		return NULL
	endif

	*--- Retornar o valor
	return leReturn
ENDPROC
ENDDEFINE

DEFINE CLASS oEvents AS CUSTOM
ENDDEFINE

DEFINE CLASS oExecute AS CUSTOM
ENDDEFINE

FUNCTION Array
LPARAMETERS lcArrayName,lnIndex,lnSize

if empty(lnSize)
	messagebox("Não foram informados todos parametros necessários para a função array.",48,Alias())
	lnSize = 10
endif

if empty(lnIndex)
	return space(lnSize)
endif

if empty(alen((lcArrayName),2))
	lcArrayName = lcArrayName+"["+alltrim(str(lnIndex))+"]"
else
	lcArrayName = lcArrayName+"["+alltrim(str(lnIndex))+",1]"
endif

if type(lcArrayName) = "U" OR lnIndex = 0
	return space(lnSize)
endif

return substr(eval(lcArrayName)+space(lnSize),1,lnSize)
LOCAL loJSON,loResult,loData

*--- Create JSON Parser
loJSON = newobject("JSON","json.prg")

*--- Result object
loResult = createobject("EMPTY")
addproperty(loResult,"file","landcodes")

cVar = strconv(strextract(Request.Query_String+"&",'key=',"&"),11)
lHeaders = iif(strextract(Request.Query_String+"&",'headers=',"&")="1",.T.,.F.)
lLabels = iif(strextract(Request.Query_String+"&",'labels=',"&")="1",.T.,.F.)

do case
case Request.Method = "GET"
	if lHeaders
		*--- Edit grid definition
		addproperty(loResult,"headers[3]")
		
		loResult.Headers[1] = createobject("EMPTY")
		addproperty(loResult.Headers[1],"title","Country code:")
		addproperty(loResult.Headers[1],"data","code")
		addproperty(loResult.Headers[1],"edit",.F.)
		addproperty(loResult.Headers[1],"type","text")
		addproperty(loResult.Headers[1],"width","20%")
		loResult.Headers[2] = createobject("EMPTY")
		addproperty(loResult.Headers[2],"title","Country:")
		addproperty(loResult.Headers[2],"data","land")
		addproperty(loResult.Headers[2],"edit",.T.)
		addproperty(loResult.Headers[2],"type","text")
		addproperty(loResult.Headers[2],"width","60%")
		loResult.Headers[3] = createobject("EMPTY")
		addproperty(loResult.Headers[3],"title","Tax code:")
		addproperty(loResult.Headers[3],"data","landcode")
		addproperty(loResult.Headers[3],"edit",.F.)
		addproperty(loResult.Headers[3],"type","text")
		addproperty(loResult.Headers[3],"width","20%")
	endif

	*--- Form tabs fields definition
	if lLabels
		*--- Set properties to rename
		dimension loJSON.PropertyAlias[1,2]
		loJSON.PropertyAlias[1,1] = 'text_transform' && VFP Object name
		loJSON.PropertyAlias[1,2] = 'text-transform' && JSON Object name

		addproperty(loResult,"labels[7]")
		
		loBlocks = createobject("EMPTY")
		addproperty(loBlocks,"width",12)
		addproperty(loResult,"blocks[1]")
		loResult.Blocks[1] = loBlocks

		loResult.Labels[1] = createobject("EMPTY")
		addproperty(loResult.Labels[1],"block",1)
		addproperty(loResult.Labels[1],"display","")
		addproperty(loResult.Labels[1],"fieldname","id")
		addproperty(loResult.Labels[1],"length",8)
		addproperty(loResult.Labels[1],"inputtype","hidden")

		loResult.Labels[2] = createobject("EMPTY")
		addproperty(loResult.Labels[2],"block",1)
		addproperty(loResult.Labels[2],"display","Country code:")
		addproperty(loResult.Labels[2],"tooltip","")
		addproperty(loResult.Labels[2],"fieldname",'code')
		addproperty(loResult.Labels[2],"length",3)
		if Request.ID > "0" && Prevent editing of the primary key
			addproperty(loResult.Labels[2],"inputtype",'read_text')
		else
			addproperty(loResult.Labels[2],"inputtype",'text')
			addproperty(loResult.Labels[2],"notempty",.T.)
		endif
		addproperty(loResult.Labels[2],"newline",.F.)
		addproperty(loResult.Labels[2],"labelwidth",3)
		addproperty(loResult.Labels[2],"fieldwidth",3)
		addproperty(loResult.Labels[2],"notempty",.T.)

		loResult.Labels[3] = createobject("EMPTY")
		addproperty(loResult.Labels[3],"block",1)
		addproperty(loResult.Labels[3],"display","Country:")
		addproperty(loResult.Labels[3],"tooltip","Country name.")
		addproperty(loResult.Labels[3],"fieldname",'land')
		addproperty(loResult.Labels[3],"length",30)
		addproperty(loResult.Labels[3],"inputtype",'text')
		addproperty(loResult.Labels[3],"newline",.T.)
		addproperty(loResult.Labels[3],"labelwidth",3)
		addproperty(loResult.Labels[3],"fieldwidth",6)
		addproperty(loResult.Labels[3],"notempty",.T.)
		addproperty(loResult.Labels[3],"pipe","uppercase")
		addproperty(loResult.Labels[3],"style",createobject("EMPTY"))
		addproperty(loResult.Labels[3].Style,"text_transform","uppercase")

		loResult.Labels[4] = createobject("EMPTY")
		addproperty(loResult.Labels[4],"block",1)
		addproperty(loResult.Labels[4],"display","This is a label to use")
		addproperty(loResult.Labels[4],"tooltip","")
		addproperty(loResult.Labels[4],"fieldname",'')
		addproperty(loResult.Labels[4],"length",0)
		addproperty(loResult.Labels[4],"inputtype",'label')
		addproperty(loResult.Labels[4],"newline",.T.)
		addproperty(loResult.Labels[4],"labelwidth",3)
		addproperty(loResult.Labels[4],"fieldwidth",6)

		loResult.Labels[5] = createobject("EMPTY")
		addproperty(loResult.Labels[5],"block",1)
		addproperty(loResult.Labels[5],"display","Tax code:")
		addproperty(loResult.Labels[5],"tooltip","Country Code used for VAT.")
		addproperty(loResult.Labels[5],"fieldname",'landcode')
		addproperty(loResult.Labels[5],"length",2)
		addproperty(loResult.Labels[5],"inputtype",'text')
		addproperty(loResult.Labels[5],"newline",.T.)
		addproperty(loResult.Labels[5],"labelwidth",3)
		addproperty(loResult.Labels[5],"fieldwidth",3)
		addproperty(loResult.Labels[5],"notempty",.T.)
		addproperty(loResult.Labels[5],"pipe","uppercase")
		addproperty(loResult.Labels[5],"style",createobject("EMPTY"))
		addproperty(loResult.Labels[5].Style,"text_transform","uppercase")

		loResult.Labels[6] = createobject("EMPTY")
		addproperty(loResult.Labels[6],"block",1)
		addproperty(loResult.Labels[6],"display","Signature.")
		addproperty(loResult.Labels[6],"tooltip","")
		addproperty(loResult.Labels[6],"fieldname",'signature')
		addproperty(loResult.Labels[6],"length",0)
		addproperty(loResult.Labels[6],"inputtype",'draw')
		addproperty(loResult.Labels[6],"newline",.T.)
		addproperty(loResult.Labels[6],"labelwidth",3)
		addproperty(loResult.Labels[6],"fieldwidth",8)
		addproperty(loResult.Labels[6],"fieldheight",5)

		loResult.Labels[7] = createobject("EMPTY")
		addproperty(loResult.Labels[7],"block",1)
		addproperty(loResult.Labels[7],"display","image")
		addproperty(loResult.Labels[7],"tooltip","")
		addproperty(loResult.Labels[7],"fieldname",'signature')
		addproperty(loResult.Labels[7],"length",0)
		addproperty(loResult.Labels[7],"inputtype",'image')
		addproperty(loResult.Labels[7],"newline",.T.)
		addproperty(loResult.Labels[7],"labelwidth",3)
		addproperty(loResult.Labels[7],"fieldwidth",6)
		addproperty(loResult.Labels[7],"fieldheight",5)
	endif

	*--- Grid search
	if !empty(cVar)
		addproperty(loResult,"Data[1]",NULL)
		
		if cVar = "*"
			select code AS id, code, land, landcode from landcode where !empty(code) order by land into cursor result
		else
			cVar = upper(cVar)+"%"
			select code AS id, code, land, landcode from landcode where code like cVar order by land into cursor result
		endif		
		select result
		if !eof()
			*--- Add items array
			dimension loResult.Data[reccount()]

			*--- Fill array with records as objects
			scan
				scatter name loResult.Data[recno()]
			endscan
		endif	
	endif

	if Request.ID # "grid"
		SendData(@loResult)
	endif
case Request.Method = "POST"
	*--- Insert
	loJSON.Parse(Request.Content,,@loData)

	try
		insert into landcode from name loData

		Request.ID = code
		SendData(@loResult)
	catch to oException
		addproperty(loResult,"error","Error: "+oException.Message)
	endtry
case Request.Method = "PUT"
	*--- Update
	loJSON.Parse(Request.Content,,@loData)

	try
		use landcode
		locate for code = Request.ID
		
		gather name loData memo

		SendData(@loResult)
	catch to oException
		addproperty(loResult,"error","Error: "+oException.Message)
	endtry
case Request.Method = "DELETE"
	*--- Delete
	loJSON.Parse(Request.Content,,@loData)

	try
		delete from landcode where code = Request.ID

		addproperty(loResult,"Data[1]",NULL)
	catch to oException
		recall
		
		addproperty(loResult,"error","Erro: "+oException.Message)
	endtry
endcase

*--- Generate JSON
Response.Content      = loJSON.Stringify(@loResult)
Response.Content_Type = "application/json; charset=utf8"

*--- Release System and JSON Parser object
release loJSON

*--- Release class
clear class json

**********************************************************************************
FUNCTION SendData
*****************
LPARAMETERS loData
	*--- Form data
	if !empty(Request.ID) and Request.ID > "0"
		addproperty(loData,"Data[1]",NULL)

		select code AS id, code, land, landcode, signature from landcode where code = Request.ID into cursor result
		
		select result
		if !eof()
			scatter name loData.Data[1] memo
		endif
	endif
ENDFUNC
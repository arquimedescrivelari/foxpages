LOCAL loJSON,loResult,loData

*--- Create JSON Parser
loJSON = newobject("JSON","json.prg")

*--- Result object
loResult = createobject("EMPTY")
addproperty(loResult,"file","postnrs")

cFields = strextract(Request.Query_String+"&",'fields',"&")
cVar = strconv(strextract(Request.Query_String+"&",'key=',"&"),11)
lHeaders = iif(strextract(Request.Query_String+"&",'headers=',"&")="1",.T.,.F.)
lLabels = iif(strextract(Request.Query_String+"&",'labels=',"&")="1",.T.,.F.)

do case
case Request.Method = "GET"
	if Request.ID = "grid" OR lHeaders
		*--- Search grid definition
		addproperty(loResult,"headers[2]")
		
		loResult.Headers[1] = createobject("EMPTY")
		addproperty(loResult.Headers[1],"title","Item number:")
		addproperty(loResult.Headers[1],"data","postnr")
		addproperty(loResult.Headers[1],"type","text")
		addproperty(loResult.Headers[1],"width","20%")
		loResult.Headers[2] = createobject("EMPTY")
		addproperty(loResult.Headers[2],"title","City / Town:")
		addproperty(loResult.Headers[2],"data","plaats")
		addproperty(loResult.Headers[2],"type","text")
		addproperty(loResult.Headers[2],"width","80%")
	endif

	*--- Form tabs fields definition
	if lLabels
		*--- Set properties to rename
		dimension loJSON.PropertyAlias[1,2]
		loJSON.PropertyAlias[1,1] = 'text_transform' && VFP Object name
		loJSON.PropertyAlias[1,2] = 'text-transform' && JSON Object name

		addproperty(loResult,"labels[3]")
		
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
		addproperty(loResult.Labels[2],"display","Item Number:")
		addproperty(loResult.Labels[2],"tooltip","Code postal code:")
		addproperty(loResult.Labels[2],"fieldname",'postnr')
		addproperty(loResult.Labels[2],"length",8)
		addproperty(loResult.Labels[2],"inputtype",'text')
		addproperty(loResult.Labels[2],"newline",.T.)
		addproperty(loResult.Labels[2],"labelwidth",3)
		addproperty(loResult.Labels[2],"fieldwidth",3)
		addproperty(loResult.Labels[2],"notempty",.T.)

		loResult.Labels[3] = createobject("EMPTY")
		addproperty(loResult.Labels[3],"block",1)
		addproperty(loResult.Labels[3],"display","City / Town:")
		addproperty(loResult.Labels[3],"tooltip","Place Name of the city or municipality.")
		addproperty(loResult.Labels[3],"fieldname",'plaats')
		addproperty(loResult.Labels[3],"length",30)
		addproperty(loResult.Labels[3],"inputtype",'text')
		addproperty(loResult.Labels[3],"newline",.T.)
		addproperty(loResult.Labels[3],"labelwidth",3)
		addproperty(loResult.Labels[3],"fieldwidth",9)
		addproperty(loResult.Labels[3],"notempty",.T.)
		addproperty(loResult.Labels[3],"pipe","uppercase")
		addproperty(loResult.Labels[3],"style",createobject("EMPTY"))
		addproperty(loResult.Labels[3].Style,"text_transform","uppercase")
	endif

	*--- Grid search
	if !empty(cVar)
		addproperty(loResult,"Data[1]",NULL)
		
		if empty(val(cVar))
			*--- Search by city
			cVar = upper(strconv(HTTP.URLDecode(cVar),11))+"%"
			select newpost AS id, postnr, plaats, newpost from postnrs where plaats like cVar order by postnr into cursor result
		else
			*--- Search by zip code
			select newpost AS id, postnr, plaats, newpost from postnrs where postnr = cVar order by postnr into cursor result
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
		insert into postnrs from name loData

		Request.ID = alltrim(str(newpost))
		SendData(@loResult)
	catch to oException
		addproperty(loResult,"error","Error: "+oException.Message)
	endtry
case Request.Method = "PUT"
	*--- Update
	loJSON.Parse(Request.Content,,@loData)

	try
		use postnrs
		locate for newpost = val(Request.ID)
		
		gather name loData memo

		SendData(@loResult)
	catch to oException
		addproperty(loResult,"error","Error: "+oException.Message)
	endtry
case Request.Method = "DELETE"
	*--- Delete
	loJSON.Parse(Request.Content,,@loData)

	try
		delete from postnrs where newpost = val(Request.ID)

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

		select newpost AS id, postnr, plaats, newpost from postnrs where newpost = val(Request.ID) order by postnr into cursor result
		
		select result
		if !eof()
			scatter name loData.Data[1]
		endif
	endif
ENDFUNC
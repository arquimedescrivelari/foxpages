#DEFINE TOKENTYPE_UNDEFINED	0
#DEFINE TOKENTYPE_OBJECT	1
#DEFINE TOKENTYPE_ARRAY		2
#DEFINE TOKENTYPE_KEY		3
#DEFINE TOKENTYPE_STRING	4
#DEFINE TOKENTYPE_LOGICAL	5
#DEFINE TOKENTYPE_NUMBER	6
#DEFINE TOKENTYPE_DATETIME	8
#DEFINE TOKENTYPE_DATE		9
#DEFINE TOKENTYPE_NULL		10
#DEFINE TOKENTYPE_CURSOR	11

DEFINE CLASS json AS custom
	*-- Specifies what should be used in VFP as Undefined. Chr(0) is the default.
	undefined = ""
	*-- Specifies the class to use when deserializing JSON objects. The Empty class is the default.
	defaultclass = "Empty"
	*-- Specifies the module to get the class from when deserializing JSON Objects.
	defaultmodule = ""
	*-- Determines the format to use when parsing dates: 1 = ISO 8601 (default), 2 = new Date(), 3 = MS JSON Date
	parsedatetype = 1
	usejsonfll = .T.
	trimstrings = .T.
	utf8strings = .T.
	*-- Dojo compatibility
	dojocompatible = .T.
	*-- JSON key to be used when identifying cursors.
	keyforcursors = "VFPData"
	*-- JSON key to be used when identifying collection items.
	keyforitems = "items"
	*-- If .T. then the class and classlibrary keys/properties will be taken into consideration when parsing an object. If .F. then the defaults are used.
	parserespectclass = .F.
	*-- Target year last time GetTimezoneOffset was called.
	PROTECTED _tzyear
	_tzyear = .NULL.
	*-- Between year GetTimezoneOffset.
	PROTECTED _tzbetween
	_tzbetween = .NULL.
	*-- Start datetime for daylight saving last time GetTimezoneOffset was called.
	PROTECTED _tzdaylightstart
	_tzdaylightstart = .NULL.
	*-- Start datetime of standard last time GetTimezoneOffset was called.
	PROTECTED _tzstandardstart
	_tzstandardstart = .NULL.
	*-- Setting for tlUTCDatetime parameter last time GetTimezoneOffset was called.
	PROTECTED _tzutc
	_tzutc = .F.
	*-- Standard offset last time GetTimezoneInformation was called.
	PROTECTED _tzoffset
	_tzoffset = .NULL.
	*-- Daylight saving offset last time GetTimezoneInformation was called.
	PROTECTED _tzdloffset
	_tzdloffset = .NULL.
	Name = "json"

	*-- If .T. then all datetimes will be serialized to UTC equivalents and deserialized as UTC. If .F. then all datetimes will be conversely treated as Local datetimes.
	useutcdatetime = .F.
	PROTECTED name
	PROTECTED classlibrary
	PROTECTED addobject
	PROTECTED addproperty
	PROTECTED baseclass
	PROTECTED class
	PROTECTED cloneobject
	PROTECTED comment
	PROTECTED controlcount
	PROTECTED controls
	PROTECTED destroy
	PROTECTED error
	PROTECTED height
	PROTECTED helpcontextid
	PROTECTED newobject
	PROTECTED objects
	PROTECTED parent
	PROTECTED parentclass
	PROTECTED picture
	PROTECTED readexpression
	PROTECTED readmethod
	PROTECTED removeobject
	PROTECTED resettodefault
	PROTECTED saveasclass
	PROTECTED showwhatsthis
	PROTECTED tag
	PROTECTED whatsthishelpid
	PROTECTED width
	PROTECTED writeexpression
	PROTECTED writemethod


	PROCEDURE stringify
		LPARAMETERS tvValue, tvReplacer, tvSpace, tnLevel, tcKey

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Serialize VFP objects, values, arrays and cursors to JSON
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!* 	tvValue: (required)
		*!*			Either an instance of a VFP object/value/array or an Alias that will be stringified.
		*!*			Arrays must be sent in byref... JSON.Stringify(@MyArray)... otherwise only the first
		*!*			element of the array will be stringified
		*!* 	tvReplacer: (optional)
		*!*			The optional tvReplacer parameter is either a string specifying a Function/Object.Method,
		*!*			a byref Array or a string containing a comma-delimited list of keys.
		*!*			If cFunction/cMethod is sent in it will be used via Evaluate. It is sent the parent object
		*!*			and each of the member keys and value pairs. Evaluate(m.tcReviver(parent, membername, value)'s
		*!*			return value is then serialized instead of the original object.
		*!*			If the return value equals This.Undefined, then the object is not serialized.
		*!*			If Array/CSV is sent in then it contains a list of keys (member names) that should be serialized.
		*!*			All other keys (members) will be ignored.
		*!* 	tvSpace: (optional)
		*!*			A string to be used with line-breaks to indent the JSON produced, or it can be numeric specifying
		*!*			the number of spaces to use for indention. It simply makes the JSON easier to read by beautifying it.
		*!*		tnLevel: (internal-use)
		*!*			Tracks the hierarchy levels used for proper indention of JSON when tvSpace is sent in.
		*!*		tcKey: (internal-use)
		*!*			Allows the keys (member names) to be sent in when stringifying key/value pairs.
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		String - JSON representation of tvValue sent in
		*********************************************************************

		LOCAL lcTypeOfValue, lcReturnJSON, lvValue, lcIndent, lcKey
		LOCAL lcPointSettingWas, lcSeparatorSettingWas

		m.lcReturnJSON = THIS.Undefined && default considered to be undefined

		IF VARTYPE(m.tnLevel, .F.) != "N"
			m.tnLevel = 0
		ENDIF

		IF m.tnLevel > 58 && Avoid nesting too deep error
			RETURN (m.lcReturnJSON)
		ENDIF

		IF VARTYPE(m.tcKey) = "C"
			m.lcKey = ["] + THIS.serializekey(m.tcKey) + [": ]
		ELSE
			m.lcKey = ""
		ENDIF

		m.lcTypeOfValue = TYPE("m.tvValue", 1)
		IF m.lcTypeOfValue != "A" && if it's not an array then let's get the Type
			m.lcTypeOfValue = VARTYPE(m.tvValue, .F.)
			IF m.lcTypeOfValue = "O"
				*!* ToJSON() method shouldn't serialize, simply pass back a value or undefined
				IF PEMSTATUS(m.tvValue, "tojson", 5) && if object has a ToJSON() method then use it to get value to serialize
					m.lvValue = EVALUATE("m.tvValue.tojson()")
				ELSE
					m.lvValue = m.tvValue
				ENDIF
			ELSE
				m.lvValue = m.tvValue
			ENDIF
		ENDIF

		*!* save settings - handle localization
		m.lcPointSettingWas = SET("Point")
		m.lcSeparatorSettingWas = SET("Separator")
		IF m.lcPointSettingWas != "."
			SET POINT TO "."
		ENDIF
		IF m.lcSeparatorSettingWas != ","
			SET SEPARATOR TO ","
		ENDIF

		DO CASE
		CASE m.lcTypeOfValue = "A" && Array
			m.lcReturnJSON = THIS.SerializeArray(@m.tvValue, @m.tvReplacer, tvSpace, tnLevel)
		CASE m.lcTypeOfValue = "C" && Character, Memo, Varchar, Varchar (Binary)
			*!* are we on the first pass (cursor serialization would never be nested in an array/object) and is it an alias?
			IF m.tnLevel = 0 AND USED(m.lvValue)
				m.lcReturnJSON = THIS.Serializecursor(m.lvValue, @m.tvReplacer, m.tvSpace, m.tnLevel)
			ELSE && then it must be a string
				IF THIS.TrimStrings
					m.lcReturnJSON = THIS.SerializeString(ALLTRIM(m.lvValue))
				ELSE
					m.lcReturnJSON = THIS.SerializeString(m.lvValue)
				ENDIF
			ENDIF
		CASE m.lcTypeOfValue = "D" && Date
			m.lcReturnJSON = THIS.SerializeDate(m.lvValue)
		CASE m.lcTypeOfValue = "G" && General
			m.lcReturnJSON = THIS.Undefined
		CASE m.lcTypeOfValue = "L" && Logical
			m.lcReturnJSON = THIS.SerializeLogical(m.lvValue)
		CASE INLIST(m.lcTypeOfValue, "N", "Y") && Numeric, Float, Double, Integer, or Currency
			m.lcReturnJSON = THIS.SerializeNumber(m.lvValue)
		CASE m.lcTypeOfValue = "O" && Object
			m.lcReturnJSON = THIS.SerializeObject(@m.lvValue, @m.tvReplacer, tvSpace, tnLevel)
		CASE m.lcTypeOfValue = "Q" && Blob, Varbinary
			m.lcReturnJSON = THIS.Undefined
		CASE m.lcTypeOfValue = "T" && DateTime
			m.lcReturnJSON = THIS.SerializeDatetime(m.lvValue)
		CASE m.lcTypeOfValue = "U" && Unknown or variable does not exist
			m.lcReturnJSON = THIS.Undefined
		CASE m.lcTypeOfValue = "X" && Null
			m.lcReturnJSON = THIS.SerializeNull()
		OTHERWISE
			m.lcReturnJSON = THIS.Undefined
		ENDCASE

		*!* revert settings if applicable - handle localization
		IF m.lcPointSettingWas != "."
			SET POINT TO (m.lcPointSettingWas)
		ENDIF
		IF m.lcSeparatorSettingWas != ","
			SET SEPARATOR TO (m.lcSeparatorSettingWas)
		ENDIF

		IF !THIS.IsUndefined(m.lcReturnJSON)
			m.lcIndent = THIS.GetIndentChars(m.tvSpace, m.tnLevel)
			IF m.tnLevel != 0
				m.lcReturnJSON = m.lcIndent + m.lcKey + m.lcReturnJSON
			ENDIF
		ENDIF

		RETURN (m.lcReturnJSON)

		*********************************************************************
		*!*	ADDITIONAL NOTES AND COMMENTS
		*********************************************************************
		*!* Online JSON Validator
		*!*	http://www.jsonlint.com/
		*********************************************************************
	ENDPROC

	PROCEDURE parse
		LPARAMETERS tcJSONString, tcReviver, tvValue, ;
			tnTokenType, tnTokenStart, tnTokenLength, tcTokenText

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Parse JSON to create/fill a VFP object, value, array or cursor
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!* 	tcJSONString: (required)
		*!*			A string of valid JSON that will be parsed to return an instance of a VFP object, value, array or cursor
		*!*			If you are expecting an array back, then you must send an Array in byref to the tvValue parameter.
		*!*			The array will be automatically dimensioned appropriately
		*!* 	tcReviver: (optional)
		*!*			A string containing a "Function" or "Object.Method" that will be
		*!*			evaluated via VFP's Evaluate() function.
		*!*			It is sent the parent object and each of the member keys and value pairs, such as...
		*!*			Evaluate(m.tcReviver(parent, membername, value). Its return value is then used in lieu of the member.
		*!*			If its return value equals This.Undefined, then the member is ignored, thus allowing you to filter what is parsed.
		*!* 	tvValue: (optional)
		*!*			An instance of a VFP object\value\array or an Alias for the cursor to be filled or created.
		*!*			If you are parsing a cursor, but do not send in an alias then a unique alias name will
		*!*			be generated for you and used as the return value of the parse function.
		*!*			As noted above, if you are dealing with an array, then you must send it in byref.
		*!*		tnTokenType: (internal-use)
		*!*			Used internally to track the type of token being returned from This.GetNextToken().
		*!*			Interested parties can see the list of valid token types in json.h (I wish VFP had enums)
		*!*		tnTokenStart: (internal-use)
		*!*			Used internally to track the start position of the TokenText within the JSON
		*!*			of the token being returned by This.GetNextToken()
		*!*		tnTokenLength: (internal-use)
		*!*			Used internally to track the length of the TokenText of the token being returned by This.GetNextToken()
		*!*		tcTokenText: (internal-use)
		*!*			Used internally to track the TokenText generated by This.GetNextToken() when This.Parse is called recursively.
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		Any - Depends on parameters and settings
		*********************************************************************

		LOCAL lvReturnVariableOrAlias, lnStringLength, lnStartPosition

		m.tnTokenType = TOKENTYPE_UNDEFINED
		m.tnTokenStart = 0
		m.tnTokenLength = 0
		m.tcTokenText = THIS.Undefined
		m.lvReturnVariableOrAlias = THIS.Undefined

		IF VARTYPE(m.tcJSONString, .F.) = "C"
			IF !EMPTY(m.tcJSONString)
				m.lnStringLength = LEN(m.tcJSONString)
				m.lnStartPosition = 1
				m.tcTokenText = THIS.GetNextToken(@m.tcJSONString, m.lnStringLength, m.lnStartPosition, ;
					@m.tnTokenType, @m.tnTokenStart, @m.tnTokenLength)
				DO CASE
				CASE m.tnTokenType = TOKENTYPE_OBJECT
					m.lvReturnVariableOrAlias = THIS.DeserializeObject(m.tcTokenText, @m.tcReviver, @m.tvValue)
				CASE m.tnTokenType = TOKENTYPE_ARRAY
					m.lvReturnVariableOrAlias = THIS.DeserializeArray(m.tcTokenText, @m.tcReviver, @m.tvValue)
				CASE m.tnTokenType = TOKENTYPE_KEY
					m.lvReturnVariableOrAlias = THIS.DeserializeKey(m.tcTokenText)
				CASE m.tnTokenType = TOKENTYPE_DATETIME
					m.lvReturnVariableOrAlias = THIS.DeserializeDatetime(m.tcTokenText)
				CASE m.tnTokenType = TOKENTYPE_STRING
					m.lvReturnVariableOrAlias = THIS.DeserializeString(m.tcTokenText)
				CASE m.tnTokenType = TOKENTYPE_LOGICAL
					m.lvReturnVariableOrAlias = THIS.DeserializeLogical(m.tcTokenText)
				CASE m.tnTokenType = TOKENTYPE_NUMBER
					m.lvReturnVariableOrAlias = THIS.DeserializeNumber(m.tcTokenText)
				CASE m.tnTokenType = TOKENTYPE_DATE
					m.lvReturnVariableOrAlias = THIS.DeserializeDate(m.tcTokenText)
				CASE m.tnTokenType = TOKENTYPE_NULL
					m.lvReturnVariableOrAlias = THIS.DeserializeNull(m.tcTokenText)
				CASE m.tnTokenType = TOKENTYPE_CURSOR
					m.lnStartPosition = m.lnStartPosition + (AT("[", SUBSTR(m.tcJSONString, m.lnStartPosition),1) - 1)
					m.tcTokenText = THIS.GetNextToken(@m.tcJSONString, m.lnStringLength, m.lnStartPosition, ;
						@m.tnTokenType, @m.tnTokenStart, @m.tnTokenLength)
					m.lvReturnVariableOrAlias = THIS.DeserializeCursor(m.tcTokenText, @m.tcReviver, m.tvValue)
				OTHERWISE && TOKENTYPE_UNDEFINED
					m.lvReturnVariableOrAlias = THIS.Undefined
				ENDCASE
				IF m.tnTokenType != TOKENTYPE_ARRAY && arrays have to be byref
					m.tvValue = m.lvReturnVariableOrAlias
				ENDIF
			ENDIF
		ENDIF
		RETURN (m.lvReturnVariableOrAlias)
	ENDPROC


	PROTECTED PROCEDURE quote
		LPARAMETERS tcString

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Take a VFP string, escape it and surround it with quotes
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tcString
		*!*			A VFP string that needs to be escaped and wrapped as part of serializing it to JSON string
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		String - escaped and quoted equivalent of the string sent in
		*********************************************************************

		LOCAL lcReturnWrappedInQuotes

		if THIS.utf8strings
			m.lcReturnWrappedInQuotes = strtran(strtran(strtran(strconv(m.tcString,9),"\","\\"),'"','\"'),chr(13)+chr(10),"\n")
		else
			m.lcReturnWrappedInQuotes = THIS.EscapeChars(m.tcString)
		endif
		m.lcReturnWrappedInQuotes = ["] + m.lcReturnWrappedInQuotes + ["]

		RETURN (m.lcReturnWrappedInQuotes)
	ENDPROC


	PROCEDURE isundefined
		LPARAMETERS tvValueToCheck

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Check whether a value matches the setting for This.Undefined
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tvValueToCheck
		*!*			The value to check when determining whether it is Undefined
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		Logical - indicating whether the value sent in is considered Undefined
		*********************************************************************

		LOCAL llReturnUndefined

		m.llReturnUndefined = VARTYPE(m.tvValueToCheck, .F.) = "C"
		m.llReturnUndefined = m.llReturnUndefined AND (m.tvValueToCheck == THIS.Undefined)

		RETURN (m.llReturnUndefined)
	ENDPROC


	PROTECTED PROCEDURE escapechars
		LPARAMETERS tcStringToEscape

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Escape chars according to RFC4627 section 2.5
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tcStringToEscape
		*!*			The string to be escaped a valid JSON string
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		String - escaped equivalent of the string sent in
		*********************************************************************

		LOCAL lcReturnEscapedString, lnCharCounter, lnAsc
		m.lcReturnEscapedString = ""
		IF This.UseJSONFLL && using FLL to escape chars (best performance)
			IF ATC("JSON.FLL", SET("Library")) = 0
				SET LIBRARY TO JSON.FLL ADDITIVE
			ENDIF
			m.lcReturnEscapedString = JSONEscapeStr(m.tcStringToEscape)
			*********************************************************************
			*!* NOTE: 
			*********************************************************************
			*!* If you want to escape all chars with ASCII values < 32 and > 126
			*!* you can use the following line of code instead of the above:
			*!*
			*!* m.lcReturnEscapedString = JSONEncodeStr(m.tcStringToEscape)
			*!*
			*********************************************************************
		ELSE && Use VFP to escape chars (no dependency on FLL)
			FOR m.lnCharCounter = 1 TO LEN(m.tcStringToEscape)
				m.lcCurrentChar = SUBSTR(m.tcStringToEscape, m.lnCharCounter, 1)
				m.lnAsc = ASC(m.lcCurrentChar)
				IF (m.lnAsc < 32 ;
						OR m.lnAsc > 255 ;
						OR INLIST(m.lnAsc, 34, 92, 127, 129, 141, 143, 144, 157, 173)) && needs to be escaped
					IF m.lnAsc > 92 OR !INLIST(m.lnAsc, 8, 9, 10, 12, 13, 34, 92)
						m.lcCurrentChar = "\u" + RIGHT(TRANSFORM(m.lnAsc, "@0"), 4)
					ELSE
						DO CASE
						CASE m.lnAsc = 8
							m.lcCurrentChar = "\b"
						CASE m.lnAsc = 9
							m.lcCurrentChar = "\t"
						CASE m.lnAsc = 10
							m.lcCurrentChar = "\n"
						CASE m.lnAsc = 12
							m.lcCurrentChar = "\f"
						CASE m.lnAsc = 13
							m.lcCurrentChar = "\r"
						CASE m.lnAsc = 34
							m.lcCurrentChar = [\"]
						CASE m.lnAsc = 92
							m.lcCurrentChar = "\\"
						ENDCASE
					ENDIF
				ENDIF
				m.lcReturnEscapedString = m.lcReturnEscapedString + m.lcCurrentChar
			ENDFOR
		ENDIF
		RETURN (m.lcReturnEscapedString)

		*********************************************************************
		*!*	ADDITIONAL NOTES AND COMMENTS
		*********************************************************************
		*!* Below are the results of a test I ran via JSON.stringify from json2.js.
		*!* It shows which ASCII chars are escaped and the format used.
		*!* ASC#: Return
		*!* The format is based on RFC4627 and...
		*!* addition information regarding RFC4627 can be found...
		*!* http://www.ietf.org/rfc/rfc4627.txt?number=4627
		*********************************************************************
		*!* 0: "\u0001"
		*!*	1: "\u0001"
		*!*	2: "\u0002"
		*!*	3: "\u0003"
		*!*	4: "\u0004"
		*!*	5: "\u0005"
		*!*	6: "\u0006"
		*!*	7: "\u0007"
		*!*	8: "\b"
		*!*	9: "\t"
		*!*	10: "\n"
		*!*	11: "\u000b"
		*!*	12: "\f"
		*!*	13: "\r"
		*!*	14: "\u000e"
		*!*	15: "\u000f"
		*!*	16: "\u0010"
		*!*	17: "\u0011"
		*!*	18: "\u0012"
		*!*	19: "\u0013"
		*!*	20: "\u0014"
		*!*	21: "\u0015"
		*!*	22: "\u0016"
		*!*	23: "\u0017"
		*!*	24: "\u0018"
		*!*	25: "\u0019"
		*!*	26: "\u001a"
		*!*	27: "\u001b"
		*!*	28: "\u001c"
		*!*	29: "\u001d"
		*!*	30: "\u001e"
		*!*	31: "\u001f"
		*!*	32: " "
		*!*	33: "!"
		*!*	34: "\""
		*!*	35: "#"
		*!*	36: "$"
		*!*	37: "%"
		*!*	38: "&"
		*!*	39: "&"
		*!*	40: "("
		*!*	41: ")"
		*!*	42: "*"
		*!*	43: "+"
		*!*	44: ","
		*!*	45: "-"
		*!*	46: "."
		*!*	47: "/"
		*!*	48: "0"
		*!*	49: "1"
		*!*	50: "2"
		*!*	51: "3"
		*!*	52: "4"
		*!*	53: "5"
		*!*	54: "6"
		*!*	55: "7"
		*!*	56: "8"
		*!*	57: "9"
		*!*	58: ":"
		*!*	59: ";"
		*!*	60: "<"
		*!*	61: "="
		*!*	62: ">"
		*!*	63: "?"
		*!*	64: "@"
		*!*	65: "A"
		*!*	66: "B"
		*!*	67: "C"
		*!*	68: "D"
		*!*	69: "E"
		*!*	70: "F"
		*!*	71: "G"
		*!*	72: "H"
		*!*	73: "I"
		*!*	74: "J"
		*!*	75: "K"
		*!*	76: "L"
		*!*	77: "M"
		*!*	78: "N"
		*!*	79: "O"
		*!*	80: "P"
		*!*	81: "Q"
		*!*	82: "R"
		*!*	83: "S"
		*!*	84: "T"
		*!*	85: "U"
		*!*	86: "V"
		*!*	87: "W"
		*!*	88: "X"
		*!*	89: "Y"
		*!*	90: "Z"
		*!*	91: "["
		*!*	92: "\\"
		*!*	93: "]"
		*!*	94: "^"
		*!*	95: "_"
		*!*	96: "`"
		*!*	97: "a"
		*!*	98: "b"
		*!*	99: "c"
		*!*	100: "d"
		*!*	101: "e"
		*!*	102: "f"
		*!*	103: "g"
		*!*	104: "h"
		*!*	105: "i"
		*!*	106: "j"
		*!*	107: "k"
		*!*	108: "l"
		*!*	109: "m"
		*!*	110: "n"
		*!*	111: "o"
		*!*	112: "p"
		*!*	113: "q"
		*!*	114: "r"
		*!*	115: "s"
		*!*	116: "t"
		*!*	117: "u"
		*!*	118: "v"
		*!*	119: "w"
		*!*	120: "x"
		*!*	121: "y"
		*!*	122: "z"
		*!*	123: "{"
		*!*	124: "|"
		*!*	125: "}"
		*!*	126: "~"
		*!*	127: "\u007f"
		*!*	128: "€"
		*!*	129: "\u0081"
		*!*	130: "‚"
		*!*	131: "ƒ"
		*!*	132: "„"
		*!*	133: "…"
		*!*	134: "†"
		*!*	135: "‡"
		*!*	136: "ˆ"
		*!*	137: "‰"
		*!*	138: "Š"
		*!*	139: "‹"
		*!*	140: "Œ"
		*!*	141: "\u008d"
		*!*	142: "Ž"
		*!*	143: "\u008f"
		*!*	144: "\u0090"
		*!*	145: "‘"
		*!*	146: "’"
		*!*	147: "“"
		*!*	148: "”"
		*!*	149: "•"
		*!*	150: "–"
		*!*	151: "—"
		*!*	152: "˜"
		*!*	153: "™"
		*!*	154: "š"
		*!*	155: "›"
		*!*	156: "œ"
		*!*	157: "\u009d"
		*!*	158: "ž"
		*!*	159: "Ÿ"
		*!*	160: " "
		*!*	161: "¡"
		*!*	162: "¢"
		*!*	163: "£"
		*!*	164: "¤"
		*!*	165: "¥"
		*!*	166: "¦"
		*!*	167: "§"
		*!*	168: "¨"
		*!*	169: "©"
		*!*	170: "ª"
		*!*	171: "«"
		*!*	172: "¬"
		*!*	173: "\u00ad"
		*!*	174: "®"
		*!*	175: "¯"
		*!*	176: "°"
		*!*	177: "±"
		*!*	178: "²"
		*!*	179: "³"
		*!*	180: "´"
		*!*	181: "µ"
		*!*	182: "¶"
		*!*	183: "·"
		*!*	184: "¸"
		*!*	185: "¹"
		*!*	186: "º"
		*!*	187: "»"
		*!*	188: "¼"
		*!*	189: "½"
		*!*	190: "¾"
		*!*	191: "¿"
		*!*	192: "À"
		*!*	193: "Á"
		*!*	194: "Â"
		*!*	195: "Ã"
		*!*	196: "Ä"
		*!*	197: "Å"
		*!*	198: "Æ"
		*!*	199: "Ç"
		*!*	200: "È"
		*!*	201: "É"
		*!*	202: "Ê"
		*!*	203: "Ë"
		*!*	204: "Ì"
		*!*	205: "Í"
		*!*	206: "Î"
		*!*	207: "Ï"
		*!*	208: "Ð"
		*!*	209: "Ñ"
		*!*	210: "Ò"
		*!*	211: "Ó"
		*!*	212: "Ô"
		*!*	213: "Õ"
		*!*	214: "Ö"
		*!*	215: "×"
		*!*	216: "Ø"
		*!*	217: "Ù"
		*!*	218: "Ú"
		*!*	219: "Û"
		*!*	220: "Ü"
		*!*	221: "Ý"
		*!*	222: "Þ"
		*!*	223: "ß"
		*!*	224: "à"
		*!*	225: "á"
		*!*	226: "â"
		*!*	227: "ã"
		*!*	228: "ä"
		*!*	229: "å"
		*!*	230: "æ"
		*!*	231: "ç"
		*!*	232: "è"
		*!*	233: "é"
		*!*	234: "ê"
		*!*	235: "ë"
		*!*	236: "ì"
		*!*	237: "í"
		*!*	238: "î"
		*!*	239: "ï"
		*!*	240: "ð"
		*!*	241: "ñ"
		*!*	242: "ò"
		*!*	243: "ó"
		*!*	244: "ô"
		*!*	245: "õ"
		*!*	246: "ö"
		*!*	247: "÷"
		*!*	248: "ø"
		*!*	249: "ù"
		*!*	250: "ú"
		*!*	251: "û"
		*!*	252: "ü"
		*!*	253: "ý"
		*!*	254: "þ"
		*!*	255: "ÿ"
		*********************************************************************
	ENDPROC


	PROTECTED PROCEDURE unescapechars
		LPARAMETERS tcJSONStringToUnescape

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Unescape a JSON string according to RFC4627 section 2.5
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tcJSONStringToUnescape
		*!*			A JSON string that is to be unescaped
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		String - escaped equivalent of the JSON string sent in
		*********************************************************************

		LOCAL lcReturnUnescapedString, lnCharCounter, lnStringLength
		LOCAL lnEscapePosition, lnEscapeOccurrence, lnPositionAfterPreviousEscape
		LOCAL lnPositionDifference

		m.lcReturnUnescapedString = ""

		IF This.UseJSONFLL && using FLL to unescape chars (best performance)
			IF ATC("JSON.FLL", SET("Library")) = 0
				SET LIBRARY TO JSON.FLL ADDITIVE
			ENDIF
			m.lcReturnUnescapedString = JSONUnescapeStr(m.tcJSONStringToUnescape)
		ELSE && Use VFP to unescape chars (no dependency on FLL)
			m.lnEscapePosition = AT("\", m.tcJSONStringToUnescape)
			IF m.lnEscapePosition > 0 && do any escaped chars exist?
				m.lcReturnUnescapedString = LEFT(m.tcJSONStringToUnescape, m.lnEscapePosition - 1) && add everything before the escape to the return string
				m.lnEscapeOccurrence = 1
				DO WHILE m.lnEscapePosition > 0 && walk all the escape characters in the string
					m.lcCurrentChar = SUBSTR(m.tcJSONStringToUnescape, m.lnEscapePosition + 1, 1)
					m.lnPositionAfterPreviousEscape = m.lnEscapePosition + 2
					DO CASE
					CASE m.lcCurrentChar = "b" && ASCII 8
						m.lcCurrentChar = CHR(8)
					CASE m.lcCurrentChar = "t" && ASCII 9
						m.lcCurrentChar = CHR(9)
					CASE m.lcCurrentChar = "n" && ASCII 10
						m.lcCurrentChar = CHR(10)
					CASE m.lcCurrentChar = "f" && ASCII 12
						m.lcCurrentChar = CHR(12)
					CASE m.lcCurrentChar = "r" && ASCII 13
						m.lcCurrentChar = CHR(13)
					CASE m.lcCurrentChar = ["] && ASCII 34
						m.lcCurrentChar = CHR(34)
					CASE m.lcCurrentChar = "\" && ASCII 92
						m.lnEscapeOccurrence = m.lnEscapeOccurrence + 1
					CASE m.lcCurrentChar = "u" && u00XX
						m.lcCurrentChar = CHR(EVALUATE("0x" + SUBSTR(m.tcJSONStringToUnescape, m.lnEscapePosition + 2, 4)))
						m.lnPositionAfterPreviousEscape = m.lnPositionAfterPreviousEscape + 4
					ENDCASE
					m.lcReturnUnescapedString = m.lcReturnUnescapedString + m.lcCurrentChar
					m.lnEscapeOccurrence = m.lnEscapeOccurrence + 1
					m.lnEscapePosition = AT("\", m.tcJSONStringToUnescape, m.lnEscapeOccurrence)
					IF m.lnEscapePosition > 0
						m.lnPositionDifference = ((m.lnEscapePosition - m.lnPositionAfterPreviousEscape))
						m.lcReturnUnescapedString = m.lcReturnUnescapedString + SUBSTR(m.tcJSONStringToUnescape, m.lnPositionAfterPreviousEscape, m.lnPositionDifference)
					ELSE
						m.lcReturnUnescapedString = m.lcReturnUnescapedString + SUBSTR(m.tcJSONStringToUnescape, m.lnPositionAfterPreviousEscape)
					ENDIF
				ENDDO
			ELSE
				m.lcReturnUnescapedString = m.tcJSONStringToUnescape
			ENDIF
		ENDIF
		RETURN (m.lcReturnUnescapedString)

		*********************************************************************
		*!*	ADDITIONAL NOTES AND COMMENTS
		*********************************************************************
		*!* See This.Escape() for additional information regarding JSON char escaping
		*********************************************************************
	ENDPROC


	PROTECTED PROCEDURE serializearray
		LPARAMETERS taArray, tvReplacer, tvSpace, tnLevel

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Serialize a VFP array to JSON
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		taArray
		*!*			An array that is sent in byref to be serialized to JSON
		*!*		tvReplacer
		*!*			See parameter notes in This.Stringify()
		*!*		tvSpace
		*!*			See parameter notes in This.Stringify()
		*!*		tnLevel
		*!*			Current nesting level of the array being serialized
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		String - JSON array
		*********************************************************************

		LOCAL lcReturnJSONArray
		LOCAL lcMultiBegin, lcMultiEnd, lnMultiLevel
		LOCAL lnRows, lnColumns, lnRowCounter, lnColumnCounter, llIsMultiDimension
		LOCAL lcColumn, lcAllColumns, lcRow, lcArrayIndent, lcMultiIndent

		m.lcReturnJSONArray = ""
		m.lcArrayIndent = THIS.GetIndentChars(m.tvSpace, m.tnLevel)
		m.lnRows = ALEN(m.taArray, 1)

		m.lnColumns = ALEN(m.taArray, 2)

		IF m.lnColumns > 1 && Multi-dimensional array
			m.lnMultiLevel = m.tnLevel + 1
			m.lcMultiIndent = THIS.GetIndentChars(m.tvSpace, m.lnMultiLevel)
			m.lcMultiBegin = m.lcMultiIndent + "["
			m.lcMultiEnd = m.lcMultiIndent + "]"
			m.llIsMultiDimension = .T.
		ELSE && flat array
			m.lnMultiLevel = 0
			STORE "" TO m.lcMultiBegin, m.lcMultiEnd
			m.llIsMultiDimension = .F.
		ENDIF

		IF 	m.llIsMultiDimension
			FOR m.lnRowCounter = 1 TO m.lnRows
				m.lcRow = ""
				m.lcAllColumns = ""
				FOR m.lnColumnCounter = 1 TO m.lnColumns
					m.lcColumn = THIS.stringify(m.taArray(m.lnRowCounter, m.lnColumnCounter), @m.tvReplacer, m.tvSpace, m.lnMultiLevel + 1)
					IF !THIS.Isundefined(m.lcColumn)
						m.lcAllColumns = m.lcAllColumns + IIF(!EMPTY(m.lcAllColumns), ",", "") + m.lcColumn
						*!* m.lcRow = m.lcRow + m.lcColumn
					ELSE && discard entire row to handle multi-dimensional correctly
						m.lcRow = This.Undefined
						EXIT
					ENDIF
					m.lcRow = m.lcMultiBegin + m.lcAllColumns + m.lcMultiEnd
				ENDFOR
				IF !This.IsUndefined(m.lcRow)
					m.lcReturnJSONArray = m.lcReturnJSONArray + IIF(!EMPTY(m.lcReturnJSONArray), ",", "") + m.lcRow
				ENDIF
			ENDFOR
		ELSE
			IF !ISNULL(m.taArray)
				FOR m.lnRowCounter = 1 TO m.lnRows
					m.lcRow = THIS.stringify(m.taArray(m.lnRowCounter), @m.tvReplacer, m.tvSpace, m.lnMultiLevel + 1)
					IF THIS.Isundefined(m.lcRow)
						loop
					ENDIF
					m.lcReturnJSONArray = m.lcReturnJSONArray + IIF(!EMPTY(m.lcReturnJSONArray), ",", "") + m.lcRow
				ENDFOR
			ENDIF
		ENDIF
		m.lcReturnJSONArray = "[" + m.lcReturnJSONArray + m.lcArrayIndent + "]"

		RETURN (m.lcReturnJSONArray)
	ENDPROC


	PROTECTED PROCEDURE serializeobject
		LPARAMETERS toObject, tvReplacer, tvSpace, tnLevel

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Serialize a VFP object instance to JSON
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		toObject
		*!*			An instance of a VFP object that is to be serialized to a JSON object
		*!*		tvReplacer
		*!*			See parameter notes in This.Stringify()
		*!*		tvSpace
		*!*			See parameter notes in This.Stringify()
		*!*		tnLevel
		*!*			Current nesting level of the array being serialized
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		String - JSON object
		*********************************************************************

		LOCAL lcReturnJSONObject
		LOCAL lcReplacerType, lcKey, lcObjectIndent
		LOCAL lcMember, lcAllMembers, lcPropertyFullname
		LOCAL lnPEMSCounter, lnTotalPEMs, lcCommaDelimitedList
		LOCAL loItem, lcItem, lcItems, lnTotalItems, lnItemCounter
		LOCAL ARRAY aPEMS(1,2)

		m.lcReturnJSONObject = ""
		m.lcObjectIndent = THIS.GetIndentChars(m.tvSpace, m.tnLevel)
		m.lcTypeOfReplacer = TYPE("m.tvReplacer", 1)

		IF m.lcTypeOfReplacer != "A"
			m.lcTypeOfReplacer = VARTYPE(m.tvReplacer, .F.)
			IF m.lcTypeOfReplacer = "C"
				IF AT(",", m.tvReplacer) != 0 && developer sent in a comma delimited list, so convert to an array
					m.lcTypeOfReplacer = "A"
					m.lcCommaDelimitedList = m.tvReplacer
					DIMENSION m.tvReplacer[1]
					=ALINES(m.tvReplacer, m.lcCommaDelimitedList, 5, ",")
					RELEASE m.lcCommaDelimitedList
				ENDIF
			ENDIF
		ENDIF

		m.lcAllMembers = ""
		m.lnTotalPEMs = AMEMBERS(aPEMS, m.toObject, 1)

		FOR m.lnPEMSCounter = 1 TO m.lnTotalPEMs
			IF aPEMS(m.lnPEMSCounter,2) = "Property"
				m.lcKey = LOWER(aPEMS(m.lnPEMSCounter,1))
				IF m.lcTypeOfReplacer = "A" && only check the replacer if it's an array of key names
					IF ASCAN(m.tvReplacer, m.lcKey, -1, -1, 1, 1) = 0 && if the key doesn't exist in the replacer ignore
						LOOP
					ENDIF
				ENDIF
				m.lcPropertyFullname = "m.toObject." + m.lcKey
				LOCAL lvMemberValue
				IF TYPE(m.lcPropertyFullname) != "U" && members like ACTIVECONTROL may not be an object
					IF TYPE(m.lcPropertyFullname, 1) != "A"
						m.lvMemberValue = GETPEM(m.toObject, m.lcKey)
					ELSE
						RELEASE lvMemberValue
						=ACOPY(&lcPropertyFullname, lvMemberValue)
					ENDIF
				ELSE
					m.lvMemberValue = NULL
				ENDIF
				IF m.lcTypeOfReplacer = "C" && Replacer is a string representing a function/method to call
					m.lvMemberValue = &tvReplacer.(m.toObject, m.lvMemberValue, m.lcKey) && Parent, Member, Property Name
					IF THIS.IsUndefined(m.lvMemberValue) && consider it undefined and ignore
						LOOP
					ENDIF
				ENDIF
				m.lcMember = THIS.stringify(@m.lvMemberValue, @m.tvReplacer, m.tvSpace, m.tnLevel + 1, m.lcKey)
				IF !THIS.IsUndefined(m.lcMember)
					m.lcAllMembers = m.lcAllMembers + IIF(!EMPTY(m.lcAllMembers), ",", "")
					m.lcAllMembers = m.lcAllMembers + m.lcMember
				ENDIF
				RELEASE lvMemberValue
			ENDIF
		ENDFOR

		IF PEMSTATUS(m.toObject, "baseclass",5) AND LOWER(m.toObject.BASECLASS) == "collection"
			m.lnTotalItems = m.toObject.COUNT
			IF m.lnTotalItems > 0
				STORE "" TO m.lcItem, m.lcItems
				FOR m.lnItemCounter = 1 TO m.lnTotalItems
					m.loItem = m.toObject.Item(m.lnItemCounter)
					m.lcItem = THIS.stringify(@m.loItem, @m.tvReplacer, m.tvSpace, m.tnLevel + 2)
					IF !THIS.IsUndefined(m.lcItem)
						m.lcItems = m.lcItems + IIF(!EMPTY(m.lcItems),",","")
						m.lcItems = m.lcItems + m.lcItem
					ENDIF
				ENDFOR
				m.lcAllMembers = m.lcAllMembers + IIF(!EMPTY(m.lcAllMembers), ",", "") + THIS.GetIndentChars(m.tvSpace, m.tnLevel+1)
				m.lcAllMembers = m.lcAllMembers +["]+ THIS.KeyForItems + '": [' + m.lcItems + THIS.GetIndentChars(m.tvSpace, m.tnLevel+1) +"]"
			ENDIF
		ENDIF

		m.lcReturnJSONObject = [{] + m.lcAllMembers + m.lcObjectIndent + [}]

		RETURN (m.lcReturnJSONObject)
	ENDPROC


	PROTECTED PROCEDURE serializestring
		LPARAMETERS tcString

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Serialize a VFP string to JSON
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tcString
		*!*			The VFP string value to be serialized
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		String - JSON string
		*********************************************************************

		LOCAL lcReturnJSONString
		m.lcReturnJSONString = THIS.Quote(m.tcString)

		RETURN (m.lcReturnJSONString)
	ENDPROC


	PROTECTED PROCEDURE serializenumber
		LPARAMETERS tnNumber

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Serialize a VFP numeric or integer value to JSON
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tnNumber
		*!*			The VFP numeric/integer value to be serialized
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		String - JSON number
		*********************************************************************

		LOCAL lcReturnJSONNumber

		m.lcReturnJSONNumber = TRANSFORM(m.tnNumber)

		RETURN (m.lcReturnJSONNumber)
	ENDPROC


	PROTECTED PROCEDURE serializenull
		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Serialize a VFP null to JSON
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		String - JSON null
		*********************************************************************

		LOCAL lcReturnJSONNull

		m.lcReturnJSONNull = "null"

		RETURN (m.lcReturnJSONNull)
	ENDPROC


	PROTECTED PROCEDURE serializedatetime
		LPARAMETERS ttDateTime

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Serialize a VFP datetime value to JSON
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		ttDateTime
		*!*			The VFP datetime value to be serialized
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		String - JSON datetime
		*********************************************************************

		*****************************************
		*!* ISO 8601
		*!* http://www.w3.org/TR/NOTE-datetime
		*****************************************
		LOCAL lcReturnJSONDateTime, lcISO8601Datetime, ltDatetime, lnOffsetSeconds, lnMilliSecondsSinceEpoch

		IF THIS.UseUTCDatetime
			m.lnOffsetSeconds = (THIS.GetTimeZoneOffset(m.ttDateTime) * 60)
			m.ltDatetime = m.ttDateTime + m.lnOffsetSeconds
		ELSE
			m.ltDatetime = m.ttDateTime
		ENDIF

		DO CASE
		CASE THIS.ParseDateType = 2 && new Date()
			m.lcReturnJSONDateTime = "new Date(" ;
				+ TRANSFORM(YEAR(m.ltDatetime)) + "," ;
				+ TRANSFORM(MONTH(m.ltDatetime)) + "," ;
				+ TRANSFORM(DAY(m.ltDatetime)) + "," ;
				+ TRANSFORM(HOUR(m.ltDatetime)) + "," ;
				+ TRANSFORM(MINUTE(m.ltDatetime)) + "," ;
				+ TRANSFORM(SEC(m.ltDatetime)) + ",0)"
		CASE THIS.ParseDateType = 3 && MS JSON Date format (ASP.NET AJAX)
			*!* Strange behavior where the datetime math would return a precision number
			*!* necessitated the use of Ceiling() to ensure that differences were only
			*!* captured to the whole second. Only appeared to happen when m.ltDatetime
			*!* was coming in from a field in a cursor. In any event, Ceiling() is the
			*!* workaround.
			m.lnMilliSecondsSinceEpoch = (CEILING(m.ltDatetime - DTOT(DATE(1970,1,1))) * 1000)
			IF This.UseUTCDatetime
				m.lcReturnJSONDateTime = "\/Date(" + TRANSFORM(m.lnMilliSecondsSinceEpoch) + ")\/"
			ELSE
				m.lcReturnJSONDateTime = "\/Date(" + TRANSFORM(m.lnMilliSecondsSinceEpoch) + THIS.GetISO8601TimezoneOffset(m.ltDatetime) + ")\/"
			ENDIF
		OTHERWISE && ISO 8601 is default and when this.ParseDateType = 1
			m.lcISO8601Datetime = (TTOC(m.ltDatetime,3) + THIS.GetISO8601TimezoneOffset(m.ttDateTime))
			m.lcReturnJSONDateTime = THIS.Quote(m.lcISO8601Datetime)
		ENDCASE

		RETURN (m.lcReturnJSONDateTime)

		*****************************************
		*!* Javascript for setting dates using ISO 8601 this string format
		*!* http://delete.me.uk/2005/03/iso8601.html
		*****************************************
		*!*	Date.prototype.setISO8601 = function (string) {
		*!*	    var regexp = "([0-9]{4})(-([0-9]{2})(-([0-9]{2})" +
		*!*	        "(T([0-9]{2}):([0-9]{2})(:([0-9]{2})(\.([0-9]+))?)?" +
		*!*	        "(Z|(([-+])([0-9]{2}):([0-9]{2})))?)?)?)?";
		*!*	    var d = string.match(new RegExp(regexp));

		*!*	    var offset = 0;
		*!*	    var date = new Date(d[1], 0, 1);

		*!*	    if (d[3]) { date.setMonth(d[3] - 1); }
		*!*	    if (d[5]) { date.setDate(d[5]); }
		*!*	    if (d[7]) { date.setHours(d[7]); }
		*!*	    if (d[8]) { date.setMinutes(d[8]); }
		*!*	    if (d[10]) { date.setSeconds(d[10]); }
		*!*	    if (d[12]) { date.setMilliseconds(Number("0." + d[12]) * 1000); }
		*!*	    if (d[14]) {
		*!*	        offset = (Number(d[16]) * 60) + Number(d[17]);
		*!*	        offset *= ((d[15] == '-') ? 1 : -1);
		*!*	    }

		*!*	    offset -= date.getTimezoneOffset();
		*!*	    time = (Number(date) + (offset * 60 * 1000));
		*!*	    this.setTime(Number(time));
		*!*	}
	ENDPROC


	PROTECTED PROCEDURE serializedate
		LPARAMETERS tdDate

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Serialize a VFP date value to JSON
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tdDate
		*!*			The VFP date value to be serialized
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		String - JSON datetime
		*********************************************************************

		LOCAL lcReturnJSONDate

		if isnull(m.tdDate) OR empty(m.tdDate)
			m.lcReturnJSONDate = [null]
 		else
			m.lcReturnJSONDate = ["]+TRANSFORM(YEAR(m.tdDate)) + "-" +;
								 TRANSFORM(MONTH(m.tdDate),"@L 99") + "-" +;
								 TRANSFORM(DAY(m.tdDate),"@L 99")+[T12:00:00"]
		endif

		RETURN (m.lcReturnJSONDate)
	ENDPROC


	PROTECTED PROCEDURE serializelogical
		LPARAMETERS tlLogical

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Serialize a VFP logical value to JSON
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tlLogical
		*!*			The VFP logical value to be serialized
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		String - JSON boolean
		*********************************************************************

		LOCAL lcReturnJSONBoolean

		m.lcReturnJSONBoolean = IIF(m.tlLogical, "true", "false")

		RETURN (m.lcReturnJSONBoolean)
	ENDPROC


	PROTECTED PROCEDURE serializecursor
		LPARAMETERS tcAlias, tvReplacer, tvSpace, tnLevel

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Serialize a VFP cursor to JSON
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tcAlias
		*!*			A VFP cursor alias that is to be serialized to a JSON array of objects
		*!*		tvReplacer
		*!*			See parameter notes in This.Stringify()
		*!*		tvSpace
		*!*			See parameter notes in This.Stringify()
		*!*		tnLevel
		*!*			Current nesting level of the array being serialized
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		String - JSON object containing an array of objects
		*********************************************************************

		LOCAL lcReturnJSONCursor, lnSelect, lcTempCursorName
		LOCAL loRecordObject, lcAllRecords, lcRecord, lcRecordsLabel
		LOCAL lcTableLevelIndent, lcObjectLevelIndent

		m.lcReturnJSONCursor = "" && Default return value
		m.lnSelect = SELECT(0) && Save workarea to restore later
		m.lcTempCursorName = THIS.GetUniqueAlias()
		m.lcAllRecords = ""
		m.lcRecordsLabel = JUSTSTEM(m.tcAlias) && just in case a full path was sent in

		SELECT * FROM (m.tcAlias) WITH (BUFFERING = .T.) INTO CURSOR (m.lcTempCursorName) NOFILTER

		IF _TALLY > 0 && We got some records from the alias
			SELECT (m.lcTempCursorName)
			SCAN ALL
				SCATTER NAME loRecordObject  && Cursors are serialized as an object containing an array of objects
				m.lcRecord = THIS.stringify(@m.loRecordObject, @m.tvReplacer, m.tvSpace, m.tnLevel + 2)
				IF !THIS.Isundefined(m.lcRecord)
					m.lcAllRecords = m.lcAllRecords + IIF(!EMPTY(m.lcAllRecords), ",", "") + m.lcRecord
				ENDIF
			ENDSCAN
			IF !EMPTY(m.lcAllRecords)
				m.lcTableLevelIndent = THIS.GetIndentChars(m.tvSpace, m.tnLevel + 1)
				m.lcAllRecords = m.lcTableLevelIndent +'[' + m.lcAllRecords
				m.lcAllRecords = m.lcAllRecords + m.lcTableLevelIndent + "]"
			ENDIF
		ENDIF

		m.lcObjectLevelIndent = THIS.GetIndentChars(m.tvSpace, m.tnLevel)
		m.lcReturnJSONCursor = m.lcReturnJSONCursor + m.lcAllRecords
		m.lcReturnJSONCursor = m.lcReturnJSONCursor + m.lcObjectLevelIndent

		*!* Clean up
		RELEASE loRecordObject
		USE IN SELECT(m.lcTempCursorName)
		SELECT (m.lnSelect) && Restore workarea

		RETURN (m.lcReturnJSONCursor)
	ENDPROC


	PROTECTED PROCEDURE deserializearray
		LPARAMETERS tcArrayJSON, tcReviver, taArray

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Deserialize JSON representing an array
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tcArrayJSON (required)
		*!*			A string representing a valid JSON array
		*!*		tcReviver (optional)
		*!*			See parameter notes in This.Parse()
		*!*		taArray (required)
		*!*			Array sent in byref
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		Numeric - Number of rows in the array that was created/filled
		*********************************************************************

		EXTERNAL ARRAY LVVALUE
		LOCAL lnReturnRows, lnStringLength, lnStartPosition, lvValue
		LOCAL lnTokenType, lnTokenStart, lnTokenLength, lcTokenText
		LOCAL lvResult, lnCurrentRow, lnRows, lnColumns, lnColumnCounter

		m.lnReturnRows = 0
		m.lnStringLength = LEN(m.tcArrayJSON)
		m.lnStartPosition = (AT("[", m.tcArrayJSON) + 1) && go just pass the beginning of the objects Token text
		m.lnCurrentRow = 0

		DO WHILE m.lnStartPosition <= lnStringLength
			m.lvValue = NULL
			m.lvResult = THIS.Parse(SUBSTR(m.tcArrayJSON, m.lnStartPosition), @m.tcReviver, ;
				@m.lvValue, ;
				@m.lnTokenType, @m.lnTokenStart, @m.lnTokenLength, @m.lcTokenText)
			IF !THIS.IsUndefined(m.lcTokenText)
				m.lnCurrentRow = m.lnCurrentRow + 1
				IF m.lnTokenType = TOKENTYPE_ARRAY
					m.lnColumns = ALEN(m.lvValue, 1) && the nested flat array's rows are this multi-dimensional array's columns
				ELSE
					m.lnColumns  = 0
				ENDIF
				IF m.lnColumns > 0 && multi-dimensional array
					DIMENSION m.taArray(m.lnCurrentRow, m.lnColumns)
					FOR m.lnColumnCounter = 1 TO m.lnColumns
						m.taArray(m.lnCurrentRow, m.lnColumnCounter) = m.lvValue(m.lnColumnCounter)
					ENDFOR
				ELSE && single-dim (flat) array
					DIMENSION m.taArray(m.lnCurrentRow)
					m.taArray(m.lnCurrentRow) = m.lvValue
				ENDIF
			ENDIF
			m.lnStartPosition = MAX((m.lnStartPosition + m.lnTokenStart + m.lnTokenLength - 1), m.lnStartPosition + 1)
		ENDDO
		IF TYPE("m.taArray",1) = "A"
			m.lnReturnRows = ALEN(m.taArray,1)
		ENDIF

		RETURN (m.lnReturnRows)
	ENDPROC


	PROTECTED PROCEDURE deserializecursor
		LPARAMETERS tcCursorJSON, tcReviver, tcAlias

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Deserialize JSON representing a VFP cursor
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tcCursorJSON
		*!*			A string representing a valid JSON array of objects
		*!*		tcReviver
		*!*			See parameter notes in This.Parse()
		*!*		tcAlias
		*!*			String specifying the name of the alias to create/fill
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		String - Alias of the cursor that was created/filled
		*********************************************************************

		EXTERNAL ARRAY LVVALUE
		LOCAL lcReturnAliasName, lvResult, lvValue
		LOCAL lnObjectCount, lnFieldCount, lnIndexCounter, lnMemberCounter
		LOCAL loRowObject, llSetUpMemberArray, lcSelectSQL, lcFieldName
		LOCAL lcTempCursorName
		LOCAL ARRAY laPEMS(1)

		m.lcReturnAliasName = THIS.Undefined
		IF VARTYPE(m.tcAlias) != "C" OR EMPTY(m.tcAlias)
			m.tcAlias = THIS.GetUniqueAlias()
			SELECT 0
		ELSE
			IF USED(m.tcAlias)
				SELECT (m.tcAlias)
			ELSE
				SELECT 0
			ENDIF
		ENDIF

		m.lnStringLength = LEN(m.tcCursorJSON)
		*!*	m.lnStartPosition = (AT("{", m.tcCursorJSON) + 1) && go just pass the beginning of the objects Token text
		m.lnStartPosition = (AT("[", m.tcCursorJSON)) && go just pass the beginning of the objects Token text
		m.lvResult = THIS.Parse(@m.tcCursorJSON, @m.tcReviver, @m.lvValue)

		IF TYPE("m.lvValue",1) = "A" && Should be a single-dim (flat) array of objects
			m.lnObjectCount = ALEN(m.lvValue)
			IF m.lnObjectCount > 0
				m.llSetUpMemberArray = !USED(m.tcAlias) && we only need to setup the cursor if one hasn't been provided
				IF !m.llSetUpMemberArray
					SELECT (m.tcAlias)
				ENDIF
				FOR m.lnIndexCounter = 1 TO m.lnObjectCount
					m.loRowObject = m.lvValue(m.lnIndexCounter)
					IF TYPE("m.loRowObject") = "O"
						IF m.llSetUpMemberArray && then create a cursor with field types and precision based on the first object in the array
							m.llSetUpMemberArray = .F.
							m.lnFieldCount = AMEMBERS(m.laPEMS, m.loRowObject, 0)
							m.lcSelectSQL = ""
							FOR m.lnMemberCounter = 1 TO m.lnFieldCount
								m.lcFieldName = LOWER(m.laPEMS(m.lnMemberCounter))
								m.lcSelectSQL = m.lcSelectSQL + IIF(!EMPTY(m.lcSelectSQL), ", ", "")
								m.lcSelectSQL = m.lcSelectSQL + "m.loRowObject." + m.lcFieldName + " as " + m.lcFieldName
							ENDFOR
							IF !EMPTY(m.lcSelectSQL)
								m.lcTempCursorName = THIS.GetUniqueAlias()
								SELECT 0
								CREATE CURSOR (m.lcTempCursorName) (pkid I) && anything will do, this is just to keep the select from failing
								m.lcSelectSQL = "Select " + m.lcSelectSQL + " From " + m.lcTempCursorName + " into cursor " + m.tcAlias + " readwrite"
								&lcSelectSQL
								USE IN SELECT(m.lcTempCursorName)
								IF !USED(m.tcAlias) && ensure that the cursor was created successfully
									EXIT
								ELSE
									SELECT (m.tcAlias)
								ENDIF
							ENDIF
						ENDIF
						APPEND BLANK IN (m.tcAlias)
						GATHER NAME m.loRowObject
					ENDIF
				ENDFOR
				m.lcReturnAliasName = m.tcAlias
			ENDIF
		ENDIF

		RETURN (m.lcReturnAliasName)
	ENDPROC


	PROTECTED PROCEDURE deserializedate
		LPARAMETERS tcDateJSON

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Deserialize JSON representing a date value
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tcDateJSON
		*!*			A string representing a valid JSON date
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		Date
		*********************************************************************

		*!* tcDateJSON is expected YYYY-MM-DD
		LOCAL ldReturn, ltDateTime

		m.ltDateTime = STRTRAN(m.tcDateJSON, ["], "") && get rid of the quotes around it
		IF EMPTY(m.ltDateTime)
			m.ldReturn = {}
		ELSE
			m.ldReturn = DATE(VAL(SUBSTR(m.ltDateTime,1,4)),VAL(SUBSTR(m.ltDateTime,6,2)),VAL(SUBSTR(m.ltDateTime,9,2)))
		ENDIF

		RETURN (m.ldReturn)
	ENDPROC


	PROTECTED PROCEDURE deserializedatetime
		LPARAMETERS tcDatetimeJSON

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Deserialize JSON representing a datetime value
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tcDatetimeJSON
		*!*			A string representing a valid JSON datetime
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		Datetime
		*********************************************************************

		*!* tcDatetimeJSON can be in ISO 8601 format, such as:
		*!* "2008-11-09T09:53:40Z"
		*!* "2008-11-09T09:53:40-01:00"
		*!* "2008-11-09T09:53:40+01:00"

		*!* OR

		*!* tcDatetimeJSON can be in MS JSON Datetime, such as:
		*!* \/Date(1226224420000)\/
		*!* \/Date(1226224420000+0100)\/
		*!* \/Date(1226224420000+0100)\/
		*!* More info regarding this format... http://msdn.microsoft.com/en-us/library/bb299886.aspx#intro_to_json_sidebarb

		LOCAL ltReturn, lnHours, lnMinutes, lcMilliSecondsPart, lcOffsetPart
		LOCAL lnDelimiterPosition, lnSecondsFromDate, lnOffsetDifference

		m.lnOffsetSeconds = 0
		m.tcDatetimeJSON = STRTRAN(m.tcDatetimeJSON, ["], "") && get rid of the quotes around it
		m.tcDatetimeJSON = ALLTRIM(m.tcDatetimeJSON)

		IF LEFT(m.tcDatetimeJSON, 7) != "\/Date(" && ISO 8601 format
			m.ltReturn = CTOT(SUBSTR(m.tcDatetimeJSON,1,19))
			IF LEN(m.tcDatetimeJSON) = 25 && Does the datetime string have a timezone offset?
				m.lnHours = VAL(SUBSTR(m.tcDatetimeJSON, 20, 3))
				m.lnMinutes = VAL(SUBSTR(m.tcDatetimeJSON, 20, 1) + SUBSTR(m.tcDatetimeJSON, 24, 2))
				m.lnOffsetSeconds = ((m.lnHours * 3600) + (m.lnMinutes * 60))
			ENDIF
		ELSE && MS JSON Datetime (ASP.NET AJAX format)
			m.lcOffsetPart = ""
			m.lcMilliSecondsPart = STREXTRACT(tcDatetimeJSON, "(", ")")
			m.lnDelimiterPosition = MAX(AT("+", m.lcMilliSecondsPart), AT("-", m.lcMilliSecondsPart))
			IF m.lnDelimiterPosition > 0
				m.lcOffsetPart = SUBSTR(m.lcMilliSecondsPart, m.lnDelimiterPosition)
				m.lcMilliSecondsPart = SUBSTR(m.lcMilliSecondsPart, 1, m.lnDelimiterPosition - 1)
			ENDIF
			m.lnSecondsFromDate = INT(VAL(m.lcMilliSecondsPart)/1000)
			m.ltReturn = (DATETIME(1970, 1, 1) + m.lnSecondsFromDate)
			IF !EMPTY(m.lcOffsetPart) && Does the datetime string have a timezone offset?
				m.lnHours = VAL(SUBSTR(m.lcOffsetPart, 1, 3))
				m.lnMinutes = VAL(SUBSTR(m.lcOffsetPart, 1, 1) + SUBSTR(m.tcDatetimeJSON, 4, 2))
				m.lnOffsetSeconds = ((m.lnHours * 3600) + (m.lnMinutes * 60))
			ENDIF
		ENDIF

		*!* get the Local datetime equivalent of the Datetime JSON sent in
		IF m.lnOffsetSeconds = 0
			m.lnLocalTimezoneOffset = (THIS.GetTimeZoneOffset(m.ltReturn, .T.) * 60)
			m.ltReturn = m.ltReturn - m.lnLocalTimezoneOffset
		ELSE
			m.lnLocalTimezoneOffset = (THIS.GetTimeZoneOffset(m.ltReturn) * 60)
			m.lnOffsetDifference = (m.lnLocalTimezoneOffset + m.lnOffsetSeconds)
			m.ltReturn = m.ltReturn - m.lnOffsetDifference
		ENDIF

		RETURN (m.ltReturn)
	ENDPROC


	PROTECTED PROCEDURE deserializelogical
		LPARAMETERS tcBooleanJSON

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Deserialize JSON representing a logical value
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tcBooleanJSON
		*!*			A string representing a valid JSON boolean
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		Logical
		*********************************************************************

		LOCAL llReturn

		m.tcBooleanJSON = LOWER(ALLTRIM(m.tcBooleanJSON))
		m.llReturn = (m.tcBooleanJSON == "true" OR m.tcBooleanJSON == '["on"]')

		RETURN (m.llReturn)
	ENDPROC


	PROTECTED PROCEDURE deserializenull
		LPARAMETERS tcNullJSON

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Deserialize JSON representing a nulll value
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tcNullJSON
		*!*			A string representing a valid JSON null
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		Null
		*********************************************************************

		LOCAL lvReturn

		*!* m.lvReturn = EVALUATE(m.tcNullJSON)
		m.lvReturn = NULL

		RETURN (m.lvReturn)
	ENDPROC


	PROTECTED PROCEDURE deserializenumber
		LPARAMETERS tcNumberJSON

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Deserialize JSON representing a numeric or integer value
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tcNumberJSON
		*!*			A string representing a valid JSON number
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		Numeric
		*********************************************************************

		LOCAL lnReturn

		m.lnReturn = EVALUATE(m.tcNumberJSON)

		RETURN (m.lnReturn)
	ENDPROC


	PROTECTED PROCEDURE deserializeobject
		LPARAMETERS tcObjectJSON, tcReviver, tvClassOrInstance, tcClassModule

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Deserialize JSON representing an object
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tcObjectJSON
		*!*			A string representing a valid JSON array
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		Object
		*********************************************************************

		EXTERNAL ARRAY LVVALUE
		LOCAL loReturn, lnStringLength, lnStartPosition, lnEndPosition, lvValue
		LOCAL lnTokenType, lnTokenStart, lnTokenLength, lcTokenText, llProcessValue
		LOCAL lcJSONKey, lcLowerJSONKey, lvResult, lnRows, lnColumns, lcTypeOfReviver
		LOCAL llIsCollection, lnTotalItems, lnItemCounter, lvTempClass, lvTempClassModule
		LOCAL llFoundClass, llFoundClassLibrary, lcArrayKey, lcArrayProperty
		m.lnStringLength = LEN(m.tcObjectJSON)
		m.lnStartPosition = (AT("{", m.tcObjectJSON) + 1) && go just pass the beginning of the objects Token text
		m.lcJSONKey = ""
		STORE .F. TO m.lvTempClass, m.lvTempClassModule
		m.lcTypeOfReviver = VARTYPE(m.tcReviver)

		*!* determine if class and classlibrary keys should be respected
		IF INLIST(TYPE("m.tvClassOrInstance"), "L", "C") ;
			AND EMPTY(m.tvClassOrInstance) ;
			AND This.ParseRespectClass ;
			AND ATC("class", SUBSTR(m.tcObjectJSON, m.lnStartPosition)) > 0 ;
			AND ATC("classlibrary", SUBSTR(m.tcObjectJSON, m.lnStartPosition)) > 0
			This.ParseRespectClass = .F. && don't need to process collections to find class and classlibrary
			DO WHILE m.lnStartPosition <= m.lnStringLength && find class and classlibrary
				m.lvValue = NULL
				m.lvResult = THIS.Parse(SUBSTR(m.tcObjectJSON, m.lnStartPosition), @m.tcReviver, ;
										@m.lvValue, ;
										@m.lnTokenType, @m.lnTokenStart, @m.lnTokenLength, @m.lcTokenText)
				IF !THIS.IsUndefined(m.lcTokenText)
					IF m.lnTokenType = TOKENTYPE_KEY
						m.lcJSONKey = m.lvResult
					ELSE
						IF !EMPTY(m.lcJSONKey)
							m.llProcessValue = .F.
							m.lcLowerJSONKey = LOWER(ALLTRIM(m.lcJSONKey))
							DO CASE
							CASE m.lcLowerJSONKey == "class"
								m.llProcessValue = .T.
							CASE m.lcLowerJSONKey == "classlibrary"
								m.llProcessValue = .T.
							ENDCASE
							IF m.llProcessValue
								IF m.lcTypeOfReviver = "C" AND !EMPTY(m.tcReviver) && then replace the value via the reviver
									m.lvResult = EVALUATE(m.tcReviver + "(@m.loReturn, @m.lcJSONKey, @m.lvValue)")
									IF THIS.IsUndefined(m.lvValue)
										m.lnTokenType = TOKENTYPE_UNDEFINED
									ELSE
										IF TYPE("m.lvValue", 1) = "A"
											m.lnTokenType = TOKENTYPE_ARRAY
										ELSE
											IF VARTYPE(m.lvValue) != "U"
												m.lnTokenType = -1 && TOKENTYPE_REVIVER
											ENDIF
										ENDIF
									ENDIF
								ENDIF
								IF m.lnTokenType = TOKENTYPE_STRING
									DO CASE
									CASE m.lcLowerJSONKey == "class"
										m.lvTempClass = m.lvValue
									CASE m.lcLowerJSONKey == "classlibrary"
										m.lvTempClassModule = m.lvValue
									ENDCASE
								ENDIF
							ENDIF
							m.lcJSONKey = ""
						ENDIF
					ENDIF
				ENDIF
				IF VARTYPE(m.lvTempClass) = "C" AND VARTYPE(m.lvTempClassModule) = "C" && we've got the properties we need, let's get out of this loop
					EXIT
				ELSE
					m.lnStartPosition = MAX((m.lnStartPosition + m.lnTokenStart + m.lnTokenLength - 1), m.lnStartPosition + 1)
				ENDIF
			ENDDO
			This.ParseRespectClass = .T.
			*!* set position and key back to original values now that
			*!* we've tried or succeeded in locating the defining class and classlibrary
			*!* for the object being parsed
			m.lnStartPosition = (AT("{", m.tcObjectJSON) + 1) && go just pass the beginning of the objects Token text
			m.lcJSONKey = ""
		ENDIF

		IF VARTYPE(m.lvTempClass) != "C"
			m.lvTempClass = m.tvClassOrInstance
		ENDIF
		IF VARTYPE(m.lvTempClassModule) != "C"
			m.lvTempClassModule = m.tcClassModule
		ENDIF

		*!* Begin to parse the object
		m.loReturn = THIS.CreateNewObject(m.lvTempClass, m.lvTempClassModule)
		m.llIsCollection = (TYPE("m.loReturn.baseclass") = "C" AND LOWER(ALLTRIM(m.loReturn.baseclass)) = "collection")

		DO WHILE m.lnStartPosition <= m.lnStringLength
			m.lvValue = NULL
			m.lvResult = THIS.Parse(SUBSTR(m.tcObjectJSON, m.lnStartPosition), @m.tcReviver, ;
									@m.lvValue, ;
									@m.lnTokenType, @m.lnTokenStart, @m.lnTokenLength, @m.lcTokenText)
			IF !THIS.IsUndefined(m.lcTokenText)
				IF m.lnTokenType = TOKENTYPE_KEY
					m.lcJSONKey = m.lvResult
				ELSE
					IF !EMPTY(m.lcJSONKey)
						IF m.lcTypeOfReviver = "C" AND !EMPTY(m.tcReviver) && then replace the value via the reviver
							m.lvResult = EVALUATE(m.tcReviver + "(@m.loReturn, @m.lcJSONKey, @m.lvValue)")
							IF THIS.IsUndefined(m.lvValue)
								m.lnTokenType = TOKENTYPE_UNDEFINED
							ELSE
								IF TYPE("m.lvValue", 1) = "A"
									m.lnTokenType = TOKENTYPE_ARRAY
								ELSE
									IF VARTYPE(m.lvValue) != "U"
										m.lnTokenType = -1 && TOKENTYPE_REVIVER
									ENDIF
								ENDIF
							ENDIF
						ENDIF
						DO CASE
						CASE m.lnTokenType = TOKENTYPE_ARRAY
							IF m.llIsCollection AND LOWER(ALLTRIM(m.lcJSONKey)) == LOWER(ALLTRIM(This.Keyforitems))
								m.lnTotalItems = ALEN(m.lvValue,1)
								FOR m.lnItemCounter = 1 TO m.lnTotalItems
									m.loReturn.Add(m.lvValue(m.lnItemCounter,1))
								ENDFOR 
							ELSE
								m.lnRows = ALEN(m.lvValue, 1)
								m.lnColumns = MAX(ALEN(m.lvValue, 2),1)
								m.lcArrayKey = m.lcJSONKey + "[" + TRANSFORM(m.lnRows) + "," + TRANSFORM(m.lnColumns) + "]"
								ADDPROPERTY(m.loReturn, m.lcArrayKey)
								m.lcArrayProperty = "m.loReturn." + m.lcJSONKey
								=ACOPY(m.lvValue, &lcArrayProperty)
							ENDIF
						CASE m.lnTokenType = TOKENTYPE_CURSOR && Just in case - but, should never happen
							*!* Ignore Member - could throw an error though
						CASE m.lnTokenType = TOKENTYPE_UNDEFINED
							*!* Ignore Member - I could throw an error here, but just ignore for now
						OTHERWISE
							IF This.ParseRespectClass
	*!*								TRY
	*!*									ADDPROPERTY(m.loReturn, m.lcJSONKey, m.lvValue)
	*!*								CATCH
	*!*									*!* fail silently here
	*!*								ENDTRY
								IF PEMSTATUS(m.loReturn, m.lcJSONKey, 5) AND PEMSTATUS(m.loReturn, m.lcJSONKey, 1)
									*!* leave it alone... it's readonly
								ELSE
									ADDPROPERTY(m.loReturn, m.lcJSONKey, m.lvValue)
								ENDIF
							ELSE
								ADDPROPERTY(m.loReturn, m.lcJSONKey, m.lvValue)
							ENDIF
						ENDCASE
						m.lcJSONKey = ""
					ENDIF
				ENDIF
			ENDIF
			m.lnStartPosition = MAX((m.lnStartPosition + m.lnTokenStart + m.lnTokenLength - 1), m.lnStartPosition + 1)
		ENDDO

		RETURN (m.loReturn)
	ENDPROC


	PROTECTED PROCEDURE deserializestring
		LPARAMETERS tcStringJSON

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Deserialize JSON representing a string value
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tcStringJSON
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		String
		*********************************************************************

		LOCAL lcReturnVFPString

		if THIS.utf8strings
			m.lcReturnVFPString= strconv(strtran(strtran(strtran(m.tcStringJSON,"\n",chr(13)+chr(10)),'\"','"'),"\\","\"),11)
		else
			m.lcReturnVFPString = strconv(THIS.UnescapeChars(m.tcStringJSON),11)
		endif
		IF LEFT(m.lcReturnVFPString, 1) = ["] and RIGHT(m.lcReturnVFPString,1) = ["]
			m.lcReturnVFPString = SUBSTR(m.lcReturnVFPString,2,LEN(m.lcReturnVFPString) - 2) && remove quotes
		ENDIF
		RETURN (m.lcReturnVFPString)
	ENDPROC


	PROTECTED PROCEDURE getindentchars
		LPARAMETERS tvSpace, tnLevel

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Produce the appropriate indent char(s) based on the space and nesting level
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tvSpace
		*!*			See parameter notes in This.Stringify()
		*!*		tnLevel
		*!*			Nesting level for which to get the indent char(s)
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		String - Indent to be used on successive level of heirarchy
		*********************************************************************

		LOCAL lcReturnIndentChars, lcTypeOfSpace

		m.lcReturnIndentChars = ""
		m.lcTypeOfSpace = VARTYPE(m.tvSpace, .F.)

		IF INLIST(m.lcTypeOfSpace, "C", "N")
			m.lcReturnIndentChars = IIF(m.lcTypeOfSpace = "C", m.tvSpace, SPACE(m.tvSpace))
			m.lcReturnIndentChars = REPLICATE(m.lcReturnIndentChars, m.tnLevel)
			IF LEN(m.lcReturnIndentChars) > 0 OR (m.tnLevel = 0 AND ((m.lcTypeOfSpace = "C" AND LEN(m.tvSpace) > 0) OR (m.lcTypeOfSpace = "N" AND m.tvSpace > 0)))
				m.lcReturnIndentChars = CHR(10) + m.lcReturnIndentChars
			ENDIF
		ENDIF

		RETURN (m.lcReturnIndentChars)
	ENDPROC


	PROTECTED PROCEDURE gettimezoneoffset
		LPARAMETERS ttDateTime, tlUTCDatetime
		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Get offset from GMT for Local timezone in minutes
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		Numeric - offset in minutes from GMT for Local timezone
		*********************************************************************
		#DEFINE TIME_ZONE_ID_INVALID	-1
		#DEFINE TIME_ZONE_ID_UNKNOWN	0x00000000
		#DEFINE TIME_ZONE_ID_STANDARD	0x00000001
		#DEFINE TIME_ZONE_ID_DAYLIGHT	0x00000002

		LOCAL lnReturnOffset, lnResult, lcTZInformationCurrentYear, lcTZInformationLastYear
		LOCAL lcDaylightInfo, lcStandardInfo, llCheckForDaylightSavings, lnCurrentYear, ;
		      lnDaylightSavingsOffset, ltDaylightEnd, ltDaylightStart, ltStandardStart, llBetween

		m.lnReturnOffset = NULL
		m.lcTZInformationLastYear = SPACE(172)
		m.lcTZInformationCurrentYear = SPACE(172)

		m.llBetween = .T.
		m.lnCurrentYear = YEAR(m.ttDateTime)
		m.llCheckForDaylightSavings = .T.

		if isNull(this._TZYear) OR this._TZYear != m.lnCurrentYear OR this._TZUTC != m.tlUTCDatetime
			DECLARE INTEGER GetTimeZoneInformationForYear IN kernel32 AS GetTZInfo SHORT wYear, STRING pDynamicTimeZoneInformation, STRING @lpTimeZoneInformation
			GetTZInfo(m.lnCurrentYear-1,NULL,@m.lcTZInformationLastYear)
			m.lnResult = GetTZInfo(m.lnCurrentYear,NULL,@m.lcTZInformationCurrentYear)

			IF INLIST(m.lnResult, TIME_ZONE_ID_STANDARD, TIME_ZONE_ID_DAYLIGHT)
				TRY
					m.lcDaylightInfo = SUBSTR(m.lcTZInformationCurrentYear, 153, 16)
					m.ltDaylightStart = this.GetRelativeDatetime(m.lcDaylightInfo, m.lnCurrentYear)
					IF m.tlUTCDatetime && the time sent in was UTC, so we need to figure the UTC equivalent for standard
						m.ltDaylightStart = (m.ltDaylightStart + (This.GetTimezoneOffset(m.ltDaylightStart - 1) * 60))
					endif

					m.lcStandardInfo = SUBSTR(m.lcTZInformationCurrentYear, 69, 16)
					m.ltStandardStart = this.GetRelativeDatetime(m.lcStandardInfo, m.lnCurrentYear)
					IF m.tlUTCDatetime && the time sent in was UTC, so we need to figure the UTC equivalent for standard
						m.ltStandardStart = (m.ltStandardStart + (This.GetTimezoneOffset(m.ltStandardStart - 1) * 60))
					ENDIF
					
					IF m.ltStandardStart > m.ltDaylightStart
						m.ltStandardStart = m.ltStandardStart - 1
					ELSE
						m.llBetween = .F.

						m.ltDaylightStart = m.ltStandardStart
						m.ltDaylightStart = m.ltDaylightStart + 1

						m.lcStandardInfo = SUBSTR(m.lcTZInformationlASTYear, 153, 16)
						m.ltStandardStart = this.GetRelativeDatetime(m.lcStandardInfo, m.lnCurrentYear)
						IF m.tlUTCDatetime && the time sent in was UTC, so we need to figure the UTC equivalent for standard
							m.ltStandardStart = (m.ltStandardStart + (This.GetTimezoneOffset(m.ltStandardStart - 1) * 60))
						ENDIF
					ENDIF
					
					m.lnReturnOffset = CTOBIN(SUBSTR(m.lcTZInformationCurrentYear,1,4), "4RS")
					m.lnDaylightSavingsOffset = CTOBIN(RIGHT(m.lcTZInformationCurrentYear,4), "4RS")

					*!* keep offset information to save time on future calls for same year
					this._TZUTC = m.tlUTCDatetime
					this._TZDLOffset = m.lnDaylightSavingsOffset
					this._TZOffset = m.lnReturnOffset
					this._TZBetween = m.llBetween
					this._TZYear = m.lnCurrentYear 
					this._TZDaylightStart = m.ltDaylightStart
					this._TZStandardStart = m.ltStandardStart

				CATCH && daylight must not be filled out so just use standard bias
					m.lnReturnOffset = CTOBIN(SUBSTR(m.lcTZInformationCurrentYear,1,4), "4RS")
					m.llCheckForDaylightSavings = .F.

				ENDTRY
			ELSE && TIME_ZONE_ID_UNKNOWN or TIME_ZONE_ID_INVALID
				m.lnReturnOffset = 0 && let's just punt rather than let the NULL return
				m.llCheckForDaylightSavings = .F.
			ENDIF
		ELSE && we can reuse previously saved information
			m.lnDaylightSavingsOffset = this._TZDLOffset
			m.lnReturnOffset = this._TZOffset
			m.llBetween = this._TZBetween
			m.lnCurrentYear = this._TZYear
			m.ltDaylightStart = this._TZDaylightStart
			m.ltStandardStart = this._TZStandardStart
		endif

		IF m.llCheckForDaylightSavings
			m.ltDaylightEnd = m.ltStandardStart
			IF (m.llBetween AND Between(m.ttDateTime, m.ltDaylightStart, m.ltDaylightEnd)) OR (!m.llBetween AND !Between(m.ttDateTime, m.ltDaylightStart, m.ltDaylightEnd))
				m.lnReturnOffset = m.lnReturnOffset + m.lnDaylightSavingsOffset && Daylight
			ENDIF
		ENDIF

		RETURN (m.lnReturnOffset)
	ENDPROC


	PROTECTED PROCEDURE getiso8601timezoneoffset
		LPARAMETERS ttDatetime

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Return ISO8601 suffix for the UTC timezone or Local timezone
		*!*		offest from GMT based on the setting of This.UseUTCDatetime
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		String - representing the HH:MM offset from GMT
		*********************************************************************

		LOCAL lcReturnTZOffset, lnTimeZoneOffset, lnAbsMinOffset, lcOperator
		LOCAL lcMinutes, lcHours

		m.lcReturnTZOffset = ""

		IF THIS.UseUTCDatetime && GTM Timezone
			m.lcReturnTZOffset = "Z"
		ELSE
			m.lnTimeZoneOffset = THIS.GetTimeZoneOffset(m.ttDatetime)
			DO CASE
			CASE m.lnTimeZoneOffset > 0
				m.lcOperator = "-"
			CASE m.lnTimeZoneOffset < 0
				m.lcOperator = "+"
			OTHERWISE
				m.lcReturnTZOffset = "Z"
			ENDCASE
			IF EMPTY(m.lcReturnTZOffset)
				m.lnAbsMinOffset = ABS(m.lnTimeZoneOffset)
				m.lcMinutes = PADL(TRANSFORM(MOD(m.lnAbsMinOffset, 60)), 2, "0")
				m.lcHours = PADL(TRANSFORM(INT(m.lnAbsMinOffset/60)), 2, "0")
				m.lcReturnTZOffset = m.lcOperator + m.lcHours + ":" + m.lcMinutes
			ENDIF
		ENDIF

		RETURN (m.lcReturnTZOffset)
	ENDPROC


	PROTECTED PROCEDURE getnexttoken
		LPARAMETERS tcStringToSearch, tnStringLength, tnStartPosition, ;
			tnTokenType, tnTokenStart, tnTokenLength

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Get the next token when parsing a JSON string
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tcStringToSearch
		*!*			The string to search for the next token
		*!*		tnStringLength
		*!*			The total length of the string being searched
		*!*		tnStartPosition
		*!*			The position at which to start searching for the next token
		*!*		tnTokenType
		*!*			The type of token found (byref out parameter)
		*!*		tnTokenStart
		*!*			The position within the string searched where the found token text starts
		*!*		tnTokenLength
		*!*			The total length of the found token text
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		String - the TokenText of the token found
		*********************************************************************

		LOCAL lcReturnTokenText, lnCharCounter, lnStringLen
		LOCAL lcNextChar, llPreviousCharWasEscape
		LOCAL lnMatchingBracePosition, lcNextWord, llColonAfterString

		m.lcReturnTokenText = THIS.Undefined
		m.tnTokenStart = 0
		m.tnTokenLength = 0
		m.tnTokenType = TOKENTYPE_UNDEFINED

		IF VARTYPE(m.tnStringLength) != "N"
			m.tnStringLength = LEN(m.tcStringToSearch)
		ENDIF
		IF VARTYPE(m.tnStartPosition) != "N"
			m.tnStartPosition = 1
		ENDIF
		m.lnCharCounter = m.tnStartPosition && This.GetBeginningOfToken(@m.tcStringToSearch, m.tnStringLength, m.tnStartPosition)
		m.llEscapeFound = .F.

		*!* walk the string from the Start Position
		DO WHILE m.lnCharCounter <= m.tnStringLength
			m.lcNextChar = SUBSTR(m.tcStringToSearch, m.lnCharCounter, 1)
			IF !EMPTY(EVL(m.lcNextChar,"")) && do not count any whitespace or commas
				DO CASE
				CASE m.llPreviousCharWasEscape AND m.lcNextChar = "/" AND SUBSTR(m.tcStringToSearch, m.lnCharCounter, 6) == "/Date("
					m.lnMatchingBracePosition = THIS.GetPositionOfMatchingBrace(@m.tcStringToSearch, m.lcNextChar, m.lnCharCounter)
					IF m.lnMatchingBracePosition > 0
						m.lnCharCounter = m.lnCharCounter - 1
						m.tnTokenLength = ((m.lnMatchingBracePosition - m.lnCharCounter) + 1)
						m.lcReturnTokenText = SUBSTR(m.tcStringToSearch, m.lnCharCounter, m.tnTokenLength)
						m.tnTokenType = TOKENTYPE_DATETIME
					ENDIF
				CASE m.lcNextChar = "{"
					m.lnMatchingBracePosition = THIS.GetPositionOfMatchingBrace(@m.tcStringToSearch, m.lcNextChar, m.lnCharCounter)
					IF m.lnMatchingBracePosition > 0
						m.tnTokenLength = ((m.lnMatchingBracePosition - m.lnCharCounter) + 1)
						m.lcReturnTokenText = SUBSTR(m.tcStringToSearch, m.lnCharCounter, m.tnTokenLength)
						m.tnTokenType = TOKENTYPE_OBJECT
					ENDIF
				CASE m.lcNextChar = "["
					IF This.DojoCompatible
						m.lnMatchingBracePosition = THIS.GetPositionOfMatchingBrace(@m.tcStringToSearch, m.lcNextChar, m.lnCharCounter)
						m.tnTokenLength = ((m.lnMatchingBracePosition - m.lnCharCounter) + 1)
						m.lcReturnTokenText = SUBSTR(m.tcStringToSearch, m.lnCharCounter, m.tnTokenLength)
						IF m.lcReturnTokenText = '["on"]' OR m.lcReturnTokenText = '[]' && Dijit CheckBox returns an array
							m.tnTokenType = TOKENTYPE_LOGICAL
						ELSE
							IF m.lnMatchingBracePosition > 0
								m.tnTokenType = TOKENTYPE_ARRAY
							ENDIF
						ENDIF
					ELSE
						m.lnMatchingBracePosition = THIS.GetPositionOfMatchingBrace(@m.tcStringToSearch, m.lcNextChar, m.lnCharCounter)
						IF m.lnMatchingBracePosition > 0
							m.tnTokenLength = ((m.lnMatchingBracePosition - m.lnCharCounter) + 1)
							m.lcReturnTokenText = SUBSTR(m.tcStringToSearch, m.lnCharCounter, m.tnTokenLength)
							m.tnTokenType = TOKENTYPE_ARRAY
						ENDIF
					ENDIF
				CASE (m.lcNextChar = ["] AND !m.llPreviousCharWasEscape)
					m.lnMatchingBracePosition = THIS.GetPositionOfMatchingBrace(@m.tcStringToSearch, m.lcNextChar, m.lnCharCounter)
					IF m.lnMatchingBracePosition > 0
						m.llColonAfterString = (LEFT(LTRIM(SUBSTR(m.tcStringToSearch, m.lnMatchingBracePosition+1), 0, CHR(13) + CHR(10) + CHR(9) + CHR(32)),1) == ":")
						IF !m.llColonAfterString && make sure it isn't a key
							m.tnTokenLength = ((m.lnMatchingBracePosition - m.lnCharCounter) + 1)
							m.lcReturnTokenText = SUBSTR(m.tcStringToSearch, m.lnCharCounter, m.tnTokenLength)
							DO CASE
							CASE THIS.IsStringISO8601(m.lcReturnTokenText)
								m.tnTokenType = TOKENTYPE_DATETIME
							CASE THIS.IsStringDate(m.lcReturnTokenText)
								m.tnTokenType = TOKENTYPE_DATE
							OTHERWISE
								m.tnTokenType = TOKENTYPE_STRING
							ENDCASE
						ELSE
							m.lnMatchingBracePosition = THIS.GetPositionOfMatchingBrace(@m.tcStringToSearch, ":", m.lnCharCounter)
							IF m.lnMatchingBracePosition > 0
								m.tnTokenLength = ((m.lnMatchingBracePosition - m.lnCharCounter) + 1)
								m.lcReturnTokenText = SUBSTR(m.tcStringToSearch, m.lnCharCounter, m.tnTokenLength)
								m.lcDeserializedKey = THIS.Deserializekey(m.lcReturnTokenText)
								DO CASE
								CASE UPPER(ALLTRIM(m.lcDeserializedKey)) == UPPER(THIS.KeyForCursors)
									m.tnTokenType = TOKENTYPE_CURSOR
								CASE THIS.IsStringISO8601(m.lcReturnTokenText)
									m.tnTokenType = TOKENTYPE_DATETIME
								OTHERWISE
									m.tnTokenType = TOKENTYPE_KEY
								ENDCASE
							ENDIF
						ENDIF
					ENDIF
				OTHERWISE
					m.lcNextWord = GETWORDNUM(SUBSTR(m.tcStringToSearch, m.lnCharCounter), 1, CHR(13) + CHR(10) + CHR(9) + CHR(32) + '{}[]",')
					IF ISALPHA(m.lcNextChar) && boolean, null or key
						DO CASE
						CASE m.lcNextWord == "true" OR m.lcNextWord == "false"
							m.tnTokenLength = LEN(m.lcNextWord)
							m.lcReturnTokenText = m.lcNextWord
							m.tnTokenType = TOKENTYPE_LOGICAL
						CASE m.lcNextWord == "null"
							m.tnTokenLength = LEN(m.lcNextWord)
							m.lcReturnTokenText = m.lcNextWord
							m.tnTokenType = TOKENTYPE_NULL
						OTHERWISE && assume key until proven wrong
							m.lnMatchingBracePosition = THIS.GetPositionOfMatchingBrace(@m.tcStringToSearch, ":", m.lnCharCounter)
							IF m.lnMatchingBracePosition > 0
								m.tnTokenLength = ((m.lnMatchingBracePosition - m.lnCharCounter) + 1)
								m.lcReturnTokenText = SUBSTR(m.tcStringToSearch, m.lnCharCounter, m.tnTokenLength)
								IF UPPER(ALLTRIM(THIS.Deserializekey(m.lcReturnTokenText))) == "VFPDATA"
									m.tnTokenType = TOKENTYPE_CURSOR
								ELSE
									m.tnTokenType = TOKENTYPE_KEY
								ENDIF
							ENDIF
						ENDCASE
					ELSE
						IF ISDIGIT(m.lcNextChar) OR INLIST(m.lcNextChar, "-", "+") && number, datetime, or date
							IF AT(":", m.lcNextWord) = 0 && number
								m.tnTokenLength = LEN(m.lcNextWord)
								m.lcReturnTokenText = m.lcNextWord
								m.tnTokenType = TOKENTYPE_NUMBER
							ELSE
								IF THIS.IsStringISO8601(m.lcReturnTokenText)
									m.tnTokenLength = 25
									m.lcReturnTokenText = LEFT(m.lcNextWord,25)
									m.tnTokenType = TOKENTYPE_DATETIME
								ENDIF
							ENDIF
						ELSE
							IF m.lcNextChar = "\" AND SUBSTR(m.tcStringToSearch, m.lnCharCounter, 2) = "\/"
								m.tnTokenLength = AT("\/", SUBSTR(m.tcStringToSearch, m.lnCharCounter, 30), 2)
								m.lcReturnTokenText = SUBSTR(m.tcStringToSearch, m.lnCharCounter, m.tnTokenLength)
								m.tnTokenType = TOKENTYPE_DATETIME
							ENDIF
						ENDIF
					ENDIF
					IF !THIS.IsUndefined(m.lcReturnTokenText)
						IF LEN(m.lcNextWord) > 0
							m.lnCharCounter = AT(m.lcNextWord, SUBSTR(m.tcStringToSearch, m.lnCharCounter)) + m.lnCharCounter - 1
						ENDIF
					ENDIF
				ENDCASE
				IF !THIS.IsUndefined(m.lcReturnTokenText)
					m.tnTokenStart = m.lnCharCounter
					EXIT && we've got the next token so let's exit the loop
				ENDIF
			ENDIF
			IF m.lcNextChar = "\" AND !m.llPreviousCharWasEscape
				m.llPreviousCharWasEscape = .T.
			ELSE
				IF m.llPreviousCharWasEscape && in case the previous char was "\" as well
					m.llPreviousCharWasEscape = .F.
				ENDIF
			ENDIF
			m.lnCharCounter = MAX((m.tnTokenStart + m.tnTokenLength), m.lnCharCounter + 1)
		ENDDO

		RETURN (m.lcReturnTokenText)
	ENDPROC


	PROTECTED PROCEDURE getpositionofmatchingbrace
		LPARAMETERS tcStringToSearch, tcStartBrace, tnStartBracePosition

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Get the position of a matching end brace (i.e. "}" or "]") within a string
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tcStringToSearch
		*!*			The string to search for the matching brace
		*!*		tcStartBrace
		*!*			The beginning brace for which the ending match is located
		*!*		tnStartBracePosition
		*!*			The position at which to start searching for the matching brace within the tcStringToSearch sent in
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		Numeric - position of the matching brace for the brace char(s) sent in
		*********************************************************************

		LOCAL lnReturnPositionOfMatch, lcSubstring, lcMatchBraceChar, lnNextStartBraceAt
		LOCAL lnNextMatchBraceAt, lnOtherStartBracesCount, llFoundMatchBrace
		LOCAL lnOccurenceToFind, llCompensate, lnNextStartBraceOccurrence

		m.lnReturnPositionOfMatch = 0 && assume that we won't find the matching brace
		m.llFoundMatchBrace = .F.
		m.llCompensate = .T.
		IF VARTYPE(m.tnStringLength) != "N"
			m.tnStringLength = LEN(m.tcStringToSearch)
		ENDIF
		IF VARTYPE(m.tnStartBracePosition) != "N"
			m.tnStartBracePosition = AT(m.tcStartBrace, m.tcStringToSearch)
		ENDIF

		DO CASE
		CASE m.tcStartBrace = ["] && Looking for string's matching brace
			m.lcMatchBraceChar = ["]
		CASE m.tcStartBrace = "{" && Looking for object's matching brace
			m.lcMatchBraceChar = "}"
		CASE m.tcStartBrace = "[" && Looking for array's matching brace
			m.lcMatchBraceChar = "]"
		CASE m.tcStartBrace = ":" && Looking for key's matching brace
			m.lcMatchBraceChar = ":"
		CASE m.tcStartBrace = "/" && Looking for date's matching brace
			m.lcMatchBraceChar = ")\/"
		ENDCASE

		IF !EMPTY(m.lcMatchBraceChar)
			DO CASE
			CASE m.lcMatchBraceChar = ["] && JSON string
				m.lcSubstring = SUBSTR(m.tcStringToSearch, m.tnStartBracePosition)
				m.lnOccurenceToFind = 2
				m.lnNextMatchBraceAt = AT(m.lcMatchBraceChar, m.lcSubstring, m.lnOccurenceToFind)
				DO WHILE m.lnNextMatchBraceAt > 0 && need to handle escaped quotes
					IF SUBSTR(m.lcSubstring, m.lnNextMatchBraceAt - 1, 1) != "\" && if quote is not escaped this is the one we want
						m.llFoundMatchBrace = .T.
						EXIT
					ELSE
						m.lnOccurenceToFind = m.lnOccurenceToFind + 1
						m.lnNextMatchBraceAt = AT(m.lcMatchBraceChar, m.lcSubstring, m.lnOccurenceToFind)
					ENDIF
				ENDDO
			CASE m.lcMatchBraceChar = ":" && JSON key
				m.lnNextMatchBraceAt = AT(m.lcMatchBraceChar, m.tcStringToSearch, 1)
				IF m.lnNextMatchBraceAt > 0
					m.llFoundMatchBrace = .T.
					m.llCompensate = .F.
				ENDIF
			CASE m.lcMatchBraceChar = ")\/" && MS JSON Datetime
				m.lnNextMatchBraceAt = AT(m.lcMatchBraceChar, m.tcStringToSearch, 2)
				IF m.lnNextMatchBraceAt > 0
					m.lnNextMatchBraceAt = m.lnNextMatchBraceAt + 2
					m.llFoundMatchBrace = .T.
					m.llCompensate = .F.
				ENDIF
			OTHERWISE && JSON object or array
				m.lcSubstring = IIF(m.tnStartBracePosition = 1, m.tcStringToSearch, SUBSTR(m.tcStringToSearch, m.tnStartBracePosition))
				m.lnMatchBraceOccurence = 1
				m.lnNextMatchBraceAt = AT(m.lcMatchBraceChar, m.lcSubstring, m.lnMatchBraceOccurence)
				IF m.lnNextMatchBraceAt != 0
	*!*					m.lnNextStartBraceAt = AT(m.tcStartBrace, m.lcSubstring, 2)
	*!*					IF m.lnNextStartBraceAt > 0 AND m.lnNextStartBraceAt < m.lnNextMatchBraceAt
	*!*						m.lnOtherStartBracesCount = OCCURS(m.tcStartBrace, SUBSTR(m.lcSubstring, m.lnNextStartBraceAt, m.lnNextMatchBraceAt))
	*!*						m.lnOccurenceToFind = (m.lnOtherStartBracesCount + 1)
	*!*						m.lnNextMatchBraceAt = AT(m.lcMatchBraceChar, m.lcSubstring, m.lnOccurenceToFind)
	*!*						m.llFoundMatchBrace = (m.lnNextMatchBraceAt > 0)
	*!*					ELSE
	*!*						m.llFoundMatchBrace = (m.lnNextMatchBraceAt > 0)
	*!*					ENDIF
					m.lnMatchBraceOccurs = OCCURS(m.lcMatchBraceChar, SUBSTR(m.lcSubstring, 1, m.lnNextMatchBraceAt))
					m.lnStartBracesOccurs = OCCURS(m.tcStartBrace, SUBSTR(m.lcSubstring, 1, m.lnNextMatchBraceAt))
					DO WHILE m.lnMatchBraceOccurs != m.lnStartBracesOccurs
						m.lnMatchBraceOccurence = m.lnMatchBraceOccurence + 1
						m.lnNextMatchBraceAt = AT(m.lcMatchBraceChar, m.lcSubstring, m.lnMatchBraceOccurence)
						IF m.lnNextMatchBraceAt > 0
							m.lnMatchBraceOccurs = OCCURS(m.lcMatchBraceChar, SUBSTR(m.lcSubstring, 1, m.lnNextMatchBraceAt))
							m.lnStartBracesOccurs = OCCURS(m.tcStartBrace, SUBSTR(m.lcSubstring, 1, m.lnNextMatchBraceAt))
						ELSE
							m.lnNextMatchBraceAt = AT(m.lcMatchBraceChar, m.lcSubstring, m.lnMatchBraceOccurence - 1)
							EXIT
						ENDIF
					ENDDO
					m.llFoundMatchBrace = (m.lnNextMatchBraceAt > 0)
				ENDIF
			ENDCASE
			IF m.llFoundMatchBrace
				IF m.llCompensate
					m.lnReturnPositionOfMatch = (m.lnNextMatchBraceAt + m.tnStartBracePosition - 1) && must compensate for the fact that AT() was on Substring
				ELSE
					m.lnReturnPositionOfMatch = m.lnNextMatchBraceAt
				ENDIF
			ENDIF
		ENDIF

		RETURN (m.lnReturnPositionOfMatch)
	ENDPROC


	PROTECTED PROCEDURE serializekey
		LPARAMETERS tcJSONKey

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Rename a JSON key
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tcJSONKey
		*!*			A string representing a valid JSON key
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		String - JSON Key
		*********************************************************************

		LOCAL lcReturnJustKey,lnAlias

		m.lcReturnJustKey = tcJSONKey
		
		IF  !ISNULL(THIS.PropertyAlias[1])
			m.lnAlias = ascan(THIS.PropertyAlias,m.lcReturnJustKey,-1,-1,1,8)
			IF !EMPTY(m.lnAlias)
				m.lcReturnJustKey = THIS.PropertyAlias[m.lnAlias,2]
			ENDIF
		ENDIF
		
		RETURN (m.lcReturnJustKey)
	ENDPROC

	PROTECTED PROCEDURE deserializekey
		LPARAMETERS tcJSONKey

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Strip off superfluous characters from a JSON key
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tcJSONKey
		*!*			A string representing a valid JSON key
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		String - JSON Key
		*********************************************************************

		LOCAL lcReturnJustKey,lnAlias

		m.lcReturnJustKey = GETWORDNUM(m.tcJSONKey, 1, ":") && strip the : if it exists
		m.lcReturnJustKey = STRTRAN(m.lcReturnJustKey,["],"") && strip the " if they exist
		m.lcReturnJustKey = ALLTRIM(m.lcReturnJustKey)

		IF  !ISNULL(THIS.PropertyAlias[1])
			m.lnAlias = ascan(THIS.PropertyAlias,m.lcReturnJustKey,-1,-1,2,8)
			IF !EMPTY(m.lnAlias)
				m.lcReturnJustKey = THIS.PropertyAlias[m.lnAlias,1]
			ENDIF
		ENDIF
		
		RETURN (m.lcReturnJustKey)
	ENDPROC

	PROTECTED PROCEDURE createnewobject
		LPARAMETERS tvClassOrInstance, tcClassModule

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Allow an instance or class to be created based on what is sent
		*!*		in or This.DefaultClass and This.DefaultModule
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tvClassOrInstance (optional)
		*!*			Class string or Object instance that you want used when creating and/or returning
		*!*		tcClassModule (optional)
		*!*			Class module to use when creating an instance of the tvClassOrInstance
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		Object or NULL
		*********************************************************************

		LOCAL loReturnNewObject, lcParamType

		m.loReturnNewObject = NULL
		m.lcTypeOfParamType = VARTYPE(m.tvClassOrInstance)
		IF m.lcTypeOfParamType = "O"
			m.loReturnNewObject = m.tvClassOrInstance
		ELSE
			IF m.lcTypeOfParamType != "C" OR EMPTY(m.tvClassOrInstance)
				m.tvClassOrInstance = THIS.DefaultClass
				m.tcClassModule = THIS.DefaultModule
			ENDIF
			IF VARTYPE(m.tcClassModule) = "C" AND !EMPTY(m.tcClassModule)
				m.loReturnNewObject = NEWOBJECT(m.tvClassOrInstance, m.tcClassModule)
			ELSE
				IF EMPTY(m.tvClassOrInstance)
					m.tvClassOrInstance = "Empty"
				ENDIF
				m.loReturnNewObject = CREATEOBJECT(m.tvClassOrInstance)
			ENDIF
		ENDIF

		RETURN (m.loReturnNewObject)
	ENDPROC


	PROTECTED PROCEDURE getuniquealias
		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Get a unique (unused) name for an alias
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		String - unique and unused alias
		*********************************************************************

		LOCAL lcReturnUniqueAlias

		m.lcReturnUniqueAlias = SYS(2015)

		DO WHILE USED(m.lcReturnUniqueAlias)
			m.lcReturnUniqueAlias = SYS(2015)
		ENDDO

		RETURN (m.lcReturnUniqueAlias)
	ENDPROC


	PROTECTED PROCEDURE getbeginningoftoken
		LPARAMETERS tcJSONString, tnStringLength, tnStartPosition

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Find the start position of a token
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tcJSONString
		*!*			A string representing valid JSON
		*!*		tnStringLength
		*!*			Total length of the string sent in
		*!*		tnStartPosition
		*!*			Position to start looking within the tcJSONString for the beginning of a token 
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		Numeric - Position of the beginning of the TokenText
		*********************************************************************

		LOCAL lnCharCounter, lcChar, lnReturnBeginningPosition

		IF VARTYPE(m.tnStartPosition) != "N"
			m.tnStartPosition = 1
		ENDIF
		IF VARTYPE(m.tnStringLength) != "N"
			m.tnStringLength = LEN(m.tcJSONString)
		ENDIF

		m.lnReturnBeginningPosition = 1
		m.lnCharCounter = m.tnStartPosition

		DO WHILE m.lnCharCounter <= m.tnStringLength
			m.lcChar = SUBSTR(m.tcJSONString, m.lnCharCounter, 1)
			DO CASE
			CASE INLIST(m.lcChar, "{", "[")
				m.lnReturnBeginningPosition = m.lnCharCounter
				EXIT
			CASE INLIST(m.lcChar, ",", ":")
				m.lnReturnBeginningPosition = m.lnCharCounter + 1
				EXIT
			OTHERWISE
				m.lnCharCounter = m.lnCharCounter + 1
			ENDCASE
		ENDDO

		RETURN (m.lnReturnBeginningPosition)
	ENDPROC


	PROTECTED PROCEDURE isstringiso8601
		LPARAMETERS tcStringToCheck

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Check whether a date string is valid according to ISO8601 standard
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tcStringToCheck
		*!*			A string to validate against ISO8601
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		Logical - indicating whether or not the string sent in is a valid ISO8601 Datetime string
		*********************************************************************

		LOCAL llReturnIsValidISO8601

		m.llReturnIsValidISO8601 = ISDIGIT(SUBSTR(m.tcStringToCheck,2))
		m.llReturnIsValidISO8601 = (m.llReturnIsValidISO8601 AND BETWEEN(OCCURS("-", m.tcStringToCheck), 2, 3))
		m.llReturnIsValidISO8601 = (m.llReturnIsValidISO8601 AND BETWEEN(OCCURS(":", m.tcStringToCheck),2,3))

		RETURN (m.llReturnIsValidISO8601)
	ENDPROC
	

	PROTECTED PROCEDURE isstringdate
		LPARAMETERS tcStringToCheck

		*********************************************************************
		*!* PURPOSE
		*********************************************************************
		*!*		Check string is a valid date
		*********************************************************************
		*!* PARAMETERS
		*********************************************************************
		*!*		tcStringToCheck
		*!*			A string to validate
		*********************************************************************
		*!*	RETURN
		*********************************************************************
		*!*		Logical - indicating whether or not the string sent in is a Date string
		*********************************************************************

		LOCAL llReturnIsDate

		m.llReturnIsDate = ISDIGIT(SUBSTR(m.tcStringToCheck,2)) AND ISDIGIT(SUBSTR(m.tcStringToCheck,3)) AND ;
						   ISDIGIT(SUBSTR(m.tcStringToCheck,4)) AND ISDIGIT(SUBSTR(m.tcStringToCheck,5)) AND ;
						   ISDIGIT(SUBSTR(m.tcStringToCheck,7)) AND ISDIGIT(SUBSTR(m.tcStringToCheck,8)) AND ;
						   ISDIGIT(SUBSTR(m.tcStringToCheck,10)) AND ISDIGIT(SUBSTR(m.tcStringToCheck,11))
		m.llReturnIsDate = (m.llReturnIsDate AND OCCURS("-", m.tcStringToCheck) = 2)

		RETURN (m.llReturnIsDate)
	ENDPROC


	*-- Returns a datetime for a given year based on a relative SYSTEMTIME structure.
	PROTECTED PROCEDURE getrelativedatetime
		LPARAMETERS	tcSystemtimeStructure, tnTargetYear

		LOCAL ltReturnDatetime, lnYear, lnMonth, lnDOW, lnDay, lnHour, lnMinute, lnSecond

		*!* check parameters
		m.tcSystemtimeStructure = IIF(VARTYPE(m.tcSystemtimeStructure) = "C", m.tcSystemtimeStructure, SPACE(16))
		m.tnTargetYear = IIF(VARTYPE(m.tnTargetYear) = "N", m.tnTargetYear, YEAR(DATE()))

		*!* process SYSTEMTIME structure
		m.lnYear = CTOBIN(SUBSTR(m.tcSystemtimeStructure, 1, 2), "2SR")
		m.lnMonth = CTOBIN(SUBSTR(m.tcSystemtimeStructure, 3, 2), "2SR")
		m.lnDoW = CTOBIN(SUBSTR(m.tcSystemtimeStructure, 5, 2), "2SR")
		m.lnDay = CTOBIN(SUBSTR(m.tcSystemtimeStructure, 7, 2), "2SR")
		m.lnHour = CTOBIN(SUBSTR(m.tcSystemtimeStructure, 9, 2), "2SR")
		m.lnMinute = CTOBIN(SUBSTR(m.tcSystemtimeStructure, 11, 2), "2SR")
		m.lnSecond = CTOBIN(SUBSTR(m.tcSystemtimeStructure, 13, 2), "2SR")
		*!* m.lnMSec = CTOBIN(SUBSTR(m.tcSysTimeStruc, 15, 2), "2SR")

		IF INLIST(m.lnYear, 0, m.tnTargetYear) && does it occur on a yearly basis or on the target year only?
			m.lnDay = THIS.GetOccurenceDay(m.tnTargetYear, m.lnMonth, m.lnDoW, m.lnDay)
			m.ltReturnDatetime = DATETIME(m.tnTargetYear, m.lnMonth, m.lnDay, m.lnHour, m.lnMinute, m.lnSecond)
		ELSE && occurs one time only and not on the target year
			m.ltReturnDatetime = {// ::}
		ENDIF

		RETURN (m.ltReturnDatetime)

		******************************************************************************************
		*!*  According to http://msdn.microsoft.com/en-us/library/ms725481(VS.85).aspx         *!*
		*!*  the SYSTEMTIME structures embedded in the TIME_ZONE_INFORMATION Structure         *!*
		*!*  in most cases do not represent absolute but relative figures:                     *!*
		*!*                                                                                    *!*
		*!*      ...To select the correct day in the month, set the wYear member to zero,      *!*
		*!*      the wHour and wMinute members to the transition time, the wDayOfWeek member   *!*
		*!*      to the appropriate weekday, and the wDay member to indicate the occurrence    *!*
		*!*      of the day of the week within the month (1 to 5, where 5 indicates the final  *!*
		*!*      occurrence during the month if that day of the week does not occur 5 times).  *!*
		*!*                                                                                    *!*
		*!*      Using this notation, specify 02:00 on the first Sunday in April as follows:   *!*
		*!*      wHour = 2, wMonth = 4, wDayOfWeek = 0, wDay = 1.                              *!*
		*!*      Specify 02:00 on the last Thursday in October as follows:                     *!*
		*!*      wHour = 2, wMonth = 10, wDayOfWeek = 4, wDay = 5.                             *!*
		*!*                                                                                    *!*
		*!*      If the wYear member is not zero, the transition date is absolute; it will     *!*
		*!*      only occur one time. Otherwise, it is a relative date that occurs yearly.     *!*
		******************************************************************************************
	ENDPROC


	*-- Returns day for a given year, month, DOW, and occurrence.
	PROTECTED PROCEDURE getoccurenceday
		***********************************************************
		*!*  Calculate date from given Weekday and occurrence	*!*
		*!*  for a specific Year and Month. An occurrence of	*!*
		*!*  5 means last occurrence in the month				*!*
		***********************************************************
		LPARAMETERS	tnTargetYear, tnTargetMonth, tnTargetDOW, tnTargetOccurrence

		LOCAL lnReturnRelativeDay, ldCurrentDate, ldRelativeDate
		LOCAL ldTargetMonthFirstDay, ldTargetMonthLastDay
		LOCAL lnFirstDayDOW, lnAdditionalDaysNeeded

		*!* check parameters
		m.ldCurrentDate = DATE()
		m.tnTargetYear = IIF(VARTYPE(tnTargetYear) = "N", m.tnTargetYear, YEAR(m.ldCurrentDate))
		m.tnTargetMonth = IIF(VARTYPE(tnTargetMonth) = "N", m.tnTargetMonth, MONTH(m.ldCurrentDate)) && Month: 1...12
		m.tnTargetDOW = IIF(VARTYPE(tnTargetDOW) = "N", m.tnTargetDOW, 0) && 0=Sunday ... 6=Saturday
		m.tnTargetOccurrence = IIF(VARTYPE(tnTargetOccurrence) = "N", MIN(MAX(m.tnTargetOccurrence,1),5), 5) && 1 ... 5

		*!* begin finding the specific day that matches the target year, month, DOW, and occurrence
		*!* that was sent into this function
		m.ldTargetMonthFirstDay = DATE(m.tnTargetYear, m.tnTargetMonth, 1)
		m.lnFirstDayDOW = (DOW(m.ldTargetMonthFirstDay) - 1) && SYSTEMTIME structures use 0 based DOW
		m.ldTargetMonthLastDay = (GOMONTH(m.ldTargetMonthFirstDay, 1) - 1)

		IF m.tnTargetDOW < m.lnFirstDayDOW
			m.lnAdditionalDaysNeeded = (m.tnTargetDOW - m.lnFirstDayDOW)
		ELSE
			m.lnAdditionalDaysNeeded = (m.tnTargetDOW - m.lnFirstDayDOW - 7)
		ENDIF

		*!* Take tnTargetOccurrence into consideration
		m.lnAdditionalDaysNeeded = m.lnAdditionalDaysNeeded + (m.tnTargetOccurrence * 7)

		m.ldRelativeDate = m.ldTargetMonthFirstDay + m.lnAdditionalDaysNeeded

		*!* 5th occurrence may have erroneously pushed us into the next month
		IF m.tnTargetOccurrence = 5 AND m.ldRelativeDate > m.ldTargetMonthLastDay
			m.ldRelativeDate = (m.ldRelativeDate - 7)
		ENDIF

		m.lnReturnRelativeDay = DAY(m.ldRelativeDate)

		RETURN (m.lnReturnRelativeDay)
	ENDPROC


	PROTECTED PROCEDURE Init
		*********************************************************************
		*!* Change This.Undefined if you wish to use a different indicator for TOKENTYPE_UNDEFINED
		*!* Note: null is a valid value, so I have chosen to use the ASCII null-terminator instead
		*!* This class provides a This.IsUndefined() method that can be used publicly to determine
		*!* if This.Parse() returned an Undefined value.
		*********************************************************************
		THIS.Undefined = CHR(0)

		*-- Array of properties aliases
		THIS.AddProperty("PropertyAlias[1]",NULL)
	ENDPROC
ENDDEFINE

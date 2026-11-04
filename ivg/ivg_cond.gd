extends RefCounted
# محلل شروط المشاهد التفاعلية (IVG). بدون eval:
#   mood >= 60 && (trust > 2 || !angry)
# الاستخدام: IvgCond.check("mood >= 60", vars) -> bool
# ملاحظة: المتغير غير الموجود قيمته 0. الأسماء العربية مدعومة.

var _tk: Array = []
var _p := 0
var _vars: Dictionary = {}
var _err := ""
var _src := ""

static func check(expr, vars: Dictionary) -> bool:
	if expr == null: return true
	if typeof(expr) == TYPE_BOOL: return expr
	var s := str(expr)
	if s.strip_edges() == "": return true
	var c = load("res://ivg/ivg_cond.gd").new()
	return c._run(s, vars)

static func _is_digit(c: int) -> bool:
	return c >= 48 and c <= 57

static func _is_id_start(c: int) -> bool:
	return (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95 or (c >= 0x0600 and c <= 0x06FF)

static func _is_id(c: int) -> bool:
	return _is_id_start(c) or _is_digit(c)

func _fail(msg: String):
	if _err == "": _err = msg + ": " + _src

func _tokenize(s: String) -> Array:
	var out: Array = []
	var i := 0
	var n := s.length()
	while i < n:
		var c := s.unicode_at(i)
		if c == 32 or c == 9 or c == 10 or c == 13:
			i += 1
			continue
		if _is_digit(c):
			var j := i
			while j < n and (_is_digit(s.unicode_at(j)) or s[j] == "."):
				j += 1
			out.append({"t": "num", "v": float(s.substr(i, j - i))})
			i = j
			continue
		if s[i] == "\"" or s[i] == "'":
			var e := s.find(s[i], i + 1)
			if e < 0:
				_fail("نص ما انقفل")
				return out
			out.append({"t": "str", "v": s.substr(i + 1, e - i - 1)})
			i = e + 1
			continue
		var two := s.substr(i, 2)
		if two in ["&&", "||", "==", "!=", ">=", "<="]:
			out.append({"t": "op", "v": two})
			i += 2
			continue
		if s[i] in ["<", ">", "!", "(", ")", "+", "-", "*", "/"]:
			out.append({"t": "op", "v": s[i]})
			i += 1
			continue
		if _is_id_start(c):
			var j2 := i
			while j2 < n and _is_id(s.unicode_at(j2)):
				j2 += 1
			var w := s.substr(i, j2 - i)
			if w == "true": out.append({"t": "num", "v": 1.0})
			elif w == "false": out.append({"t": "num", "v": 0.0})
			else: out.append({"t": "var", "v": w})
			i = j2
			continue
		_fail("شرط غلط عند " + s.substr(i))
		return out
	return out

func _run(expr: String, vars: Dictionary) -> bool:
	_src = expr
	_vars = vars
	_p = 0
	_err = ""
	_tk = _tokenize(expr)
	if _err != "":
		push_warning("IVG: " + _err)
		return false
	var r = _or()
	if _err == "" and _p < _tk.size(): _fail("شرط فيه زيادة")
	if _err != "":
		push_warning("IVG: " + _err)
		return false
	return _truthy(r)

func _peek(v: String) -> bool:
	return _p < _tk.size() and _tk[_p]["t"] == "op" and _tk[_p]["v"] == v

static func _num(v) -> float:
	match typeof(v):
		TYPE_BOOL: return 1.0 if v else 0.0
		TYPE_INT, TYPE_FLOAT: return float(v)
		TYPE_STRING:
			return float(v) if String(v).is_valid_float() else 0.0
	return 0.0

static func _truthy(v) -> bool:
	if typeof(v) == TYPE_STRING: return String(v) != ""
	return _num(v) != 0.0

static func _eq(a, b) -> bool:
	if typeof(a) == TYPE_STRING or typeof(b) == TYPE_STRING:
		if String(str(a)).is_valid_float() and String(str(b)).is_valid_float():
			return float(str(a)) == float(str(b))
		return str(a) == str(b)
	return _num(a) == _num(b)

func _prim():
	if _p >= _tk.size():
		_fail("شرط ناقص")
		return 0.0
	var x: Dictionary = _tk[_p]
	_p += 1
	match x["t"]:
		"num", "str":
			return x["v"]
		"var":
			return _vars.get(x["v"], 0.0)
		"op":
			if x["v"] == "(":
				var r = _or()
				if _peek(")"): _p += 1
				else: _fail("قوس ناقص")
				return r
			if x["v"] == "!":
				return 0.0 if _truthy(_prim()) else 1.0
			if x["v"] == "-":
				return -_num(_prim())
	_fail("شرط غلط")
	return 0.0

func _mul():
	var a = _prim()
	while _peek("*") or _peek("/"):
		var o: String = _tk[_p]["v"]
		_p += 1
		var b = _prim()
		if o == "*": a = _num(a) * _num(b)
		else: a = 0.0 if _num(b) == 0.0 else _num(a) / _num(b)
	return a

func _add():
	var a = _mul()
	while _peek("+") or _peek("-"):
		var o: String = _tk[_p]["v"]
		_p += 1
		var b = _mul()
		if o == "+": a = _num(a) + _num(b)
		else: a = _num(a) - _num(b)
	return a

func _cmp():
	var a = _add()
	while _p < _tk.size() and _tk[_p]["t"] == "op" and _tk[_p]["v"] in ["==", "!=", ">=", "<=", ">", "<"]:
		var o: String = _tk[_p]["v"]
		_p += 1
		var b = _add()
		var r := false
		match o:
			"==": r = _eq(a, b)
			"!=": r = not _eq(a, b)
			">=": r = _num(a) >= _num(b)
			"<=": r = _num(a) <= _num(b)
			">": r = _num(a) > _num(b)
			"<": r = _num(a) < _num(b)
		a = 1.0 if r else 0.0
	return a

func _and():
	var a = _cmp()
	while _peek("&&"):
		_p += 1
		var b = _cmp()
		a = 1.0 if (_truthy(a) and _truthy(b)) else 0.0
	return a

func _or():
	var a = _and()
	while _peek("||"):
		_p += 1
		var b = _and()
		a = 1.0 if (_truthy(a) or _truthy(b)) else 0.0
	return a

-- Copyright 2019 云风 https://github.com/cloudwu . All rights reserved.
-- License (the same with bgfx) : https://github.com/bkaradzic/bgfx/blob/master/LICENSE

local idl = {}

local all_types = {}

local function copy_attribs(to, from)
	assert(type(from) == "table", "Attribs should be a table")
	for k, v in pairs(from) do
		if type(k) == "number" then
			to[v] = true
		else
			to[k] = v
		end
	end
end

local function typedef(_, typename)
	assert(all_types[typename] == nil, "Duplicate type")
	local t = {}
	all_types[typename] = t
	local function type_attrib(attrib)
		copy_attribs(t, attrib)
	end
	return function(cname)
		local typ = type(cname)
		if typ == "table" then
			type_attrib(cname)
			return
		end
		assert(typ == "string" , "type should be a string")
		t.cname = cname
		return type_attrib
	end
end

idl.typedef = setmetatable({} , { __index = typedef, __call = typedef })
idl.types = all_types

local function enumdef(_, typename)
	assert(all_types[typename] == nil, "Duplicate type (Enum)")

	local t = { enum = {} }
	all_types[typename] = t

	local function enum_attrib(obj, attribs)
		copy_attribs(t, attribs)
		return obj
	end

	local function new_enum_item(_, itemname)
		local item = { name = itemname }
		t.enum[#t.enum + 1] = item
		local function add_attrib_or_comment(obj , attribs)
			if type(attribs) == "string" then
				item.comment = attribs
			elseif attribs then
				copy_attribs(item, attribs)
			end
			return obj
		end
		return setmetatable({}, { __index = new_enum_item, __call = add_attrib_or_comment })
	end

	return setmetatable({}, { __index = new_enum_item , __call = enum_attrib })
end

idl.enum = setmetatable({} , { __index = enumdef, __call = enumdef })

local function structdef(_, typename)
	assert(all_types[typename] == nil, "Duplicate type (Struct)")
	local t = { struct = {} }
	all_types[typename] = t

	local function struct_attrib(obj, attribs)
		copy_attribs(t, attribs)
		return obj
	end

	local function new_struct_item(_, itemname)
		local item = { name = itemname }
		t.struct[#t.struct + 1] = item

		local function item_attrib(obj, attribs)
			if type(attribs) == "string" then
				item.comment = attribs
			else
				copy_attribs(item, attribs)
			end
			return obj
		end

		return function (itemtype)
			item.fulltype = itemtype
			return setmetatable({}, { __index = new_struct_item, __call = item_attrib })
		end
	end

	return setmetatable({}, { __index = new_struct_item , __call = struct_attrib })
end

idl.struct = setmetatable({}, { __index = structdef , __call = structdef })

local function handledef(_, typename)
	assert(all_types[typename] == nil, "Duplicate type (Handle)")

	local t = { handle = true }
	all_types[typename] = t

	return function (attribs)
		copy_attribs(t, attribs)
		return obj
	end
end

idl.handle = setmetatable({} , { __index = handledef, __call = handledef })

local all_funcs = {}

local function duplicate_arg_name(name)
	error ("Duplicate arg name " .. name)
end

local function funcdef(_, funcname)
	local f = { name = funcname , args = {} }
	all_funcs[#all_funcs+1] = f
	local args
	local function args_desc(obj, args_name)
		obj[args_name] = duplicate_arg_name
		return function (fulltype)
			local arg = {
				name = "_" .. args_name,
				fulltype = fulltype,
			}
			f.args[#f.args+1] = arg
			local function arg_attrib(_, attrib )
				copy_attribs(arg, attrib)
				return args
			end
			return setmetatable( {} , {
				__index = function(_, name)
					return args_desc(obj, name)
				end
				, __call = arg_attrib } )
		end
	end
	args = setmetatable({}, { __index = args_desc })
	local function rettype(value)
		assert(type(value) == "string", "Need return type")
		f.ret = { fulltype = value }
		return args
	end

	local function funcdef(value)
		if type(value) == "table" then
			copy_attribs(f, value)
			return rettype
		end
		return rettype(value)
	end

	local function classfunc(_, methodname)
		f.class = f.name
		f.name = methodname
		return funcdef
	end

	return setmetatable({} , { __index = classfunc, __call = function(_, value) return funcdef(value) end })
end

idl.func = setmetatable({}, { __index = funcdef })
idl.funcs = all_funcs

idl.out = "out"
idl.const = "const"
idl.ctor = "ctor"
idl.NULL = "NULL"
idl.UINT16_MAX = "UINT16_MAX"
idl.INT32_MAX = "INT32_MAX"
idl.UINT32_MAX = "UINT32_MAX"
idl.UINT8_MAX = "UINT8_MAX"

local all_comments = {}
idl.comments = all_comments

local function comment(_, what)
	local comments = all_comments[what]
	if comments == nil then
		comments = {}
		all_comments[what] = comments
	end
	return function(comment)
		assert(type(comment) == "string" , "Doxygen comment should be a string")
		comments[#comments + 1] = comment
	end
end

idl.comment = setmetatable({} , { __index = comment })

return setmetatable(idl , { __index = function (_, keyword)
	error (tostring(keyword) .. " is invalid")
	end})

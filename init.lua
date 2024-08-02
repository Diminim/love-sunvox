local path = ...

local function require_relative(p)
	return require(table.concat({path, p}, "."))
end

local function load_external_library(local_path, library_name)
   local lib_path = love.filesystem.getSource() .. "/" .. local_path
   local extension = jit.os == "Windows" and "dll" or jit.os == "Linux" and "so" or jit.os == "OSX" and "dylib"

   if love.filesystem.isFused() then
      local file_directory = "/"..local_path
      local file_name = ("%s.%s"):format(library_name, extension)
      love.filesystem.write(file_name, love.filesystem.read(file_directory.."/"..file_name))
      package.cpath = string.format("%s;%s/?.%s", package.cpath, love.filesystem.getSaveDirectory(), extension)
   else
      package.cpath = string.format("%s;%s/?.%s", package.cpath, lib_path, extension)
   end
end

load_external_library(string.gsub(path, "%.", "/"), "sunvox")

require_relative("cdef")

local wrap = require_relative("wrap")

return wrap
--[[
   Areia_SQLiteDB
-- Usage:
sqlitedb = require "areia_sqlitedb"

-- Create a new DB object at the default location.
-- Default is Mushclient/worlds/main.db if no plugin data can be found (i.e.,
-- if running from the main script file). Otherwise, it is
-- <plugin_directory>/<plugin_name>.db.
-- This is where the DB file and any backups are written.
db = sqlitedb:new()

-- Create a DB object in a location other than the default.
db = sqlitedb:new{path="/", name="test.db"}

-- Open the DB if it is not already open. This also turns foreign keys func-
-- tionality on. Also not usually strictly necessary, as exec and select methods
-- do this themselves.
db:open()

-- Execute a SQL statement. Pass false as second argument to suppress checking
-- of return codes. This will not check the return code. Also may pass a call-
-- back function as third argument.
db:exec("CREATE TABLE test(id INTEGER);", false)

-- Execute another SQL statement. This will display an error if the return
-- code is not ok/done/row.
db:exec("INSERT INTO test VALUES (1);")

-- Get the number of changes made.
changes = db:changes()

-- Query the DB.
rows = db:select("SELECT * FROM test;")
tprint(rows)

-- Vacuum the DB. Return value is the number of KB recovered by the operation.
kbRecovered = db:vacuum()

-- Backup the DB. Returns true or false, depending on success. Will not backup
-- a DB file that fails an integrity check. The backup is written in the same
-- directory in which the DB file itself is stored.
success = db:backup()

-- Close the DB if it is open.
db:close()

-- Also available are the size() and integrity() methods, which return, re-
-- spectively, the size (in KB) of the DB file and whether or not it passes an
-- integrity check.
]]


SQLiteDB = {
    path = GetPluginInfo(GetPluginID(), 20) or GetInfo(67),
    name = (GetPluginInfo(GetPluginID(), 1) or "main"):lower() .. ".db",
    db = nil,
}


function SQLiteDB:new(db)
    db = db or {}
    setmetatable(db, self)
    self.__index = self
    return db
end


function SQLiteDB:open()
    if (self.db == nil or not self.db:isopen()) then
        self.db = assert(
            sqlite3.open(self.path .. self.name),
            "Failed to open file."
        )
        self:exec("PRAGMA foreign_keys=on;")
    end
end


function SQLiteDB:close()
    if (self.db and self.db:isopen()) then
        self.db:close()
    end
    self.db = nil
end


function SQLiteDB:changes()
    return self.db:changes()
end


function SQLiteDB:check(code)
    if (code ~= sqlite3.OK
    and code ~= sqlite3.ROW
    and code ~= sqlite3.DONE) then
        local errmsg = self.db:errmsg()
        self.db:execute("ROLLBACK;")
        error(errmsg, 2)
    end
end


function SQLiteDB:exec(sql, check, callback)
    self:open()
    local code = self.db:execute(sql, callback)
    if (check ~= false) then
        self:check(code)
    end
    return code
end


function SQLiteDB:select(sql)
    self:open()
    local rows = {}
    for row in self.db:nrows(sql) do
        table.insert(rows, row)
    end
    return rows
end


function SQLiteDB:size()
    local file = assert(io.open(self.path .. self.name), "Failed to open file.")
    local bytes = file:seek("end")
    file:close()
    return bytes / 1024 -- convert to KB
end


function SQLiteDB:vacuum()
    local sizeBefore = self:size()
    self:exec("VACUUM;")
    local sizeAfter = self:size()
    return sizeBefore - sizeAfter
end


function SQLiteDB:integrity()
    local result = self:select("PRAGMA integrity_check;")
    return #result == 1 and result[1].integrity_check == "ok"
end


function SQLiteDB:backup()
    if (not self:integrity()) then
        return false
    end

    self:close()
    local original = assert(
        io.open(self.path .. self.name, "rb"),
        "Failed to open original file."
    )
    local data = original:read("*a")
    original:close()

    local backup = assert(
        io.open(self.path .. self.name .. ".backup", "wb"),
        "Failed to open backup file."
    )
    backup:write(data)
    backup:close()

    self:open()
    return true
end


return SQLiteDB

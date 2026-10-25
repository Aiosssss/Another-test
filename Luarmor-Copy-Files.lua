-- Luarmor file copier for the script identified below.
-- Reads files / fetches public Lua; never executes the copied contents.
-- Run the original loader separately first if you want its local cache.
-- Exports ONE selected file as numbered Base64 packets, with checksums.
local SCRIPT_ID = "20a3558e57a0b4dca7cb38cfca83c56e"
local CACHE_DIR = "static_content_170926"
local INIT_FILE = CACHE_DIR .. "/init-a8a80fe17b2-ocend.lua"
local LOADER_URL = "https://api.luarmor.net/files/v4/loaders/" .. SCRIPT_ID .. ".lua"
local RUNTIME_URL = "https://cdn.luarmor.net/v4_init_ocendmz.lua"
local CHUNK_BYTES = 180000
local MAX_BYTES = 12 * 1024 * 1024

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local env = _G
if type(getgenv) == "function" then
    local ok, value = pcall(getgenv)
    if ok and type(value) == "table" then env = value end
end
local function resolve(name, fallback)
    if type(env[name]) == "function" then return env[name] end
    if type(fallback) == "function" then return fallback end
end
local read = resolve("readfile", readfile)
local list = resolve("listfiles", listfiles)
local folder = resolve("isfolder", isfolder)
local clipboard = resolve("setclipboard", setclipboard) or resolve("toclipboard", toclipboard)

local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function base64(data)
    local out, count = {}, 0
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        count = count + 1
        out[count] = alphabet:sub(math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1)
            .. alphabet:sub(math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
            .. (b and alphabet:sub(math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1) or "=")
            .. (c and alphabet:sub(n % 64 + 1, n % 64 + 1) or "=")
        if i % 24000 == 1 and i > 1 then task.wait() end
    end
    return table.concat(out)
end
local function adler32(data)
    local a, b = 1, 0
    for i = 1, #data do
        a = (a + data:byte(i)) % 65521
        b = (b + a) % 65521
        if i % 120000 == 0 then task.wait() end
    end
    return string.format("%08x", b * 65536 + a)
end
local function basename(path)
    return tostring(path):gsub("\\", "/"):match("([^/]+)/*$") or tostring(path)
end
local function packet(data, name, source, checksum, index)
    local total = math.max(1, math.ceil(#data / CHUNK_BYTES))
    local chunk = data:sub((index - 1) * CHUNK_BYTES + 1, index * CHUNK_BYTES)
    local info = {
        format = "LUARMOR_FILE_EXPORT_V1", script_id = SCRIPT_ID,
        filename = name, source = source, total_bytes = #data,
        file_adler32 = checksum, part = index, parts = total,
        chunk_bytes = #chunk, chunk_adler32 = adler32(chunk),
        encoding = "base64", data = base64(chunk)
    }
    return "---BEGIN LUARMOR_FILE_EXPORT_V1---\n" .. HttpService:JSONEncode(info)
        .. "\n---END LUARMOR_FILE_EXPORT_V1---", total
end

local previous = env.LuarmorFileCopierUI
if typeof(previous) == "Instance" then pcall(function() previous:Destroy() end) end
local gui = Instance.new("ScreenGui")
gui.Name = "LuarmorFileCopier"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local player = Players.LocalPlayer
local parented = false
if type(gethui) == "function" then
    local ok, parent = pcall(gethui)
    if ok and parent then parented = pcall(function() gui.Parent = parent end) end
end
if not parented then gui.Parent = player:WaitForChild("PlayerGui") end
env.LuarmorFileCopierUI = gui

local navy = Color3.fromRGB(20, 26, 38)
local panel = Color3.fromRGB(33, 42, 58)
local white = Color3.fromRGB(236, 240, 247)
local muted = Color3.fromRGB(174, 185, 204)
local orange = Color3.fromRGB(245, 155, 68)
local function make(class, props, parent)
    local item = Instance.new(class)
    for key, value in pairs(props) do item[key] = value end
    item.Parent = parent
    return item
end
local function round(item, radius)
    make("UICorner", {CornerRadius = UDim.new(0, radius or 9)}, item)
end
local frame = make("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromScale(0.94, 0.88), BackgroundColor3 = navy, BorderSizePixel = 0
}, gui)
round(frame, 14)
make("UISizeConstraint", {MaxSize = Vector2.new(560, 620), MinSize = Vector2.new(260, 330)}, frame)
local function label(text, position, size, parent, color)
    return make("TextLabel", {
        Text = text, Position = position, Size = size, BackgroundTransparency = 1,
        TextColor3 = color or white, TextSize = 14, Font = Enum.Font.Gotham,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center
    }, parent or frame)
end
local title = label("Luarmor · Salin file", UDim2.new(0, 16, 0, 10), UDim2.new(1, -68, 0, 30))
title.Font = Enum.Font.GothamBold
title.TextSize = 19
local function button(text, pos, size, parent)
    local b = make("TextButton", {
        Text = text, Position = pos, Size = size, BackgroundColor3 = panel,
        BorderSizePixel = 0, TextColor3 = white, TextSize = 13,
        TextWrapped = true, Font = Enum.Font.GothamMedium, AutoButtonColor = true
    }, parent or frame)
    round(b)
    return b
end
local close = button("X", UDim2.new(1, -44, 0, 10), UDim2.new(0, 30, 0, 30))
close.Activated:Connect(function() gui:Destroy() end)
label("Pilih file milik script ini. Cache dapat berisi script lain. Hasil salinan bisa tetap disamarkan atau terenkripsi.",
    UDim2.new(0, 16, 0, 43), UDim2.new(1, -32, 0, 34), nil, muted).TextSize = 12
local scan = button("Baca cache", UDim2.new(0, 16, 0, 83), UDim2.new(0.32, -12, 0, 32))
local loader = button("Ambil loader", UDim2.new(0.32, 8, 0, 83), UDim2.new(0.34, -12, 0, 32))
local runtime = button("Ambil runtime", UDim2.new(0.66, 4, 0, 83), UDim2.new(0.34, -20, 0, 32))
local files = make("ScrollingFrame", {
    Position = UDim2.new(0, 16, 0, 123), Size = UDim2.new(1, -32, 1, -283),
    BackgroundColor3 = panel, BorderSizePixel = 0, ScrollBarThickness = 5,
    CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y
}, frame)
round(files)
make("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, files)
make("UIPadding", {PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5),
    PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5)}, files)
local selectedLabel = label("Belum ada file dipilih.", UDim2.new(0, 16, 1, -155), UDim2.new(1, -32, 0, 38))
local status = label("Jalankan loader asli dahulu untuk membuat cache, lalu tekan Baca cache.",
    UDim2.new(0, 16, 1, -113), UDim2.new(1, -32, 0, 49), nil, muted)
local prev = button("<", UDim2.new(0, 16, 1, -59), UDim2.new(0, 42, 0, 34))
local copy = button("Salin bagian", UDim2.new(0, 65, 1, -59), UDim2.new(1, -130, 0, 34))
copy.BackgroundColor3 = orange
copy.TextColor3 = navy
local nextButton = button(">", UDim2.new(1, -58, 1, -59), UDim2.new(0, 42, 0, 34))
label("Tempel setiap bagian ke satu .txt, lalu lampirkan file itu di chat.",
    UDim2.new(0, 16, 1, -24), UDim2.new(1, -32, 0, 23), nil, muted).TextSize = 10

local selected, part, busy = nil, 1, false
local function alive() return gui.Parent ~= nil end
local function setStatus(text) if alive() then status.Text = text end end
local function update()
    if not selected then return end
    local total = math.max(1, math.ceil(#selected.data / CHUNK_BYTES))
    selectedLabel.Text = selected.name .. "\n" .. #selected.data .. " byte · " .. total .. " bagian"
    copy.Text = "Salin bagian " .. part .. "/" .. total
end
local function work(fn)
    if busy then return end
    busy = true
    task.spawn(function()
        local ok = pcall(fn)
        if not ok then setStatus("Gagal membaca atau menyalin. Coba pilih ulang file atau salin lagi.") end
        busy = false
    end)
end
local function choose(name, source, getter)
    work(function()
        setStatus("Membaca " .. name .. "...")
        local ok, data = pcall(getter)
        if not ok or type(data) ~= "string" then
            setStatus("File atau unduhan tidak bisa dibaca oleh executor ini.")
            return
        end
        if #data == 0 or #data > MAX_BYTES then
            setStatus("File kosong atau melebihi batas 12 MB.")
            return
        end
        local checksum = adler32(data)
        selected = {name = name, source = source, data = data, checksum = checksum}
        part = 1
        if alive() then update() end
        if data:find("Your executor is not supported by Luarmor", 1, true) then
            setStatus("Ini hanya pesan executor tidak didukung. Pilih file cache lain untuk diperiksa.")
        else
            setStatus("Siap. Salin bagian 1, tempel ke .txt, tekan >, lalu ulangi sampai selesai.")
        end
    end)
end
local function addRow(name, source, getter, order)
    local row = button(name, UDim2.new(), UDim2.new(1, -5, 0, 40), files)
    row.LayoutOrder = order or 1
    row.TextXAlignment = Enum.TextXAlignment.Left
    row.TextSize = 12
    make("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, row)
    row.Activated:Connect(function() choose(basename(name), source, getter) end)
end
local function scanCache()
    if busy then return end
    for _, item in ipairs(files:GetChildren()) do
        if item:IsA("TextButton") then item:Destroy() end
    end
    local seen, count = {}, 0
    local function addPath(path)
        local normalized = path:gsub("\\", "/"):gsub("^%./", "")
        if seen[normalized] then return end
        seen[normalized] = true
        if folder then
            local ok, isDirectory = pcall(folder, path)
            if ok and isDirectory then return end
        end
        local name = basename(path)
        local lower = name:lower()
        if lower:find("key", 1, true) or lower:find("hwid", 1, true)
            or lower:find("token", 1, true) or lower:find("cookie", 1, true) then return end
        count = count + 1
        local exactPath = path
        local order = name:find(SCRIPT_ID, 1, true) and 1 or 3
        if name == basename(INIT_FILE) then order = 2 end
        addRow(name, "cache", function() return read(exactPath) end, order)
    end
    if read and list then
        local ok, paths = pcall(list, CACHE_DIR)
        if ok and type(paths) == "table" then
            table.sort(paths)
            for _, path in ipairs(paths) do
                if type(path) == "string" then
                    local normalized = path:gsub("\\", "/")
                    if not normalized:find("/", 1, true) then normalized = CACHE_DIR .. "/" .. normalized; path = normalized end
                    if normalized:find(CACHE_DIR .. "/", 1, true)
                        and not ("/" .. normalized .. "/"):find("/../", 1, true) then addPath(path) end
                end
            end
        end
    end
    if read and count == 0 then
        local ok, data = pcall(read, INIT_FILE)
        if ok and type(data) == "string" then
            addRow(basename(INIT_FILE), "cache", function() return read(INIT_FILE) end, 2)
            count = count + 1
        end
    end
    local inMemory = env.ldrupd8m or ldrupd8m
    if type(inMemory) == "string" and #inMemory > 2000 then
        local captured = inMemory
        addRow("Runtime-dari-sesi.lua", "session_runtime", function() return captured end, 0)
        count = count + 1
    end
    if count == 0 then
        setStatus("Cache belum terbaca. Jalankan loader asli lalu Baca cache, atau gunakan Ambil runtime.")
    else
        setStatus(count .. " file tersedia. Pilih yang terkait script ini. Runtime/init masih merupakan pemuat.")
    end
end
scan.Activated:Connect(scanCache)
loader.Activated:Connect(function()
    choose("Luarmor-loader-" .. SCRIPT_ID .. ".lua", "public_loader", function() return game:HttpGet(LOADER_URL) end)
end)
runtime.Activated:Connect(function()
    choose("Luarmor-v4_init_ocendmz.lua", "public_runtime", function() return game:HttpGet(RUNTIME_URL) end)
end)
prev.Activated:Connect(function()
    if selected and not busy then part = math.max(1, part - 1); update() end
end)
nextButton.Activated:Connect(function()
    if selected and not busy then
        part = math.min(math.max(1, math.ceil(#selected.data / CHUNK_BYTES)), part + 1)
        update()
    end
end)
copy.Activated:Connect(function()
    if not selected then setStatus("Pilih file dahulu dari daftar atau tombol unduhan."); return end
    if not clipboard then setStatus("Executor ini tidak menyediakan setclipboard/toclipboard."); return end
    work(function()
        local current, index = selected, part
        setStatus("Menyiapkan bagian " .. index .. "...")
        local text, total = packet(current.data, current.name, current.source, current.checksum, index)
        local ok, result = pcall(clipboard, text)
        if ok and result ~= false then
            setStatus("Bagian " .. index .. "/" .. total .. " disalin. Tempel ke .txt sebelum menekan >.")
        else
            setStatus("Clipboard gagal. Tetap di bagian ini dan coba salin lagi.")
        end
    end)
end)
scanCache()

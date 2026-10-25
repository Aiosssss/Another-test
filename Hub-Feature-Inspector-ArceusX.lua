-- Runtime UI inspection, scoped to the hub selected by the user.
-- Reads UI text and available callback metadata/constants. Does not execute
-- callbacks, hook authentication, inspect all GC objects, or dump input values.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local SCRIPT_ID = "20a3558e57a0b4dca7cb38cfca83c56e"
local CHUNK_BYTES = 90000
local env = _G
if type(getgenv) == "function" then
    local ok, result = pcall(getgenv)
    if ok and type(result) == "table" then env = result end
end
local function resolve(name, fallback)
    if type(env[name]) == "function" then return env[name] end
    if type(fallback) == "function" then return fallback end
end
local clipboard = resolve("setclipboard", setclipboard) or resolve("toclipboard", toclipboard)
local connectionsAPI = resolve("getconnections", getconnections)
local constantsAPI = resolve("getconstants", getconstants) or (type(debug) == "table" and debug.getconstants)
local upvaluesAPI = resolve("getupvalues", getupvalues) or (type(debug) == "table" and debug.getupvalues)
local infoAPI = type(debug) == "table" and debug.info
local oldInfoAPI = type(debug) == "table" and debug.getinfo

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



local LIMITS = {controls = 450, functions = 120, constants = 28, actions = 100, scans = 16}
local function readProperty(obj, name)
    local ok, value = pcall(function() return obj[name] end)
    if ok then return value end
end
local function isA(obj, class)
    local ok, value = pcall(function() return obj:IsA(class) end)
    return ok and value == true
end
local function children(obj, descendants)
    local ok, value = pcall(function()
        if descendants then return obj:GetDescendants() end
        return obj:GetChildren()
    end)
    return ok and type(value) == "table" and value or {}
end
local function sensitive(text)
    local lower = tostring(text or ""):lower()
    for _, word in ipairs({"script_key", "password", "passwd", "hwid", "cookie", "token", "secret", "accesskey", "licensekey"}) do
        if lower:find(word, 1, true) then return true end
    end
    return lower:match("%f[%a]key%f[%A]") ~= nil
end
local function clean(value, maxLength)
    local text = tostring(value or ""):gsub("[%c]", " ")
    -- Avoid exporting URLs, opaque keys, or identifiers embedded in labels.
    text = text:gsub("https?://[^%s]+", "[URL]")
    text = text:gsub("[%w_%-]+", function(word)
        if #word >= 28 then return "[opaque value]" end
        return word
    end)
    return text:sub(1, maxLength or 150)
end
local function nameOf(obj)
    return clean(readProperty(obj, "Name") or "?", 80)
end
local function privateNode(obj, root)
    local current = obj
    for _ = 1, 18 do
        if not current then break end
        if sensitive(readProperty(current, "Name")) then return true end
        if current == root then break end
        current = readProperty(current, "Parent")
    end
    return false
end
local function pathOf(obj, root)
    local path, current = {}, obj
    for _ = 1, 22 do
        if not current then break end
        table.insert(path, 1, nameOf(current))
        if current == root then break end
        current = readProperty(current, "Parent")
    end
    return table.concat(path, "/")
end
local function displayText(obj, root)
    if isA(obj, "TextBox") then
        return "[input value omitted] " .. clean(readProperty(obj, "PlaceholderText"), 80)
    end
    if privateNode(obj, root) then return "[private control omitted]" end
    local text = readProperty(obj, "Text")
    if type(text) ~= "string" then return "" end
    if sensitive(text) then return "[sensitive label omitted]" end
    return clean(text)
end
local function caps()
    return {
        getconnections = type(connectionsAPI) == "function",
        getconstants = type(constantsAPI) == "function",
        getupvalues = type(upvaluesAPI) == "function",
        debug_info = type(infoAPI) == "function" or type(oldInfoAPI) == "function",
        clipboard = type(clipboard) == "function"
    }
end
local function newSession(root)
    return {
        root = root, controls = {}, functions = {}, scans = {}, actions = {}, notes = {},
        controlIds = {}, functionIds = {}, inspectedEvents = {}, watched = {}, observation = false,
        rootName = nameOf(root), rootClass = clean(readProperty(root, "ClassName"), 50),
        createdAt = os.time(), noteSet = {}, skippedPrivate = 0
    }
end
local function note(session, message)
    if not session.noteSet[message] then
        session.noteSet[message] = true
        session.notes[#session.notes + 1] = message
    end
end
local inspectFunction
inspectFunction = function(session, fn, depth)
    if type(fn) ~= "function" then return nil end
    if session.functionIds[fn] then return session.functionIds[fn] end
    if #session.functions >= LIMITS.functions then note(session, "Function limit reached"); return nil end
    local id = "F" .. (#session.functions + 1)
    session.functionIds[fn] = id
    local item = {id = id, name = "", source = "", line = -1, constants = {}, upvalue_types = {}, table_methods = {}, linked_functions = {}}
    session.functions[#session.functions + 1] = item
    if type(infoAPI) == "function" then
        for _, field in ipairs({{"name", "n"}, {"source", "s"}, {"line", "l"}}) do
            local ok, value = pcall(infoAPI, fn, field[2])
            if ok then
                if field[1] == "line" then item.line = type(value) == "number" and value or -1
                else item[field[1]] = clean(value, 180) end
            end
        end
    elseif type(oldInfoAPI) == "function" then
        local ok, value = pcall(oldInfoAPI, fn)
        if ok and type(value) == "table" then
            item.name = clean(value.name)
            item.source = clean(value.source or value.short_src, 180)
            item.line = tonumber(value.linedefined) or -1
        end
    end
    if type(constantsAPI) == "function" then
        local ok, values = pcall(constantsAPI, fn)
        item.constants_readable = ok and type(values) == "table"
        if item.constants_readable then
            local seen, visited = {}, 0
            for _, value in pairs(values) do
                visited = visited + 1
                if visited > 160 then break end
                if type(value) == "string" and #value > 0 and #value <= 180
                    and not value:find("[^ -~]") and not sensitive(value) then
                    local text = clean(value, 180)
                    if not seen[text] and #item.constants < LIMITS.constants then
                        seen[text] = true
                        item.constants[#item.constants + 1] = text
                    end
                end
            end
        else note(session, "Some callback constants could not be read") end
    end
    if depth < 1 and type(upvaluesAPI) == "function" then
        local ok, values = pcall(upvaluesAPI, fn)
        item.upvalues_readable = ok and type(values) == "table"
        if item.upvalues_readable then
            local visited = 0
            for _, value in pairs(values) do
                visited = visited + 1
                if visited > 16 then break end
                local kind = type(value)
                item.upvalue_types[kind] = (item.upvalue_types[kind] or 0) + 1
                if kind == "function" then
                    local child = inspectFunction(session, value, depth + 1)
                    if child then item.linked_functions[#item.linked_functions + 1] = child end
                elseif kind == "table" then
                    local count = 0
                    for key, method in pairs(value) do
                        count = count + 1
                        if count > 40 then break end
                        if type(key) == "string" and not sensitive(key) and type(method) == "function" then
                            local child = inspectFunction(session, method, depth + 1)
                            if child then item.table_methods[#item.table_methods + 1] = {name = clean(key, 80), callback = child} end
                            if #item.table_methods >= 16 then break end
                        end
                    end
                end
                -- No scalar or table data values are exported.
            end
        else note(session, "Some callback upvalues could not be read") end
    end
    return id
end
local function inspectEvent(session, obj, eventName)
    if type(connectionsAPI) ~= "function" then return nil end
    local signal = readProperty(obj, eventName)
    if not signal then return nil end
    local ok, result = pcall(connectionsAPI, signal)
    if not ok or type(result) ~= "table" then
        note(session, "Some event connections could not be read")
        return {event = eventName, readable = false, callbacks = {}}
    end
    local item, visited = {event = eventName, readable = true, callbacks = {}}, 0
    for _, connection in pairs(result) do
        visited = visited + 1
        if visited > 10 then break end
        if not session.watched[connection] then
            local fn = readProperty(connection, "Function")
            local id = inspectFunction(session, fn, 0)
            if id then item.callbacks[#item.callbacks + 1] = id end
        end
    end
    return item
end
local function addControl(session, obj)
    if privateNode(obj, session.root) then session.skippedPrivate = session.skippedPrivate + 1; return nil end
    local id = session.controlIds[obj]
    local item
    if id then item = session.controls[id]
    else
        if #session.controls >= LIMITS.controls then note(session, "UI control limit reached"); return nil end
        id = #session.controls + 1
        session.controlIds[obj] = id
        item = {id = "C" .. id, events = {}}
        session.controls[id] = item
    end
    item.path = pathOf(obj, session.root)
    item.name = nameOf(obj)
    item.class = clean(readProperty(obj, "ClassName"), 50)
    item.text = displayText(obj, session.root)
    item.visible = readProperty(obj, "Visible") == true
    item.last_seen = os.time()
    if isA(obj, "GuiButton") or isA(obj, "TextButton") or isA(obj, "ImageButton") then
        item.events = {}
        for _, eventName in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down"}) do
            local event = inspectEvent(session, obj, eventName)
            if event then item.events[#item.events + 1] = event end
        end
    elseif isA(obj, "TextBox") then
        local event = inspectEvent(session, obj, "FocusLost")
        item.events = event and {event} or {}
    end
    return item
end
local function scanSession(session)
    if #session.scans >= LIMITS.scans then note(session, "Scan limit reached; select the hub again for a new session"); return end
    local all, processed = children(session.root, true), 0
    for i, obj in ipairs(all) do
        if i > 12000 then note(session, "GUI descendant scan limit reached"); break end
        if isA(obj, "TextLabel") or isA(obj, "TextButton") or isA(obj, "ImageButton")
            or isA(obj, "TextBox") or isA(obj, "ScrollingFrame") then
            addControl(session, obj)
            processed = processed + 1
            if processed % 35 == 0 then task.wait() end
        end
    end
    session.scans[#session.scans + 1] = {time = os.time(), inspected_controls = processed}
    if not connectionsAPI then note(session, "getconnections unavailable; only UI metadata was collected") end
    if not constantsAPI then note(session, "getconstants unavailable; no callback constants were collected") end
end
local function stopObservation(session)
    if not session then return end
    session.observation = false
    for connection in pairs(session.watched) do pcall(function() connection:Disconnect() end) end
    session.watched = {}
end
local function startObservation(session)
    stopObservation(session)
    session.observation = true
    for obj, index in pairs(session.controlIds) do
        if isA(obj, "GuiButton") or isA(obj, "TextButton") or isA(obj, "ImageButton") then
            local signal = readProperty(obj, "Activated")
            if signal then
                local ok, connection = pcall(function()
                    return signal:Connect(function()
                        if not session.observation or #session.actions >= LIMITS.actions then return end
                        session.actions[#session.actions + 1] = {
                            time = os.time(), control = "C" .. index,
                            event = "Activated", text = displayText(obj, session.root)
                        }
                    end)
                end)
                if ok and connection then session.watched[connection] = true end
            end
        end
    end
end
local function reportOf(session)
    return {
        format = "HUB_FEATURE_INSPECTION_V1", created_at = session.createdAt, exported_at = os.time(),
        target_loader_id = SCRIPT_ID, place_id = game.PlaceId, universe_id = game.GameId,
        selected_gui = {name = session.rootName, class = session.rootClass}, capabilities = caps(),
        limits = LIMITS, controls = session.controls, functions = session.functions,
        scans = session.scans, actions = session.actions, notes = session.notes,
        scope = "Selected GUI and readable callbacks only. Input text, global credentials, full function bodies and network traffic are not collected.",
        interpretation = "UI labels and constants are evidence to investigate, not proof that a feature works or that the protected source was recovered."
    }
end

local old = env.AIOSFeatureInspectorGUI
if typeof(old) == "Instance" then pcall(function() old:Destroy() end) end
if type(env.AIOSFeatureInspectorCleanup) == "function" then pcall(env.AIOSFeatureInspectorCleanup) end
local gui = Instance.new("ScreenGui")
gui.Name = "AIOSFeatureInspector"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local roots, parented = {}, false
local function addRoot(root)
    if root and typeof(root) == "Instance" then
        for _, existing in ipairs(roots) do if existing == root then return end end
        roots[#roots + 1] = root
    end
end
if type(gethui) == "function" then
    local ok, root = pcall(gethui)
    if ok and root then
        addRoot(root)
        parented = pcall(function() gui.Parent = root end)
    end
end
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
addRoot(playerGui)
pcall(function() addRoot(game:GetService("CoreGui")) end)
if not parented then gui.Parent = playerGui end
env.AIOSFeatureInspectorGUI = gui

local C = {bg = Color3.fromRGB(20, 26, 38), panel = Color3.fromRGB(33, 42, 58),
    text = Color3.fromRGB(236, 240, 247), muted = Color3.fromRGB(174, 185, 204), orange = Color3.fromRGB(245, 155, 68)}
local function make(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props) do obj[k] = v end
    obj.Parent = parent
    return obj
end
local function round(obj)
    make("UICorner", {CornerRadius = UDim.new(0, 9)}, obj)
end
local frame = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromScale(0.94, 0.88), BackgroundColor3 = C.bg, BorderSizePixel = 0}, gui)
round(frame)
make("UISizeConstraint", {MaxSize = Vector2.new(560, 620), MinSize = Vector2.new(260, 340)}, frame)
local function label(text, pos, size, color)
    return make("TextLabel", {Text = text, Position = pos, Size = size, BackgroundTransparency = 1,
        TextColor3 = color or C.text, TextSize = 13, Font = Enum.Font.Gotham, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center}, frame)
end
local title = label("AIOS · Periksa fitur hub", UDim2.new(0, 16, 0, 10), UDim2.new(1, -68, 0, 29))
title.Font = Enum.Font.GothamBold; title.TextSize = 18
label("Jalankan hub asli dahulu. Pilih GUI hub, lalu pindai. Buka tab lain dan pindai lagi untuk melengkapi laporan.",
    UDim2.new(0, 16, 0, 43), UDim2.new(1, -32, 0, 34), C.muted).TextSize = 12
local function button(text, pos, size, parent)
    local obj = make("TextButton", {Text = text, Position = pos, Size = size, BackgroundColor3 = C.panel,
        BorderSizePixel = 0, TextColor3 = C.text, TextSize = 13, TextWrapped = true, Font = Enum.Font.GothamMedium}, parent or frame)
    round(obj); return obj
end
local close = button("X", UDim2.new(1, -44, 0, 10), UDim2.new(0, 30, 0, 29))
local find = button("Cari hub", UDim2.new(0, 16, 0, 83), UDim2.new(0.32, -12, 0, 32))
local scan = button("Pindai fitur", UDim2.new(0.32, 8, 0, 83), UDim2.new(0.34, -12, 0, 32))
local watch = button("Pantau tombol", UDim2.new(0.66, 4, 0, 83), UDim2.new(0.34, -20, 0, 32))
local list = make("ScrollingFrame", {Position = UDim2.new(0, 16, 0, 123), Size = UDim2.new(1, -32, 1, -283),
    BackgroundColor3 = C.panel, BorderSizePixel = 0, ScrollBarThickness = 5, CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y}, frame)
round(list)
make("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, list)
make("UIPadding", {PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5)}, list)
local selectedLabel = label("Belum ada hub dipilih.", UDim2.new(0, 16, 1, -155), UDim2.new(1, -32, 0, 38))
local status = label("", UDim2.new(0, 16, 1, -113), UDim2.new(1, -32, 0, 49), C.muted)
local previous = button("<", UDim2.new(0, 16, 1, -59), UDim2.new(0, 42, 0, 34))
local copy = button("Salin laporan", UDim2.new(0, 65, 1, -59), UDim2.new(1, -130, 0, 34))
copy.BackgroundColor3 = C.orange; copy.TextColor3 = C.bg
local nextButton = button(">", UDim2.new(1, -58, 1, -59), UDim2.new(0, 42, 0, 34))
label("Salin semua bagian ke satu .txt atau dokumen, lalu kirim di chat.", UDim2.new(0, 16, 1, -24), UDim2.new(1, -32, 0, 23), C.muted).TextSize = 10
local session, frozen, exportName, exportChecksum, part, busy, closed = nil, nil, nil, nil, 1, false, false
local function setStatus(text) if not closed and gui.Parent then status.Text = text end end
local function update()
    if not session then return end
    selectedLabel.Text = session.rootName .. " · " .. #session.controls .. " kontrol · " .. #session.functions .. " fungsi · " .. #session.actions .. " aksi"
    if frozen then copy.Text = "Salin bagian " .. part .. "/" .. math.max(1, math.ceil(#frozen / CHUNK_BYTES))
    else copy.Text = "Salin laporan" end
end
local function clearExport() frozen, exportName, exportChecksum, part = nil, nil, nil, 1 end
local function cleanup()
    stopObservation(session)
    closed = true
    pcall(function() gui:Destroy() end)
end
env.AIOSFeatureInspectorCleanup = cleanup
close.Activated:Connect(cleanup)
local function work(fn)
    if busy then setStatus("Proses sebelumnya masih berjalan."); return end
    busy = true
    task.spawn(function()
        local ok = pcall(fn)
        busy = false
        if not ok then setStatus("Pemeriksaan gagal pada executor ini. Kirim screenshot pesan atau daftar hub.") end
    end)
end
local function preview(root)
    local pieces = {}
    for i, obj in ipairs(children(root, true)) do
        if i > 500 then break end
        if isA(obj, "TextLabel") or isA(obj, "TextButton") then
            local text = displayText(obj, root)
            if #text > 1 and #text < 65 and not text:find("omitted", 1, true) then
                pieces[#pieces + 1] = text
                if #pieces == 3 then break end
            end
        end
    end
    return table.concat(pieces, " · ")
end
local function discover()
    if busy then return end
    for _, obj in ipairs(children(list)) do if isA(obj, "TextButton") then obj:Destroy() end end
    local seen, candidates = {}, {}
    local excluded = {RobloxGui=true, RobloxPromptGui=true, TouchGui=true, BubbleChat=true,
        Chat=true, ExperienceChat=true, PlayerList=true, TopBarApp=true, DevConsoleMaster=true}
    local function add(root)
        local name = readProperty(root, "Name")
        if seen[root] or root == gui or excluded[name] or name == "AIOSFeatureInspector" then return end
        seen[root] = true
        if not isA(root, "ScreenGui") then return end
        candidates[#candidates + 1] = root
    end
    local function walk(root, depth)
        if #candidates >= 70 then return end
        if isA(root, "ScreenGui") then add(root); return end
        if depth > 4 then return end
        for i, child in ipairs(children(root)) do
            if i > 200 then break end
            if isA(child, "ScreenGui") then add(child)
            elseif isA(child, "Folder") then walk(child, depth + 1) end
        end
    end
    for _, root in ipairs(roots) do walk(root, 0) end
    table.sort(candidates, function(a, b) return nameOf(a) < nameOf(b) end)
    for _, root in ipairs(candidates) do
        local target, text = root, nameOf(root)
        local subtitle = preview(root)
        if #subtitle > 0 then text = text .. "\n" .. subtitle end
        local row = button(text, UDim2.new(), UDim2.new(1, -5, 0, 48), list)
        row.TextXAlignment = Enum.TextXAlignment.Left; row.TextSize = 12
        make("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, row)
        row.Activated:Connect(function()
            if busy then return end
            if not session or session.root ~= target then stopObservation(session); session = newSession(target) end
            clearExport(); update()
            setStatus("Hub dipilih. Tekan Pindai fitur. Metadata yang tertutup bisa tetap tidak terbaca.")
        end)
    end
    setStatus(#candidates .. " GUI ditemukan. Pilih yang berisi nama atau menu hub kamu, lalu Pindai fitur.")
end
find.Activated:Connect(discover)
scan.Activated:Connect(function()
    if not session then setStatus("Pilih GUI hub dari daftar terlebih dahulu."); return end
    work(function()
        stopObservation(session); watch.Text = "Pantau tombol"
        clearExport(); setStatus("Memeriksa UI dan callback yang bisa dibaca...")
        scanSession(session)
        if closed then return end
        update()
        setStatus("Pindai selesai. Buka tab lain di hub lalu pindai lagi, atau salin laporan.")
    end)
end)
watch.Activated:Connect(function()
    if busy then return end
    if not session or #session.controls == 0 then setStatus("Pilih hub dan Pindai fitur dahulu."); return end
    clearExport()
    if session.observation then
        stopObservation(session); watch.Text = "Pantau tombol"; update()
        setStatus("Pemantauan berhenti. Aksi tombol sudah masuk laporan.")
    else
        startObservation(session); watch.Text = "Stop pantau"; update()
        setStatus("Pantau aktif. Gunakan tombol hub seperti biasa, lalu Stop pantau. Input teks tidak direkam.")
    end
end)
previous.Activated:Connect(function() if frozen and not busy then part = math.max(1, part - 1); update() end end)
nextButton.Activated:Connect(function()
    if frozen and not busy then part = math.min(math.ceil(#frozen / CHUNK_BYTES), part + 1); update() end
end)
copy.Activated:Connect(function()
    if not session or #session.scans == 0 then setStatus("Pilih hub lalu Pindai fitur dahulu."); return end
    if not clipboard then setStatus("Clipboard tidak tersedia di executor ini. Kirim screenshot ringkasannya."); return end
    work(function()
        if not frozen then
            stopObservation(session); watch.Text = "Pantau tombol"
            frozen = HttpService:JSONEncode(reportOf(session))
            exportName = "Hub-Feature-Report-" .. os.time() .. ".json"
            exportChecksum = adler32(frozen); part = 1
        end
        setStatus("Menyiapkan bagian " .. part .. "...")
        local encoded, total = packet(frozen, exportName, "runtime_inspection", exportChecksum, part)
        local ok, value = pcall(clipboard, encoded)
        update()
        setStatus(ok and value ~= false and ("Bagian " .. part .. "/" .. total .. " disalin. Tempel ke dokumen sebelum menekan >.")
            or "Clipboard gagal. Coba salin bagian yang sama lagi.")
    end)
end)
discover()

-- AIOS / Pixel Lineage Inspector 1.0 - client-visible diagnostic report only.
-- Made by Ilham Ziqri. Standalone; does not replace the AIOS HUB file.
-- Never invokes remotes, executes a game module, hooks calls, or changes gameplay.
-- Optional executor inspection functions are detected and protected with pcall.
-- No player identifiers, keys, profile contents or full script sources are exported.
-- References: create.roblox.com/docs/scripting/events/remote
-- docs.sunc.io/Scripts/getscriptclosure/ and docs.sunc.io/Debug/getconstants/
--!nocheck
--!nolint

-- REPORT CORE START
local function buildReport(deps)
    local game,player=deps.game,deps.player
    local caps=deps.caps or{}
    local limits={nodes=12000,remotes=200,scripts=220,analysis=60,source=1024*1024,
        sourceTotal=3*1024*1024,functions=96,depth=4,constants=1500,hints=64,bytes=140000}
    local stats={nodes=0,remotes=0,scripts=0,analyzed=0,sources=0,closures=0,functions=0,
        constants=0,errors=0,roots=0,truncated=false}
    local lines,bytes={},0
    local function clean(value,max)
        return tostring(value or""):gsub("[%c]"," "):sub(1,max or 180)
    end
    local function add(value)
        value=tostring(value or"")
        if bytes+#value+1>limits.bytes then stats.truncated=true;return false end
        lines[#lines+1]=value;bytes=bytes+#value+1;return true
    end
    local function cancelled()return deps.cancelled and deps.cancelled()end
    local function yield()if deps.yield then deps.yield()end;return cancelled()end
    local function child(parent,name)
        if not parent then return nil end
        local ok,value=pcall(function()return parent:FindFirstChild(name)end)
        return ok and value or nil
    end
    local function path(object)
        local parts={}
        for _=1,32 do
            if not object or object==game then break end
            if object==player then table.insert(parts,1,"LocalPlayer");break end
            table.insert(parts,1,clean(object.Name,100))
            object=object.Parent
        end
        return table.concat(parts,".")
    end
    local needles={"combat","damage","health","attack","kill","hit","item","inventory","gear","loot",
        "drop","reward","grant","give","spawn","admin","profile","rpg","sell","purchase","buy","chest",
        "claim","redeem","equip","skill","remote","fireserver","invokeserver","target","battle"}
    local blocked={"password","token","secret","cookie","hwid","webhook","license","auth","sessionkey","apikey"}
    local function interesting(value)
        if type(value)~="string"or#value<3 or#value>72 or not value:match("^[A-Za-z_][A-Za-z0-9_.:]*$")then return false end
        local low=value:lower()
        for _,word in ipairs(blocked)do if low:find(word,1,true)then return false end end
        for _,word in ipairs(needles)do if low:find(word,1,true)then return true end end
        return false
    end
    local function priority(name)
        local low=name:lower()
        for _,word in ipairs(needles)do if low:find(word,1,true)then return 1 end end
        return 2
    end

    add("AIOS PIXEL LINEAGE - LAPORAN PEMERIKSAAN CLIENT v1.0")
    add("Waktu UTC: "..os.date("!%Y-%m-%dT%H:%M:%SZ"))
    add("GameId: "..tostring(game.GameId).." | PlaceId: "..tostring(game.PlaceId))
    add("Mode: snapshot baca-saja. Tidak ada remote yang dipanggil atau modul yang dijalankan.")
    add("Nama/kata yang ditemukan adalah petunjuk, bukan bukti perintah itu tersedia atau diterima server.")
    add("Kode server yang tidak direplikasi tidak dapat diperiksa oleh laporan ini.")
    add("Tidak mengumpulkan profil, UserId, username, kunci, atau isi skrip lengkap.")
    add("")
    add("KEMAMPUAN PEMERIKSAAN")
    for _,name in ipairs({"getscriptclosure","getconstants","getprotos"})do
        add(name..": "..(type(caps[name])=="function"and"tersedia (masih bisa ditolak per skrip)"or"tidak tersedia"))
    end
    add("writefile: "..(caps.writefile and"tersedia"or"tidak tersedia").." | clipboard: "..(caps.clipboard and"tersedia"or"tidak tersedia"))
    add("")
    if game.GameId~=10767928510 then
        stats.wrongGame=true
        add("GAME BERBEDA: buka Pixel Lineage lalu jalankan pemeriksa ini kembali.")
        add("Pemeriksaan dihentikan sebelum membaca hierarki game lain.")
        return table.concat(lines,"\n"),stats
    end

    local storage=game:GetService("ReplicatedStorage")
    local scripts=child(player,"PlayerScripts")
    local roots={}
    local function root(object,label)
        if object then roots[#roots+1]={object=object,label=label};stats.roots=stats.roots+1
        else add("Root belum tersedia: "..label)end
    end
    root(child(storage,"PlatformBattles"),"ReplicatedStorage.PlatformBattles")
    root(child(scripts,"PlatformBattlesClient"),"LocalPlayer.PlayerScripts.PlatformBattlesClient")
    if stats.roots==0 then
        add("Tunggu game selesai dimuat, buka bag sekali, lalu tekan Cek ulang.")
        return table.concat(lines,"\n"),stats
    end
    local foundScripts,foundRemotes,queue,seen={},{},{},{}
    for _,entry in ipairs(roots)do queue[#queue+1]=entry.object end
    local at=1
    while at<=#queue and stats.nodes<limits.nodes do
        if cancelled()then return nil,stats end
        local object=queue[at];at=at+1
        if not seen[object]then
            seen[object]=true;stats.nodes=stats.nodes+1
            local class=object.ClassName
            if class=="RemoteEvent"or class=="RemoteFunction"or class=="UnreliableRemoteEvent"then
                stats.remotes=stats.remotes+1
                if #foundRemotes<limits.remotes then
                    foundRemotes[#foundRemotes+1]={kind=class,path=path(object)}
                else stats.truncated=true end
            elseif class=="ModuleScript"or class=="LocalScript"then
                stats.scripts=stats.scripts+1
                if #foundScripts<limits.scripts then
                    foundScripts[#foundScripts+1]={object=object,kind=class,path=path(object),rank=priority(object.Name)}
                else stats.truncated=true end
            end
            local ok,children=pcall(function()return object:GetChildren()end)
            if ok and type(children)=="table"then
                for _,value in ipairs(children)do
                    if #queue<limits.nodes then queue[#queue+1]=value else stats.truncated=true;break end
                end
            else stats.errors=stats.errors+1 end
            if stats.nodes%100==0 and yield()then return nil,stats end
        end
    end
    if at<=#queue then stats.truncated=true end
    table.sort(foundRemotes,function(a,b)return a.path<b.path end)
    table.sort(foundScripts,function(a,b)if a.rank~=b.rank then return a.rank<b.rank end;return a.path<b.path end)
    add("")
    add("REMOTE YANG TERLIHAT (nama/path; tidak dipanggil)")
    if #foundRemotes==0 then add("Tidak ditemukan pada root yang diperiksa.")end
    for _,entry in ipairs(foundRemotes)do add(entry.kind.." | "..entry.path)end
    add("")
    add("MODUL DAN LOCAL SCRIPT YANG TERLIHAT")
    for _,entry in ipairs(foundScripts)do add(entry.kind.." | "..entry.path)end
    add("")
    add("PETUNJUK KODE CLIENT (terbatas; skrip game tidak dieksekusi)")
    local sourceBytes=0
    for index=1,math.min(#foundScripts,limits.analysis)do
        if cancelled()then return nil,stats end
        local entry=foundScripts[index]
        stats.analyzed=stats.analyzed+1
        if deps.progress then deps.progress("Memeriksa "..index.."/"..math.min(#foundScripts,limits.analysis)..": "..clean(entry.object.Name,60))end
        local hints,seenHints,commands={}, {},{}
        local function hint(value)
            if #hints<limits.hints and interesting(value)and not seenHints[value]then
                seenHints[value]=true;hints[#hints+1]=value
            end
        end
        local readable,source=pcall(function()return entry.object.Source end)
        local sourceStatus="tidak tersedia/ditolak"
        if readable and type(source)=="string"and#source>0 and sourceBytes<limits.sourceTotal then
            local take=math.min(#source,limits.source,limits.sourceTotal-sourceBytes)
            if take<#source then stats.truncated=true end
            source=source:sub(1,take);sourceBytes=sourceBytes+take;stats.sources=stats.sources+1
            sourceStatus="terbaca (hanya identifier yang diekspor)"
            for token in source:gmatch("[A-Za-z_][A-Za-z0-9_.:]*")do hint(token)end
            for _,method in ipairs({"FireServer","InvokeServer"})do
                local pattern=":"..method.."%s*%(%s*[\"']([A-Za-z_][A-Za-z0-9_]*)[\"']"
                for command in source:gmatch(pattern)do
                    if interesting(command)and#commands<16 then commands[#commands+1]=method.." -> "..command end
                end
            end
        elseif readable and type(source)=="string"and#source==0 then sourceStatus="kosong/tidak direplikasi"end
        source=nil
        local closureStatus="fungsi pemeriksaan tidak tersedia"
        local functions=0
        if type(caps.getscriptclosure)=="function"and type(caps.getconstants)=="function"then
            local ok,closure=pcall(caps.getscriptclosure,entry.object)
            if ok and type(closure)=="function"then
                stats.closures=stats.closures+1
                closureStatus="closure terbaca; bukan handler server"
                local pending={{fn=closure,depth=0}}
                local visited={}
                local cursor=1
                while cursor<=#pending and functions<limits.functions do
                    if cancelled()then return nil,stats end
                    local item=pending[cursor];cursor=cursor+1
                    if not visited[item.fn]then
                        visited[item.fn]=true;functions=functions+1;stats.functions=stats.functions+1
                        -- Only inspect compiled metadata. Never call item.fn or a returned proto.
                        local passed,constants=pcall(caps.getconstants,item.fn)
                        if passed and type(constants)=="table"then
                            stats.constants=stats.constants+1
                            local count=0
                            for _,value in pairs(constants)do
                                count=count+1;if count>limits.constants then stats.truncated=true;break end
                                hint(value)
                            end
                        else stats.errors=stats.errors+1 end
                        if item.depth<limits.depth and type(caps.getprotos)=="function"then
                            local got,children=pcall(caps.getprotos,item.fn)
                            if got and type(children)=="table"then
                                for _,value in pairs(children)do
                                    if #pending>=limits.functions then stats.truncated=true;break end
                                    if type(value)=="function"and not visited[value]then
                                        pending[#pending+1]={fn=value,depth=item.depth+1}
                                    end
                                end
                            else stats.errors=stats.errors+1 end
                        end
                        if functions%16==0 and yield()then return nil,stats end
                    end
                end
                if cursor<=#pending then stats.truncated=true end
            else closureStatus="tidak tersedia untuk skrip ini"end
        end
        table.sort(hints)
        add("")
        add(entry.path)
        add("  Source: "..sourceStatus.." | Metadata: "..closureStatus.." | Fungsi diperiksa: "..functions)
        add("  Identifier gameplay: "..(#hints>0 and table.concat(hints,", ")or"tidak ada yang terbaca"))
        if #commands>0 then add("  Pola teks pemanggilan (bisa juga komentar/string): "..table.concat(commands,"; "))end
        if yield()then return nil,stats end
    end
    if #foundScripts>limits.analysis then stats.truncated=true end
    add("")
    add("RINGKASAN")
    add(string.format("Root: %d | Objek: %d | Remote: %d | Skrip: %d | Dianalisis: %d",stats.roots,stats.nodes,stats.remotes,stats.scripts,stats.analyzed))
    add(string.format("Source terbaca: %d | Closure terbaca: %d | Tabel konstanta terbaca: %d | Pemeriksaan ditolak/gagal: %d",stats.sources,stats.closures,stats.constants,stats.errors))
    add("Cakupan: "..(stats.truncated and"dibatasi; ada bagian yang tidak diperiksa/ditampilkan"or"root yang tersedia telah diperiksa dalam batas laporan"))
    add("Tidak membaca ServerScriptService, ServerStorage, heap global, upvalue, profil, atau lalu lintas pemain.")
    add("Hasil ini belum membuktikan spawn item atau one hit kill bisa dilakukan.")
    if stats.truncated then lines[#lines+1]="\n[PEMERIKSAAN DIBATASI; LAPORAN BUKAN HASIL LENGKAP]"end
    return table.concat(lines,"\n"),stats
end
-- REPORT CORE END

-- EXPORT CORE START
local function makeExporter(deps)
    local exporter={path=nil}
    function exporter.Save(text)
        if type(text)~="string"or text==""then return false,"Belum ada hasil pemeriksaan."end
        if type(deps.writefile)~="function"then return false,"Simpan file tidak didukung. Gunakan Salin hasil."end
        if not exporter.path then
            for _=1,10 do
                local candidate=deps.newName()
                local exists=false
                if type(deps.isfile)=="function"then
                    local ok,value=pcall(deps.isfile,candidate);exists=ok and value==true
                end
                if not exists then exporter.path=candidate;break end
            end
            if not exporter.path then return false,"Belum bisa memilih nama file baru. Gunakan Salin hasil."end
        end
        local wrote,value=pcall(deps.writefile,exporter.path,text)
        if not wrote or value==false then return false,"File gagal disimpan. Gunakan Salin hasil lalu buat TXT di aplikasi catatan."end
        if type(deps.readfile)=="function"then
            local read,value=pcall(deps.readfile,exporter.path)
            if read and value~=text then return false,"Isi file berbeda saat diverifikasi. Gunakan Salin hasil."end
            if not read then return true,"Tertulis: "..exporter.path.."\nVerifikasi baca tidak tersedia. Salin hasil sebagai cadangan."end
        end
        return true,"Tersimpan: "..exporter.path.."\n"..#text.." byte. Path relatif terhadap workspace executor."
    end
    function exporter.Copy(text)
        if type(text)~="string"or text==""then return false,"Belum ada hasil pemeriksaan."end
        if type(deps.clipboard)~="function"then return false,"Clipboard tidak tersedia. Pilih teks hasil lalu Salin secara manual."end
        if not pcall(deps.clipboard,text)then return false,"Clipboard gagal. Pilih teks hasil lalu Salin secara manual."end
        return true,"Hasil disalin. Tempel ke dokumen TXT lalu kirim ke chat ini."
    end
    return exporter
end
-- EXPORT CORE END

local player=game:GetService("Players").LocalPlayer
assert(player,"AIOS Inspector: tunggu pemain selesai dimuat lalu jalankan kembali.")
local parent=player:FindFirstChild("PlayerGui")or player:WaitForChild("PlayerGui",5)
assert(parent,"AIOS Inspector: PlayerGui belum tersedia.")
local env=type(getgenv)=="function"and getgenv()or _G
local previous=env.AiosPixelLineageInspector
if type(previous)=="table"and type(previous.Destroy)=="function"then pcall(previous.Destroy)end
local state={closed=false,running=false,text="",connections={}}
local function create(class,properties)
    local object=Instance.new(class)
    for key,value in pairs(properties or{})do object[key]=value end
    return object
end
local function connect(signal,fn)
    local connection=signal:Connect(fn);state.connections[#state.connections+1]=connection;return connection
end
local rgb=Color3.fromRGB
local screen=create("ScreenGui",{Name="AiosPixelLineageInspector",ResetOnSpawn=false,IgnoreGuiInset=true,
    DisplayOrder=100040,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,Parent=parent})
local panel=create("Frame",{Name="Panel",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
    BackgroundColor3=rgb(20,24,32),BorderSizePixel=0,Parent=screen})
create("UICorner",{CornerRadius=UDim.new(0,14),Parent=panel})
create("UIStroke",{Color=rgb(230,143,66),Transparency=.25,Thickness=1,Parent=panel})
local title=create("TextLabel",{Name="Title",Text="AIOS Inspector",Font=Enum.Font.GothamBold,TextSize=22,
    TextColor3=rgb(255,176,94),TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,
    Position=UDim2.fromOffset(18,12),Size=UDim2.new(1,-78,0,28),Parent=panel})
local close=create("TextButton",{Name="Close",Text="×",TextSize=28,Font=Enum.Font.Gotham,
    TextColor3=rgb(222,227,236),BackgroundTransparency=1,AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-6,0,4),
    Size=UDim2.fromOffset(46,44),Parent=panel})
local status=create("TextLabel",{Name="Status",Text="Menyiapkan pemeriksaan...",Font=Enum.Font.Gotham,TextSize=13,
    TextColor3=rgb(178,189,205),TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top,BackgroundTransparency=1,Position=UDim2.fromOffset(18,46),
    Size=UDim2.new(1,-36,0,38),Parent=panel})
local scroll=create("ScrollingFrame",{Name="Report",BackgroundColor3=rgb(13,17,24),BorderSizePixel=0,
    Position=UDim2.fromOffset(14,88),Size=UDim2.new(1,-28,1,-192),CanvasSize=UDim2.new(),
    AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,
    ScrollBarThickness=4,ScrollBarImageColor3=rgb(235,149,74),Parent=panel})
create("UICorner",{CornerRadius=UDim.new(0,8),Parent=scroll})
create("UIPadding",{PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10),PaddingTop=UDim.new(0,8),
    PaddingBottom=UDim.new(0,12),Parent=scroll})
local resultBox=create("TextBox",{Name="ReportText",Text="Hasil akan muncul di sini.",Font=Enum.Font.Code,TextSize=13,
    TextColor3=rgb(216,225,237),TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
    TextWrapped=true,MultiLine=true,ClearTextOnFocus=false,TextEditable=true,BackgroundTransparency=1,
    Size=UDim2.new(1,-8,0,22),AutomaticSize=Enum.AutomaticSize.Y,Parent=scroll})
local fileStatus=create("TextLabel",{Name="FileStatus",Text="",Font=Enum.Font.Gotham,TextSize=12,
    TextColor3=rgb(177,208,188),TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top,BackgroundTransparency=1,Position=UDim2.new(0,16,1,-94),
    Size=UDim2.new(1,-32,0,42),Parent=panel})
local footer=create("Frame",{Name="Buttons",BackgroundTransparency=1,Position=UDim2.new(0,14,1,-46),
    Size=UDim2.new(1,-28,0,36),Parent=panel})
local function button(text,index,color)
    local object=create("TextButton",{Name=text,Text=text,Font=Enum.Font.GothamMedium,TextSize=14,
        TextColor3=rgb(244,239,230),BackgroundColor3=color,BorderSizePixel=0,TextWrapped=true,
        Position=UDim2.new((index-1)/3,0,0,0),Size=UDim2.new(1/3,-6,1,0),Parent=footer})
    create("UICorner",{CornerRadius=UDim.new(0,8),Parent=object})
    return object
end
local copy=button("Salin hasil",1,rgb(164,91,36))
local save=button("Simpan TXT",2,rgb(42,52,68))
local again=button("Cek ulang",3,rgb(42,52,68))
local function resize()
    if state.closed then return end
    local camera=workspace.CurrentCamera
    local view=camera and camera.ViewportSize or Vector2.new(854,480)
    panel.Size=UDim2.fromOffset(math.max(240,math.min(1080,view.X-24)),math.max(260,math.min(740,view.Y-24)))
end
resize()
if workspace.CurrentCamera then connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),resize)end
local debugTable=type(debug)=="table"and debug or{}
local caps={getscriptclosure=type(getscriptclosure)=="function"and getscriptclosure or nil,
    getconstants=type(getconstants)=="function"and getconstants or debugTable.getconstants,
    getprotos=type(getprotos)=="function"and getprotos or debugTable.getprotos,
    writefile=type(writefile)=="function",clipboard=type(setclipboard)=="function"or type(toclipboard)=="function"}
local clipboard=type(setclipboard)=="function"and setclipboard or type(toclipboard)=="function"and toclipboard or nil
local exporter=makeExporter({writefile=writefile,readfile=readfile,isfile=isfile,clipboard=clipboard,newName=function()
    return "AIOS-PL-Check-"..tostring(os.time()).."-"..tostring(math.random(1000,9999))..".txt"
end})
local function setFileStatus(ok,message)
    if state.closed then return end
    fileStatus.Text=message
    fileStatus.TextColor3=ok and rgb(177,208,188)or rgb(245,184,117)
end
local function saveReport()
    if state.running or state.closed then return end
    local ok,message=exporter.Save(state.text);setFileStatus(ok,message)
end
local function start()
    if state.running or state.closed then return end
    state.running=true;status.Text="Memeriksa metadata client...";fileStatus.Text=""
    task.spawn(function()
        local ok,text,stats=pcall(buildReport,{game=game,player=player,caps=caps,yield=function()task.wait()end,
            cancelled=function()return state.closed end,progress=function(message)if not state.closed then status.Text=message end end})
        if state.closed then return end
        state.running=false
        if not ok or not text then
            status.Text="Pemeriksaan belum selesai. Tekan Cek ulang setelah game dimuat."
            return
        end
        state.text=text;state.stats=stats;resultBox.Text=text
        status.Text=stats.wrongGame and"Buka Pixel Lineage, lalu jalankan kembali."
            or stats.roots==0 and"Modul game belum terlihat. Tunggu game dimuat lalu Cek ulang."
            or string.format("Selesai: %d remote, %d skrip. %s",stats.remotes,stats.scripts,
                stats.truncated and"Hasil dibatasi; baca catatan laporan."or"Salin hasil atau gunakan file TXT.")
        saveReport()
    end)
end
function state.Destroy()
    if state.closed then return end
    state.closed=true
    for _,connection in ipairs(state.connections)do pcall(function()connection:Disconnect()end)end
    screen:Destroy()
    if env.AiosPixelLineageInspector==state then env.AiosPixelLineageInspector=nil end
end
state.Save=saveReport
state.Copy=function()
    if state.running or state.closed then return end
    local ok,message=exporter.Copy(state.text)
    setFileStatus(ok,message)
    if not ok and state.text~=""then
        pcall(function()resultBox:CaptureFocus();resultBox.CursorPosition=#resultBox.Text+1;resultBox.SelectionStart=1 end)
    end
end
connect(copy.Activated,state.Copy)
connect(save.Activated,saveReport)
connect(again.Activated,start)
connect(close.Activated,state.Destroy)
env.AiosPixelLineageInspector=state
task.defer(start)
return state

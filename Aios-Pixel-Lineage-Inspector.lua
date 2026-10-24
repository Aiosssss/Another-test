-- AIOS / Pixel Lineage Item Inspector 1.3 - focused client bytecode export.
-- Made by Ilham Ziqri. Standalone; does not replace the AIOS HUB file.
-- Exports only AdminToolCatalog, AdminPanelClient, MarketGiveaways and MarketGifts.
-- Never invokes remotes, executes game modules, changes inventory or grants admin access.
-- No decompiler needed on the phone; getscriptbytecode must return readable bytes.
-- Bytecode contains static client code/literals, not runtime player/profile variables.
-- No GC, upvalues, player identities, account keys, network hooks or server-only code reads.
-- Exports complete modules in numbered Base64 TXT parts with checksums; no silent truncation.
-- Reference: docs.sunc.io/Scripts/getscriptbytecode/
--!nocheck
--!nolint

-- ITEM CODE CORE START
local function buildItemReports(deps)
    local parts,notes={},{}
    local stats={targets=4,available=0,exported=0,bytes=0,roots=0,scripts=0,remotes=0,parts=0}
    local game,player=deps.game,deps.player
    local function child(parent,name)
        if not parent then return nil end
        local ok,value=pcall(function()return parent:FindFirstChild(name)end)
        return ok and value or nil
    end
    local function cancelled()return deps.cancelled and deps.cancelled()end
    local function yield()if deps.yield then deps.yield()end;return cancelled()end
    local function note(text)notes[#notes+1]=text end
    local function adler(value)
        local a,b=1,0
        for i=1,#value do a=(a+string.byte(value,i))%65521;b=(b+a)%65521 end
        return string.format("%08x",b*65536+a)
    end
    local alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local function encode(value)
        local output={}
        for i=1,#value,3 do
            local a,b,c=string.byte(value,i,i+2)
            local n=a*65536+(b or 0)*256+(c or 0)
            local p,q,r,s=math.floor(n/262144)%64,math.floor(n/4096)%64,math.floor(n/64)%64,n%64
            output[#output+1]=alphabet:sub(p+1,p+1)..alphabet:sub(q+1,q+1)
                ..(b and alphabet:sub(r+1,r+1)or"=")..(c and alphabet:sub(s+1,s+1)or"=")
            if i%6144==1 and yield()then return nil end
        end
        local result=table.concat(output)
        local lines={}
        for i=1,#result,80 do lines[#lines+1]=result:sub(i,i+79)end
        return table.concat(lines,"\n")
    end
    local function summary()
        return table.concat({"AIOS ITEM INSPECTOR v1.3",
            "GameId: "..tostring(game.GameId).." | PlaceId: "..tostring(game.PlaceId),
            "Fokus: jalur pemberian item yang dapat dikonfirmasi dari inventory server.",
            "Membaca bytecode modul client saja. Tidak melakukan dekompilasi di HP.",
            "Tidak memanggil fungsi game, remote, atau mengubah inventory/hak akses.",
            "Tidak membaca kode server, profil, UserId, username, upvalue, atau tabel GC.",
            "Bytecode adalah kode client statik; bukan isi variabel pemain saat runtime.",
            "Format hasil API bisa berbeda antar executor; belum dijamin dapat dianalisis.",
            "Nama GiveGear/AdminAction belum membuktikan akun berhak memakainya.",
            "Status bytecode:",table.concat(notes,"\n")},"\n")
    end
    if game.GameId~=10767928510 then
        stats.wrongGame=true;stats.parts=1;note("Buka Pixel Lineage lalu jalankan kembali.")
        return{{tag="Status",label="Status pemeriksaan",text=summary()}},stats
    end
    local storage=game:GetService("ReplicatedStorage")
    local root=child(storage,"PlatformBattles")
    local client=child(child(player,"PlayerScripts"),"PlatformBattlesClient")
    local shared=child(root,"Shared")
    stats.roots=(root and 1 or 0)+(client and 1 or 0)
    stats.remotes=child(child(root,"Remotes"),"RPGCommand")and 1 or 0
    local flagRead,flag=pcall(function()return player:GetAttribute("PBAdminAccessAllowed")end)
    note("PBAdminAccessAllowed (flag client, bukan bukti izin server): "..(flagRead and type(flag)=="boolean"and tostring(flag)or"tidak terbaca/tidak tersedia"))
    local getBytecode=deps.caps and deps.caps.getscriptbytecode
    note("getscriptbytecode: "..(type(getBytecode)=="function"and"tersedia; diuji per modul"or"tidak tersedia"))
    local targets={{parent=client,name="AdminToolCatalog",prefix="LocalPlayer.PlayerScripts.PlatformBattlesClient."},
        {parent=client,name="AdminPanelClient",prefix="LocalPlayer.PlayerScripts.PlatformBattlesClient."},
        {parent=shared,name="MarketGiveaways",prefix="ReplicatedStorage.PlatformBattles.Shared."},
        {parent=shared,name="MarketGifts",prefix="ReplicatedStorage.PlatformBattles.Shared."}}
    local maxModule,maxTotal,chunkSize=262144,786432,49152
    for _,target in ipairs(targets)do
        if cancelled()then return nil,stats end
        local object=child(target.parent,target.name)
        local modulePath=target.prefix..target.name
        if not object or object.ClassName~="ModuleScript"then note(target.name..": modul belum tersedia.")
        else
            stats.available=stats.available+1;stats.scripts=stats.scripts+1
            if type(getBytecode)~="function"then note(target.name..": ekspor tidak didukung executor.")
            else
                if deps.progress then deps.progress("Membaca bytecode client: "..target.name)end
                local ok,bytes=pcall(getBytecode,object)
                if not ok then note(target.name..": API menolak pembacaan (pesan internal tidak diekspor).")
                elseif type(bytes)~="string"or#bytes==0 then note(target.name..": tidak mengembalikan bytecode.")
                elseif #bytes>maxModule or stats.bytes+#bytes>maxTotal then note(target.name..": melewati batas ukuran; tidak diekspor.")
                else
                    stats.exported=stats.exported+1;stats.bytes=stats.bytes+#bytes
                    local fullHash=adler(bytes)
                    local count=math.ceil(#bytes/chunkSize)
                    note(string.format("%s: %d byte; %d bagian TXT; Adler32=%s",target.name,#bytes,count,fullHash))
                    for index=1,count do
                        local piece=bytes:sub((index-1)*chunkSize+1,index*chunkSize)
                        local encoded=encode(piece)
                        if not encoded then return nil,stats end
                        local header={"MODULE_PATH: "..modulePath,"BYTECODE_TOTAL_BYTES: "..#bytes,
                            "BYTECODE_ADLER32: "..fullHash,"BYTECODE_FIRST_BYTE: "..string.byte(bytes,1),
                            "PART: "..index.."/"..count,"PART_BYTES: "..#piece,"PART_ADLER32: "..adler(piece),"ENCODING: base64"}
                        parts[#parts+1]={tag=target.name.."-"..index,label=target.name.." "..index.."/"..count,
                            body=table.concat(header,"\n").."\nDATA_BEGIN\n"..encoded.."\nDATA_END\n"}
                    end
                end
            end
        end
        if yield()then return nil,stats end
    end
    if #parts==0 then
        note("Tidak ada bytecode yang berhasil diekspor. Jalur ini tidak memberi data kode tambahan dari executor ini.")
        parts[1]={tag="Status",label="Status ekspor item",text=summary()}
    else
        local intro=summary().."\n\nKirim semua bagian TXT; data Base64 jangan diedit. Hash hanya untuk mengecek hasil salin.\n"
        for _,part in ipairs(parts)do part.text=intro.."\n"..part.body;part.body=nil end
    end
    stats.parts=#parts
    return parts,stats
end
-- ITEM CODE CORE END


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
        local ok,value=pcall(deps.clipboard,text)
        if not ok or value==false then return false,"Clipboard gagal. Pilih teks hasil lalu Salin secara manual."end
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
local state={closed=false,running=false,saving=false,text="",parts={},index=1,exporters={},connections={}}
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
local title=create("TextLabel",{Name="Title",Text="AIOS Item Inspector 1.3",Font=Enum.Font.GothamBold,TextSize=22,
    TextColor3=rgb(255,176,94),TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,
    Position=UDim2.fromOffset(18,12),Size=UDim2.new(1,-78,0,28),Parent=panel})
local close=create("TextButton",{Name="Close",Text="×",TextSize=28,Font=Enum.Font.Gotham,
    TextColor3=rgb(222,227,236),BackgroundTransparency=1,AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-6,0,4),
    Size=UDim2.fromOffset(46,44),Parent=panel})
local status=create("TextLabel",{Name="Status",Text="Menyiapkan pemeriksaan...",Font=Enum.Font.Gotham,TextSize=13,
    TextColor3=rgb(178,189,205),TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top,BackgroundTransparency=1,Position=UDim2.fromOffset(18,46),
    Size=UDim2.new(1,-36,0,38),Parent=panel})
local navigation=create("Frame",{Name="Parts",BackgroundTransparency=1,
    Position=UDim2.fromOffset(14,86),Size=UDim2.new(1,-28,0,30),Parent=panel})
local previousPart=create("TextButton",{Name="PreviousPart",Text="<",Font=Enum.Font.GothamBold,TextSize=20,
    TextColor3=rgb(255,176,94),BackgroundColor3=rgb(42,52,68),BorderSizePixel=0,
    Size=UDim2.fromOffset(42,30),Parent=navigation})
local nextPart=create("TextButton",{Name="NextPart",Text=">",Font=Enum.Font.GothamBold,TextSize=20,
    TextColor3=rgb(255,176,94),BackgroundColor3=rgb(42,52,68),BorderSizePixel=0,
    AnchorPoint=Vector2.new(1,0),Position=UDim2.fromScale(1,0),Size=UDim2.fromOffset(42,30),Parent=navigation})
local partLabel=create("TextLabel",{Name="PartLabel",Text="Menunggu hasil",Font=Enum.Font.GothamMedium,TextSize=13,
    TextColor3=rgb(222,227,236),BackgroundTransparency=1,TextWrapped=true,
    Position=UDim2.fromOffset(48,0),Size=UDim2.new(1,-96,1,0),Parent=navigation})
for _,object in ipairs({previousPart,nextPart})do create("UICorner",{CornerRadius=UDim.new(0,6),Parent=object})end
local scroll=create("ScrollingFrame",{Name="Report",BackgroundColor3=rgb(13,17,24),BorderSizePixel=0,
    Position=UDim2.fromOffset(14,124),Size=UDim2.new(1,-28,1,-228),CanvasSize=UDim2.new(),
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
local caps={getscriptbytecode=type(getscriptbytecode)=="function"and getscriptbytecode or nil}
local clipboard=type(setclipboard)=="function"and setclipboard or type(toclipboard)=="function"and toclipboard or nil
local copyExporter=makeExporter({clipboard=clipboard})
local function setFileStatus(ok,message)
    if state.closed then return end
    fileStatus.Text=message
    fileStatus.TextColor3=ok and rgb(177,208,188)or rgb(245,184,117)
end
local function renderPage()
    if state.closed then return end
    local part=state.parts[state.index]
    state.text=part and part.text or""
    resultBox.Text=state.text
    scroll.CanvasPosition=Vector2.new(0,0)
    partLabel.Text=part and(string.format("%d/%d - %s",state.index,#state.parts,part.label))or"Menunggu hasil"
    previousPart.TextColor3=state.index>1 and rgb(255,176,94)or rgb(95,104,118)
    nextPart.TextColor3=state.index<#state.parts and rgb(255,176,94)or rgb(95,104,118)
end
local function newExporter(tag)
    return makeExporter({writefile=writefile,readfile=readfile,isfile=isfile,newName=function()
        return "AIOS-ItemCode-"..tag.."-"..tostring(os.time()).."-"..tostring(math.random(1000,9999))..".txt"
    end})
end
local function saveReports()
    if state.running or state.saving or state.closed then return end
    if #state.parts==0 then setFileStatus(false,"Belum ada hasil pemeriksaan.");return end
    state.saving=true
    local saved,lastMessage=0,""
    for index,part in ipairs(state.parts)do
        if state.closed then state.saving=false;return end
        local exporter=state.exporters[index]
        if not exporter then exporter=newExporter(part.tag);state.exporters[index]=exporter end
        local ok,message=exporter.Save(part.text)
        if not ok then lastMessage=message;break end
        saved=saved+1;lastMessage=message
        if saved<#state.parts then task.wait()end
    end
    state.saving=false
    if state.closed then return end
    if saved==#state.parts then
        if saved==1 then setFileStatus(true,lastMessage)
        else setFileStatus(true,"Tersimpan "..saved.." TXT bernama AIOS-ItemCode-... di workspace executor. Kirim semua bagian TXT.")end
    else
        setFileStatus(false,"Tersimpan "..saved.."/"..#state.parts.." bagian. "..lastMessage.." Pakai < > untuk menyalin tiap bagian.")
    end
end
local function start()
    if state.running or state.saving or state.closed then return end
    state.running=true;state.parts={};state.exporters={};state.index=1;state.text=""
    resultBox.Text="Membaca modul item...";partLabel.Text="Menunggu hasil"
    status.Text="Ekspor kode client terkait item; belum memberi item.";fileStatus.Text=""
    task.spawn(function()
        if state.closed then return end
        local ok,parts,stats=pcall(buildItemReports,{game=game,player=player,caps=caps,yield=function()task.wait()end,
            cancelled=function()return state.closed end,progress=function(message)if not state.closed then status.Text=message end end})
        if state.closed then return end
        state.running=false
        if not ok or not parts then
            status.Text="Pemeriksaan belum selesai. Tekan Cek ulang setelah game dimuat."
            return
        end
        state.parts=parts;state.stats=stats;renderPage()
        status.Text=stats.wrongGame and"Buka Pixel Lineage, lalu jalankan kembali."
            or stats.roots==0 and"Modul game belum terlihat. Tunggu game dimuat lalu Cek ulang."
            or stats.exported==0 and"Bytecode belum diperoleh. Salin/kirim laporan status untuk melihat penyebabnya."
            or string.format("%d modul, %d bagian TXT. Ini ekspor kode; item belum diberikan.",stats.exported,#parts)
        saveReports()
    end)
end
function state.Destroy()
    if state.closed then return end
    state.closed=true
    for _,connection in ipairs(state.connections)do pcall(function()connection:Disconnect()end)end
    screen:Destroy()
    if env.AiosPixelLineageInspector==state then env.AiosPixelLineageInspector=nil end
end
state.Save=saveReports
state.Copy=function()
    if state.running or state.closed then return end
    local ok,message=copyExporter.Copy(state.text)
    if ok then message="Bagian "..state.index.."/"..#state.parts.." disalin. Tempel ke TXT; ulangi untuk semua bagian dengan tombol >."end
    setFileStatus(ok,message)
    if not ok and state.text~=""then
        pcall(function()resultBox:CaptureFocus();resultBox.CursorPosition=#resultBox.Text+1;resultBox.SelectionStart=1 end)
    end
end
connect(copy.Activated,state.Copy)
connect(previousPart.Activated,function()
    if state.running or state.closed or state.index<=1 then return end
    state.index=state.index-1;renderPage()
end)
connect(nextPart.Activated,function()
    if state.running or state.closed or state.index>=#state.parts then return end
    state.index=state.index+1;renderPage()
end)
connect(save.Activated,saveReports)
connect(again.Activated,start)
connect(close.Activated,state.Destroy)
env.AiosPixelLineageInspector=state
task.defer(start)
return state

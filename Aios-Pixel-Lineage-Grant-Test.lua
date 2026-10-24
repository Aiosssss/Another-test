-- AIOS Pixel Lineage - single-request grant test 1.0
-- Made by Ilham Ziqri.
-- Requests GiveRenewalCrystal only after the user presses the test button.
-- Server contract is inferred from client metadata, not verified against server source.
-- Does not change access flags, patch game code, replay requests or edit local inventory.
-- An AdminResult acknowledgement is not proof of a saved inventory change.
--!nocheck
--!nolint

-- GRANT TEST CORE START
local function makeGrantTest(deps)
    local state={used=false,sent=false,waiting=false,closed=false,connection=nil,status="Siap",detail="Tekan Kirim tes sekali untuk mencoba satu permintaan.",observation=""}
    local action="GiveRenewalCrystal"
    local function text(value)
        if type(value)~="string"and type(value)~="number"and type(value)~="boolean"then return "(tidak tersedia)"end
        value=tostring(value):gsub("[%z\1-\8\11\12\14-\31]","")
        if #value>600 then
            value=value:sub(1,600)
            if utf8 and utf8.len then
                while #value>0 and not utf8.len(value)do value=value:sub(1,-2)end
            end
            value=value.."..."
        end
        return value
    end
    function state.Report()
        return table.concat({"AIOS PIXEL LINEAGE - TES PERMINTAAN ITEM v1.0",
            "Aksi: "..action,"Item: RenewalCrystal","Pengiriman dicoba: "..(state.sent and"ya"or"belum"),
            "Status: "..state.status,state.detail,
            state.observation~=""and("Catatan balasan: "..state.observation)or"",
            "Inventory belum diverifikasi oleh tes ini. Periksa lewat Inventory game.",
            "Tidak mengubah izin admin atau inventory lokal."},"\n")
    end
    local function update(status,detail)
        if state.closed then return end
        state.status=status;state.detail=detail
        deps.update(state.Report(),state.used)
    end
    local function disconnect()
        local connection=state.connection;state.connection=nil
        if connection then pcall(function()connection:Disconnect()end)end
    end
    local function finish(status,detail)
        if state.closed or not state.waiting then return end
        state.waiting=false;disconnect();update(status,detail)
    end
    function state.Send()
        if state.closed or state.used then return false end
        state.used=true;state.waiting=true
        update("Menyiapkan tes","Satu permintaan; menunggu AdminResult dengan aksi yang cocok.")
        local connected,connection=pcall(deps.listen,function(kind,data)
            if state.closed or not state.waiting or kind~="AdminResult"or type(data)~="table"then return end
            local replyAction=rawget(data,"action")
            if type(replyAction)=="string"and replyAction~=action then return end
            local ok=rawget(data,"ok")
            local message=text(rawget(data,"text"))
            if replyAction~=action then
                state.observation="AdminResult tanpa pengenal aksi; ok="..text(ok).."; text="..message
                update("Balasan belum dapat dikaitkan","Masih menunggu balasan yang menyebut "..action..". Tidak menganggap balasan umum sebagai keberhasilan.")
                return
            end
            if type(ok)~="boolean"then
                state.observation="Aksi cocok tetapi field ok bukan boolean; text="..message
                update("Format balasan belum lengkap","Masih menunggu balasan yang dapat dinilai.")
                return
            end
            if ok then
                finish("Server menjawab ok=true","Pesan: "..message.."\nPeriksa Renewal Crystal di Inventory game. Balasan ini belum membuktikan item tersimpan.")
            else
                finish("Server menjawab ok=false","Pesan: "..message.."\nPermintaan tidak diulang.")
            end
        end)
        if not connected or not connection then
            state.waiting=false
            update("Tes tidak dikirim","Listener balasan gagal dipasang. Tidak ada permintaan yang dikirim.")
            return false
        end
        state.connection=connection
        state.sent=true
        local sent,reason=pcall(deps.send,{action=action,item="RenewalCrystal",count=1})
        if not sent then finish("Gagal mengirim dari client",text(reason));return false end
        if state.waiting then update("Permintaan dikirim","Menunggu balasan server hingga 12 detik. Inventory belum diverifikasi.")end
        deps.delay(12,function()
            finish("Tidak ada balasan yang cocok","Batas tunggu habis. Ini belum membuktikan item diberikan ataupun ditolak; tidak ada pengulangan otomatis.")
        end)
        return true
    end
    function state.Destroy()
        if state.closed then return end
        state.closed=true;state.waiting=false;disconnect()
    end
    update(state.status,state.detail)
    return state
end
-- GRANT TEST CORE END

local player=game:GetService("Players").LocalPlayer
assert(player,"AIOS: tunggu pemain dimuat.")
local parent=player:FindFirstChild("PlayerGui")or player:WaitForChild("PlayerGui",5)
assert(parent,"AIOS: PlayerGui belum tersedia.")
local env=type(getgenv)=="function"and getgenv()or _G
local previous=env.AiosPixelLineageGrantTest
if type(previous)=="table"and type(previous.Destroy)=="function"then pcall(previous.Destroy)end
local state={closed=false,connections={},text=""}
local function create(class,properties)
    local object=Instance.new(class)
    for key,value in pairs(properties)do object[key]=value end
    return object
end
local function connect(signal,callback)
    local connection=signal:Connect(callback);state.connections[#state.connections+1]=connection
end
local rgb=Color3.fromRGB
local screen=create("ScreenGui",{Name="AiosPixelLineageGrantTest",ResetOnSpawn=false,IgnoreGuiInset=true,
    DisplayOrder=100050,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,Parent=parent})
local panel=create("Frame",{Name="Panel",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
    BackgroundColor3=rgb(20,24,32),BorderSizePixel=0,Parent=screen})
create("UICorner",{CornerRadius=UDim.new(0,12),Parent=panel})
create("UIStroke",{Color=rgb(230,143,66),Thickness=1,Parent=panel})
create("TextLabel",{Text="AIOS - Tes permintaan item",Font=Enum.Font.GothamBold,TextSize=19,
    TextColor3=rgb(255,176,94),BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,
    Position=UDim2.fromOffset(16,12),Size=UDim2.new(1,-70,0,30),Parent=panel})
local close=create("TextButton",{Text="X",Name="Close",Font=Enum.Font.GothamBold,TextSize=19,
    TextColor3=rgb(235,235,235),BackgroundTransparency=1,Position=UDim2.new(1,-48,0,6),Size=UDim2.fromOffset(42,42),Parent=panel})
create("TextLabel",{Text="Mencoba GiveRenewalCrystal satu kali. Server menentukan izin dan hasilnya.",
    Font=Enum.Font.Gotham,TextSize=13,TextWrapped=true,TextColor3=rgb(184,195,210),BackgroundTransparency=1,
    TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(16,47),Size=UDim2.new(1,-32,0,38),Parent=panel})
local scroll=create("ScrollingFrame",{Name="Report",BackgroundColor3=rgb(13,17,24),BorderSizePixel=0,
    Position=UDim2.fromOffset(14,90),Size=UDim2.new(1,-28,1,-151),CanvasSize=UDim2.new(),
    AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,ScrollBarThickness=4,Parent=panel})
create("UIPadding",{PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10),PaddingTop=UDim.new(0,8),PaddingBottom=UDim.new(0,10),Parent=scroll})
local report=create("TextBox",{Name="ReportText",Text="Menyiapkan tes...",Font=Enum.Font.Code,TextSize=13,
    TextColor3=rgb(218,227,238),TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
    TextWrapped=true,MultiLine=true,ClearTextOnFocus=false,BackgroundTransparency=1,
    AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,-8,0,20),Parent=scroll})
local send=create("TextButton",{Name="Send",Text="Kirim tes sekali",Font=Enum.Font.GothamBold,TextSize=14,
    BackgroundColor3=rgb(164,91,36),TextColor3=rgb(255,245,230),BorderSizePixel=0,
    Position=UDim2.new(0,14,1,-47),Size=UDim2.new(.5,-20,0,34),Parent=panel})
local copy=create("TextButton",{Name="Copy",Text="Salin hasil",Font=Enum.Font.GothamBold,TextSize=14,
    BackgroundColor3=rgb(42,52,68),TextColor3=rgb(235,240,248),BorderSizePixel=0,
    Position=UDim2.new(.5,4,1,-47),Size=UDim2.new(.5,-18,0,34),Parent=panel})
for _,object in ipairs({send,copy})do create("UICorner",{CornerRadius=UDim.new(0,7),Parent=object})end
local function resize()
    if state.closed then return end
    local camera=workspace.CurrentCamera
    local view=camera and camera.ViewportSize or Vector2.new(854,480)
    panel.Size=UDim2.fromOffset(math.max(240,math.min(670,view.X-24)),math.max(260,math.min(400,view.Y-24)))
end
resize()
if workspace.CurrentCamera then connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),resize)end
local function display(text,sent)
    if state.closed then return end
    state.text=text;report.Text=text
    send.Text=sent and"Tes sudah digunakan"or"Kirim tes sekali"
    send.Active=not sent;send.AutoButtonColor=not sent
end
local storage=game:GetService("ReplicatedStorage")
local root=storage:FindFirstChild("PlatformBattles")
local remotes=root and root:FindFirstChild("Remotes")
local command=remotes and remotes:FindFirstChild("RPGCommand")
local events=remotes and remotes:FindFirstChild("RPGState")
local probe
if game.GameId~=10767928510 then
    display("Game berbeda. Jalankan di Pixel Lineage. Tidak ada permintaan dikirim.",true)
elseif not command or command.ClassName~="RemoteEvent"or not events or events.ClassName~="RemoteEvent"then
    display("RPGCommand/RPGState belum tersedia. Jalankan ulang setelah game dimuat. Tidak ada permintaan dikirim.",true)
else
    probe=makeGrantTest({
        listen=function(callback)return events.OnClientEvent:Connect(callback)end,
        send=function(payload)command:FireServer("AdminAction",payload)end,
        delay=function(seconds,callback)task.delay(seconds,callback)end,
        update=display,
    })
end
state.Send=function()if probe then return probe.Send()end;return false end
state.Copy=function()
    if state.closed then return end
    local clipboard=type(setclipboard)=="function"and setclipboard or type(toclipboard)=="function"and toclipboard or nil
    local ok,value=false,nil
    if clipboard then ok,value=pcall(clipboard,state.text)end
    if ok and value~=false then copy.Text="Hasil disalin"
    else
        copy.Text="Pilih teks lalu salin"
        pcall(function()report:CaptureFocus();report.CursorPosition=#report.Text+1;report.SelectionStart=1 end)
    end
end
function state.Destroy()
    if state.closed then return end
    state.closed=true
    if probe then probe.Destroy()end
    for _,connection in ipairs(state.connections)do pcall(function()connection:Disconnect()end)end
    screen:Destroy()
    if env.AiosPixelLineageGrantTest==state then env.AiosPixelLineageGrantTest=nil end
end
connect(send.Activated,state.Send)
connect(copy.Activated,state.Copy)
connect(close.Activated,state.Destroy)
env.AiosPixelLineageGrantTest=state
return state

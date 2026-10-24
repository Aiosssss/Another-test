-- AIOS / Pixel Lineage Inspector 1.2 - self-tests and scoped loaded-function metadata.
-- Made by Ilham Ziqri. Standalone; does not replace the AIOS HUB file.
-- Never invokes remotes, executes a game module, hooks calls, or changes gameplay.
-- Optional executor inspection functions are detected and protected with pcall.
-- getgc(false) is used only to find functions belonging to selected game scripts.
-- No GC tables, upvalues, player identifiers, keys, profiles or full sources are exported.
-- References: create.roblox.com/docs/scripting/events/remote
-- docs.sunc.io/Scripts/getscriptclosure/ and docs.sunc.io/Debug/getconstants/
--!nocheck
--!nolint

-- REPORT CORE START
local function buildReport(deps)
    local game,player=deps.game,deps.player
    local caps=deps.caps or{}
    local limits={nodes=12000,remotes=200,scripts=600,analysis=120,source=1024*1024,
        sourceTotal=3*1024*1024,functions=96,depth=4,constants=1500,hints=96,bytes=180000,
        liveReferences=80000,liveFunctions=1800,livePerScript=160,liveRows=160,liveHints=24}
    local stats={nodes=0,remotes=0,scripts=0,analyzed=0,sources=0,closures=0,functions=0,
        constants=0,errors=0,roots=0,truncated=false,shared=0,client=0,analyzedShared=0,analyzedClient=0,
        protoCalls=0,protoEmpty=0,protoChildren=0,protoFallback=0,
        liveReferences=0,liveFunctions=0,liveConstants=0,liveUnmapped=0,liveDenied=0,liveRows=0,liveStatus="belum diperiksa"}
    local lines,bytes={},0
    local function clean(value,max)
        return tostring(value or""):gsub("[%c]"," "):sub(1,max or 180)
    end
    local function add(value,summary)
        value=tostring(value or"")
        if bytes+#value+1>limits.bytes-(summary and 0 or 2200)then stats.truncated=true;return false end
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
        "claim","redeem","equip","skill","remote","fireserver","invokeserver","target","battle",
        "actionid","revision","turnnumber","context","hero","uid"}
    local blocked={"password","token","secret","cookie","hwid","webhook","license","auth","sessionkey","apikey"}
    local function interesting(value)
        if type(value)~="string"or#value<3 or#value>72 or not value:match("^[A-Za-z_][A-Za-z0-9_.:]*$")then return false end
        local low=value:lower()
        for _,word in ipairs(blocked)do if low:find(word,1,true)then return false end end
        for _,word in ipairs(needles)do if low:find(word,1,true)then return true end end
        return false
    end
    local essential={gameconfig=true,gearconfig=true,combatconfig=true,combatrules=true,battlecommandrules=true,
        rpgclient=true,pixelgearview=true,inventorybrowse=true,inventoryweaponstats=true,lootrules=true,lootconfig=true,
        rewardconfig=true,adminpermissions=true,adminconsolemodel=true,admingeareditor=true,marketgiveaways=true}
    local cosmetics={"visual","presentation","preview","showcase","animation","sound","audio","camera","icons","backdrop","layout","feel"}
    local function priority(name,shared)
        local low=name:lower()
        if low=="gameconfig"or low=="gearconfig"then return 0 end
        if essential[low]then return 1 end
        for _,word in ipairs(cosmetics)do if low:find(word,1,true)then return 9 end end
        if low:match("art$")or low:match("fx$")then return 9 end
        for _,word in ipairs(needles)do if low:find(word,1,true)then return shared and 2 or 4 end end
        return shared and 3 or 7
    end
    local function before(a,b)
        if a.rank~=b.rank then return a.rank<b.rank end
        return a.path<b.path
    end
    local function hintRank(value)
        local low=value:lower()
        if low=="fireserver"or low=="invokeserver"or low=="combataction"or low=="gearsell"or low=="rpgcommand"then return 0 end
        for _,word in ipairs(cosmetics)do if low:find(word,1,true)then return 9 end end
        if low:find("tooltip",1,true)or low:find("button",1,true)or low:find("scale",1,true)or low:match("fx$")then return 9 end
        if low:find("give",1,true)or low:find("grant",1,true)or low:find("claim",1,true)or low:find("sell",1,true)then return 1 end
        return 3
    end

    local function selfTests()
        -- This is our own harmless function, not a game function or module.
        local function holder()
            local function nested(text)return "AIOS_INSPECTOR_LOCAL_PROBE_12"..text end
            return nested
        end
        local sample=holder()
        local function outcome(value)
            return value==nil and"tidak tersedia"or value and"lulus"or"gagal/kosong pada fungsi uji sendiri"
        end
        if type(caps.getconstants)=="function"then
            stats.selfConstants=false
            local ok,values=pcall(caps.getconstants,sample)
            if ok and type(values)=="table"then
                local count=0
                for _,value in pairs(values)do
                    count=count+1;if count>1500 then break end
                    if value=="AIOS_INSPECTOR_LOCAL_PROBE_12"then stats.selfConstants=true;break end
                end
            end
        end
        if type(caps.getprotos)=="function"then
            stats.selfProtos=false
            local ok,values=pcall(caps.getprotos,holder)
            if ok and type(values)=="table"then
                local count=0
                for _,value in pairs(values)do
                    count=count+1;if count>96 then break end
                    if type(value)=="function"then stats.selfProtos=true;break end
                end
            end
        end
        if type(caps.getproto)=="function"then
            local ok,value=pcall(caps.getproto,holder,1,false)
            stats.selfProto=ok and type(value)=="function"
        end
        add("TES LOKAL API EXECUTOR (pada fungsi buatan pemeriksa sendiri)")
        add("getconstants: "..outcome(stats.selfConstants))
        add("getprotos: "..outcome(stats.selfProtos))
        add("getproto: "..outcome(stats.selfProto))
        add("Tes ini memisahkan API yang hanya tersedia namanya dari API yang mengembalikan metadata uji.")
        add("")
    end
    local function inspectLoaded(entries)
        add("FUNGSI CLIENT YANG SUDAH DIMUAT (metadata saja; tanpa dekompilasi)")
        add("Metode: getgc(false), lalu getfenv(...).script dicocokkan dengan modul game yang dipilih.")
        add("Tabel GC/profil tidak diperiksa. Fungsi game tidak dipanggil; konstanta fungsi terkait saja yang dibaca.")
        if type(caps.getgc)~="function"or type(caps.getfenv)~="function"or type(caps.getconstants)~="function"then
            stats.liveStatus="API pembacaan fungsi belum tersedia"
            add(stats.liveStatus);return true
        end
        if stats.selfConstants~=true then
            stats.liveStatus="dilewati: getconstants tidak lulus tes lokal"
            add(stats.liveStatus);return true
        end
        local allowed={}
        for _,entry in ipairs(entries)do if entry.rank<=4 then allowed[entry.object]=entry end end
        local ok,references=pcall(caps.getgc,false)
        if not ok or type(references)~="table"then
            stats.liveStatus="getgc(false) ditolak atau tidak mengembalikan daftar"
            add(stats.liveStatus);return true
        end
        local perScript,seenFunctions,rows={},{},{}
        local function rowBefore(a,b)
            if a.rank~=b.rank then return a.rank<b.rank end
            if a.path~=b.path then return a.path<b.path end
            return a.order<b.order
        end
        for _,fn in pairs(references)do
            if cancelled()then return false end
            stats.liveReferences=stats.liveReferences+1
            if stats.liveReferences>limits.liveReferences then stats.truncated=true;break end
            if type(fn)=="function"and not seenFunctions[fn]then
                seenFunctions[fn]=true
                local executorFunction=false
                if type(caps.isexecutorclosure)=="function"then
                    local passed,value=pcall(caps.isexecutorclosure,fn)
                    executorFunction=passed and value==true
                end
                if not executorFunction then
                    local got,environment=pcall(caps.getfenv,fn)
                    local origin=got and type(environment)=="table"and rawget(environment,"script")or nil
                    local entry=origin and allowed[origin]
                    if not entry then stats.liveUnmapped=stats.liveUnmapped+1
                    elseif (perScript[origin]or 0)<limits.livePerScript then
                        stats.liveFunctions=stats.liveFunctions+1
                        perScript[origin]=(perScript[origin]or 0)+1
                        local passed,constants=pcall(caps.getconstants,fn)
                        if passed and type(constants)=="table"then
                            stats.liveConstants=stats.liveConstants+1
                            local names,used={},{}
                            local count=0
                            for _,value in pairs(constants)do
                                count=count+1;if count>limits.constants then stats.truncated=true;break end
                                if interesting(value)and not used[value]then
                                    used[value]=true;names[#names+1]=value
                                end
                            end
                            table.sort(names,function(a,b)if hintRank(a)~=hintRank(b)then return hintRank(a)<hintRank(b)end;return a<b end)
                            if #names>0 then
                                while #names>limits.liveHints do names[#names]=nil end
                                local name,nargs,varargs="tanpa nama",nil,nil
                                if type(caps.info)=="function"then
                                    local named,value=pcall(caps.info,fn,"n")
                                    if named and type(value)=="string"and value:match("^[A-Za-z_][A-Za-z0-9_.:]*$")then
                                        local low=value:lower();local safe=true
                                        for _,word in ipairs(blocked)do if low:find(word,1,true)then safe=false;break end end
                                        if safe then name=clean(value,72)end
                                    end
                                    local counted,n,v=pcall(caps.info,fn,"a")
                                    if counted and type(n)=="number"and n>=0 and n<=100 and n==math.floor(n)then nargs=n;varargs=v==true end
                                end
                                local row={path=entry.path,name=name,nargs=nargs,varargs=varargs,names=names,rank=hintRank(names[1]),order=stats.liveFunctions}
                                if #rows<limits.liveRows then rows[#rows+1]=row
                                else
                                    stats.truncated=true
                                    local worst=1
                                    for n=2,#rows do if rowBefore(rows[worst],rows[n])then worst=n end end
                                    if rowBefore(row,rows[worst])then rows[worst]=row end
                                end
                            end
                        else stats.liveDenied=stats.liveDenied+1 end
                        if stats.liveFunctions>=limits.liveFunctions then stats.truncated=true;break end
                    else stats.truncated=true end
                end
            end
            if stats.liveReferences%160==0 then
                if deps.progress then deps.progress("Mencocokkan fungsi client: "..stats.liveReferences.." referensi; "..stats.liveConstants.." metadata terbaca")end
                if yield()then return false end
            end
        end
        references=nil;seenFunctions=nil
        table.sort(rows,rowBefore)
        stats.liveRows=#rows
        for _,row in ipairs(rows)do
            add("")
            add(row.path.." | "..row.name..(row.nargs and(" | parameter="..row.nargs..(row.varargs and" + vararg"or""))or""))
            add("  Konstanta identifier: "..table.concat(row.names,", "))
        end
        stats.liveStatus=stats.liveConstants>0 and"metadata fungsi terkait berhasil dibaca"or"belum ada metadata fungsi terkait yang berhasil dibaca"
        add("")
        add(stats.liveStatus..". Ini bukan rekaman panggilan atau bukti server menerima suatu perintah.")
        if stats.liveConstants==0 then add("Buka bag dan lakukan satu serangan biasa secara manual, lalu Cek ulang. Jika tetap nol, metode ini tidak memperoleh akses yang diperlukan dari executor.")end
        return true
    end

    add("AIOS PIXEL LINEAGE - LAPORAN PEMERIKSAAN CLIENT v1.2")
    add("Waktu UTC: "..os.date("!%Y-%m-%dT%H:%M:%SZ"))
    add("GameId: "..tostring(game.GameId).." | PlaceId: "..tostring(game.PlaceId))
    add("Mode: snapshot baca-saja. Tidak ada remote yang dipanggil atau modul yang dijalankan.")
    add("Nama/kata yang ditemukan adalah petunjuk, bukan bukti perintah itu tersedia atau diterima server.")
    add("Kode server yang tidak direplikasi tidak dapat diperiksa oleh laporan ini.")
    add("Tidak mengumpulkan profil, UserId, username, kunci, atau isi skrip lengkap.")
    add("")
    add("KEMAMPUAN PEMERIKSAAN")
    for _,name in ipairs({"getscriptclosure","getconstants","getprotos","getproto","getgc","getfenv"})do
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
    selfTests()

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
                local fullPath=path(object)
                local shared=fullPath:find("ReplicatedStorage.PlatformBattles.Shared.",1,true)==1
                if shared then stats.shared=stats.shared+1 else stats.client=stats.client+1 end
                local entry={object=object,kind=class,path=fullPath,shared=shared,rank=priority(object.Name,shared)}
                if #foundScripts<limits.scripts then
                    foundScripts[#foundScripts+1]=entry
                else
                    -- Retain the best candidates, even when they arrive after many client UI scripts.
                    stats.truncated=true
                    local worst=1
                    for n=2,#foundScripts do if before(foundScripts[worst],foundScripts[n])then worst=n end end
                    if before(entry,foundScripts[worst])then foundScripts[worst]=entry end
                end
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
    table.sort(foundScripts,before)
    local focused={}
    for _,entry in ipairs(foundScripts)do if entry.rank<9 then focused[#focused+1]=entry end end
    local selected=math.min(#focused,limits.analysis)
    add("")
    add("REMOTE YANG TERLIHAT (nama/path; tidak dipanggil)")
    if #foundRemotes==0 then add("Tidak ditemukan pada root yang diperiksa.")end
    for _,entry in ipairs(foundRemotes)do add(entry.kind.." | "..entry.path)end
    add("")
    if not inspectLoaded(foundScripts)then return nil,stats end
    add("")
    add("PEMILIHAN PEMERIKSAAN")
    add(string.format("Skrip ditemukan: %d (Shared: %d; client/lainnya: %d). Metadata disimpan: %d.",stats.scripts,stats.shared,stats.client,#foundScripts))
    add(string.format("Menganalisis %d modul prioritas. GameConfig, GearConfig, aturan game, dan pengendali client diperiksa lebih dahulu.",selected))
    add("Modul kosmetik diturunkan prioritasnya. Nama Admin* bukan bukti hak admin atau izin memberi item.")
    add("")
    add("PETUNJUK KODE CLIENT (terbatas; skrip game tidak dieksekusi)")
    local sourceBytes=0
    for index=1,selected do
        if cancelled()then return nil,stats end
        local entry=focused[index]
        stats.analyzed=stats.analyzed+1
        if entry.shared then stats.analyzedShared=stats.analyzedShared+1 else stats.analyzedClient=stats.analyzedClient+1 end
        if deps.progress then deps.progress("Memeriksa "..index.."/"..selected..": "..clean(entry.object.Name,60))end
        local hints,seenHints,commands={}, {},{}
        local function hint(value)
            if not interesting(value)or seenHints[value]then return end
            if #hints<limits.hints then
                seenHints[value]=true;hints[#hints+1]=value
            else
                local worst=1
                for n=2,#hints do
                    if hintRank(hints[n])>hintRank(hints[worst])then worst=n end
                end
                if hintRank(value)<hintRank(hints[worst])then
                    seenHints[hints[worst]]=nil;hints[worst]=value;seenHints[value]=true
                end
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
        local protoCalls,protoEmpty,protoChildren,protoFallback=0,0,0,0
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
                        if item.depth<limits.depth then
                            local returned=0
                            local function enqueue(value)
                                if type(value)~="function"then return end
                                returned=returned+1;protoChildren=protoChildren+1
                                if #pending>=limits.functions then stats.truncated=true;return end
                                if not visited[value]then pending[#pending+1]={fn=value,depth=item.depth+1}end
                            end
                            if type(caps.getprotos)=="function"then
                                protoCalls=protoCalls+1
                                local got,children=pcall(caps.getprotos,item.fn)
                                if got and type(children)=="table"then
                                    local examined=0
                                    for _,value in pairs(children)do
                                        examined=examined+1;if examined>limits.functions then stats.truncated=true;break end
                                        enqueue(value)
                                    end
                                    if returned==0 then protoEmpty=protoEmpty+1 end
                                else stats.errors=stats.errors+1 end
                            end
                            -- Some executors expose getprotos but return an empty table.
                            -- Probe individual inactive protos when that separate API exists.
                            if returned==0 and type(caps.getproto)=="function"then
                                for protoIndex=1,32 do
                                    local got,value=pcall(caps.getproto,item.fn,protoIndex,false)
                                    if not got or type(value)~="function"then break end
                                    protoFallback=protoFallback+1;enqueue(value)
                                    if #pending>=limits.functions then break end
                                end
                            end
                        end
                        if functions%16==0 and yield()then return nil,stats end
                    end
                end
                if cursor<=#pending then stats.truncated=true end
            else closureStatus="tidak tersedia untuk skrip ini"end
        end
        stats.protoCalls=stats.protoCalls+protoCalls;stats.protoEmpty=stats.protoEmpty+protoEmpty
        stats.protoChildren=stats.protoChildren+protoChildren;stats.protoFallback=stats.protoFallback+protoFallback
        table.sort(hints,function(a,b)if hintRank(a)~=hintRank(b)then return hintRank(a)<hintRank(b)end;return a<b end)
        add("")
        add(entry.path)
        add("  Source: "..sourceStatus.." | Metadata: "..closureStatus.." | Fungsi diperiksa: "..functions)
        add(string.format("  Proto: pemeriksaan=%d; daftar kosong=%d; anak terbaca=%d; fallback indeks=%d",protoCalls,protoEmpty,protoChildren,protoFallback))
        add("  Identifier gameplay: "..(#hints>0 and table.concat(hints,", ")or"tidak ada yang terbaca"))
        if #commands>0 then add("  Pola teks pemanggilan (bisa juga komentar/string): "..table.concat(commands,"; "))end
        if yield()then return nil,stats end
    end
    if #foundScripts>selected then stats.truncated=true end
    add("")
    add("LAMPIRAN METADATA MODUL/LOCAL SCRIPT (diurutkan menurut prioritas)")
    for _,entry in ipairs(foundScripts)do if not add(entry.kind.." | "..entry.path)then break end end
    add("",true)
    add("RINGKASAN",true)
    add(string.format("Root: %d | Objek: %d | Remote: %d | Skrip: %d | Dianalisis: %d",stats.roots,stats.nodes,stats.remotes,stats.scripts,stats.analyzed),true)
    add(string.format("Analisis Shared: %d | Analisis client/lainnya: %d",stats.analyzedShared,stats.analyzedClient),true)
    add(string.format("Source terbaca: %d | Closure terbaca: %d | Tabel konstanta terbaca: %d | Pemeriksaan ditolak/gagal: %d",stats.sources,stats.closures,stats.constants,stats.errors),true)
    add(string.format("Proto: pemeriksaan=%d; daftar kosong=%d; anak terbaca=%d; fallback indeks=%d",stats.protoCalls,stats.protoEmpty,stats.protoChildren,stats.protoFallback),true)
    add(string.format("Fungsi dimuat: referensi=%d; fungsi terkait=%d; konstanta terbaca=%d; ditolak=%d; baris hasil=%d",stats.liveReferences,stats.liveFunctions,stats.liveConstants,stats.liveDenied,stats.liveRows),true)
    add("Status fungsi dimuat: "..stats.liveStatus,true)
    if stats.closures>0 and stats.functions==stats.closures then
        add("Catatan: hanya fungsi terluar yang terbaca. Bisa karena tidak ada proto yang tersedia atau keterbatasan implementasi executor; belum bisa dibedakan dari laporan ini.",true)
    end
    add("Cakupan: "..(stats.truncated and"dibatasi; ada bagian yang tidak diperiksa/ditampilkan"or"root yang tersedia telah diperiksa dalam batas laporan"),true)
    add("Tidak membaca ServerScriptService, ServerStorage, tabel GC, upvalue, profil, atau lalu lintas pemain. Referensi fungsi GC dicocokkan hanya melalui field script.",true)
    add("Hasil ini belum membuktikan spawn item atau one hit kill bisa dilakukan.",true)
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
local title=create("TextLabel",{Name="Title",Text="AIOS Inspector 1.2",Font=Enum.Font.GothamBold,TextSize=22,
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
    getproto=type(getproto)=="function"and getproto or debugTable.getproto,
    getgc=type(getgc)=="function"and getgc or nil,
    getfenv=type(getfenv)=="function"and getfenv or nil,
    isexecutorclosure=type(isexecutorclosure)=="function"and isexecutorclosure or nil,
    info=debugTable.info,
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

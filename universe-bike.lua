--[[
    Bike Universe  |  Auto Drive + Anti-AFK
    NostraTeam
]]

local TARGET_POSITION = Vector3.new(5344.32, 3.5, 493.93)
local TARGET_CFRAME = CFrame.new(TARGET_POSITION) * CFrame.Angles(0, math.rad(-90), 0)

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
local Cfg = {
    AutoDrive = true,
    AutoTeleport = true,
    AntiAFK = true,
    Notifications = true,
    RespawnTeleport = true,
    AutoRejoin = true, -- rejoin automatically if you get disconnected
    AutoReseat = true, -- sit back on your vehicle if you fall off / respawn
    FpsBoost = false, -- lower graphics quality for more FPS
    Render3DOff = false, -- turn off 3D rendering while AFK (saves GPU / battery)
    JumpInterval = 45, -- seconds between anti-AFK space presses
    HoldTime = 0.5, -- seconds space is held
}

local FlagNames = {
    AutoRejoin = "Auto Rejoin",
    AutoReseat = "Auto Re-sit",
    FpsBoost = "FPS Boost",
    Render3DOff = "Save GPU mode",
    AutoDrive = "Auto Drive",
    AutoTeleport = "Auto Teleport",
    AntiAFK = "Anti-AFK",
    Notifications = "Notifications",
    RespawnTeleport = "Teleport on respawn",
}

local Alive = true
local HasTeleported = false
local TeleportCount = 0
local JumpCount = 0
local Jumping = false
local JumpEnd = 0
local StartTime = os.clock()
local LastJump = os.clock()
local TopSpeed = 0
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local CoreGui = nil
pcall(function() CoreGui = game:GetService("CoreGui") end)
local Rejoining = false
local SavedSeat = nil
local SavedVehicleName = nil
local NextReseat = 0
local PendingReseat = false
local LastFullScan = -100
local ReseatFails = 0
local Lighting = game:GetService("Lighting")
local BoostBackup = nil
local ToggleKey = Enum.KeyCode.K
local HideKey = Enum.KeyCode.RightShift
local Listening = nil
local Connections = {}

-- drive state
local Humanoid = nil
local LastSeat = nil
local KeyHeld = false
local NextKeyRefresh = 0

local function track(conn)
    table.insert(Connections, conn)
    return conn
end

---------------------------------------------------------------------
-- Theme
---------------------------------------------------------------------
local C = {
    bg = Color3.fromRGB(19, 20, 26),
    side = Color3.fromRGB(14, 15, 20),
    card = Color3.fromRGB(28, 29, 37),
    cardHi = Color3.fromRGB(36, 38, 48),
    line = Color3.fromRGB(42, 44, 56),
    text = Color3.fromRGB(233, 235, 241),
    dim = Color3.fromRGB(125, 130, 148),
    accent = Color3.fromRGB(70, 140, 255),
    good = Color3.fromRGB(64, 196, 128),
    warn = Color3.fromRGB(240, 180, 60),
    bad = Color3.fromRGB(232, 80, 80),
    off = Color3.fromRGB(58, 60, 74),
}

---------------------------------------------------------------------
-- Languages
---------------------------------------------------------------------
local Languages = {
    { "en", "English" },
    { "tr", "Türkçe" },
    { "es", "Español" },
    { "de", "Deutsch" },
    { "fr", "Français" },
}
local Lang = "en"
local Strings = { tr = {}, es = {}, de = {}, fr = {} }
local LangCols = { tr = 2, es = 3, de = 4, fr = 5 }

-- { English, Türkçe, Español, Deutsch, Français }
local Rows = {
    -- tabs
    { "Main", "Ana Sayfa", "Principal", "Start", "Accueil" },
    { "Settings", "Ayarlar", "Ajustes", "Einstellungen", "Paramètres" },
    { "Log", "Kayıt", "Registro", "Protokoll", "Journal" },
    { "Info", "Bilgi", "Info", "Info", "Infos" },
    -- status
    { "Waiting", "Bekleniyor", "Esperando", "Warten", "En attente" },
    { "Driving", "Sürüyor", "Conduciendo", "Fährt", "Conduite" },
    { "Paused", "Duraklatıldı", "En pausa", "Pausiert", "En pause" },
    { "Rejoining", "Yeniden bağlanıyor", "Reconectando", "Verbinde neu", "Reconnexion" },
    { "Sit on a vehicle to begin", "Başlamak için bir araca bin", "Siéntate en un vehículo para empezar", "Setz dich zum Start auf ein Fahrzeug", "Montez sur un véhicule pour commencer" },
    { "Auto Drive is turned off", "Otomatik sürüş kapalı", "La conducción automática está desactivada", "Auto-Fahren ist ausgeschaltet", "La conduite auto est désactivée" },
    { "Connection lost - joining a new server", "Bağlantı koptu - yeni sunucuya giriliyor", "Conexión perdida - entrando a un servidor nuevo", "Verbindung verloren - neuer Server wird betreten", "Connexion perdue - rejoint un nouveau serveur" },
    { "Vehicle: ", "Araç: ", "Vehículo: ", "Fahrzeug: ", "Véhicule : " },
    { "SPEED", "HIZ", "VELOCIDAD", "TEMPO", "VITESSE" },
    { "studs / sec", "stud / sn", "studs / s", "Studs / s", "studs / s" },
    { "RUNTIME", "SÜRE", "TIEMPO", "LAUFZEIT", "DURÉE" },
    { "TELEPORTS", "IŞINLANMA", "TELEPORTES", "TELEPORTS", "TÉLÉPORTS" },
    { "JUMPS", "ZIPLAMA", "SALTOS", "SPRÜNGE", "SAUTS" },
    { "TO TARGET", "HEDEFE", "AL OBJETIVO", "ZUM ZIEL", "VERS LA CIBLE" },
    { "Next anti-AFK jump", "Sonraki anti-AFK basışı", "Próxima pulsación anti-AFK", "Nächster Anti-AFK-Tastendruck", "Prochain appui anti-AFK" },
    { "Off", "Kapalı", "Apagado", "Aus", "Désactivé" },
    { "Pressing...", "Basılıyor...", "Pulsando...", "Drücke...", "Appui..." },
    -- sections
    { "AUTOMATION", "OTOMASYON", "AUTOMATIZACIÓN", "AUTOMATISIERUNG", "AUTOMATISATION" },
    { "KEYBINDS", "TUŞ ATAMALARI", "ATAJOS", "TASTENBELEGUNG", "RACCOURCIS" },
    { "ANTI-AFK TIMING", "ANTI-AFK ZAMANLAMASI", "TIEMPOS ANTI-AFK", "ANTI-AFK-ZEITEN", "DÉLAIS ANTI-AFK" },
    { "BEHAVIOR", "DAVRANIŞ", "COMPORTAMIENTO", "VERHALTEN", "COMPORTEMENT" },
    { "PERFORMANCE", "PERFORMANS", "RENDIMIENTO", "LEISTUNG", "PERFORMANCES" },
    { "APPEARANCE", "GÖRÜNÜM", "APARIENCIA", "DESIGN", "APPARENCE" },
    { "LANGUAGE", "DİL", "IDIOMA", "SPRACHE", "LANGUE" },
    { "SCRIPT", "SCRİPT", "SCRIPT", "SKRIPT", "SCRIPT" },
    { "ABOUT", "HAKKINDA", "ACERCA DE", "ÜBER", "À PROPOS" },
    { "HOW IT WORKS", "NASIL ÇALIŞIR", "CÓMO FUNCIONA", "SO FUNKTIONIERT'S", "FONCTIONNEMENT" },
    { "SESSION", "OTURUM", "SESIÓN", "SITZUNG", "SESSION" },
    { "HOTKEYS", "KISAYOLLAR", "TECLAS RÁPIDAS", "TASTENKÜRZEL", "RACCOURCIS CLAVIER" },
    { "ACTIVITY", "ETKİNLİK", "ACTIVIDAD", "AKTIVITÄT", "ACTIVITÉ" },
    -- toggles
    { "Auto Drive", "Otomatik Sürüş", "Conducción automática", "Auto-Fahren", "Conduite auto" },
    { "Holds W continuously while enabled", "Açıkken W tuşunu sürekli basılı tutar", "Mantiene W pulsada mientras esté activo", "Hält W gedrückt, solange aktiv", "Maintient W enfoncée tant que c'est activé" },
    { "Auto Teleport", "Otomatik Işınlanma", "Teletransporte automático", "Auto-Teleport", "Téléportation auto" },
    { "Moves your vehicle to the target point", "Aracını hedef noktaya taşır", "Mueve tu vehículo al punto objetivo", "Bringt dein Fahrzeug zum Zielpunkt", "Déplace votre véhicule vers le point cible" },
    { "Anti-AFK", "Anti-AFK", "Anti-AFK", "Anti-AFK", "Anti-AFK" },
    { "One short space press every interval", "Her aralıkta tek kısa boşluk tuşu basışı", "Una pulsación corta de espacio en cada intervalo", "Ein kurzer Leertastendruck pro Intervall", "Un appui bref sur espace à chaque intervalle" },
    { "Auto Re-sit", "Otomatik Tekrar Oturma", "Volver a sentarse automático", "Auto-Wiederhinsetzen", "Reprise de place auto" },
    { "Sits back on your vehicle if you fall off", "Düşersen aracına tekrar oturur", "Te vuelve a sentar en el vehículo si te caes", "Setzt dich zurück aufs Fahrzeug, wenn du fällst", "Vous remet sur le véhicule si vous tombez" },
    { "Auto Rejoin", "Otomatik Yeniden Giriş", "Reentrada automática", "Auto-Wiederbeitritt", "Reconnexion auto" },
    { "Rejoins if disconnected (public servers only)", "Bağlantı koparsa yeniden girer (sadece herkese açık sunucular)", "Reentra si te desconectas (solo servidores públicos)", "Tritt bei Trennung neu bei (nur öffentliche Server)", "Se reconnecte en cas de déconnexion (serveurs publics uniquement)" },
    -- buttons
    { "Teleport Now", "Şimdi Işınla", "Teletransportar ya", "Jetzt teleportieren", "Se téléporter" },
    { "Reset Stats", "İstatistikleri Sıfırla", "Restablecer estadísticas", "Statistik zurücksetzen", "Réinitialiser les stats" },
    { "Clear Log", "Kaydı Temizle", "Borrar registro", "Protokoll leeren", "Effacer le journal" },
    { "Unload Script", "Scripti Kapat", "Descargar script", "Skript beenden", "Décharger le script" },
    -- settings
    { "Toggle Auto Drive", "Otomatik Sürüşü Aç/Kapat", "Alternar conducción automática", "Auto-Fahren umschalten", "Basculer la conduite auto" },
    { "Quickly start or stop driving", "Sürüşü hızlıca başlat veya durdur", "Inicia o detén la conducción rápidamente", "Fahren schnell starten oder stoppen", "Démarrer ou arrêter la conduite rapidement" },
    { "Show / Hide Menu", "Menüyü Göster / Gizle", "Mostrar / ocultar menú", "Menü ein-/ausblenden", "Afficher / masquer le menu" },
    { "Hide the window out of the way", "Pencereyi yoldan çekmek için gizle", "Oculta la ventana para despejar la vista", "Blendet das Fenster aus", "Masque la fenêtre pour dégager la vue" },
    { "Press a key...", "Bir tuşa bas...", "Pulsa una tecla...", "Taste drücken...", "Appuyez sur une touche..." },
    { "Jump Interval", "Basış Aralığı", "Intervalo de pulsación", "Tastenintervall", "Intervalle d'appui" },
    { "Seconds between space presses", "Boşluk tuşu basışları arası saniye", "Segundos entre pulsaciones de espacio", "Sekunden zwischen Leertastendrücken", "Secondes entre les appuis sur espace" },
    { "Press Length", "Basış Süresi", "Duración de pulsación", "Tastendauer", "Durée d'appui" },
    { "How long space is held down (seconds)", "Boşluk tuşunun basılı kalma süresi (saniye)", "Cuánto se mantiene el espacio (segundos)", "Wie lange die Leertaste gehalten wird (Sekunden)", "Durée de maintien de la touche espace (secondes)" },
    { "Teleport on respawn", "Doğunca ışınlan", "Teletransportar al reaparecer", "Beim Respawn teleportieren", "Téléportation à la réapparition" },
    { "Teleport again after your character respawns", "Karakterin yeniden doğduktan sonra tekrar ışınlar", "Teletransporta de nuevo tras reaparecer", "Teleportiert erneut nach dem Respawn", "Se téléporte à nouveau après la réapparition" },
    { "Notifications", "Bildirimler", "Notificaciones", "Benachrichtigungen", "Notifications" },
    { "Show pop-up messages in the corner", "Köşede açılır mesajları göster", "Muestra mensajes emergentes en la esquina", "Zeigt Pop-up-Meldungen in der Ecke", "Affiche des messages contextuels dans le coin" },
    { "FPS Boost", "FPS Artırıcı", "Mejora de FPS", "FPS-Boost", "Boost FPS" },
    { "Lowest graphics quality and no shadows", "En düşük grafik kalitesi ve gölgesiz", "Calidad gráfica mínima y sin sombras", "Niedrigste Grafikqualität und keine Schatten", "Qualité graphique minimale et sans ombres" },
    { "Save GPU mode", "GPU Tasarruf Modu", "Modo ahorro de GPU", "GPU-Sparmodus", "Mode économie GPU" },
    { "Turns off 3D rendering while AFK (screen goes blank)", "AFK iken 3D çizimi kapatır (ekran boşalır)", "Desactiva el renderizado 3D en AFK (la pantalla queda en blanco)", "Schaltet 3D-Darstellung im AFK aus (Bildschirm wird leer)", "Désactive le rendu 3D en AFK (l'écran devient vide)" },
    { "Accent Color", "Vurgu Rengi", "Color de acento", "Akzentfarbe", "Couleur d'accent" },
    { "Changes highlights across the menu", "Menüdeki vurguları değiştirir", "Cambia los resaltados del menú", "Ändert die Hervorhebungen im Menü", "Change les accents du menu" },
    { "Language", "Dil", "Idioma", "Sprache", "Langue" },
    { "Choose the menu language", "Menü dilini seç", "Elige el idioma del menú", "Menüsprache wählen", "Choisissez la langue du menu" },
    -- info
    { "Script", "Script", "Script", "Skript", "Script" },
    { "Developer", "Geliştirici", "Desarrollador", "Entwickler", "Développeur" },
    { "Moves vehicle to target", "Aracı hedefe taşır", "Mueve el vehículo al objetivo", "Bringt Fahrzeug zum Ziel", "Déplace le véhicule vers la cible" },
    { "Holds W non-stop", "W'yi kesintisiz basılı tutar", "Mantiene W sin parar", "Hält W dauerhaft gedrückt", "Maintient W sans arrêt" },
    { "Sits back on vehicle", "Araca tekrar oturur", "Vuelve a sentarse en el vehículo", "Setzt sich zurück aufs Fahrzeug", "Se remet sur le véhicule" },
    { "Reconnects if kicked", "Atılırsan yeniden bağlanır", "Se reconecta si te expulsan", "Verbindet neu bei Kick", "Se reconnecte en cas d'expulsion" },
    { "Top speed", "En yüksek hız", "Velocidad máxima", "Höchstgeschwindigkeit", "Vitesse max" },
    { "Show / Hide", "Göster / Gizle", "Mostrar / ocultar", "Ein-/Ausblenden", "Afficher / masquer" },
    -- messages
    { "%s enabled", "%s açıldı", "%s activado", "%s aktiviert", "%s activé" },
    { "%s disabled", "%s kapatıldı", "%s desactivado", "%s deaktiviert", "%s désactivé" },
    { "Respawned - resyncing", "Yeniden doğdun - senkronize ediliyor", "Reapareciste - resincronizando", "Respawn - synchronisiere neu", "Réapparition - resynchronisation" },
    { "Disconnected - rejoining", "Bağlantı koptu - yeniden giriliyor", "Desconectado - reentrando", "Getrennt - Wiederbeitritt", "Déconnecté - reconnexion" },
    { "Vehicle teleported", "Araç ışınlandı", "Vehículo teletransportado", "Fahrzeug teleportiert", "Véhicule téléporté" },
    { "No vehicle found - sit on one first", "Araç bulunamadı - önce bir araca bin", "No se encontró vehículo - siéntate en uno primero", "Kein Fahrzeug gefunden - setz dich zuerst auf eins", "Aucun véhicule - montez d'abord sur un" },
    { "Session stats reset", "Oturum istatistikleri sıfırlandı", "Estadísticas de sesión restablecidas", "Sitzungsstatistik zurückgesetzt", "Stats de session réinitialisées" },
    { "Key set to %s", "Tuş %s olarak ayarlandı", "Tecla establecida en %s", "Taste auf %s gesetzt", "Touche définie sur %s" },
    { "Bike Universe loaded", "Bike Universe yüklendi", "Bike Universe cargado", "Bike Universe geladen", "Bike Universe chargé" },
    { "Vehicle teleported to target", "Araç hedefe ışınlandı", "Vehículo teletransportado al objetivo", "Fahrzeug zum Ziel teleportiert", "Véhicule téléporté vers la cible" },
    { "Anti-AFK: space pressed", "Anti-AFK: boşluk tuşuna basıldı", "Anti-AFK: espacio pulsado", "Anti-AFK: Leertaste gedrückt", "Anti-AFK : espace appuyé" },
    { "Re-sitting on vehicle", "Araca tekrar oturuluyor", "Volviendo a sentarse en el vehículo", "Setze mich zurück aufs Fahrzeug", "Remise sur le véhicule" },
    { "Private server - Auto Rejoin is off", "Özel sunucu - Otomatik Yeniden Giriş kapalı", "Servidor privado - reentrada automática desactivada", "Privater Server - Auto-Wiederbeitritt aus", "Serveur privé - reconnexion auto désactivée" },
    { "Space every %ds (%.1fs)", "Her %d sn'de bir boşluk (%.1f sn)", "Espacio cada %ds (%.1fs)", "Leertaste alle %ds (%.1fs)", "Espace toutes les %ds (%.1fs)" },
    { "%d studs/s", "%d stud/sn", "%d studs/s", "%d Studs/s", "%d studs/s" },
}
for _, row in ipairs(Rows) do
    for code, col in pairs(LangCols) do
        Strings[code][row[1]] = row[col]
    end
end

-- translate a key (English text); falls back to the English text itself
local function T(s)
    local t = Strings[Lang]
    return t and t[s] or s
end

-- every translatable label / button registers here so it can be re-translated live
local Localized = {}
local function localize(obj, key)
    table.insert(Localized, { obj, key })
end

---------------------------------------------------------------------
-- CORE ENGINE  (runs on its own - does not depend on the UI at all)
---------------------------------------------------------------------
local log = function() end    -- replaced by the real logger once the UI exists
local notify = function() end -- replaced by the real toast once the UI exists
local saveConfig = function() end -- replaced once config support is loaded
local Painters = {}

local function getHumanoid()
    if Humanoid and Humanoid.Parent then
        return Humanoid
    end
    local char = LocalPlayer.Character
    Humanoid = char and char:FindFirstChildOfClass("Humanoid") or nil
    return Humanoid
end

local function getSeat()
    local hum = getHumanoid()
    return hum and hum.SeatPart or nil
end

-- the seat's parent model is the vehicle
local function getVehicle()
    local seat = getSeat()
    if not seat then return nil end
    local parent = seat.Parent
    if parent and parent:IsA("Model") then
        return parent
    end
    return seat
end

local function zeroVelocity(part)
    part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
end

local function sendKey(down, key)
    pcall(function()
        VIM:SendKeyEvent(down, key, false, game)
    end)
end

local function releaseKeys()
    sendKey(false, Enum.KeyCode.W)
    sendKey(false, Enum.KeyCode.Space)
    Jumping = false
    KeyHeld = false
    pcall(function()
        local seat = getSeat()
        if seat and seat:IsA("VehicleSeat") then
            seat.Throttle = 0
            seat.ThrottleFloat = 0
        end
    end)
end

local function TryTeleport()
    local vehicle = getVehicle()
    if not vehicle then
        return false
    end
    pcall(function()
        if vehicle:IsA("Model") then
            vehicle:PivotTo(TARGET_CFRAME)
            for _, p in ipairs(vehicle:GetDescendants()) do
                if p:IsA("BasePart") then zeroVelocity(p) end
            end
        else
            vehicle.CFrame = TARGET_CFRAME
            zeroVelocity(vehicle)
        end
    end)
    HasTeleported = true
    TeleportCount = TeleportCount + 1
    log("Vehicle teleported to target", C.good)
    return true
end

-- find a free seat of the vehicle we were driving before
local function findSeat()
    if SavedSeat and SavedSeat.Parent and SavedSeat.Occupant == nil and not SavedSeat.Disabled then
        return SavedSeat
    end
    local hum = getHumanoid()
    local root = hum and hum.RootPart
    if not root then return nil end
    local best, bestDist = nil, nil
    local function consider(d)
        if (d:IsA("VehicleSeat") or d:IsA("Seat")) and d.Occupant == nil and not d.Disabled then
            local pname = d.Parent and d.Parent.Name or d.Name
            if pname == SavedVehicleName then
                local dist = (d.Position - root.Position).Magnitude
                if not bestDist or dist < bestDist then
                    best, bestDist = d, dist
                end
            end
        end
    end

    -- 1) look only at parts near the character (cheap, no big tables)
    local okN, near = pcall(function()
        return workspace:GetPartBoundsInRadius(root.Position, 400)
    end)
    if okN and near then
        for _, d in ipairs(near) do consider(d) end
    end
    if best then return best end

    -- 2) the whole map is only scanned rarely (at most once a minute)
    local now = os.clock()
    if now - LastFullScan >= 60 then
        LastFullScan = now
        for _, d in ipairs(workspace:GetDescendants()) do consider(d) end
    end
    return best
end

-- sit back on the vehicle; returns true if a seat was found
local function tryReseat()
    local hum = getHumanoid()
    if not hum or hum.Health <= 0 or not hum.RootPart then return false end
    local seat = findSeat()
    if not seat then return false end
    PendingReseat = true
    -- FIX: if the sit never succeeds, don't leave PendingReseat stuck on forever
    task.delay(4, function() PendingReseat = false end)
    log("Re-sitting on vehicle", C.dim)
    pcall(function() seat:Sit(hum) end)
    task.delay(0.35, function()
        if Alive and hum.Parent and not hum.SeatPart and seat.Parent then
            local root = hum.RootPart
            if root then
                pcall(function() root.CFrame = seat.CFrame * CFrame.new(0, 2, 0) end)
            end
        end
    end)
    return true
end

-- performance helpers
local function applyBoost(on)
    pcall(function()
        if on then
            if not BoostBackup then
                BoostBackup = {
                    quality = settings().Rendering.QualityLevel,
                    shadows = Lighting.GlobalShadows,
                }
            end
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            Lighting.GlobalShadows = false
        elseif BoostBackup then
            settings().Rendering.QualityLevel = BoostBackup.quality
            Lighting.GlobalShadows = BoostBackup.shadows
            BoostBackup = nil
        end
    end)
end

local function apply3D(off)
    pcall(function()
        RunService:Set3dRenderingEnabled(not off)
    end)
end

local function setFlag(key, value)
    Cfg[key] = value
    if Painters[key] then Painters[key]() end
    if key == "FpsBoost" then
        applyBoost(value)
    elseif key == "Render3DOff" then
        apply3D(value)
    elseif key == "AutoDrive" then
        if value then
            HasTeleported = false
            KeyHeld = false
        else
            releaseKeys()
        end
    elseif key == "AutoTeleport" and value then
        HasTeleported = false
    elseif key == "AntiAFK" then
        LastJump = os.clock()
        if not value and Jumping then
            sendKey(false, Enum.KeyCode.Space)
            Jumping = false
        end
    end
    saveConfig()
    notify(string.format(T(value and "%s enabled" or "%s disabled"), T(FlagNames[key])), value and C.good or C.warn)
end

-- anti-afk (idle event)
track(LocalPlayer.Idled:Connect(function()
    if not Cfg.AntiAFK then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
end))

-- auto rejoin: if the game kicks / disconnects you, join a fresh server.
-- To get the script back automatically, save it in your executor's workspace
-- folder as "BikeUniverse.lua" (or put it in the autoexecute folder).
local function queueReload()
    pcall(function()
        local q = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
        if q then
            q('pcall(function() if isfile and isfile("BikeUniverse.lua") then loadstring(readfile("BikeUniverse.lua"))() end end)')
        end
    end)
end

local PrivateNotice = false
local function rejoin()
    if Rejoining or not Alive or not Cfg.AutoRejoin then return end
    if game.PrivateServerId ~= "" then
        -- private / VIP servers: leave the player alone, rejoining would move them to a public server
        if not PrivateNotice then
            PrivateNotice = true
            notify("Private server - Auto Rejoin is off", C.warn)
        end
        return
    end
    Rejoining = true
    notify("Disconnected - rejoining", C.warn)
    task.spawn(function()
        task.wait(1.5) -- let the error screen settle
        queueReload()
        while Alive and Cfg.AutoRejoin do
            pcall(function()
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end)
            task.wait(10) -- retry if the teleport did not go through
        end
        Rejoining = false
    end)
end

track(GuiService.ErrorMessageChanged:Connect(function()
    local msg = ""
    pcall(function() msg = GuiService:GetErrorMessage() end)
    if msg ~= "" then rejoin() end
end))

task.spawn(function()
    if not CoreGui then return end
    local ok, overlay = pcall(function()
        return CoreGui:WaitForChild("RobloxPromptGui", 15):WaitForChild("promptOverlay", 15)
    end)
    if ok and overlay and Alive then
        track(overlay.ChildAdded:Connect(function(child)
            if child.Name == "ErrorPrompt" then rejoin() end
        end))
    end
end)

-- ONE engine loop: teleport, drive and anti-AFK all run here, exactly on time.
-- No polling threads, no task.wait delays.
track(RunService.Heartbeat:Connect(function()
    if not Alive then return end
    local now = os.clock()
    local seat = getSeat()

    -- new seat (or left the seat): make sure W gets pressed again right away
    if seat ~= LastSeat then
        LastSeat = seat
        KeyHeld = false
        if seat then
            SavedSeat = seat
            ReseatFails = 0
            SavedVehicleName = seat.Parent and seat.Parent.Name or seat.Name
            if PendingReseat then
                PendingReseat = false
                HasTeleported = not Cfg.RespawnTeleport
            end
        end
    end

    -- fell off or respawned: sit back on the vehicle
    if not seat and Cfg.AutoDrive and Cfg.AutoReseat and SavedVehicleName and now >= NextReseat then
        if tryReseat() then
            ReseatFails = 0
            NextReseat = now + 2
        else
            ReseatFails = math.min(ReseatFails + 1, 8)
            NextReseat = now + math.min(4 * ReseatFails, 30)
        end
    end

    if Cfg.AutoDrive then
        -- teleport the moment a vehicle is available
        if seat and Cfg.AutoTeleport and not HasTeleported then
            TryTeleport()
        end

        -- hold W (press once, refresh every second as a safety net)
        if (not KeyHeld) or now >= NextKeyRefresh then
            sendKey(true, Enum.KeyCode.W)
            KeyHeld = true
            NextKeyRefresh = now + 1
        end

        -- throttle only touched when needed
        if seat and seat:IsA("VehicleSeat") and seat.Throttle ~= 1 then
            seat.Throttle = 1
            seat.ThrottleFloat = 1
        end
    end

    -- anti-AFK: ONE short space press, exactly when the countdown reaches zero.
    -- The cycle is measured press-to-press, so it is always exactly JumpInterval.
    if Cfg.AntiAFK then
        if Jumping then
            if now >= JumpEnd then
                sendKey(false, Enum.KeyCode.Space)
                Jumping = false
            end
        elseif now - LastJump >= Cfg.JumpInterval then
            Jumping = true
            LastJump = now
            JumpEnd = now + Cfg.HoldTime
            JumpCount = JumpCount + 1
            sendKey(true, Enum.KeyCode.Space)
            log("Anti-AFK: space pressed", C.dim)
        end
    else
        LastJump = now
    end
end))

track(LocalPlayer.CharacterAdded:Connect(function()
    Humanoid = nil
    LastSeat = nil
    KeyHeld = false
    Jumping = false
    HasTeleported = not Cfg.RespawnTeleport
    NextReseat = os.clock() + 2.5
    notify("Respawned - resyncing", C.dim)
end))

local Swatches = {
    { "Blue", Color3.fromRGB(70, 140, 255) },
    { "Cyan", Color3.fromRGB(34, 200, 230) },
    { "Emerald", Color3.fromRGB(52, 199, 140) },
    { "Amber", Color3.fromRGB(245, 166, 35) },
    { "Rose", Color3.fromRGB(244, 86, 120) },
    { "Violet", Color3.fromRGB(139, 110, 246) },
}

---------------------------------------------------------------------
-- Saved settings (only works if your executor supports readfile/writefile)
---------------------------------------------------------------------
local CONFIG_FILE = "BikeUniverse_config.json"
local AccentIndex = 1
local ConfigReady = false
local saveToken = 0

local function loadConfig()
    local ok, data = pcall(function()
        if type(isfile) == "function" and type(readfile) == "function" and isfile(CONFIG_FILE) then
            return HttpService:JSONDecode(readfile(CONFIG_FILE))
        end
    end)
    if not ok or type(data) ~= "table" then return end

    for _, k in ipairs({ "AutoTeleport", "AntiAFK", "Notifications", "RespawnTeleport", "AutoRejoin", "AutoReseat", "FpsBoost" }) do
        if type(data[k]) == "boolean" then Cfg[k] = data[k] end
    end
    if type(data.Language) == "string" and (data.Language == "en" or Strings[data.Language]) then
        Lang = data.Language
    end
    if type(data.JumpInterval) == "number" then Cfg.JumpInterval = math.clamp(math.floor(data.JumpInterval), 15, 120) end
    if type(data.HoldSeconds) == "number" then Cfg.HoldTime = math.clamp(math.floor(data.HoldSeconds * 10 + 0.5) / 10, 0.1, 3) end

    local function keyFrom(name)
        if type(name) ~= "string" then return nil end
        local okk, kc = pcall(function() return Enum.KeyCode[name] end)
        return okk and kc or nil
    end
    ToggleKey = keyFrom(data.ToggleKey) or ToggleKey
    HideKey = keyFrom(data.HideKey) or HideKey

    if type(data.Accent) == "number" and Swatches[data.Accent] then
        AccentIndex = data.Accent
        C.accent = Swatches[AccentIndex][2]
    end
end

saveConfig = function()
    if not ConfigReady then return end
    saveToken = saveToken + 1
    local mine = saveToken
    task.delay(0.6, function() -- debounce: only write once the user stops changing things
        if mine ~= saveToken then return end
        pcall(function()
            if type(writefile) ~= "function" then return end
            writefile(CONFIG_FILE, HttpService:JSONEncode({
                AutoTeleport = Cfg.AutoTeleport,
                AntiAFK = Cfg.AntiAFK,
                Notifications = Cfg.Notifications,
                RespawnTeleport = Cfg.RespawnTeleport,
                AutoRejoin = Cfg.AutoRejoin,
                AutoReseat = Cfg.AutoReseat,
                FpsBoost = Cfg.FpsBoost,
                Language = Lang,
                JumpInterval = Cfg.JumpInterval,
                HoldSeconds = Cfg.HoldTime,
                ToggleKey = ToggleKey.Name,
                HideKey = HideKey.Name,
                Accent = AccentIndex,
            }))
        end)
    end)
end

loadConfig()

local F_REG = Enum.Font.Gotham
local F_MED = Enum.Font.GothamMedium
local F_BOLD = Enum.Font.GothamBold

local WIN_W, WIN_H, TOP_H, SIDE_W = 600, 468, 46, 140
local fast = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local smooth = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function tween(obj, info, props)
    TweenService:Create(obj, info, props):Play()
end

local function new(class, props, parent)
    local inst = Instance.new(class)
    if class == "TextLabel" or class == "TextButton" or class == "ScreenGui" then
        pcall(function() inst.AutoLocalize = false end) -- keep the menu in English
    end
    for k, v in pairs(props) do
        inst[k] = v
    end
    inst.Parent = parent
    return inst
end

local function corner(parent, r)
    return new("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end

local function stroke(parent, color, transparency)
    return new("UIStroke", {
        Color = color or C.line,
        Thickness = 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function padding(parent, t, r, b, l)
    return new("UIPadding", {
        PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r),
        PaddingBottom = UDim.new(0, b), PaddingLeft = UDim.new(0, l),
    }, parent)
end

local function label(parent, str, size, color, font, pos, sz, align)
    local l = new("TextLabel", {
        BackgroundTransparency = 1,
        Text = T(str),
        TextSize = size,
        TextColor3 = color,
        Font = font,
        Position = pos or UDim2.new(),
        Size = sz or UDim2.new(1, 0, 1, 0),
        TextXAlignment = align or Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
    if str ~= "" then localize(l, str) end
    return l
end

-- only write a property when it actually changed (keeps the UI cheap)
local function setProp(obj, prop, value)
    if obj[prop] ~= value then
        obj[prop] = value
    end
end

-- objects that follow the accent color
local AccentRefs = {}
local function reg(obj, prop)
    obj[prop] = C.accent
    table.insert(AccentRefs, { obj, prop })
    return obj
end

-- little motorbike icon built from plain frames (no image assets needed)
local function bikeIcon(parent, size)
    local u = size / 24
    local function px(n) return math.max(1, math.floor(n * u + 0.5)) end
    local white = Color3.new(1, 1, 1)

    local holder = new("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(size, size),
    }, parent)

    local function wheel(x)
        local w = new("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(px(x), px(12)),
            Size = UDim2.fromOffset(px(9), px(9)),
        }, holder)
        corner(w, 99)
        new("UIStroke", {
            Color = white,
            Thickness = math.max(1.5, 2 * u),
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, w)
    end
    wheel(2)
    wheel(13)

    local function bar(x, y, w, h, rot)
        local b = new("Frame", {
            BackgroundColor3 = white,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(px(x), px(y)),
            Size = UDim2.fromOffset(px(w), px(h)),
            Rotation = rot or 0,
        }, holder)
        corner(b, px(1))
    end
    bar(11.5, 16, 10, 2)        -- lower body
    bar(8.5, 11, 7, 2.4)        -- seat
    bar(17, 11, 2, 10, 18)      -- front fork
    bar(15.5, 6, 5, 2, 18)      -- handlebar
    return holder
end

---------------------------------------------------------------------
-- Root window (shadow + window)
---------------------------------------------------------------------
local old = PlayerGui:FindFirstChild("BikeUniverseUI")
if old then old:Destroy() end

local Gui = new("ScreenGui", { Name = "BikeUniverseUI", ResetOnSpawn = false, DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, PlayerGui)

local Root = new("Frame", {
    BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0.5, -WIN_H / 2),
    Size = UDim2.fromOffset(WIN_W, WIN_H),
}, Gui)

-- shrink the whole window on small screens so it always fits
local RootScale = new("UIScale", { Scale = 1 }, Root)
local function fitScale()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    RootScale.Scale = math.clamp(math.min((vp.X - 24) / WIN_W, (vp.Y - 70) / WIN_H), 0.5, 1)
end
fitScale()
Root.Position = UDim2.new(0.5, 0, 0.5, -math.floor(WIN_H * RootScale.Scale / 2))
pcall(function()
    track(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitScale))
end)

local Shadow2 = new("Frame", {
    BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.85, ZIndex = 0,
    Position = UDim2.fromOffset(-10, -6), Size = UDim2.new(1, 20, 1, 22),
}, Root)
corner(Shadow2, 16)
local Shadow1 = new("Frame", {
    BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.7, ZIndex = 0,
    Position = UDim2.fromOffset(-4, -2), Size = UDim2.new(1, 8, 1, 10),
}, Root)
corner(Shadow1, 12)

local Window = new("Frame", {
    BackgroundColor3 = C.bg,
    Size = UDim2.new(1, 0, 1, 0),
    ClipsDescendants = true,
    ZIndex = 1,
}, Root)
corner(Window, 8)
stroke(Window)

-- top bar
local TopBar = new("Frame", {
    BackgroundColor3 = C.side,
    Size = UDim2.new(1, 0, 0, TOP_H),
    BorderSizePixel = 0,
    ZIndex = 5,
}, Window)
local TopLine = new("Frame", { BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 2), ZIndex = 5 }, TopBar)
reg(TopLine, "BackgroundColor3")

-- profile logo (gradient tile + bike icon)
local Logo = new("Frame", { Position = UDim2.fromOffset(12, 7), Size = UDim2.fromOffset(32, 32), ZIndex = 6 }, TopBar)
reg(Logo, "BackgroundColor3")
corner(Logo, 9)
new("UIGradient", {
    Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 165)),
    Rotation = 55,
}, Logo)
bikeIcon(Logo, 22)

label(TopBar, "Bike Universe", 14, C.text, F_BOLD, UDim2.fromOffset(54, 6), UDim2.new(0, 150, 0, 18)).ZIndex = 6
label(TopBar, "NostraTeam", 10, C.dim, F_MED, UDim2.fromOffset(54, 24), UDim2.new(0, 150, 0, 14)).ZIndex = 6

local FpsLabel = label(TopBar, "-- FPS", 11, C.dim, F_MED, UDim2.new(1, -168, 0, 0), UDim2.new(0, 80, 1, -2), Enum.TextXAlignment.Right)
FpsLabel.ZIndex = 6

local function topButton(symbol, xOff)
    local b = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, xOff, 0.5, -1),
        Size = UDim2.fromOffset(28, 28),
        BackgroundColor3 = C.card,
        BackgroundTransparency = 1,
        Text = symbol,
        TextColor3 = C.dim,
        TextSize = 16,
        Font = F_BOLD,
        AutoButtonColor = false,
        ZIndex = 6,
    }, TopBar)
    corner(b, 6)
    return b
end

local CloseBtn = topButton("×", -10)
local MinBtn = topButton("–", -42)

local function hoverButton(btn, bg, fg)
    btn.MouseEnter:Connect(function()
        tween(btn, fast, { BackgroundTransparency = 0, BackgroundColor3 = bg, TextColor3 = fg })
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, fast, { BackgroundTransparency = 1, TextColor3 = C.dim })
    end)
end
hoverButton(MinBtn, C.cardHi, C.text)
hoverButton(CloseBtn, C.bad, Color3.new(1, 1, 1))

-- Body holds sidebar + content. It clips everything and is hidden when minimized,
-- so nothing can ever overlap the title bar.
local Body = new("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(0, TOP_H),
    Size = UDim2.new(1, 0, 1, -TOP_H),
    ClipsDescendants = true,
}, Window)

local Sidebar = new("Frame", {
    BackgroundColor3 = C.side,
    Size = UDim2.new(0, SIDE_W, 1, 0),
    BorderSizePixel = 0,
}, Body)
new("Frame", { BackgroundColor3 = C.line, BorderSizePixel = 0, Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0) }, Sidebar)

local NavHolder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -62) }, Sidebar)
padding(NavHolder, 12, 10, 0, 10)
new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, NavHolder)

-- sidebar footer: live status pill
local Pill = new("Frame", {
    BackgroundColor3 = C.card,
    Position = UDim2.new(0, 10, 1, -46),
    Size = UDim2.new(1, -20, 0, 34),
    ClipsDescendants = true,
}, Sidebar)
corner(Pill, 7)
stroke(Pill, C.line, 0.4)
local PillDot = new("Frame", { BackgroundColor3 = C.dim, Position = UDim2.fromOffset(12, 13), Size = UDim2.fromOffset(8, 8) }, Pill)
corner(PillDot, 4)
local PillText = label(Pill, "Waiting", 12, C.text, F_MED, UDim2.fromOffset(28, 0), UDim2.new(1, -34, 1, 0))

local Content = new("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(SIDE_W, 0),
    Size = UDim2.new(1, -SIDE_W, 1, 0),
    ClipsDescendants = true,
}, Body)

---------------------------------------------------------------------
-- Pages / tabs
---------------------------------------------------------------------
local Pages, NavButtons, Order = {}, {}, {}
local CurrentTab

local function nextOrder(parent)
    Order[parent] = (Order[parent] or 0) + 1
    return Order[parent]
end

local function selectTab(name)
    CurrentTab = name
    for n, page in pairs(Pages) do
        page.Visible = (n == name)
    end
    for n, nav in pairs(NavButtons) do
        local active = (n == name)
        tween(nav.btn, fast, { BackgroundTransparency = active and 0 or 1, TextColor3 = active and C.text or C.dim })
        tween(nav.bar, fast, { BackgroundTransparency = active and 0 or 1 })
    end
end

local function addTab(name)
    local btn = new("TextButton", {
        BackgroundColor3 = C.card,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 34),
        Text = T(name),
        TextColor3 = C.dim,
        TextSize = 13,
        Font = F_MED,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
        LayoutOrder = nextOrder(NavHolder),
    }, NavHolder)
    localize(btn, name)
    corner(btn, 6)
    padding(btn, 0, 0, 0, 16)

    local bar = new("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, -10, 0.5, 0),
        Size = UDim2.fromOffset(3, 16),
        BorderSizePixel = 0,
    }, btn)
    reg(bar, "BackgroundColor3")
    corner(bar, 2)

    NavButtons[name] = { btn = btn, bar = bar }

    local page = new("ScrollingFrame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.line,
        BorderSizePixel = 0,
        Visible = false,
    }, Content)
    padding(page, 10, 16, 10, 16)
    new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, page)
    Pages[name] = page

    btn.MouseButton1Click:Connect(function()
        selectTab(name)
    end)
    btn.MouseEnter:Connect(function()
        if CurrentTab ~= name then tween(btn, fast, { TextColor3 = C.text }) end
    end)
    btn.MouseLeave:Connect(function()
        if CurrentTab ~= name then tween(btn, fast, { TextColor3 = C.dim }) end
    end)
    return page
end

---------------------------------------------------------------------
-- Components
---------------------------------------------------------------------
local function section(page, text)
    local l = label(page, string.upper(text), 10, C.dim, F_BOLD, nil, UDim2.new(1, 0, 0, 16))
    l.LayoutOrder = nextOrder(page)
    return l
end

local function makeRow(page, height)
    local row = new("Frame", {
        BackgroundColor3 = C.card,
        Size = UDim2.new(1, 0, 0, height),
        LayoutOrder = nextOrder(page),
        ClipsDescendants = true,
    }, page)
    corner(row, 7)
    stroke(row, C.line, 0.4)
    return row
end

-- rightW = width reserved for the control on the right side of the row
local function rowTitle(row, title, desc, rightW)
    local reserve = -((rightW or 60) + 28)
    if desc then
        label(row, title, 13, C.text, F_MED, UDim2.fromOffset(14, 5), UDim2.new(1, reserve, 0, 18))
        label(row, desc, 11, C.dim, F_REG, UDim2.fromOffset(14, 22), UDim2.new(1, reserve, 0, 14))
    else
        label(row, title, 13, C.text, F_MED, UDim2.fromOffset(14, 0), UDim2.new(1, reserve, 1, 0))
    end
end

local function toggleRow(page, title, desc, key)
    local row = makeRow(page, 42)
    rowTitle(row, title, desc, 54)

    local trackBtn = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(40, 20),
        Text = "",
        AutoButtonColor = false,
        BackgroundColor3 = C.off,
    }, row)
    corner(trackBtn, 10)
    local knob = new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        Size = UDim2.fromOffset(14, 14),
        Position = UDim2.fromOffset(3, 3),
    }, trackBtn)
    corner(knob, 7)

    Painters[key] = function()
        local on = Cfg[key]
        tween(trackBtn, fast, { BackgroundColor3 = on and C.accent or C.off })
        tween(knob, fast, { Position = on and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3) })
    end
    Painters[key]()

    trackBtn.MouseButton1Click:Connect(function()
        setFlag(key, not Cfg[key])
    end)
end

-- color may be a Color3 or the string "accent"
local function makeButton(parent, text, color, callback, size, order)
    local isAccent = (color == "accent")
    local function base() return isAccent and C.accent or color end
    local btn = new("TextButton", {
        BackgroundColor3 = base(),
        Size = size or UDim2.new(1, 0, 0, 36),
        Text = T(text),
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 13,
        Font = F_BOLD,
        AutoButtonColor = false,
        LayoutOrder = order or 0,
    }, parent)
    localize(btn, text)
    if isAccent then reg(btn, "BackgroundColor3") end
    corner(btn, 7)
    btn.MouseEnter:Connect(function()
        tween(btn, fast, { BackgroundColor3 = base():Lerp(Color3.new(1, 1, 1), 0.12) })
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, fast, { BackgroundColor3 = base() })
    end)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function buttonRow(page, text, color, callback)
    return makeButton(page, text, color, callback, nil, nextOrder(page))
end

local function buttonPair(page, a, b)
    local holder = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 36),
        LayoutOrder = nextOrder(page),
    }, page)
    new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, holder)
    makeButton(holder, a[1], a[2], a[3], UDim2.new(0.5, -4, 1, 0), 1)
    makeButton(holder, b[1], b[2], b[3], UDim2.new(0.5, -4, 1, 0), 2)
end

local function keybindRow(page, title, desc, getKey, setKey)
    local row = makeRow(page, 42)
    rowTitle(row, title, desc, 114)

    local btn = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(100, 26),
        BackgroundColor3 = C.bg,
        Text = getKey().Name,
        TextSize = 12,
        Font = F_BOLD,
        AutoButtonColor = false,
    }, row)
    reg(btn, "TextColor3")
    corner(btn, 6)
    stroke(btn)

    btn.MouseButton1Click:Connect(function()
        if Listening then
            Listening.btn.Text = Listening.get().Name
            Listening.btn.TextColor3 = C.accent
        end
        Listening = { btn = btn, get = getKey, set = setKey }
        btn.Text = T("Press a key...")
        btn.TextColor3 = C.dim
    end)
end

local function sliderRow(page, title, desc, min, max, default, suffix, callback, fmt)
    local row = makeRow(page, 62)
    label(row, title, 13, C.text, F_MED, UDim2.fromOffset(14, 7), UDim2.new(1, -100, 0, 18))
    label(row, desc, 11, C.dim, F_REG, UDim2.fromOffset(14, 24), UDim2.new(1, -100, 0, 14))
    local valueLbl = label(row, "", 12, C.accent, F_BOLD, UDim2.new(1, -74, 0, 8), UDim2.fromOffset(60, 18), Enum.TextXAlignment.Right)
    reg(valueLbl, "TextColor3")

    local rail = new("Frame", {
        BackgroundColor3 = C.off,
        Position = UDim2.new(0, 14, 0, 47),
        Size = UDim2.new(1, -28, 0, 5),
        BorderSizePixel = 0,
    }, row)
    corner(rail, 3)
    local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0 }, rail)
    reg(fill, "BackgroundColor3")
    corner(fill, 3)
    local knob = new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(13, 13),
        Position = UDim2.new(0, 0, 0.5, 0),
    }, rail)
    corner(knob, 7)

    local current = nil
    local function apply(value)
        value = math.clamp(value, min, max)
        if value == current then return end
        current = value
        local a = (value - min) / (max - min)
        fill.Size = UDim2.new(a, 0, 1, 0)
        knob.Position = UDim2.new(a, 0, 0.5, 0)
        valueLbl.Text = fmt and fmt(value) or (value .. suffix)
        callback(value)
    end
    apply(default)

    local hit = new("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        Position = UDim2.new(0, 8, 0, 38),
        Size = UDim2.new(1, -16, 0, 22),
    }, row)

    local dragging = false
    local function fromX(x)
        local a = math.clamp((x - rail.AbsolutePosition.X) / rail.AbsoluteSize.X, 0, 1)
        apply(math.floor(min + a * (max - min) + 0.5))
    end
    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            fromX(input.Position.X)
        end
    end)
    track(UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            fromX(input.Position.X)
        end
    end))
    track(UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

local function infoRow(page, key, value)
    local row = makeRow(page, 34)
    label(row, key, 12, C.dim, F_MED, UDim2.fromOffset(14, 0), UDim2.new(0.5, -14, 1, 0))
    return label(row, value, 12, C.text, F_MED, UDim2.new(0.5, 0, 0, 0), UDim2.new(0.5, -14, 1, 0), Enum.TextXAlignment.Right)
end

---------------------------------------------------------------------
-- Tabs
---------------------------------------------------------------------
local MainPage = addTab("Main")
local SettingsPage = addTab("Settings")
local LogPage = addTab("Log")
local InfoPage = addTab("Info")

---------------------------------------------------------------------
-- Activity log + toast
---------------------------------------------------------------------
local LogEntries, logCount = {}, 0

log = function(msg, color)
    logCount = logCount + 1
    local row = new("Frame", {
        BackgroundColor3 = C.card,
        Size = UDim2.new(1, 0, 0, 26),
        LayoutOrder = -logCount,
    }, LogPage)
    corner(row, 5)
    label(row, os.date("%H:%M:%S"), 11, C.dim, F_MED, UDim2.fromOffset(10, 0), UDim2.fromOffset(56, 26))
    local dot = new("Frame", { BackgroundColor3 = color or C.accent, Position = UDim2.fromOffset(70, 10), Size = UDim2.fromOffset(6, 6) }, row)
    corner(dot, 3)
    label(row, msg, 12, C.text, F_REG, UDim2.fromOffset(86, 0), UDim2.new(1, -94, 1, 0))
    table.insert(LogEntries, row)
    if #LogEntries > 40 then
        table.remove(LogEntries, 1):Destroy()
    end
end

do
    local head = label(LogPage, "ACTIVITY", 10, C.dim, F_BOLD, nil, UDim2.new(1, 0, 0, 16))
    head.LayoutOrder = -1000000
    makeButton(LogPage, "Clear Log", C.cardHi, function()
        for _, r in ipairs(LogEntries) do r:Destroy() end
        LogEntries = {}
    end, UDim2.new(1, 0, 0, 30), -999999)
end

local Toast = new("Frame", {
    BackgroundColor3 = C.card,
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, -70),
    Size = UDim2.fromOffset(240, 40),
}, Gui)
corner(Toast, 8)
stroke(Toast)
local ToastBar = new("Frame", { BackgroundColor3 = C.accent, Size = UDim2.new(0, 3, 1, -16), Position = UDim2.fromOffset(9, 8), BorderSizePixel = 0 }, Toast)
corner(ToastBar, 2)
local ToastText = label(Toast, "", 12, C.text, F_MED, UDim2.fromOffset(24, 0), UDim2.new(1, -32, 1, 0))
local toastToken = 0

notify = function(msg, color)
    log(msg, color)
    if not Cfg.Notifications then return end
    toastToken = toastToken + 1
    local mine = toastToken
    ToastText.Text = T(msg)
    ToastBar.BackgroundColor3 = color or C.accent
    tween(Toast, smooth, { Position = UDim2.new(0.5, 0, 0, 12) })
    task.delay(2.4, function()
        if mine == toastToken and Alive then
            tween(Toast, smooth, { Position = UDim2.new(0.5, 0, 0, -70) })
        end
    end)
end

---------------------------------------------------------------------
-- Main page
---------------------------------------------------------------------
-- hero card
local Hero = new("Frame", {
    BackgroundColor3 = C.card,
    ClipsDescendants = true,
    Size = UDim2.new(1, 0, 0, 72),
    LayoutOrder = nextOrder(MainPage),
}, MainPage)
corner(Hero, 8)
stroke(Hero, C.line, 0.3)

local HeroDot = new("Frame", { BackgroundColor3 = C.dim, Position = UDim2.fromOffset(16, 17), Size = UDim2.fromOffset(10, 10) }, Hero)
corner(HeroDot, 5)
local HeroStatus = label(Hero, "Waiting", 20, C.text, F_BOLD, UDim2.fromOffset(34, 7), UDim2.new(0.6, -34, 0, 30))
local HeroSub = label(Hero, "Sit on a vehicle to begin", 12, C.dim, F_REG, UDim2.fromOffset(16, 40), UDim2.new(0.6, -16, 0, 18))
label(Hero, "SPEED", 10, C.dim, F_BOLD, UDim2.new(0.6, 0, 0, 9), UDim2.new(0.4, -16, 0, 12), Enum.TextXAlignment.Right)
local SpeedVal = label(Hero, "0", 24, C.accent, F_BOLD, UDim2.new(0.6, 0, 0, 20), UDim2.new(0.4, -16, 0, 30), Enum.TextXAlignment.Right)
reg(SpeedVal, "TextColor3")
label(Hero, "studs / sec", 10, C.dim, F_REG, UDim2.new(0.6, 0, 0, 52), UDim2.new(0.4, -16, 0, 14), Enum.TextXAlignment.Right)

-- stats strip
local StatsRow = new("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 50),
    LayoutOrder = nextOrder(MainPage),
}, MainPage)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, StatsRow)

local function statCard(order, title, value)
    local card = new("Frame", {
        BackgroundColor3 = C.card,
        ClipsDescendants = true,
        Size = UDim2.new(0.25, -6, 1, 0),
        LayoutOrder = order,
    }, StatsRow)
    corner(card, 7)
    stroke(card, C.line, 0.4)
    label(card, title, 10, C.dim, F_BOLD, UDim2.fromOffset(12, 7), UDim2.new(1, -20, 0, 12))
    return label(card, value, 15, C.text, F_BOLD, UDim2.fromOffset(12, 21), UDim2.new(1, -20, 0, 22))
end

local RuntimeVal = statCard(1, "RUNTIME", "00:00")
local TeleportVal = statCard(2, "TELEPORTS", "0")
local JumpVal = statCard(3, "JUMPS", "0")
local DistVal = statCard(4, "TO TARGET", "-")

-- anti-AFK countdown
local CountRow = makeRow(MainPage, 42)
label(CountRow, "Next anti-AFK jump", 13, C.text, F_MED, UDim2.fromOffset(14, 5), UDim2.new(0.6, 0, 0, 18))
local CountVal = label(CountRow, "45s", 12, C.accent, F_BOLD, UDim2.new(0.6, 0, 0, 5), UDim2.new(0.4, -14, 0, 18), Enum.TextXAlignment.Right)
reg(CountVal, "TextColor3")
local CountRail = new("Frame", { BackgroundColor3 = C.off, Position = UDim2.new(0, 14, 0, 31), Size = UDim2.new(1, -28, 0, 4), BorderSizePixel = 0 }, CountRow)
corner(CountRail, 2)
local CountFill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0 }, CountRail)
reg(CountFill, "BackgroundColor3")
corner(CountFill, 2)

section(MainPage, "Automation")
toggleRow(MainPage, "Auto Drive", "Holds W continuously while enabled", "AutoDrive")
toggleRow(MainPage, "Auto Teleport", "Moves your vehicle to the target point", "AutoTeleport")
toggleRow(MainPage, "Anti-AFK", "One short space press every interval", "AntiAFK")
toggleRow(MainPage, "Auto Re-sit", "Sits back on your vehicle if you fall off", "AutoReseat")
toggleRow(MainPage, "Auto Rejoin", "Rejoins if disconnected (public servers only)", "AutoRejoin")

---------------------------------------------------------------------
-- Settings page
---------------------------------------------------------------------
section(SettingsPage, "Keybinds")
keybindRow(SettingsPage, "Toggle Auto Drive", "Quickly start or stop driving",
    function() return ToggleKey end, function(k) ToggleKey = k; saveConfig() end)
keybindRow(SettingsPage, "Show / Hide Menu", "Hide the window out of the way",
    function() return HideKey end, function(k) HideKey = k; saveConfig() end)

section(SettingsPage, "Anti-AFK timing")
sliderRow(SettingsPage, "Jump Interval", "Seconds between space presses", 15, 120, Cfg.JumpInterval, "s", function(v)
    Cfg.JumpInterval = v
    saveConfig()
end)
sliderRow(SettingsPage, "Press Length", "How long space is held down (seconds)", 1, 30, math.floor(Cfg.HoldTime * 10 + 0.5), "", function(v)
    Cfg.HoldTime = v / 10
    saveConfig()
end, function(v)
    return string.format("%.1fs", v / 10)
end)


section(SettingsPage, "Behavior")
toggleRow(SettingsPage, "Teleport on respawn", "Teleport again after your character respawns", "RespawnTeleport")
toggleRow(SettingsPage, "Notifications", "Show pop-up messages in the corner", "Notifications")

section(SettingsPage, "Performance")
toggleRow(SettingsPage, "FPS Boost", "Lowest graphics quality and no shadows", "FpsBoost")
toggleRow(SettingsPage, "Save GPU mode", "Turns off 3D rendering while AFK (screen goes blank)", "Render3DOff")

section(SettingsPage, "Appearance")
do
    local row = makeRow(SettingsPage, 56)
    rowTitle(row, "Accent Color", "Changes highlights across the menu", 168)
    local holder = new("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(6 * 26, 22),
    }, row)
    new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, holder)

    local rings = {}
    local function setAccent(color, index)
        C.accent = color
        AccentIndex = index
        saveConfig()
        for _, r in ipairs(AccentRefs) do
            if r[1].Parent then r[1][r[2]] = color end
        end
        for _, paint in pairs(Painters) do paint() end
        for i, ring in pairs(rings) do
            ring.Transparency = (i == index) and 0 or 1
        end
    end

    for i, sw in ipairs(Swatches) do
        local b = new("TextButton", {
            BackgroundColor3 = sw[2],
            Size = UDim2.fromOffset(22, 22),
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = i,
        }, holder)
        corner(b, 11)
        rings[i] = new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 1 }, b)
        b.MouseButton1Click:Connect(function()
            setAccent(sw[2], i)
        end)
    end
    rings[AccentIndex].Transparency = 0
end

section(SettingsPage, "Language")
do
    local function setLanguage(code)
        if code ~= "en" and not Strings[code] then return end
        Lang = code
        -- FIX: drop entries of destroyed objects (old log rows) so this list can't grow forever
        local keep = {}
        for _, e in ipairs(Localized) do
            if e[1].Parent then
                e[1].Text = T(e[2])
                table.insert(keep, e)
            end
        end
        Localized = keep
        saveConfig()
    end

    local row = makeRow(SettingsPage, 112)
    label(row, "Language", 13, C.text, F_MED, UDim2.fromOffset(14, 7), UDim2.new(1, -28, 0, 18))
    label(row, "Choose the menu language", 11, C.dim, F_REG, UDim2.fromOffset(14, 24), UDim2.new(1, -28, 0, 14))
    local grid = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 50),
        Size = UDim2.new(1, -28, 0, 56),
    }, row)
    new("UIGridLayout", {
        CellSize = UDim2.new(1 / 3, -5, 0, 25),
        CellPadding = UDim2.fromOffset(7, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, grid)

    local chips = {}
    local function paintChips()
        for code, b in pairs(chips) do
            local on = (code == Lang)
            b.BackgroundColor3 = on and C.accent or C.cardHi
            b.TextColor3 = on and Color3.new(1, 1, 1) or C.dim
        end
    end
    Painters["_language"] = paintChips

    for i, l in ipairs(Languages) do
        local b = new("TextButton", {
            LayoutOrder = i,
            BackgroundColor3 = C.cardHi,
            Text = l[2],
            TextColor3 = C.dim,
            TextSize = 12,
            Font = F_BOLD,
            AutoButtonColor = false,
        }, grid)
        corner(b, 6)
        chips[l[1]] = b
        b.MouseButton1Click:Connect(function()
            setLanguage(l[1])
            paintChips()
        end)
    end
    paintChips()
end

section(SettingsPage, "Script")

---------------------------------------------------------------------
-- Info page
---------------------------------------------------------------------
section(InfoPage, "About")
infoRow(InfoPage, "Script", "Bike Universe")
infoRow(InfoPage, "Developer", "NostraTeam")
section(InfoPage, "How it works")
infoRow(InfoPage, "Auto Teleport", "Moves vehicle to target")
infoRow(InfoPage, "Auto Drive", "Holds W non-stop")
infoRow(InfoPage, "Auto Re-sit", "Sits back on vehicle")
infoRow(InfoPage, "Auto Rejoin", "Reconnects if kicked")
local AfkInfo = infoRow(InfoPage, "Anti-AFK", "")
section(InfoPage, "Session")
local TopSpeedInfo = infoRow(InfoPage, "Top speed", "0 studs/s")
section(InfoPage, "Hotkeys")
local DriveKeyInfo = infoRow(InfoPage, "Auto Drive", ToggleKey.Name)
local HideKeyInfo = infoRow(InfoPage, "Show / Hide", HideKey.Name)

-- actions (Main)
buttonPair(MainPage,
    { "Teleport Now", "accent", function()
        HasTeleported = false
        if TryTeleport() then
            notify("Vehicle teleported", C.good)
        else
            notify("No vehicle found - sit on one first", C.bad)
        end
    end },
    { "Reset Stats", C.cardHi, function()
        TeleportCount, JumpCount, TopSpeed = 0, 0, 0
        StartTime = os.clock()
        notify("Session stats reset", C.dim)
    end })

-- unload (Settings)
local PulseTween
local function Shutdown()
    if not Alive then return end
    Alive = false
    for _, c in ipairs(Connections) do
        c:Disconnect()
    end
    if PulseTween then pcall(function() PulseTween:Cancel() end) end
    applyBoost(false)
    apply3D(false)
    releaseKeys()
    Gui:Destroy()
end

buttonRow(SettingsPage, "Unload Script", C.bad, Shutdown)
CloseBtn.MouseButton1Click:Connect(Shutdown)

-- window drag
local dragging, dragStart, startPos
TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Root.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
track(UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        local ox, oy = startPos.X.Offset + d.X, startPos.Y.Offset + d.Y
        local vp = Gui.AbsoluteSize
        local s = RootScale.Scale
        local halfW = WIN_W * s / 2
        -- keep at least 70px of the window and the whole title bar reachable
        ox = math.clamp(ox, -(vp.X / 2) - halfW + 70, (vp.X / 2) + halfW - 70)
        oy = math.clamp(oy, -(vp.Y / 2), (vp.Y / 2) - TOP_H * s)
        Root.Position = UDim2.new(startPos.X.Scale, ox, startPos.Y.Scale, oy)
    end
end))

-- minimize: the body is hidden outright, so nothing can overlap the title bar
local Minimized = false
MinBtn.MouseButton1Click:Connect(function()
    Minimized = not Minimized
    if Minimized then
        Body.Visible = false
        tween(Root, smooth, { Size = UDim2.fromOffset(WIN_W, TOP_H) })
    else
        Body.Visible = true
        tween(Root, smooth, { Size = UDim2.fromOffset(WIN_W, WIN_H) })
    end
    MinBtn.Text = Minimized and "+" or "–"
end)

-- floating launcher button: tap to show/hide the menu, drag to move it
do
    local btn = new("TextButton", {
        Name = "Launcher",
        BackgroundColor3 = C.card,
        Position = UDim2.new(0, 12, 0.5, -20),
        Size = UDim2.fromOffset(40, 40),
        Text = "",
        AutoButtonColor = false,
    }, Gui)
    corner(btn, 20)
    reg(stroke(btn, C.accent, 0), "Color")
    bikeIcon(btn, 24)

    local down, moved, startInput, startPos2 = false, false, nil, nil
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            down, moved = true, false
            startInput = input.Position
            startPos2 = btn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    if down and not moved then
                        Root.Visible = not Root.Visible
                    end
                    down = false
                end
            end)
        end
    end)
    track(UIS.InputChanged:Connect(function(input)
        if down and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - startInput
            if d.Magnitude > 6 then moved = true end
            if moved then
                local vp = Gui.AbsoluteSize
                local x = math.clamp(startPos2.X.Offset + d.X, 0, vp.X - 40)
                local y = math.clamp(startPos2.Y.Offset + d.Y, -vp.Y / 2, vp.Y / 2 - 40)
                btn.Position = UDim2.new(0, x, 0.5, y)
            end
        end
    end))
end

-- live UI refresh (protected: an error here can never stop the engine)
local function refreshUI()
    local seat = getSeat()
    local text, color, sub
    if Rejoining then
        text, color, sub = "Rejoining", C.warn, "Connection lost - joining a new server"
    elseif not Cfg.AutoDrive then
        text, color, sub = "Paused", C.warn, "Auto Drive is turned off"
    elseif seat then
        text, color = "Driving", C.good
        sub = T("Vehicle: ") .. (seat.Parent and seat.Parent.Name or seat.Name)
    else
        text, color, sub = "Waiting", C.dim, "Sit on a vehicle to begin"
    end
    text = T(text)
    if not seat or Rejoining or not Cfg.AutoDrive then sub = T(sub) end -- FIX: vehicle name is never run through the translator
    setProp(HeroStatus, "Text", text)
    setProp(HeroSub, "Text", sub)
    setProp(HeroDot, "BackgroundColor3", color)
    setProp(PillDot, "BackgroundColor3", color)
    setProp(PillText, "Text", text)

    if seat then
        local speed = math.floor(seat.AssemblyLinearVelocity.Magnitude + 0.5)
        if speed > TopSpeed then TopSpeed = speed end
        setProp(SpeedVal, "Text", tostring(speed))
        setProp(DistVal, "Text", math.floor((seat.Position - TARGET_POSITION).Magnitude + 0.5) .. " st")
    else
        setProp(SpeedVal, "Text", "0")
        setProp(DistVal, "Text", "-")
    end

    local t = math.floor(os.clock() - StartTime)
    setProp(RuntimeVal, "Text", string.format("%02d:%02d", math.floor(t / 60), t % 60))
    setProp(TeleportVal, "Text", tostring(TeleportCount))
    setProp(JumpVal, "Text", tostring(JumpCount))
    setProp(TopSpeedInfo, "Text", string.format(T("%d studs/s"), TopSpeed))
    setProp(AfkInfo, "Text", string.format(T("Space every %ds (%.1fs)"), Cfg.JumpInterval, Cfg.HoldTime))
    setProp(DriveKeyInfo, "Text", ToggleKey.Name)
    setProp(HideKeyInfo, "Text", HideKey.Name)

    if not Cfg.AntiAFK then
        setProp(CountVal, "Text", T("Off"))
        CountFill.Size = UDim2.new(0, 0, 1, 0)
    elseif Jumping then
        setProp(CountVal, "Text", T("Pressing..."))
        CountFill.Size = UDim2.new(1, 0, 1, 0)
    else
        local left = math.max(0, Cfg.JumpInterval - (os.clock() - LastJump))
        setProp(CountVal, "Text", math.ceil(left) .. "s")
        CountFill.Size = UDim2.new(math.clamp(1 - left / Cfg.JumpInterval, 0, 1), 0, 1, 0)
    end

end

-- FPS counter + UI refresh share ONE connection. The refresh is skipped while
-- the menu is hidden or minimized, so it costs nothing when you can't see it.
do
    local fpsAcc, frames, uiAcc = 0, 0, 0
    track(RunService.Heartbeat:Connect(function(dt)
        fpsAcc = fpsAcc + dt
        frames = frames + 1
        if fpsAcc >= 0.5 then
            setProp(FpsLabel, "Text", math.floor(frames / fpsAcc + 0.5) .. " FPS")
            fpsAcc, frames = 0, 0
        end

        uiAcc = uiAcc + dt
        if uiAcc >= 0.1 then
            uiAcc = 0
            if Root.Visible and not Minimized then
                local ok, err = pcall(refreshUI)
                if not ok then warn("[BikeUniverse] UI refresh: " .. tostring(err)) end
            end
        end
    end))
end

-- status dot pulse: a single looping tween (no thread, no polling)
PulseTween = TweenService:Create(HeroDot, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.65 })
PulseTween:Play()

-- hotkeys
track(UIS.InputBegan:Connect(function(input, processed)
    if Listening then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            local l = Listening
            Listening = nil
            if input.KeyCode ~= Enum.KeyCode.Escape then
                l.set(input.KeyCode)
                notify(string.format(T("Key set to %s"), input.KeyCode.Name), C.good)
            end
            l.btn.Text = l.get().Name
            l.btn.TextColor3 = C.accent
        end
        return
    end

    if processed then return end

    if input.KeyCode == ToggleKey then
        setFlag("AutoDrive", not Cfg.AutoDrive)
    elseif input.KeyCode == HideKey then
        Root.Visible = not Root.Visible
    end
end))

---------------------------------------------------------------------
-- Intro animation (UI only - the engine is already running underneath)
---------------------------------------------------------------------
local function playIntro()
    local finalPos = Root.Position
    Root.Visible = false

    local group = new("CanvasGroup", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(280, 176),
        BackgroundColor3 = C.bg,
        GroupTransparency = 1,
        ZIndex = 50,
    }, Gui)
    corner(group, 14)
    stroke(group)
    local scale = new("UIScale", { Scale = 0.85 }, group)

    local tile = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 22),
        Size = UDim2.fromOffset(56, 56),
    }, group)
    reg(tile, "BackgroundColor3")
    corner(tile, 16)
    new("UIGradient", {
        Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 165)),
        Rotation = 55,
    }, tile)
    bikeIcon(tile, 40)

    label(group, "Bike Universe", 18, C.text, F_BOLD, UDim2.fromOffset(0, 88), UDim2.new(1, 0, 0, 24), Enum.TextXAlignment.Center)
    label(group, "NostraTeam", 11, C.dim, F_MED, UDim2.fromOffset(0, 113), UDim2.new(1, 0, 0, 16), Enum.TextXAlignment.Center)

    local rail = new("Frame", {
        BackgroundColor3 = C.off,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 146),
        Size = UDim2.fromOffset(180, 4),
        BorderSizePixel = 0,
    }, group)
    corner(rail, 2)
    local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0 }, rail)
    reg(fill, "BackgroundColor3")
    corner(fill, 2)

    -- in
    tween(group, smooth, { GroupTransparency = 0 })
    tween(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
    task.wait(0.25)
    tween(fill, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Size = UDim2.new(1, 0, 1, 0) })
    task.wait(1.35)

    -- out
    local outInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    tween(group, outInfo, { GroupTransparency = 1 })
    tween(scale, outInfo, { Scale = 1.1 })
    task.wait(0.32)
    group:Destroy()
    if not Alive then return end

    -- menu slides in
    Root.Position = finalPos + UDim2.fromOffset(0, 28)
    Root.Visible = true
    tween(Root, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = finalPos })
    notify("Bike Universe loaded", C.accent)
end

selectTab("Main")
if Cfg.FpsBoost then applyBoost(true) end
ConfigReady = true
task.spawn(function()
    local ok = pcall(playIntro)
    if not ok and Alive then
        Root.Visible = true -- never leave the menu hidden if the intro fails
        notify("Bike Universe loaded", C.accent)
    end
end)

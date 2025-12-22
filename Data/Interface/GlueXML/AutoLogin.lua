--[[==============================================================================
 Minimalist AutoLogin Plus
------------------------------------------------------------------------------
 Author: Stormhand

 Description:
 Enhanced login and character selection addon for Turtle WoW.
 Provides automatic login, multi-account management, character ordering,
 UI cleanup, and full restoration of original Glue sounds and behavior.

 Design principles:
 - Preserve original client logic and sounds
 - Avoid destructive overrides
 - Maintain maximum compatibility with Turtle / SuperWoW
==============================================================================]]


local _G = _G or getfenv(0)

local L = {}

L["enUS"] = {
  class = {
    ["Druid"] = "Druid",
    ["Hunter"] = "Hunter",
    ["Mage"] = "Mage",
    ["Paladin"] = "Paladin",
    ["Priest"] = "Priest",
    ["Rogue"] = "Rogue",
    ["Shaman"] = "Shaman",
    ["Warrior"] = "Warrior",
    ["Warlock"] = "Warlock",
  },
  ["SelectAccount"] = "Select account",
  ["RemoveAccount"] = "Remove account",
  ["LockAccounts"] = "Lock Accounts",
  ["StreamerMode"] = "Streamer Mode",
  ["LockCharacters"] = "Unlock Characters",
  ["NoSuperWoW"] = "|cff77ff00Turtle AutoLogin|r requires SuperWoW 1.4 or newer to operate.",
}

L["ruRU"] = {
  class = {
    ["Друид"] = "Druid",
    ["Охотник"] = "Hunter",
    ["Маг"] = "Mage",
    ["Паладин"] = "Paladin",
    ["Жрец"] = "Priest",
    ["Разбойник"] = "Rogue",
    ["Шаман"] = "Shaman",
    ["Воин"] = "Warrior",
    ["Чернокнижник"] = "Warlock",
  },
  ["SelectAccount"] = "Выберите аккаунт",
  ["RemoveAccount"] = "Удалить аккаунт",
  ["LockAccounts"] = "Заблокировать аккаунты",
  ["StreamerMode"] = "Режим стримера",
  ["LockCharacters"] = "Заблокировать персонажей",
  ["NoSuperWoW"] = "|cff77ff00Turtle AutoLogin|r требует SuperWoW 1.4 или новее для работы.",
}

L = L[GetLocale()] or L["enUS"]

local has_superwow = (ImportFile and ExportFile) or (SUPERWOW_VERSION and tonumber(SUPERWOW_VERSION) >= 1.4)

if not has_superwow then
  GlueDialogTypes["AL_NO_SWOW"] = {
    text = L["NoSuperWoW"],
    button1 = TEXT(OKAY),
    showAlert = 1,
  }
  GlueDialog_Show("AL_NO_SWOW")
  return
end

local CLASS_COLORS = {
  ["Druid"] = { r = 1.00, g = 0.49, b = 0.04, colorStr = "ffFF7C0A" },
  ["Mage"]  = { r = 0.25, g = 0.78, b = 0.92, colorStr = "ff3FC7EB" },
  ["Hunter"]= { r = 0.67, g = 0.83, b = 0.45, colorStr = "ffAAD372" },
  ["Paladin"]={ r = 0.96, g = 0.55, b = 0.73, colorStr = "ffF48CBA" },
  ["Priest"]= { r = 1.00, g = 1.00, b = 1.00, colorStr = "ffFFFFFF" },
  ["Rogue"] = { r = 1.00, g = 0.96, b = 0.41, colorStr = "ffFFF468" },
  ["Shaman"]= { r = 0.00, g = 0.44, b = 0.87, colorStr = "ff0070DD" },
  ["Warlock"]={ r = 0.53, g = 0.53, b = 0.93, colorStr = "ff8788EE" },
  ["Warrior"]={ r = 0.78, g = 0.61, b = 0.43, colorStr = "ffC69B6D" },
}

LoginManager = {}
LoginManager.State = {}
LoginManager.SelectedAcct = nil
LoginManager.CurrentPage = 0
LoginManager.PageSize = 9
LoginManager.LimitReached = false
LoginManager.from_login_screen = false
LoginManager.has_superwow = has_superwow
LoginManager.char_buttons_locked = true

-- NEW: flag to hide account panel and related buttons
LoginManager.HIDE_ACCOUNT_UI = true


-- Optional: show server NEWS / alerts on login screen
ENABLE_SERVER_NEWS = false
-- Optional: restore password field automatically if login fails/disconnects
RESTORE_PASSWORD_ON_FAIL = true
--------
-- utils
--------
local function moveIndexUp(list, index)
  if index > 1 then
    local item = table.remove(list, index)
    table.insert(list, index - 1, item)
  end
end

local function moveIndexDown(list, index)
  if list[index] and list[index+1] then
    local item = table.remove(list, index)
    table.insert(list, index + 1, item)
  end
end

---------
-- serialization
---------
local Serialize = {
  serializeValue = function (self,val,indent)
    local t = type(val)
    if t == "string" then
      return string.format("%q", val)
    elseif t == "number" or t == "boolean" then
      return tostring(val)
    elseif t == "table" then
      return self:serializeTable(val,indent)
    else
      return '"<unsupported type>"'
    end
  end,
  serializeTable = function (self,tbl,indent)
    indent = indent or ""
    local nextIndent = indent .. "  "
    local result = {}
    table.insert(result, "{\n")
    for k, v in pairs(tbl) do
      local key
      if type(k) == "string" and string.find(k, "^[_%a][_%w]*$") then
        key = k
      else
        key = "[" .. self:serializeValue(k, nextIndent) .. "]"
      end
      table.insert(result, nextIndent .. key .. " = " .. self:serializeValue(v, nextIndent) .. ",\n")
    end
    table.insert(result, indent .. "}")
    return table.concat(result)
  end,
}

---------------
-- LoginManager
---------------

-- NEW: helper to completely hide the account panel and associated buttons
function LoginManager:HideAccountUI()
  -- container provável do painel
  local panel = AutologinSelectAccountText and AutologinSelectAccountText:GetParent()
  local candidates = {
    "AutologinSelectAccountFrame",
    "AutologinAccountListFrame",
    "AutologinAccountPanel",
  }
  for _, n in ipairs(candidates) do
    if _G[n] then panel = _G[n]; break end
  end
  if panel then
    panel:Hide()
    panel.Show = function() end
    panel:EnableMouse(false)
  end

  -- título e botões da lista
  if AutologinSelectAccountText then AutologinSelectAccountText:Hide(); AutologinSelectAccountText.Show=function()end end
  if AutologinRemoveAccountButton then AutologinRemoveAccountButton:Hide(); AutologinRemoveAccountButton.Show=function()end end
  if AutologinPrevPageButton then AutologinPrevPageButton:Hide(); AutologinPrevPageButton.Show=function()end end
  if AutologinNextPageButton then AutologinNextPageButton:Hide(); AutologinNextPageButton.Show=function()end end
  for i = 1, (self.PageSize or 9) do
    local b = _G["AutologinAccountButton"..i]
    if b then b:Hide(); b.Show=function()end end
  end

  -- botões inferiores: Streamer e Lock Accounts
  if ButtonAccountButtonsStreamer then ButtonAccountButtonsStreamer:Hide(); ButtonAccountButtonsStreamer.Show=function()end end
  if ButtonAccountButtonsLock then ButtonAccountButtonsLock:Hide(); ButtonAccountButtonsLock.Show=function()end end
end

function LoginManager:ToFile(file,value)
  local v = Serialize:serializeValue(value)
  if v ~= '"<unsupported type>"' then
    ExportFile(file, Serialize:serializeValue(value,"  "))
    return true
  end
  return false
end

function LoginManager:FromFile(file)
  local contents = ImportFile(file)
  if contents then
    local chunk,err = loadstring("return " .. contents)
    if not err then
      return chunk()
    end
  end
  return false
end

function LoginManager:HideSideButtons()
  local hide_frames = {
    "AccountLoginTurtleWebsite",
    "AccountLoginTurtleArmory",
    "AccountLoginTurtleKnowledgeDatabase",
    "AccountLoginTurtleCommunityForum",
    "AccountLoginTurtleDiscord",
    "AccountLoginTurtleReddit",
    "AccountLoginCinematicsButton",
    "AccountLoginCreditsButton",
    "ServerAlertFrame",
  }
  for _,frame in ipairs(hide_frames) do
    if frame == "ServerAlertFrame" and ENABLE_SERVER_NEWS then
      -- user wants NEWS visible
    else
      if _G[frame] then _G[frame]:Hide() end
    end
  end

  -- ensure NEWS/ServerAlert never reappears (server may force-show it)
  self:KillServerAlert()

end


function LoginManager:KillServerAlert()
  local f = _G["ServerAlertFrame"]
  if not f then return end

  -- If NEWS is enabled, restore original behavior (if we previously suppressed it)
  if ENABLE_SERVER_NEWS then
    if f.__autologin_origShow then
      f.Show = f.__autologin_origShow
    end
    if f.__autologin_origAlpha and f.SetAlpha then
      f:SetAlpha(f.__autologin_origAlpha)
    elseif f.SetAlpha then
      f:SetAlpha(1)
    end
    if f.__autologin_origMouse ~= nil and f.EnableMouse then
      f:EnableMouse(f.__autologin_origMouse)
    end
    f.__autologin_killed = nil
    return
  end

  -- Otherwise, suppress it (server may force-show it)
  if not f.__autologin_killed then
    if not f.__autologin_origShow then
      f.__autologin_origShow = f.Show
    end
    if f.GetAlpha and not f.__autologin_origAlpha then
      f.__autologin_origAlpha = f:GetAlpha()
    end
    if f.IsMouseEnabled and f.__autologin_origMouse == nil then
      f.__autologin_origMouse = f:IsMouseEnabled()
    end

    f:Hide()
    f.Show = function() end
    if f.SetAlpha then f:SetAlpha(0) end
    if f.EnableMouse then f:EnableMouse(false) end
    f.__autologin_killed = true
  end
end


function LoginManager:RestorePasswordFromSelected()
  if not RESTORE_PASSWORD_ON_FAIL then return end
  if not self.SelectedAcct or not (self.State and self.State.accounts and self.State.accounts[self.SelectedAcct]) then return end
  local pwd = self.State.accounts[self.SelectedAcct].password
  if not pwd then return end
  -- only restore if field is currently empty (avoid overwriting user edits)
  if AccountLoginPasswordEdit and AccountLoginPasswordEdit.GetText and AccountLoginPasswordEdit.SetText then
    local cur = AccountLoginPasswordEdit:GetText()
    if not cur or cur == "" then
      AccountLoginPasswordEdit:SetText(string.sub(pwd, 2))
    end
  end
end


function LoginManager:MakeExtraAccountButtons()
  -- mantém up/down/char nos itens da lista (inofensivos mesmo ocultando o painel)
  local button_size = 26
  for i=1,self.PageSize do
    local acctButton = _G["AutologinAccountButton"..i]
    if not acctButton then break end
    if not acctButton.up then
      local upButton = CreateFrame("Button", acctButton:GetName().."Up", acctButton)
      upButton:SetWidth(button_size); upButton:SetHeight(button_size)
      upButton:SetPoint("TOPRIGHT", acctButton, "TOPRIGHT", -30, 1)
      upButton:SetHitRectInsets(1, 1, 1, 1)
      upButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
      upButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Down")
      upButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
      upButton:SetScript("OnClick", function()
        moveIndexUp(self.State.accounts, this:GetParent():GetID())
        LoginManager:UpdateUI()
      end)
      upButton:SetScript("OnEnter", function() this:GetParent():LockHighlight() end)
      upButton:SetScript("OnLeave", function() if this:GetParent():GetID() ~= self.SelectedAcct then this:GetParent():UnlockHighlight() end end)
      acctButton.up = upButton
    end
    if not acctButton.down then
      local downButton = CreateFrame("Button", acctButton:GetName().."Down", acctButton)
      downButton:SetWidth(button_size); downButton:SetHeight(button_size)
      downButton:SetPoint("TOP", acctButton.up, "BOTTOM", 0, 8)
      downButton:SetHitRectInsets(1, 1, 1, 1)
      downButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
      downButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
      downButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
      downButton:SetScript("OnClick", function()
        moveIndexDown(self.State.accounts, this:GetParent():GetID())
        LoginManager:UpdateUI()
      end)
      downButton:SetScript("OnEnter", function() this:GetParent():LockHighlight() end)
      downButton:SetScript("OnLeave", function() if this:GetParent():GetID() ~= self.SelectedAcct then this:GetParent():UnlockHighlight() end end)
      acctButton.down = downButton
    end
    if not acctButton.char then
      local charButton = CreateFrame("Button", acctButton:GetName().."Char", acctButton, "GlueButtonSmallTemplate")
      charButton:SetWidth(40); charButton:SetHeight(35)
      charButton:SetPoint("RIGHT", acctButton, "RIGHT", -50, 8)
      charButton:SetHitRectInsets(1, 1, 1, 1)
      charButton:SetScript("OnClick", function()
        LoginManager:SelectAccount(this:GetParent():GetID())
        LoginManager.auto_char_button_pressed = true
        AccountLogin_Login()
      end)
      charButton:SetScript("OnEnter", function() this:GetParent():LockHighlight() end)
      charButton:SetScript("OnLeave", function() if this:GetParent():GetID() ~= self.SelectedAcct then this:GetParent():UnlockHighlight() end end)
      acctButton.char = charButton
    end
  end

  -- *** REMOVIDO/IGNORADO: criação dos botões Lock Accounts e Streamer Mode ***
  -- Se a UI de contas estiver oculta, não cria esses botões
  if not self.HIDE_ACCOUNT_UI then
    local quitButton = _G["AccountLoginExitButton"]
    if quitButton and not quitButton.lock then
      local lockButton = CreateFrame("Button", "ButtonAccountButtonsLock", quitButton, "GlueButtonSmallTemplate")
      lockButton:SetWidth(150); lockButton:SetHeight(35)
      lockButton:SetPoint("RIGHT", quitButton, "LEFT", 4, 0)
      lockButton:SetText(L["LockAccounts"])
      lockButton:SetWidth(lockButton:GetFontString():GetStringWidth() + 50)
      lockButton:SetScript("OnClick", function()
        LoginManager.State.account_buttons_locked = not LoginManager.State.account_buttons_locked
        this:Show(); LoginManager:SaveAccounts(); LoginManager:UpdateUI()
      end)
      quitButton.lock = lockButton
    end
    if quitButton and not quitButton.streamer then
      local streamerButton = CreateFrame("Button", "ButtonAccountButtonsStreamer", quitButton, "GlueButtonSmallTemplate")
      streamerButton:SetWidth(150); streamerButton:SetHeight(35)
      streamerButton:SetPoint("RIGHT", quitButton.lock, "LEFT", 4, 0)
      streamerButton:SetText(L["StreamerMode"])
      streamerButton:SetWidth(streamerButton:GetFontString():GetStringWidth() + 50)
      streamerButton:SetScript("OnClick", function()
        LoginManager.State.account_buttons_streamer = not LoginManager.State.account_buttons_streamer
        this:Show(); LoginManager:UpdateUI()
      end)
      quitButton.streamer = streamerButton
    end
  end

  if not AccountLoginAccountEdit.cover then
    local cover = CreateFrame("Frame", nil, AccountLoginAccountEdit)
    cover:SetFrameLevel(AccountLoginAccountEdit:GetFrameLevel() + 10)
    cover:SetWidth(AccountLoginAccountEdit:GetWidth()-15)
    cover:SetHeight(AccountLoginAccountEdit:GetHeight()-15)
    cover:SetPoint("TOPLEFT",AccountLoginAccountEdit,"TOPLEFT", 10, -6)
    local tex = cover:CreateTexture()
    tex:SetAllPoints(cover)
    tex:SetTexture(0, 0, 0, 1)
    AccountLoginAccountEdit.cover = cover
  end
end

-- passwords
function LoginManager:LoadAccounts()
  self.State.accounts = {}
  self.State.last = nil

  local login_data = ImportFile("logins")
  local file = self:FromFile("logins")
  if file then
    if file.accounts then self.State.accounts = file.accounts end
    if file.last then self.State.last = file.last end
    if file.account_buttons_locked ~= nil then self.State.account_buttons_locked = file.account_buttons_locked end
    if file.account_buttons_streamer ~= nil then self.State.account_buttons_streamer = file.account_buttons_streamer end
    return true
  elseif login_data then
    for label,account,password,character,auto,last in string.gfind(login_data, "label:(%S*) account:(%S+) password(:%S+) character:(%S*) auto:(%S*) last:(%S*)\n") do
      if auto == "true" then auto = true else auto = false end
      table.insert(self.State.accounts, { account = account, password = password, character = character, auto = auto })
    end
    return true
  end
  if not next(self.State.accounts) then
    local val = GetSavedAccountName()
    for n, p, c in string.gfind(val, "(%S+) (%S+) *(%d*);") do
      if (c == "") then c = "-" end
      if (string.find(p, "~%d") == 1) then
        p = self.State.accounts[tonumber(string.sub(p, 2, 3))].password
      end
      table.insert(self.State.accounts, { account = n, password = p })
    end
    return true
  end
  return false
end

function LoginManager:SaveAccounts(by_login)
  if by_login then
    local account = AccountLoginAccountEdit:GetText()
    local password = AccountLoginPasswordEdit:GetText()
    if (account and account ~= "" and password and password ~= "") then
      local exists = false
      for i = 1, table.getn(self.State.accounts) do
        if (self.State.accounts[i].account == account) then
          exists = true
          self.State.accounts[i].password = ":"..password
          break
        end
      end
      if (not exists) then
        table.insert(self.State.accounts, { account = account, password = ":"..password })
      end
    end
  end
  return self:ToFile("logins",self.State)
end

function LoginManager:SaveLabel()
  self:SaveAccounts(true)
  self:UpdateUI()
end

function LoginManager:SelectAccount(idx)
  local i = self.CurrentPage * self.PageSize + idx;
  local act = self.State.accounts[i].account
  local pwd = self.State.accounts[i].password
  AccountLoginAccountEdit:SetText(act)
  AccountLoginPasswordEdit:SetText(string.sub(pwd,2))
  LoginManager:OnNameUpdate(act)
end

function LoginManager:OnNameUpdate(name)
  self.SelectedAcct = nil
  for i = 1, table.getn(self.State.accounts) do
    if (self.State.accounts[i].account == name) then self.SelectedAcct = i end
  end
  if (self.SelectedAcct) then
    self.CurrentPage = math.floor((self.SelectedAcct - 1) / self.PageSize)
  end
  self:UpdateUI()
end

function LoginManager:UpdateUI()
  if AccountLoginUI:IsVisible() then
    self:MakeExtraAccountButtons()
    self:HideSideButtons()
    self:KillServerAlert()
    AccountLoginSaveAccountName:Hide()
    self:UpdateLoginUI()
  elseif CharacterSelectUI:IsVisible() then
    self:UpdateCharacterUI()
  end
end

function LoginManager:UpdateLoginUI()
  local total = table.getn(self.State.accounts)
  local skip = self.CurrentPage * self.PageSize

  -- avoid changing texts / showing elements that will be hidden
  if not self.HIDE_ACCOUNT_UI then
    AutologinSelectAccountText:SetText(L["SelectAccount"])
    AutologinRemoveAccountButton:SetText(L["RemoveAccount"])
  end

  local streamer = self.State.account_buttons_streamer
  if AccountLoginAccountEdit.cover then
    if streamer and not self.HIDE_ACCOUNT_UI then
      AccountLoginAccountEdit.cover:Show()
    else
      AccountLoginAccountEdit.cover:Hide()
    end
  end

  for i = 1, self.PageSize do
    local button = _G["AutologinAccountButton" .. i]
    if not button then break end
    local acct_id = skip + i
    button:UnlockHighlight()
    if (acct_id > total) then
      button:Hide()
    else
      local r = self.State.accounts[acct_id]
      local selected = self.SelectedAcct == acct_id
      local acc_str = r.account
      if streamer and not self.HIDE_ACCOUNT_UI then
        acc_str = string.sub(acc_str,1,1) .. string.rep('*',5) .. string.sub(acc_str,-2)
      end
      local nameFS = _G["AutologinAccountButton" .. i .. "ButtonTextName"]
      if nameFS then nameFS:SetText(acc_str or "") end

      local class_str = r.class or "-----"
      local chr_str = streamer and class_str or r.character
      local class_clr = r.class and L.class[class_str] and CLASS_COLORS[L.class[class_str]].colorStr
      if class_clr then chr_str = ("|c" .. class_clr .. (chr_str or "") .. "|r") end

      if button.char then
        button.char:SetText(chr_str or "")
        button.char:SetWidth(button.char:GetFontString():GetStringWidth() + 20)
      end

      if self.State.account_buttons_locked or acct_id == table.getn(self.State.accounts) then
        if button.down then button.down:Hide() end
      else
        if button.down then button.down:Show() end
      end
      if self.State.account_buttons_locked or acct_id == 1 then
        if button.up then button.up:Hide() end
      else
        if button.up then button.up:Show() end
      end
      if not r.character or r.character == "" then
        if button.char then button.char:Hide() end
      else
        if button.char then button.char:Show() end
      end
      if selected then button:LockHighlight() end
      button:Show()
    end
  end

  -- NEW: fully hide / neutralize the panel and buttons
  if self.HIDE_ACCOUNT_UI then
    self:HideAccountUI()
  end
end

function LoginManager:UpdateCharacterUI()
  local numChars = GetNumCharacters()
  local index = 1
  for _,char in ipairs(LoginManager.realm_chars) do
    local zone = char.zone
    local button = _G["CharSelectCharacterButton"..index]
    if ( not char.name ) then
      button:SetText("ERROR - Tell Jeremy")
    else
      button:UnlockHighlight()
      if ( not char.zone ) then zone = "" end
      local classColor = L.class[char.class] and CLASS_COLORS[L.class[char.class]].colorStr or "ffFFFFFF"
      _G["CharSelectCharacterButton"..index.."ButtonTextName"]:SetText(char.name)
      _G["CharSelectCharacterButton"..index.."ButtonTextInfo"]:SetText(
        format(TEXT(char.ghost and CHARACTER_SELECT_INFO_GHOST or CHARACTER_SELECT_INFO), char.level, "|c" .. classColor .. char.class .. "|r")
      )
      _G["CharSelectCharacterButton"..index.."ButtonTextLocation"]:SetText(zone)
    end

    if (char.id == CharacterSelect.selectedIndex) then button:LockHighlight() end

    if LoginManager.char_buttons_locked then
      button.up:Hide(); button.down:Hide()
    else
      button.up:Show(); button.down:Show()
    end

    index = index + 1
    if ( index > MAX_CHARACTERS_DISPLAYED ) then break end
  end

  local lockButton = _G["ButtonCharButtonsLock"]
  if lockButton then
    if self.char_buttons_locked then
      lockButton:GetNormalTexture():SetVertexColor(1,1,1)
      lockButton:SetTextColor(1,0.78,0)
    else
      lockButton:GetNormalTexture():SetVertexColor(0.5,0.5,0.5)
      lockButton:SetTextColor(0.5,0.5,0.5)
    end
  end
end

function LoginManager:OnLogin()
  local name = AccountLoginAccountEdit:GetText()
  local password = AccountLoginPasswordEdit:GetText()
  self.State.last = self.SelectedAcct
  self:SaveAccounts(true)
  self:OnNameUpdate(name)
  self.from_login_screen = true
  if self.orig_AccountLogin_Login then
    self.orig_AccountLogin_Login()
  else
    if PlaySound then PlaySound("gsLogin") end
    DefaultServerLogin(name, password)
  end
end

function LoginManager:RemoveAccount()
  if not next(LoginManager.State.accounts) or not LoginManager.SelectedAcct then return end
  table.remove(LoginManager.State.accounts, LoginManager.SelectedAcct)
  LoginManager:SaveAccounts()
  AccountLoginAccountEdit:SetText("")
  AccountLoginPasswordEdit:SetText("")
  if (LoginManager.CurrentPage > 0 and LoginManager.CurrentPage * LoginManager.PageSize > table.getn(LoginManager.State) - 1) then
    LoginManager.CurrentPage = LoginManager.CurrentPage - 1
  end
  LoginManager:UpdateUI()
end

function LoginManager:NextPage()
  if ((self.CurrentPage + 1) * self.PageSize > table.getn(self.State.accounts) - 1) then return end
  self.CurrentPage = self.CurrentPage + 1
  self:UpdateUI()
end

function LoginManager:PrevPage()
  if (self.CurrentPage == 0) then return end
  self.CurrentPage = self.CurrentPage - 1
  self:UpdateUI()
end

function LoginManager:OnCharactersLoad()
  self:LoadAccounts()

  for i=1,10 do
    local charButton = _G["CharSelectCharacterButton"..i]
    if not charButton.up then
      local upButton = CreateFrame("Button", charButton:GetName().."Up", charButton)
      upButton:SetWidth(32); upButton:SetHeight(32)
      upButton:SetPoint("TOPRIGHT", charButton, "TOPRIGHT", -30, 0)
      upButton:SetHitRectInsets(1, 1, 1, 1)
      upButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
      upButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Down")
      upButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
      upButton:SetScript("OnClick", function()
        moveIndexUp(LoginManager.realm_chars, this:GetParent():GetID())
        LoginManager:UpdateUI()
      end)
      upButton:SetScript("OnEnter", function() this:GetParent():LockHighlight() end)
      upButton:SetScript("OnLeave", function() if this:GetParent():GetID() ~= CharacterSelect.selectedIndex then this:GetParent():UnlockHighlight() end end)
      charButton.up = upButton
    end
    if not charButton.down then
      local downButton = CreateFrame("Button", charButton:GetName().."Down", charButton)
      downButton:SetWidth(32); downButton:SetHeight(32)
      downButton:SetPoint("TOP", charButton.up, "BOTTOM", 0, 8)
      downButton:SetHitRectInsets(1, 1, 1, 1)
      downButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
      downButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
      downButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
      downButton:SetScript("OnClick", function()
        moveIndexDown(LoginManager.realm_chars, this:GetParent():GetID())
        LoginManager:UpdateUI()
      end)
      downButton:SetScript("OnEnter", function() this:GetParent():LockHighlight() end)
      downButton:SetScript("OnLeave", function() if this:GetParent():GetID() ~= CharacterSelect.selectedIndex then this:GetParent():UnlockHighlight() end end)
      charButton.down = downButton
    end
  end

  local addonsButton = _G["CharacterSelectAddonsButton"]
  -- Restore UI click sound for AddOns button (some clients/templates may not play it)
  if addonsButton and not addonsButton.__autologin_soundhook then
    local _origOnClick = addonsButton:GetScript("OnClick")
    addonsButton:SetScript("OnClick", function()
      if PlaySound then PlaySound("gsTitleOptionOK") end
      if _origOnClick then _origOnClick() end
    end)
    addonsButton.__autologin_soundhook = true
  end

  if not addonsButton.lock then
    local lockButton = CreateFrame("Button", "ButtonCharButtonsLock", addonsButton, "GlueButtonSmallTemplate")
    lockButton:SetWidth(150); lockButton:SetHeight(35)
    lockButton:SetPoint("LEFT", addonsButton, "RIGHT", 4, 0)
    lockButton:SetText(L["LockCharacters"])
    lockButton:SetWidth(lockButton:GetFontString():GetStringWidth() + 50)
    lockButton:SetScript("OnClick", function()
  if PlaySound then PlaySound("gsTitleOptionOK") end

  LoginManager.char_buttons_locked = not LoginManager.char_buttons_locked
  this:Show()
  LoginManager:SaveAccounts()
  LoginManager:UpdateUI()
end)
    addonsButton.lock = lockButton
  end

  self.realm = GetServerName()
  self.realm_chars = {}
  for c = 1, GetNumCharacters() do
    local name, race, class, level, zone, fileString, gender, ghost = GetCharacterInfo(c)
    self.realm_chars[c] = { id = c, name = name, race = race, class = class, level = level, zone = zone, fileString = fileString, gender = gender, ghost = ghost }
  end

  
  -- Determine SelectedAcct early (needed when returning from /logout)
  if not self.SelectedAcct then
    self.SelectedAcct = self.State.last
  end

  -- If we still don't know which account index matches this realm, infer it from saved character names
  if not self.SelectedAcct and not self.from_login_screen then
    local function SetIdx()
      for i,account in ipairs(self.State.accounts or {}) do
        for saved_realm,saved_chars in pairs(account.characters or {}) do
          if saved_realm == self.realm then
            for _,schar in ipairs((saved_chars and saved_chars.order) or {}) do
              for _,rchar in pairs(self.realm_chars or {}) do
                if schar and rchar and schar.name == rchar.name then
                  self.SelectedAcct = i
                  return
                end
              end
            end
          end
        end
      end
    end
    SetIdx()
  end

  -- Ensure a valid selection when characters exist (prevents fallback selecting the wrong character)
  local num = GetNumCharacters()
  if num and num > 0 then
    local acct = self.State.accounts and self.State.accounts[self.SelectedAcct]
    local last = nil

    if acct and acct.characters and acct.characters[self.realm] then
      last = acct.characters[self.realm].last
    end

    if not last or last < 1 or last > num or not GetCharacterInfo(last) then
      last = 1
      if acct and acct.characters and acct.characters[self.realm] then
        acct.characters[self.realm].last = 1
      end
    end

    CharacterSelect_SelectCharacter(last)
  end


  local acct = self.State.accounts[self.SelectedAcct]
  if acct and acct.characters then
    for saved_realm,saved_chars in pairs(acct.characters or {}) do
      if saved_realm == self.realm then
        self.char_buttons_locked = saved_chars.char_buttons_locked
        local orderRank, rank = {}, 1
        for _, item in ipairs(saved_chars.order or {}) do orderRank[item.id] = rank; rank = rank + 1 end
        table.sort(LoginManager.realm_chars, function(a,b) return (orderRank[a.id] or 10000) < (orderRank[b.id] or 10000) end)
        -- keep whatever CharacterSelect selected above (sanitized)
        if self.auto_char_button_pressed then
          local idx = CharacterSelect.selectedIndex
          if idx and idx >= 1 and idx <= GetNumCharacters() and GetCharacterInfo(idx) then
            EnterWorld()
          end
          self.auto_char_button_pressed = false
        end
        break
      end
    end
  end

  -- fallback: keep locked by default if no saved value exists
  if self.char_buttons_locked == nil then
    self.char_buttons_locked = true
  end

  self:UpdateUI()
end

function LoginManager:EnterWorld()
  if self.realm and self.SelectedAcct and self.State.accounts[self.SelectedAcct] then
    local acct = self.State.accounts[self.SelectedAcct]
    acct.characters = acct.characters or {}
    acct.characters[self.realm] = acct.characters[self.realm] or {}

    local chars = acct.characters[self.realm]
    chars.last = CharacterSelect.selectedIndex or 1
    chars.order = {}
    for i,char in ipairs(LoginManager.realm_chars) do
      table.insert(chars.order, { id = char.id, name = char.name })
    end
    chars.char_buttons_locked = self.char_buttons_locked or nil
    local name, race, class, _level, zone, _race2, _gender, _isGhost = GetCharacterInfo(chars.last)
    acct.character = name; acct.class = class; acct.race = race; acct.zone = zone
  end
  self:SaveAccounts()
  if self.orig_CharacterSelect_EnterWorld then
    self.orig_CharacterSelect_EnterWorld()
  else
    if PlaySound then PlaySound("gsEnterWorld") end
    EnterWorld()
  end
end

----------
-- buttons
----------
function AutologinAccountButton_OnClick(button)
  if button == "LeftButton" then
    LoginManager:SelectAccount(this:GetID())
  end
end

function AutologinAccountButton_OnDoubleClick()
  LoginManager:SelectAccount(this:GetID())
  AccountLogin_Login()
end

function AutologinRemoveAccountButton_OnClick()
  LoginManager:RemoveAccount()
end

--------
-- hooks
--------
local orig_AccountLogin_OnLoad = AccountLogin_OnLoad
AccountLogin_OnLoad = function (a1,a2,a3,a4,a5,a6,a7,a8,a9)
  if orig_AccountLogin_OnLoad then orig_AccountLogin_OnLoad(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
  LoginManager:LoadAccounts()
end


local orig_AccountLogin_OnEvent = AccountLogin_OnEvent
AccountLogin_OnEvent = function (a1,a2,a3,a4,a5,a6,a7,a8,a9)
  if orig_AccountLogin_OnEvent then orig_AccountLogin_OnEvent(a1,a2,a3,a4,a5,a6,a7,a8,a9) end

  -- If login fails or server disconnects, the client clears the password field immediately.
  -- Restore it (optionally) so the user can retry without relogging/restarting.
  if event == "LOGIN_FAILED" or event == "AUTH_FAILED" or event == "DISCONNECTED_FROM_SERVER" or event == "SERVER_DISCONNECTED" then
    LoginManager:RestorePasswordFromSelected()
  end
end

local orig_AccountLogin_OnShow = AccountLogin_OnShow
AccountLogin_OnShow = function (a1,a2,a3,a4,a5,a6,a7,a8,a9)
  if orig_AccountLogin_OnShow then orig_AccountLogin_OnShow(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
  if not LoginManager.State.accounts then LoginManager:LoadAccounts() end
  if LoginManager.State.last and LoginManager.State.accounts[LoginManager.State.last] then
    LoginManager:SelectAccount(LoginManager.State.last)
  end
  LoginManager:UpdateUI()

  -- reinforce hiding immediately after show (prevents flicker)
  if LoginManager.HIDE_ACCOUNT_UI then
    LoginManager:HideAccountUI()

  -- keep Server NEWS/Alert hidden even if server forces it to show
  LoginManager:KillServerAlert()
  end
end

local orig_AccountLoginAccountEdit_OnTextChanged = AccountLoginAccountEdit:GetScript("OnTextChanged")
AccountLoginAccountEdit:SetScript("OnTextChanged", function (a1,a2,a3,a4,a5,a6,a7,a8,a9)
  orig_AccountLoginAccountEdit_OnTextChanged(a1,a2,a3,a4,a5,a6,a7,a8,a9)
  LoginManager:OnNameUpdate(this:GetText())
end)

local orig_AccountLogin_Login = AccountLogin_Login
LoginManager.orig_AccountLogin_Login = orig_AccountLogin_Login
AccountLogin_Login = function (a1,a2,a3,a4,a5,a6,a7,a8,a9)
  LoginManager:OnLogin()
end

local orig_CharacterSelectButton_OnClick = CharacterSelectButton_OnClick
CharacterSelectButton_OnClick = function (a1,a2,a3,a4,a5,a6,a7,a8,a9)
  local id = this:GetID()
  local sorted_id = LoginManager.realm_chars[id].id
  if ( sorted_id ~= CharacterSelect.selectedIndex ) then
    CharacterSelect_SelectCharacter(sorted_id)
  end
  LoginManager:UpdateUI()
end

local orig_CharacterSelectButton_OnDoubleClick = CharacterSelectButton_OnDoubleClick
CharacterSelectButton_OnDoubleClick = function (a1,a2,a3,a4,a5,a6,a7,a8,a9)
  local id = this:GetID()
  local sorted_id = LoginManager.realm_chars[id].id
  if ( sorted_id ~= CharacterSelect.selectedIndex ) then
    CharacterSelect_SelectCharacter(sorted_id)
  end
  CharacterSelect_EnterWorld()
end

local orig_CharacterSelect_OnKeyDown = CharacterSelect_OnKeyDown
CharacterSelect_OnKeyDown = function (a1,a2,a3,a4,a5,a6,a7,a8,a9)
  local numChars = GetNumCharacters()
  local button_index
  for i,char in ipairs(LoginManager.realm_chars) do
    if char.id == this.selectedIndex then button_index = i; break end
  end

  if ( arg1 == "UP" or arg1 == "LEFT" ) then
    if ( numChars > 1 ) then
      if ( button_index > 1 ) then
        _G["CharSelectCharacterButton" .. (button_index - 1)]:Click()
      else
        _G["CharSelectCharacterButton" .. numChars]:Click()
      end
    end
  elseif ( arg1 == "DOWN" or arg1 == "RIGHT" ) then
    if ( numChars > 1 ) then
      if ( button_index < GetNumCharacters() ) then
        _G["CharSelectCharacterButton" .. (button_index + 1)]:Click()
      else
        _G["CharSelectCharacterButton" .. 1]:Click()
      end
    end
  else
    orig_CharacterSelect_OnKeyDown(a1,a2,a3,a4,a5,a6,a7,a8,a9)
  end
end

local orig_CharacterSelect_OnEvent = CharacterSelect_OnEvent
CharacterSelect_OnEvent = function (a1,a2,a3,a4,a5,a6,a7,a8,a9)
  if orig_CharacterSelect_OnEvent then orig_CharacterSelect_OnEvent(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
  if event == "CHARACTER_LIST_UPDATE" then
    LoginManager:OnCharactersLoad()
  end
end

local orig_CharacterSelect_EnterWorld = CharacterSelect_EnterWorld
LoginManager.orig_CharacterSelect_EnterWorld = orig_CharacterSelect_EnterWorld
CharacterSelect_EnterWorld = function (a1,a2,a3,a4,a5,a6,a7,a8,a9)
  LoginManager:EnterWorld()
end


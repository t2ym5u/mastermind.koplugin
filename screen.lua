local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local Device         = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local Size           = require("ui/size")
local UIManager      = require("ui/uimanager")
local VerticalGroup  = require("ui/widget/verticalgroup")
local VerticalSpan   = require("ui/widget/verticalspan")
local _              = require("i18n")
local T              = require("ffi/util").template

local ScreenBase         = require("screen_base")
local SettingsDialog     = require("settings_dialog")

local MastermindBoard       = lrequire("board")
local MastermindBoardWidget = lrequire("board_widget")

local DeviceScreen = Device.screen

-- ---------------------------------------------------------------------------
-- MastermindScreen
-- ---------------------------------------------------------------------------

local GAME_RULES_EN = _([[
Mastermind — Rules

Crack the secret code (a sequence of colored pegs).

After each guess, you receive feedback:
• Black peg — correct colour in the correct position.
• White peg — correct colour but in the wrong position.

Tap a slot in the current row to select it (heavy outline), then tap a number below to fill it; the next empty slot is selected automatically. Submit checks the guess, Clear empties the row. The feedback is shown next to each guess as B (black) and W (white).

Use the feedback to narrow down the code.
You have a limited number of guesses to find the exact code.
]])

local GAME_RULES_FR = [[
Mastermind — Règles

Déchiffrez le code secret (une séquence de couleurs de pions).

Après chaque proposition, vous recevez un retour :
• Pion noir — bonne couleur à la bonne position.
• Pion blanc — bonne couleur mais à la mauvaise position.

Appuyez sur une case de la ligne en cours pour la sélectionner (contour épais), puis sur un chiffre en dessous pour la remplir ; la case vide suivante est sélectionnée automatiquement. Valider vérifie la proposition, Effacer tout vide la ligne. Le retour s'affiche à côté de chaque proposition : B (noir) et W (blanc).

Utilisez le retour pour affiner vos propositions.
Vous avez un nombre limité d'essais pour trouver le code exact.
]]

local MastermindScreen = ScreenBase:extend{}

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

function MastermindScreen:init()
    local state = self.plugin:loadState()
    self.board = MastermindBoard:new{
        code_len         = self.plugin:getSetting("code_len",    4),
        num_symbols      = self.plugin:getSetting("num_symbols", 6),
        max_attempts     = self.plugin:getSetting("max_attempts", 10),
        allow_duplicates = self.plugin:getSetting("allow_duplicates", true),
    }
    if not self.board:load(state) then
        self.board:newGame()
    end
    self.selected_slot = 1
    ScreenBase.init(self)
end

function MastermindScreen:serializeState()
    return self.board:serialize()
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

function MastermindScreen:buildLayout()
    local board = self.board
    local is_landscape = self:isLandscape()

    local title_bar = self:buildTitleBar(_("Mastermind"), function()
        return {
            { text = _("New game"), callback = function() self:onNewGame() end },
            { text = _("Settings"), callback = function() self:openSettings() end },
            self:makeRulesButtonConfig(GAME_RULES_EN, GAME_RULES_FR),
        }
    end)

    -- Symbol pad: picks the symbol for the selected slot.
    local keys = {}
    for i = 1, board.num_symbols do
        local s = i
        keys[#keys + 1] = { text = tostring(s), callback = function() self:onSymbolSelected(s) end }
    end

    self.status_text:setMaxWidth(self:getControlsWidth())
    local controls = VerticalGroup:new{
        align = "center",
        self.status_text,
        VerticalSpan:new{ width = Size.span.vertical_large },
        self:buildNumberPad(keys),
        VerticalSpan:new{ width = Size.span.vertical_default },
        self:buildActionBar({
            { text = _("Submit"), callback = function() self:onSubmit() end },
            { text = _("Clear"),  callback = function() self:onClear() end },
        }),
    }

    -- The widget draws its own outline, so the frame only pads.
    local frame_pad = Size.padding.large
    local budget_w, budget_h = self:getBoardBudget(title_bar, controls)
    self.board_widget = MastermindBoardWidget:new{
        board        = board,
        max_w        = budget_w - 2 * frame_pad,
        max_h        = budget_h - 2 * frame_pad,
        onSlotTapped = function(slot) self:onSlotTapped(slot) end,
        getSelectedSlot = function() return self.selected_slot end,
    }
    local board_frame = FrameContainer:new{
        padding    = frame_pad,
        margin     = 0,
        bordersize = 0,
        self.board_widget,
    }

    if is_landscape then
        local content = HorizontalGroup:new{
            align = "center",
            board_frame,
            HorizontalSpan:new{ width = self:getGutter() },
            controls,
        }
        self:buildLandscapeLayout(title_bar, content)
    else
        self:buildPortraitLayout(title_bar, board_frame,
            VerticalGroup:new{ align = "center", controls, VerticalSpan:new{ width = self:getGutter() } })
    end

    self:updateStatus()
end

-- ---------------------------------------------------------------------------
-- Slot interaction
-- ---------------------------------------------------------------------------

function MastermindScreen:onSlotTapped(slot)
    self.selected_slot = slot
    self:updateStatus()
    self.board_widget:refresh()
end

function MastermindScreen:onSymbolSelected(sym)
    if self.board:isGameOver() then return end
    local slot = self.selected_slot
    self.board:setSlot(slot, sym)

    -- Advance to next empty slot
    local code_len = self.board.code_len
    local next_slot = slot
    for offset = 1, code_len do
        local candidate = (slot - 1 + offset) % code_len + 1
        if (self.board.current[candidate] or 0) == 0 then
            next_slot = candidate
            break
        end
    end
    self.selected_slot = next_slot

    self.plugin:saveState(self.board:serialize())
    self.board_widget:refresh()
    self:updateStatus()
end

-- ---------------------------------------------------------------------------
-- Game actions
-- ---------------------------------------------------------------------------

function MastermindScreen:onNewGame()
    local board = self.board
    board.code_len         = self.plugin:getSetting("code_len",    4)
    board.num_symbols      = self.plugin:getSetting("num_symbols", 6)
    board.max_attempts     = self.plugin:getSetting("max_attempts", 10)
    board.allow_duplicates = self.plugin:getSetting("allow_duplicates", true)
    board:newGame()
    self.selected_slot = 1
    self.plugin:saveState(board:serialize())
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

-- Solved or out of rows.
function MastermindScreen:isRoundOver()
    return self.board:isGameOver() and true or false
end

function MastermindScreen:onSubmit()
    local ok, result = self.board:submitGuess()
    if not ok then
        if result == "incomplete" then
            self:showMessage(_("Fill all slots before submitting."), 2)
        end
        return
    end
    self.selected_slot = 1
    self.plugin:saveState(self.board:serialize())
    self.board_widget:refresh()
    self:updateStatus()
    self:refreshActionBar()

    if self.board.solved then
        local n = self.board:getAttempts()
        UIManager:scheduleIn(0.4, function()
            self:showMessage(T(_("You won in %1 attempt(s)!"), n), 4)
        end)
    elseif self.board.failed then
        local secret = self.board.secret
        local parts  = {}
        for _, v in ipairs(secret) do parts[#parts + 1] = tostring(v) end
        local code_str = table.concat(parts, " ")
        UIManager:scheduleIn(0.4, function()
            self:showMessage(T(_("Game over! The secret code was: %1"), code_str), 5)
        end)
    end
end

function MastermindScreen:onClear()
    self.board:clearCurrent()
    self.selected_slot = 1
    self.plugin:saveState(self.board:serialize())
    self.board_widget:refresh()
    self:updateStatus()
end

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

function MastermindScreen:openSettings()
    SettingsDialog.open{
        title   = _("Mastermind — Settings"),
        plugin  = self.plugin,
        parent  = self,
        sections = {
            {
                title = _("Game options"),
                items = {
                    {
                        label       = _("Code length"),
                        setting_key = "code_len",
                        type        = "picker",
                        values      = {
                            { id = 3, text = "3" },
                            { id = 4, text = "4" },
                            { id = 5, text = "5" },
                        },
                        on_change = function() self:onNewGame() end,
                    },
                    {
                        label       = _("Number of symbols"),
                        setting_key = "num_symbols",
                        type        = "picker",
                        values      = {
                            { id = 4, text = "4" },
                            { id = 5, text = "5" },
                            { id = 6, text = "6" },
                            { id = 8, text = "8" },
                        },
                        on_change = function() self:onNewGame() end,
                    },
                    {
                        label       = _("Max attempts"),
                        setting_key = "max_attempts",
                        type        = "picker",
                        values      = {
                            { id = 8,  text = "8"  },
                            { id = 10, text = "10" },
                            { id = 12, text = "12" },
                        },
                        on_change = function() self:onNewGame() end,
                    },
                    {
                        label       = _("Allow duplicates"),
                        setting_key = "allow_duplicates",
                        type        = "toggle",
                        on_change   = function() self:onNewGame() end,
                    },
                },
            },
            {
                title = _("About"),
                items = {
                    { label = _("Mastermind v1.0.0"), type = "info" },
                },
            },
        },
    }
end

-- ---------------------------------------------------------------------------
-- Status bar
-- ---------------------------------------------------------------------------

function MastermindScreen:updateStatus(message)
    local status
    if message then
        status = message
    elseif self.board.solved then
        local n = self.board:getAttempts()
        status  = T(_("You won in %1 attempt(s)!"), n)
    elseif self.board.failed then
        local secret = self.board.secret or {}
        local parts  = {}
        for _, v in ipairs(secret) do parts[#parts + 1] = tostring(v) end
        status = T(_("Game over. Secret was: %1"), table.concat(parts, " "))
    else
        -- The selected slot is outlined on the board, so it isn't repeated here.
        local b = self.board
        status = self:joinStatus(
            T(_("Code: %1"), b.code_len),
            T(_("Symbols: %1"), b.num_symbols),
            T(_("Attempt: %1/%2"), b:getAttempts() + 1, b.max_attempts))
    end
    ScreenBase.updateStatus(self, status)
end

return MastermindScreen

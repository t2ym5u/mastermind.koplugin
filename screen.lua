local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local ButtonTable    = require("ui/widget/buttontable")
local Device         = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local Size           = require("ui/size")
local UIManager      = require("ui/uimanager")
local VerticalGroup  = require("ui/widget/verticalgroup")
local VerticalSpan   = require("ui/widget/verticalspan")
local _              = require("gettext")
local T              = require("ffi/util").template

local ScreenBase         = require("screen_base")
local SettingsDialog     = require("settings_dialog")

local MastermindBoard       = lrequire("board")
local MastermindBoardWidget = lrequire("board_widget")

local DeviceScreen = Device.screen

-- ---------------------------------------------------------------------------
-- MastermindScreen
-- ---------------------------------------------------------------------------

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

    self.board_widget = MastermindBoardWidget:new{
        board        = board,
        onSlotTapped = function(slot)
            self:onSlotTapped(slot)
        end,
    }

    local is_landscape  = self:isLandscape()
    local sw            = DeviceScreen:getWidth()

    local board_frame = FrameContainer:new{
        padding = Size.padding.default,
        margin  = Size.margin.default,
        self.board_widget,
    }

    local bw_size       = self.board_widget.size_w + (Size.padding.default + Size.margin.default) * 2
    local right_w       = sw - bw_size - Size.span.horizontal_default
    local button_width  = is_landscape
        and math.max(right_w - Size.span.horizontal_default, 100)
        or  math.floor(sw * 0.9)

    -- Symbol selector row(s)
    local num_syms   = board.num_symbols
    local sym_buttons = {}
    for i = 1, num_syms do
        local s = i
        sym_buttons[#sym_buttons + 1] = {
            id       = "sym_" .. s,
            text     = tostring(s),
            callback = function() self:onSymbolSelected(s) end,
        }
    end
    local symbol_bar = ButtonTable:new{
        shrink_unneeded_width = true,
        width   = button_width,
        buttons = { sym_buttons },
    }

    -- Action buttons
    local action_buttons = ButtonTable:new{
        shrink_unneeded_width = true,
        width   = button_width,
        buttons = {
            {
                { text = _("New game"), callback = function() self:onNewGame() end },
                { text = _("Submit"),   callback = function() self:onSubmit() end },
                { text = _("Clear"),    callback = function() self:onClear() end },
                { text = _("Settings"), callback = function() self:openSettings() end },
                self:makeCloseButtonConfig(),
            },
        },
    }

    if is_landscape then
        local right_panel = VerticalGroup:new{
            align = "center",
            action_buttons,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.status_text,
            VerticalSpan:new{ width = Size.span.vertical_large },
            symbol_bar,
        }
        self.layout = HorizontalGroup:new{
            align = "center",
            board_frame,
            HorizontalSpan:new{ width = Size.span.horizontal_default },
            right_panel,
        }
    else
        self.layout = VerticalGroup:new{
            align = "center",
            VerticalSpan:new{ width = Size.span.vertical_large },
            action_buttons,
            VerticalSpan:new{ width = Size.span.vertical_large },
            board_frame,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.status_text,
            VerticalSpan:new{ width = Size.span.vertical_large },
            symbol_bar,
            VerticalSpan:new{ width = Size.span.vertical_large },
        }
    end

    self[1] = self.layout
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
        local attempt = self.board:getAttempts() + 1
        local max     = self.board.max_attempts
        status = T(_("Attempt %1/%2 — slot %3 selected"), attempt, max, self.selected_slot)
    end
    ScreenBase.updateStatus(self, status)
end

return MastermindScreen

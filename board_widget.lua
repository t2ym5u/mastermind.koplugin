local Blitbuffer      = require("ffi/blitbuffer")
local Device          = require("device")
local Font            = require("ui/font")
local GestureRange    = require("ui/gesturerange")
local Geom            = require("ui/geometry")
local InputContainer  = require("ui/widget/container/inputcontainer")
local RenderText      = require("ui/rendertext")
local UIManager       = require("ui/uimanager")

local Screen = Device.screen

-- Grey fills for each symbol (1..6), from light to dark so they are visually distinct on e-ink
local SYMBOL_FILLS = {
    Blitbuffer.COLOR_WHITE,          -- 1: white
    Blitbuffer.COLOR_GRAY_E,         -- 2: very light grey
    Blitbuffer.COLOR_GRAY_B,         -- 3: light grey
    Blitbuffer.COLOR_GRAY_9,         -- 4: medium grey
    Blitbuffer.COLOR_GRAY_5,         -- 5: dark grey
    Blitbuffer.COLOR_GRAY_3,         -- 6: very dark grey
}

local SYMBOL_TEXT_COLORS = {
    Blitbuffer.COLOR_BLACK,
    Blitbuffer.COLOR_BLACK,
    Blitbuffer.COLOR_BLACK,
    Blitbuffer.COLOR_BLACK,
    Blitbuffer.COLOR_WHITE,
    Blitbuffer.COLOR_WHITE,
}

-- ---------------------------------------------------------------------------
-- MastermindBoardWidget
-- ---------------------------------------------------------------------------

local MastermindBoardWidget = InputContainer:extend{
    board        = nil,
    onSlotTapped = nil,
    max_w        = nil, -- optional width budget imposed by the caller's layout
    max_h        = nil, -- optional height budget imposed by the caller's layout
    getSelectedSlot = nil, -- function() -> slot index in the active row, or nil
}

-- Largest face whose ink for `sample` fits max_w x max_h. Measured unbounded
-- (with a width limit sizeUtf8Text truncates, so a width test against it can
-- never fail); ink height is y_top + y_bottom. Measuring keeps the digits in
-- their slots on every DPI, where a size scaled off the slot width was
-- scaled a second time by Font:getFace().
local function fitFace(font, sample, max_w, max_h)
    local lo, hi, best = 6, math.max(6, math.floor(max_h)), 6
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        local m   = RenderText:sizeUtf8Text(0, Screen:getWidth(), Font:getFace(font, mid), sample, true, false)
        if m.x <= max_w and (m.y_top + m.y_bottom) <= max_h then
            best, lo = mid, mid + 1
        else
            hi = mid - 1
        end
    end
    return Font:getFace(font, best)
end

function MastermindBoardWidget:init()
    local board        = self.board
    local code_len     = board.code_len
    local max_attempts = board.max_attempts

    local sw = Screen:getWidth()
    local sh = Screen:getHeight()
    local avail_h = self.max_h or math.floor(sh * 0.80)
    local avail_w = self.max_w or sw

    -- The board is (code_len + 1.2) slots wide, a slot being 0.9 row tall.
    self.row_h      = math.max(1, math.floor(math.min(avail_h / max_attempts,
                                                      avail_w / (0.9 * (code_len + 1.2)))))
    self.slot_w     = math.floor(self.row_h * 0.9)
    self.peg_area_w = math.floor(self.slot_w * 1.2)
    self.total_w    = code_len * self.slot_w + self.peg_area_w
    self.size_w     = self.total_w
    self.size_h     = max_attempts * self.row_h

    self.dimen      = Geom:new{ w = self.size_w, h = self.size_h }
    self.paint_rect = Geom:new{ x = 0, y = 0, w = self.size_w, h = self.size_h }

    self.num_face  = fitFace("cfont", "8", self.slot_w * 0.5, self.row_h * 0.45)
    self.peg_face  = fitFace("smallinfofont", "W:8", self.peg_area_w * 0.8, self.row_h * 0.3)

    self.ges_events = {
        Tap = {
            GestureRange:new{
                ges   = "tap",
                range = function() return self.paint_rect end,
            }
        },
    }
end

function MastermindBoardWidget:paintTo(bb, x, y)
    local board        = self.board
    local code_len     = board.code_len
    local max_attempts = board.max_attempts
    local row_h        = self.row_h
    local slot_w       = self.slot_w
    local peg_area_w   = self.peg_area_w

    self.paint_rect = Geom:new{ x = x, y = y, w = self.size_w, h = self.size_h }

    -- White background
    bb:paintRect(x, y, self.size_w, self.size_h, Blitbuffer.COLOR_WHITE)

    local active_row = #board.guesses + 1
    if board:isGameOver() then active_row = nil end

    for i = 1, max_attempts do
        local ry = y + (i - 1) * row_h

        -- Highlight active row
        if i == active_row then
            bb:paintRect(x, ry, code_len * slot_w, row_h, Blitbuffer.COLOR_GRAY_E)
        end

        -- Slot borders and fill
        for j = 1, code_len do
            local sx = x + (j - 1) * slot_w
            local margin = math.max(2, math.floor(slot_w * 0.07))
            local inner_x = sx + margin
            local inner_y = ry + margin
            local inner_w = slot_w - 2 * margin
            local inner_h = row_h - 2 * margin

            -- Determine symbol value
            local sym = 0
            if active_row == nil or i < active_row then
                -- submitted or past game
                if board.guesses[i] then
                    sym = board.guesses[i][j] or 0
                end
            elseif i == active_row then
                sym = board.current[j] or 0
            end

            -- Fill slot background
            if sym > 0 then
                local fill = SYMBOL_FILLS[sym] or Blitbuffer.COLOR_GRAY
                bb:paintRect(inner_x, inner_y, inner_w, inner_h, fill)
            end

            -- Slot border (rounded via single-pixel border rect)
            local border = math.max(1, math.floor(slot_w * 0.06))
            if i == active_row then
                border = math.max(2, border + 1)
                -- The slot the next number goes into: a much heavier outline,
                -- so the selection is visible on the board itself.
                if self.getSelectedSlot and self.getSelectedSlot() == j then
                    border = math.max(4, border * 3)
                end
            end
            -- Draw border as four lines
            bb:paintRect(inner_x, inner_y,              inner_w, border, Blitbuffer.COLOR_BLACK)
            bb:paintRect(inner_x, inner_y + inner_h - border, inner_w, border, Blitbuffer.COLOR_BLACK)
            bb:paintRect(inner_x, inner_y,              border, inner_h, Blitbuffer.COLOR_BLACK)
            bb:paintRect(inner_x + inner_w - border, inner_y, border, inner_h, Blitbuffer.COLOR_BLACK)

            -- Draw symbol digit centered in slot
            if sym > 0 then
                local text       = tostring(sym)
                local txt_color  = SYMBOL_TEXT_COLORS[sym] or Blitbuffer.COLOR_BLACK
                local avail_w    = inner_w - 2 * border
                local avail_h    = inner_h - 2 * border
                local m          = RenderText:sizeUtf8Text(0, avail_w, self.num_face, text, true, false)
                -- Baseline that centres the ink: centre + (y_top - y_bottom) / 2.
                local tx         = inner_x + border + math.floor((avail_w - m.x) / 2)
                local ty         = inner_y + border + math.floor(avail_h / 2 + (m.y_top - m.y_bottom) / 2)
                RenderText:renderUtf8Text(bb, tx, ty, self.num_face, text, true, false, txt_color)
            end
        end

        -- Feedback area (right of slots)
        local fx = x + code_len * slot_w
        local fb = board.feedback[i]
        if fb then
            local blacks = fb.blacks
            local whites = fb.whites
            -- Show "B:N" over "W:N" for clarity on e-ink: two short lines
            -- read much larger in the narrow feedback column than one.
            local lines = { "B:" .. blacks, "W:" .. whites }
            for li, fb_text in ipairs(lines) do
                local fb_m = RenderText:sizeUtf8Text(0, peg_area_w - 2, self.peg_face, fb_text, true, false)
                local fb_x = fx + math.floor((peg_area_w - fb_m.x) / 2)
                local cy   = ry + math.floor(row_h * (li == 1 and 0.3 or 0.7))
                local fb_y = cy + math.floor((fb_m.y_top - fb_m.y_bottom) / 2)
                RenderText:renderUtf8Text(bb, fb_x, fb_y, self.peg_face, fb_text, true, false, Blitbuffer.COLOR_BLACK)
            end
        end

        -- Row separator line
        local line_y = ry + row_h - 1
        bb:paintRect(x, line_y, self.size_w, 1, Blitbuffer.COLOR_GRAY_9)
    end

    -- Outer border
    bb:paintRect(x, y, self.size_w, 1, Blitbuffer.COLOR_BLACK)
    bb:paintRect(x, y + self.size_h - 1, self.size_w, 1, Blitbuffer.COLOR_BLACK)
    bb:paintRect(x, y, 1, self.size_h, Blitbuffer.COLOR_BLACK)
    bb:paintRect(x + self.size_w - 1, y, 1, self.size_h, Blitbuffer.COLOR_BLACK)

    -- Vertical separator between slots area and peg area
    local vx = x + code_len * slot_w
    bb:paintRect(vx, y, 1, self.size_h, Blitbuffer.COLOR_BLACK)

    -- Active row indicator: bold left border strip
    if active_row and active_row <= max_attempts then
        local ary = y + (active_row - 1) * row_h
        bb:paintRect(x, ary, 3, row_h, Blitbuffer.COLOR_BLACK)
    end
end

function MastermindBoardWidget:onTap(_, ges)
    if not (ges and ges.pos) then return false end
    local rect = self.paint_rect
    local lx   = ges.pos.x - rect.x
    local ly   = ges.pos.y - rect.y
    if lx < 0 or ly < 0 or lx >= rect.w or ly >= rect.h then return false end

    local board        = self.board
    local code_len     = board.code_len
    local max_attempts = board.max_attempts

    local active_row = #board.guesses + 1
    if board:isGameOver() then return false end
    if active_row > max_attempts then return false end

    local tapped_row = math.floor(ly / self.row_h) + 1
    if tapped_row ~= active_row then return false end

    -- Only respond to taps in the slots area (not peg area)
    local slots_w = code_len * self.slot_w
    if lx >= slots_w then return false end

    local tapped_slot = math.floor(lx / self.slot_w) + 1
    if tapped_slot < 1 or tapped_slot > code_len then return false end

    if self.onSlotTapped then
        self.onSlotTapped(tapped_slot)
    end
    return true
end

function MastermindBoardWidget:refresh()
    local rect = self.paint_rect
    UIManager:setDirty(self, function()
        return "ui", Geom:new{ x = rect.x, y = rect.y, w = rect.w, h = rect.h }
    end)
end

return MastermindBoardWidget

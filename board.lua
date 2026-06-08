-- ---------------------------------------------------------------------------
-- MastermindBoard — game logic for Mastermind
-- ---------------------------------------------------------------------------

local MastermindBoard = {}
MastermindBoard.__index = MastermindBoard

local DEFAULT_CODE_LEN       = 4
local DEFAULT_NUM_SYMBOLS    = 6
local DEFAULT_MAX_ATTEMPTS   = 10
local DEFAULT_ALLOW_DUPES    = true

local function score(secret, guess, n_pos, n_sym)
    local blacks = 0
    local sec_rem, gue_rem = {}, {}
    for i = 1, n_pos do
        if secret[i] == guess[i] then
            blacks = blacks + 1
        else
            sec_rem[secret[i]] = (sec_rem[secret[i]] or 0) + 1
            gue_rem[guess[i]]   = (gue_rem[guess[i]] or 0) + 1
        end
    end
    local whites = 0
    for c = 1, n_sym do
        whites = whites + math.min(sec_rem[c] or 0, gue_rem[c] or 0)
    end
    return blacks, whites
end

function MastermindBoard:new(opts)
    opts = opts or {}
    local o = setmetatable({}, self)
    o.code_len        = tonumber(opts.code_len)       or DEFAULT_CODE_LEN
    o.num_symbols     = tonumber(opts.num_symbols)    or DEFAULT_NUM_SYMBOLS
    o.max_attempts    = tonumber(opts.max_attempts)   or DEFAULT_MAX_ATTEMPTS
    if opts.allow_duplicates ~= nil then
        o.allow_duplicates = opts.allow_duplicates
    else
        o.allow_duplicates = DEFAULT_ALLOW_DUPES
    end
    o.secret   = nil
    o.guesses  = {}
    o.feedback = {}
    o.current  = {}
    o.solved   = false
    o.failed   = false
    for i = 1, o.code_len do o.current[i] = 0 end
    return o
end

function MastermindBoard:newGame()
    self.guesses  = {}
    self.feedback = {}
    self.solved   = false
    self.failed   = false
    self.current  = {}
    for i = 1, self.code_len do self.current[i] = 0 end

    local secret = {}
    if self.allow_duplicates then
        for i = 1, self.code_len do
            secret[i] = math.random(1, self.num_symbols)
        end
    else
        local pool = {}
        for i = 1, self.num_symbols do pool[i] = i end
        for i = #pool, 2, -1 do
            local j = math.random(i)
            pool[i], pool[j] = pool[j], pool[i]
        end
        for i = 1, self.code_len do
            secret[i] = pool[i]
        end
    end
    self.secret = secret
end

function MastermindBoard:setSlot(pos, symbol)
    if self:isGameOver() then return false end
    if pos < 1 or pos > self.code_len then return false end
    self.current[pos] = symbol
    return true
end

function MastermindBoard:clearCurrent()
    for i = 1, self.code_len do
        self.current[i] = 0
    end
end

function MastermindBoard:submitGuess()
    if self:isGameOver() then
        return false, "game over"
    end
    for i = 1, self.code_len do
        if (self.current[i] or 0) == 0 then
            return false, "incomplete"
        end
    end

    local guess = {}
    for i = 1, self.code_len do guess[i] = self.current[i] end

    local blacks, whites = score(self.secret, guess, self.code_len, self.num_symbols)
    local result = { blacks = blacks, whites = whites }

    self.guesses[#self.guesses + 1]  = guess
    self.feedback[#self.feedback + 1] = result

    if blacks == self.code_len then
        self.solved = true
    elseif #self.guesses >= self.max_attempts then
        self.failed = true
    end

    self:clearCurrent()
    return true, result
end

function MastermindBoard:isGameOver()
    return self.solved or self.failed
end

function MastermindBoard:getAttempts()
    return #self.guesses
end

function MastermindBoard:serialize()
    local guesses_copy = {}
    for i, g in ipairs(self.guesses) do
        guesses_copy[i] = {}
        for j, v in ipairs(g) do guesses_copy[i][j] = v end
    end
    local feedback_copy = {}
    for i, f in ipairs(self.feedback) do
        feedback_copy[i] = { blacks = f.blacks, whites = f.whites }
    end
    local secret_copy = nil
    if self.secret then
        secret_copy = {}
        for i, v in ipairs(self.secret) do secret_copy[i] = v end
    end
    local current_copy = {}
    for i, v in ipairs(self.current) do current_copy[i] = v end
    return {
        code_len         = self.code_len,
        num_symbols      = self.num_symbols,
        max_attempts     = self.max_attempts,
        allow_duplicates = self.allow_duplicates,
        secret           = secret_copy,
        guesses          = guesses_copy,
        feedback         = feedback_copy,
        current          = current_copy,
        solved           = self.solved,
        failed           = self.failed,
    }
end

function MastermindBoard:load(data)
    if type(data) ~= "table" or not data.secret then
        self:newGame()
        return false
    end
    self.code_len         = tonumber(data.code_len)       or self.code_len
    self.num_symbols      = tonumber(data.num_symbols)    or self.num_symbols
    self.max_attempts     = tonumber(data.max_attempts)   or self.max_attempts
    self.allow_duplicates = (data.allow_duplicates ~= nil) and data.allow_duplicates or self.allow_duplicates
    self.secret   = data.secret
    self.guesses  = data.guesses  or {}
    self.feedback = data.feedback or {}
    self.solved   = data.solved   or false
    self.failed   = data.failed   or false
    self.current  = data.current  or {}
    for i = 1, self.code_len do
        if not self.current[i] then self.current[i] = 0 end
    end
    return true
end

return MastermindBoard

local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

package.preload["gettext"] = function()
    return setmetatable({}, { __call = function(_, s) return s end })
end
package.path = DIR .. "common/?.lua;" .. DIR .. "?.lua;" .. package.path

describe("MastermindBoard", function()
    local Board

    setup(function()
        Board = require("board")
    end)


    local function newGame()
        math.randomseed(42)
        local b = Board:new()
        b:newGame()
        return b
    end

    describe("new game setup", function()
        it("creates a board with default settings", function()
            local b = Board:new()
            assert.are.equal(4, b.code_len)
            assert.are.equal(6, b.num_symbols)
            assert.are.equal(10, b.max_attempts)
            assert.is_true(b.allow_duplicates)
        end)

        it("honours custom options", function()
            local b = Board:new({ code_len = 5, num_symbols = 8, max_attempts = 12 })
            assert.are.equal(5, b.code_len)
            assert.are.equal(8, b.num_symbols)
            assert.are.equal(12, b.max_attempts)
        end)

        it("newGame generates a secret of the right length", function()
            local b = newGame()
            assert.are.equal(b.code_len, #b.secret)
        end)

        it("newGame resets guesses and state", function()
            local b = newGame()
            assert.are.equal(0, #b.guesses)
            assert.is_false(b.solved)
            assert.is_false(b.failed)
        end)

        it("without duplicates: all secret symbols are distinct across many seeds", function()
            local b = Board:new({ allow_duplicates = false, code_len = 4, num_symbols = 6 })
            local failures = 0
            for seed = 1, 30 do
                math.randomseed(seed)
                b:newGame()
                local seen = {}
                for _, v in ipairs(b.secret) do
                    if seen[v] then failures = failures + 1; break end
                    seen[v] = true
                end
            end
            assert.are.equal(0, failures,
                "no-duplicate mode produced duplicate symbols in at least one run")
        end)
    end)

    describe("setSlot", function()
        it("sets a position in the current guess", function()
            local b = newGame()
            assert.is_true(b:setSlot(1, 3))
            assert.are.equal(3, b.current[1])
        end)

        it("rejects out-of-range positions", function()
            local b = newGame()
            assert.is_false(b:setSlot(0, 1))
            assert.is_false(b:setSlot(b.code_len + 1, 1))
        end)

        it("returns false when game is over", function()
            local b = newGame()
            b.solved = true
            assert.is_false(b:setSlot(1, 1))
        end)
    end)

    describe("submitGuess", function()
        it("rejects an incomplete guess", function()
            local b = newGame()
            local ok, err = b:submitGuess()
            assert.is_false(ok)
            assert.are.equal("incomplete", err)
        end)

        it("scores a perfect guess as all blacks", function()
            local b = newGame()
            for i = 1, b.code_len do b:setSlot(i, b.secret[i]) end
            local ok, result = b:submitGuess()
            assert.is_true(ok)
            assert.are.equal(b.code_len, result.blacks)
            assert.are.equal(0,          result.whites)
            assert.is_true(b.solved)
        end)

        it("scores black and white pegs correctly", function()
            -- Fixed secret: use Board:new() and set secret directly
            local b = Board:new()
            b.secret  = {1, 2, 3, 4}
            b.guesses  = {}
            b.feedback = {}
            b.solved   = false
            b.failed   = false
            b.current  = {1, 3, 2, 5}   -- pos 1 exact, pos 2&3 swapped (whites)
            local ok, result = b:submitGuess()
            assert.is_true(ok)
            assert.are.equal(1, result.blacks)   -- position 1 exact
            assert.are.equal(2, result.whites)   -- 2 and 3 present but wrong pos
        end)

        it("scores all-wrong guess as 0 blacks 0 whites", function()
            local b = Board:new()
            b.secret  = {1, 2, 3, 4}
            b.guesses  = {}
            b.feedback = {}
            b.solved   = false
            b.failed   = false
            b.current  = {5, 6, 5, 6}
            local ok, result = b:submitGuess()
            assert.is_true(ok)
            assert.are.equal(0, result.blacks)
            assert.are.equal(0, result.whites)
        end)

        it("sets failed after max_attempts wrong guesses", function()
            local b = Board:new({ max_attempts = 3 })
            b:newGame()
            -- Build a wrong guess (all slots = symbol not in secret if possible)
            local wrong = {}
            for i = 1, b.code_len do wrong[i] = 0 end  -- 0 is never a valid symbol
            for attempt = 1, 3 do
                for i = 1, b.code_len do b:setSlot(i, (b.secret[1] % b.num_symbols) + 1) end
                -- Make sure it's wrong (unless secret is all same — extremely unlikely with seed 42)
                -- We just submit and don't check for solve here
                local ok, _ = b:submitGuess()
                assert.is_true(ok)
                if b.solved then break end
            end
            -- Either solved (perfect guess by coincidence) or failed
            assert.is_true(b:isGameOver())
        end)

        it("rejects submit when game is already over", function()
            local b = newGame()
            b.solved = true
            local ok, err = b:submitGuess()
            assert.is_false(ok)
            assert.are.equal("game over", err)
        end)

        it("clears current after a valid submit", function()
            local b = newGame()
            for i = 1, b.code_len do b:setSlot(i, b.secret[i]) end
            b:submitGuess()
            for i = 1, b.code_len do
                assert.are.equal(0, b.current[i])
            end
        end)
    end)

    describe("getAttempts", function()
        it("counts submitted guesses", function()
            local b = newGame()
            assert.are.equal(0, b:getAttempts())
            for i = 1, b.code_len do b:setSlot(i, 1) end
            b:submitGuess()
            assert.are.equal(1, b:getAttempts())
        end)
    end)

    describe("serialize / load", function()
        it("round-trips board state including partial guess", function()
            local b = Board:new()
            b.secret   = {1, 2, 3, 4}
            b.guesses  = {{1, 1, 1, 1}}
            b.feedback = {{blacks = 1, whites = 0}}
            b.current  = {2, 0, 0, 0}
            b.solved   = false
            b.failed   = false

            local data = b:serialize()
            local b2 = Board:new()
            local ok = b2:load(data)
            assert.is_true(ok)
            assert.are.same(b.secret,  b2.secret)
            assert.are.same(b.current, b2.current)
            assert.are.equal(1, #b2.guesses)
            assert.are.equal(1, b2.feedback[1].blacks)
        end)

        it("load returns false and starts new game for invalid data", function()
            local b = Board:new()
            local ok = b:load({})
            assert.is_false(ok)
            -- should have called newGame() as fallback
            assert.is_not_nil(b.secret)
        end)
    end)
end)

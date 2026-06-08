# mastermind.koplugin

A Mastermind plugin for [KOReader](https://github.com/koreader/koreader).

## Concept

Deduce the secret code — a sequence of coloured pegs (or digits) — in as few
guesses as possible. After each guess you receive feedback:

- **Black peg** — correct symbol in the correct position
- **White peg** — correct symbol in the wrong position

## Planned Features

- **Classic mode** — 4 positions, 6 colours/digits, 10 attempts
- **Configurable game** — 3–6 positions, 4–8 symbols, 6–12 attempts
- **Digits or symbols** — play with numbers (1–8) or abstract shapes
- **Duplicates toggle** — allow or forbid repeated symbols in the secret code
- **Auto-solve mode** — watch Knuth's minimax algorithm solve the board step by step
- **Hint** — narrow down remaining possibilities count shown after each guess
- **Statistics** — average solve length and best score
- **Auto-save** — in-progress game restored on next launch

## Controls

| Action | How |
|--------|-----|
| Place a symbol | Tap a position, then tap a symbol from the palette |
| Clear a position | Tap it again or tap **Erase** |
| Submit guess | Tap **Submit** (only enabled when all positions are filled) |
| New game | Tap **New game** |
| Change settings | Tap **Settings** |

## Why e-ink friendly?

Each guess is a discrete row submission with no animation needed.
Pegs can be rendered as filled/outlined circles or digits — no colour required.

## License

GPL-3.0

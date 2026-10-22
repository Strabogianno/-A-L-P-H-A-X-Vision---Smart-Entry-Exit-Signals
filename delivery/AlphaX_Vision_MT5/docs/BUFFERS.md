# Indicator buffers

`iCustom` / `CopyBuffer` indices. The two color-index buffers are included below; plot numbers are not buffer numbers.

| Buffer | Value |
|---:|---|
| 0 | Fast EMA, EMPTY_VALUE if hidden |
| 1 | Medium EMA, EMPTY_VALUE if hidden |
| 2 | Slow EMA, EMPTY_VALUE if hidden |
| 3 | Fusion Slow |
| 4 | Fusion Slow color index: 0 neutral, 1 bull, 2 bear |
| 5 | Fusion Fast |
| 6 | Fusion Fast color index: 0 neutral, 1 bull, 2 bear |
| 7 | Bull trend-label condition: 0/1 |
| 8 | Bear trend-label condition: 0/1 |
| 9 | Long entry: 0/1 |
| 10 | Short entry: 0/1 |
| 11 | Long exit: 0/1 |
| 12 | Short exit: 0/1 |
| 13 | Buy confidence, 0..100 |
| 14 | Sell confidence, 0..100 |
| 15 | Fast WPR |
| 16 | Slow WPR |
| 17 | Turtle WPR |
| 18 | Stored trend: -1 / 0 / +1 |
| 19 | Raw Fusion |
| 20 | Session VWAP |
| 21 | RSI(14) |
| 22 | EMA(7) of RSI |
| 23 | MACD(12,26) line |
| 24 | MACD signal EMA(9) |
| 25 | MACD histogram |
| 26 | Stochastic K(14) |
| 27 | SMA(3) of stochastic K |
| 28 | ATR(14), Wilder smoothing |
| 29 | Nine-factor bullish Fusion score |
| 30 | Nine-factor bearish Fusion score |
| 31 | Current Fusion condition: -1 / 0 / +1 |
| 32 | Stored entry flag: 0/1 |
| 33 | Pro EMA(50) |
| 34 | Pro EMA(200) |
| 35 | Selected volume / SMA(volume,20) |
| 36 | Bar-open time converted to UTC, UNIX seconds |
| 37 | VWAP session key, internal day number |

Shift 0 is the developing candle and can change. Shift 1 is the last closed candle. Missing continuous values use MT5 `EMPTY_VALUE`, never zero as a substitute. Signals use zero for false. Entries/exits are indicator events, not broker-position state.

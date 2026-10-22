# AlphaX Vision automated EA

Built for the requested **FP Markets EU → XAUUSD.cy → M1** setup. This EA embeds the existing AlphaX Vision calculation engine, so the indicator does not have to be installed for the EA to calculate signals.

**Delivery status:** native MQL5 source and compiled EA are supplied. Compilation and the isolated execution-rule checks are verified. A broker-connected Strategy Tester run, actual order execution and TradingView signal parity have not been verified. No orders were placed on an account during development.

## Install and start

1. In MT5, select **File → Open Data Folder → MQL5 → Experts**.
2. Create a folder called **AlphaX Vision EA** and put `AlphaX_Vision_EA.ex5` inside it. This compiled file is sufficient to run the EA.
3. Refresh **Navigator → Expert Advisors** and attach the EA to **XAUUSD.cy, M1**.
4. Open **Inputs → Load** and choose `EA_FP_Markets_EU_XAUUSDcy_M1_Published.set`.
5. Leave `InpEnableTrading=false` initially. The EA will calculate and show its status without submitting entry or exit orders.
6. Set a positive **InpStopLossPoints**. The initial value is deliberately **0**, because you have not specified a stop distance. All distances marked Points use the broker symbol's `SYMBOL_POINT`, not pips or a dollar risk amount. For example, *if* Point is 0.01, 100 points means a price distance of 1.00. Check the symbol's actual specification.
7. Run Strategy Tester and then a demo trial. To execute, set **InpEnableTrading=true** and enable the relevant MT5/EA algorithmic-trading permissions. Broker conditions and account permissions must allow the requested operation.

Real-account execution has a separate switch, **InpAllowRealAccount**, initially false. The delivered presets keep both execution switches false. No terminal-wide setting is changed automatically.

To edit/recompile, keep `AlphaX_Vision_EA.mq5`, `AlphaX_Vision_Core.mqh` and `AlphaX_Vision_TradePolicy.mqh` together in the EA folder. Open the EA `.mq5` in MetaEditor and compile. No DLL, external service, indicator handle or downloaded library is required.

## Automatic trade rules

| Event / condition | EA behavior |
|---|---|
| Confirmed long re-entry triangle | Buy if flat and entry controls permit |
| Confirmed short re-entry triangle | Sell if flat and entry controls permit |
| Trend label without a triangle | Sets context; does not open a trade |
| Long exit X | Close this EA's long position |
| Short exit X | Close this EA's short position |
| Opposite stored trend | Close the remaining position by default |
| Another entry triangle while a position is open | Ignore it; no adding or pyramiding |
| Stop loss | Requested at the broker with every entry |
| Owned position discovered without a broker stop | Request a protective close on ticks while execution is enabled |
| Failed signal close | Retain the close request and reconcile/retry on later ticks |

The EA processes **closed candles only**, executing at an available quote in the following candle. This is the timing you approved. It differs from the developing-candle visuals of the supplied Pine/MT5 indicator, which can change before close. Entry is skipped if the first processed quote arrives more than `InpMaxEntryDelaySeconds` into the new candle; the initial limit is 30 seconds.

Exits have priority. A tick that began with an owned position will not open a replacement position, even if it successfully closes that position and the same closed candle also contains a new entry signal. A later entry triangle is required. The EA does not force an entry merely because a trend flips.

## Starting configuration

- Fixed volume: **0.01 lots**. One position at a time.
- Stop mode: **fixed points**, requiring a positive distance supplied by you.
- Take-profit mode: **signal exits**. There is no fixed TP by default.
- Automatic exits: exit X and opposite trend enabled.
- Long and short trading enabled as directions, subject to the master execution switch.
- Spread filter: initially off (`InpMaxSpreadPoints=0`); set a positive limit to enable it.
- Broker clock: winter UTC+2 plus US DST, following the earlier documented New York-close inference. Exact server validation remains outstanding.
- Tick volume and broker-midnight VWAP remain initial feed choices, pending TradingView comparison.

The published Gold M1 calculation profile uses Fusion 40, EMAs 21/55/200, WPR 11/48/180, trend lookback 25, confidence 35%, strict trend gate enabled and cooldown 25. `EA_FP_Markets_EU_Original_Source.set` supplies the attached Pine file's original calculation defaults instead. Both EA presets include the same execution-off, 0.01-lot, stop-required starting controls. Use EA presets for the EA; the older indicator presets include visual-only options.

The signal engine is unchanged. In particular, the original divergence branch's incompatible pivot/freshness conditions and the original entry-state/exit behavior have not been repaired silently. No profitability or measured optimization claim is made by naming the published configuration.

## Optional controls

- **Equity-risk sizing:** `InpSizeMode=AXE_EQUITY_RISK` calculates volume from current equity, configured percentage and loss to the rounded stop using the broker's `OrderCalcProfit`. It rounds down and declines a trade below the broker's minimum lot size. The estimate excludes commission, slippage, gaps, swaps and changes between request and execution; it is not a guaranteed maximum loss.
- **ATR stop:** explicitly select `InpStopMode=AXE_STOP_ATR`. It uses closed-candle ATR(14) times the configurable multiplier. This mode is available but is not selected by the delivered presets.
- **Fixed TP / risk multiple:** select the target mode and supply its distance or multiplier. These remain alternatives to the default signal-only take-profit behavior.
- **Spread cap:** only new entries are filtered. High spread does not prevent an already-requested signal exit.
- **Date Filter:** follows the indicator for entries and X signals. Opposite-trend exits and broker protection remain active outside that range. Reaching End Date does not by itself force a close.
- **Initial history cap:** `InpHistoryBars=0` uses the available history. A positive cap changes initialization. After warm-up, subsequent closed bars are appended to the calculation state. Reinitialization/history changes can produce different results if the calculation dataset differs from TradingView.

Stops and targets are rounded to the symbol's actual price-tick grid and checked against current Bid/Ask and broker minimum stop distances. A too-close/invalid stop is **rejected**, not silently enlarged to make the order pass. Volume is rounded down; 0.01 lots is not raised automatically if the broker requires more. Broker order checks are made before submission and the resulting return code is inspected.

## Ownership, restart and uncertain submissions

The EA operates on its chart symbol and `InpMagicNumber`. Give another independent strategy a different magic number. A state file is held exclusively for the same account/server/symbol/magic, preventing another cooperating instance from sharing that identity across local terminals. Monitoring instances do not acquire a trading lock.

Foreign positions and existing orders on the same symbol block new entries. Hedging accounts permit ticket-specific closes of owned positions. On netting accounts, the EA checks the position's deal history and refuses to manage a position that contains another strategy's/manual trading activity, even if the current position magic matches. Avoid combining strategies or manual trades in the same netted symbol: a broker SL belongs to the whole net position and cannot isolate components.

The EA reconstructs its signal state from history after attachment/restart and does **not** replay the latest historical entry. Existing owned positions can still trigger management based on the latest closed state. Historical gaps are calculated for exit context; only the latest new closed candle can be considered for entry. Deeper/corrected history causes a rebuild with that retrospective entry suppressed.

The entry bar is recorded before submission. A timeout, connection ambiguity, accepted-but-not-confirmed request or missing result code latches **uncertain entry** and blocks further entries rather than resubmitting blindly. Check broker positions, orders and history before using `InpResetUncertainEntry=true` to clear it; set the recovery input back to false afterward. Ordinary rejected entries are not automatically retried from the same candle. Closing requests remain pending and are reconciled against currently owned tickets before retrying.

Live/demo state is stored under **Terminal → Common → Files**, as `AXVisionEA_<identity hash>.bin`. Do not delete or edit it while the EA is trading. Strategy Tester uses a clean local state for each pass. Changing the execution master switch to false stops **all EA-submitted orders, including signal closes**; already accepted broker SL/TP orders remain at the broker. Removing/stopping the EA does not close positions automatically.

## Validation and testing

See `docs/EA_VALIDATION.md` for the full record and its limits.

- EA and native policy-test programs compile without errors or warnings in MetaEditor build 6230.
- **9,058 source-shared execution-policy checks passed** in an installed .NET runtime. Only function modifiers and math-function names are mechanically adapted; the rule bodies and cases are shared with the MQL5 test program. This checks pure decisions/rounding/validation, not MT5 broker execution or the signal engine.
- The isolated MT5 Strategy Tester attempt returned **"tester not started because the account is not specified"**. No actual backtest was completed. No account login was attempted.
- TradingView parity remains unverified, including the exact TradingView provider corresponding to the user's gold chart.

For the first broker-connected test, select **AlphaX_Vision_EA**, **XAUUSD.cy**, **M1** and **Every tick based on real ticks** in an initialized MT5 Strategy Tester. Load the EA preset, set a test stop distance, and enable execution in the tester inputs. Confirm entries correspond to closed-candle triangles, X/opposite-trend closes occur, no duplicate positions appear, stop distances/lot sizes are accepted, and failed requests appear clearly in the journal. A financial-performance conclusion requires a separately designed evaluation; this build does not supply one.

The development/test harnesses contain no live order-submission calls. The trading functions exist only in the EA for use after the explicit execution switches and terminal permissions permit them.

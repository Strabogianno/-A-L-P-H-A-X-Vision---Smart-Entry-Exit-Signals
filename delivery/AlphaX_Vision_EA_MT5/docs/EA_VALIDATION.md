# AlphaX Vision EA validation — 22 October 2026

## Confirmed result

| Check | Result |
|---|---|
| Final EA compilation, FP Markets MetaEditor 5.0.0.6230, x64 regular | 0 errors, 0 warnings |
| Native MQL5 policy script compilation | 0 errors, 0 warnings |
| Native Strategy Tester policy harness compilation | 0 errors, 0 warnings |
| Source-shared pure execution-policy tests, installed .NET runtime | 9,058 passed, 0 failed |
| Two EA presets | All 58 declared inputs included; execution off, real permission off, fixed 0.01 lots, required stop distance 0 |
| Existing signal engine | Shared unchanged with the delivered indicator |

The pure tests cover entry direction and contradictory signals, one-position/foreign-position/pending-order/uncertain-result entry blocking, directional exit and trend-flip rules, required stop configuration, point and ATR distances, downward lot rounding, broker minimums, price tick grids, Bid/Ask stop restrictions, optional TP validation, signal freshness, and both documented successful `OrderCheck` return-code forms (0 and 10009). The generated .NET program executes the rule bodies from `AlphaX_Vision_TradePolicy.mqh`, with only function modifiers and built-in math names adapted. The same cases are included by `AlphaX_Vision_EA_PolicyTest.mq5`.

This is **not** execution of the compiled `.ex5`, a simulation of broker fills, a numerical test of the shared signal engine, a portfolio backtest, or a performance/profitability claim.

## Strategy Tester attempt

A no-order policy harness was launched through a separate portable MT5 instance, with no account credentials and no live order submission. The terminal reported:

> tester not started because the account is not specified

It then shut down without running the test. No account login was attempted. No successful broker-connected runtime or backtest result is inferred from this launch.

## Code review decisions

- Closed bars are calculated separately from the developing candle, implementing the timing explicitly approved by the user.
- The existing Pine-compatible signal engine is reused rather than duplicating its formulas in the EA.
- Initial attach/rebuild does not enter on an old triangle.
- Only the latest newly closed candle can enter; missed bars contribute exit context without replaying historical entries.
- A rolling history boundary moving forward retains cached state; deeper or corrected history causes a controlled rebuild and suppresses a retrospective entry.
- A tick that started with an owned position does not also open a replacement position after closing it.
- Symbol and magic identify owned positions; netting ownership also examines deal history. Mixed positions are not managed as if they belonged exclusively to this EA.
- An exclusive persistent state file blocks cooperating duplicate trading instances with the same account/server/symbol/magic. Strategy Tester passes start with clean local state.
- Before an entry is submitted, its bar and an uncertainty latch are saved. Ambiguous results lock further entries pending manual reconciliation. Definite rejections are not blindly retried.
- Exits remain pending until currently owned positions disappear; retries use current tickets/volumes.
- Every entry requires an explicit stop configuration, includes the broker SL in the order request, and passes price/lot/broker order checks. A discovered owned position without a stop triggers a protective close request on ticks while execution is permitted.
- Spread, date and size filters do not block a pending close. The master switch and account/terminal execution permissions do block all EA-submitted orders.

## Outstanding acceptance tests

1. Load the EA on the broker's demo XAUUSD.cy/M1 chart and verify status, input handling and required-stop behavior.
2. Run the native policy script/harness in an initialized MT5 environment.
3. Run the EA in Strategy Tester with real ticks, execution enabled in tester inputs and a deliberately specified test stop distance.
4. Verify broker-specific market fill modes, minimum stop distance, SL/TP attachment, point/tick/lot units and margin checks.
5. Exercise order rejection, partial fills, disconnects, timeout recovery, restart, duplicate instance and mixed netting ownership behavior.
6. Compare the closed-bar engine signals with the indicator and matching TradingView exports. The exact TradingView provider remains unconfirmed.

The delivered EA has not been installed onto a user's trading chart, enabled on an account, or used to submit account orders during this work.

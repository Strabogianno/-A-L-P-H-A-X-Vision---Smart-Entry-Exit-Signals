# Validation record — 22 October 2026

## Passed

- Indicator: MetaEditor 5.0.0.6230, x64 regular target, **0 errors and 0 warnings**. Full final log: `build/compile.log`.
- Validation script: same compiler and target, **0 errors and 0 warnings**. Full final log: `build/validation_compile.log`.
- CSV comparison utility: **9 tests passed** with Python 3.11. Tests cover exact signal comparisons, input volume differences, missing diagnostics, ISO/millisecond timestamps, duplicate timestamps, non-overlapping ranges, timezone ambiguity, and missing-versus-numeric values.
- The preserved Pine source has the same SHA-256 hash as the user-supplied text file: `8C86246FD7C31CD19BB5DC04C7B31DB026A3F11A47789789B51BBFBD2811FB41`.

## Not verified

- Actual MQL5 runtime execution, chart appearance, live updates, terminal notifications and CPU/memory behavior on a loaded chart.
- Pine compilation of the diagnostic copy in TradingView.
- Numeric or signal parity against TradingView.
- A particular broker's UTC/DST policy, volume type, session anchor or data feed.

## Broker and settings follow-up

The user subsequently specified FP Markets EU and `XAUUSD.cy` on M1, with the publication's Gold settings: confidence 35%, WPR 11/48/180, strict trend gate enabled and cooldown 25. A separate published-settings preset and an original-source preset were added. Their input names and key values were checked against the MQL5 input declarations; the compiled indicator was not changed. The exact TradingView provider remains unknown. This configuration check is not a runtime or signal-parity test.

## Runtime attempt

A separate portable terminal was launched with live trading and DLL import disabled and no account credentials. It reported successfully loading `AlphaX_Validation` but produced no script execution log or output. A minimal script that only prints a message and writes a text file was then tried in the same instance; it also loaded without executing. That isolates the observed startup issue from the indicator's calculation code, but does not establish its underlying cause.

The computer-use skill was used to try to inspect the isolated window. Capture failed first with `FrameArrived timed out: timed out waiting on channel`, then on recovery with `window capture timed out: timed out waiting on channel`. No chart was visually inspected. The separate terminal was stopped after the attempts. The user's other terminal was not stopped or modified.

There is no runtime pass, runtime failure count or screenshot from these attempts. The numerical regression harness is supplied for later execution in an initialized MT5 terminal.

## Next acceptance checks

1. Load the compiled indicator on a demo chart and inspect rendering while scrolling, zooming and resizing.
2. Run the MQL5 validation script from an initialized terminal. It creates its own synthetic custom symbol and does not submit broker orders.
3. Compile the diagnostic Pine copy and export matching historical data from both platforms.
4. Resolve any input/session/history differences before evaluating calculation differences.
5. Require exact agreement in all six closed-bar event flags and trend state over the agreed test period; inspect continuous values with the comparator's explicit tolerances.
6. Observe both charts through live candles to check temporary marker rollback and the chosen alert policy. A historical OHLCV comparison does not validate matching tick sequences.

This record deliberately separates successful compilation and comparison-tool tests from unperformed indicator runtime and cross-platform checks.

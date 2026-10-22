# AlphaX Vision for MetaTrader 5

Native MQL5 conversion of the Pine v6 source supplied by AlphaX on 22 October 2026.

**Status: implementation complete and compilation verified. MT5 runtime, visual matching and TradingView parity remain unverified.** Do the first chart checks on a demo account.

## Install

1. In the MT5 terminal you intend to use, select **File → Open Data Folder**.
2. Open **MQL5 → Indicators** and create a folder named **AlphaX Vision**.
3. Copy **AlphaX_Vision.ex5** into that folder. This is the ready-compiled indicator; no additional library or DLL is required.
4. In MT5, refresh **Navigator → Indicators** and attach **AlphaX Vision → AlphaX_Vision** to a chart.
5. Set the data-alignment options below before comparing signals with TradingView.

**FP Markets EU:** a partial time preset is included as `FP_Markets_EU_Time_Alignment.set`. Load it from the indicator's **Inputs → Load** button after resetting inputs to the supplied Pine defaults. See `docs/FP_MARKETS_EU.md` for its documented basis and the remaining feed/session checks. This does not change the generic binary's defaults.

**Confirmed target: XAUUSD.cy on M1.** For the published Gold M1 settings supplied in the follow-up message, load `FP_Markets_EU_XAUUSDcy_M1_Published.set`. It sets confidence to 35%, WPR to 11/48/180, strict trend gate on, cooldown 25, Fusion length 40, displayed slow EMA 200 and trend lookback 25. The last three values follow the publication's settings reference. For the originally attached Pine defaults, use `FP_Markets_EU_Original_Source.set`. Both include the FP Markets clock settings. Select the symbol/timeframe on the chart manually. The TradingView provider and cross-platform parity remain unconfirmed.

To edit or rebuild the source, put **AlphaX_Vision.mq5**, **AlphaX_Vision_Core.mqh**, and **AlphaX_Vision_Render.mqh** together in that same folder, then open the `.mq5` in MetaEditor and compile. The graphics code uses MT5's standard Canvas library.

This is a chart indicator. It does not place or manage broker orders.

## Match the TradingView chart

Use the same instrument/feed, standard candle type, timeframe, settings and calculation history wherever possible. A similarly named symbol from a different broker does not establish matching data.

### Broker server time

The original signal scoring uses fixed UTC hours. The dates also refer to UTC.

- **InpBrokerClock = AX_FIXED_OFFSET:** subtract `InpWinterUtcOffsetMinutes` from every broker timestamp, year round. Despite its name, the offset field is the actual fixed offset in this mode.
- **AX_EU_DST:** the configured winter offset plus one hour between the EU DST transition instants.
- **AX_US_DST:** the configured winter offset plus one hour between the US DST transition instants.

The initial configuration is **fixed UTC+02:00**, an explicit placeholder, not an automatically detected broker setting. If your broker uses UTC+03:00 year round, use 180. If it switches between UTC+02:00 and UTC+03:00, choose its actual historical DST policy with a winter offset of 120. Ask the broker for its policy if uncertain. US DST calculations use the rules introduced in 2007; older history needs separate handling. The repeated hour in a broker clock moving backward cannot be uniquely resolved from a naive server timestamp alone.

Changing chart display time in TradingView does not change the Pine script's explicit UTC session windows.

### VWAP reset

The original uses session VWAP of `(high + low + close) / 3`.

- **AX_BROKER_MIDNIGHT**, the initial choice: reset when the broker bar timestamp moves into a different calendar date.
- **AX_UTC_SESSION:** reset at the selected UTC hour and minute, with a fixed UTC boundary throughout the year.
- **AX_NEW_YORK_1700:** reset at 17:00 New York local time, using US DST rules.

Choose the reset that matches the TradingView symbol's actual trading session. These options cover common intraday feeds; split sessions, unusual exchange calendars or another boundary require additional configuration/code. Broker midnight is not a universal definition of TradingView's session.

### Volume

Select **AX_TICK_VOLUME** or **AX_REAL_VOLUME** explicitly. Tick volume is the initial choice. Real volume is often unavailable on OTC symbols. The indicator does not silently substitute tick volume for real volume. With no volume for a whole session, VWAP is unavailable and the Fusion engine may have no valid input. Different volume changes both VWAP and confidence scoring even if prices match.

### Calculation history

`InpCalculationStartUTC = 0` uses all history provided to the indicator. Set an explicit UTC start to reproduce a known TradingView calculation start. This setting resets the calculation dataset; it is separate from the original Date Filter, which only gates entry and exit signals.

Matching only the visible chart range is insufficient: EMA initialization and the stored trend/entry state depend on earlier bars. Pine's `max_bars_back=500` is a history-reference buffer setting, not a request to process only 500 candles. The MT5 port therefore processes the available dataset.

## Preserved behavior

All original input defaults are taken from the attached source, including Fusion length **122**, EMAs **21 / 55 / 120**, WPR **21 / 55 / 120**, and confidence **14%**. The website's different defaults have not been substituted.

- The current candle recalculates on each data update. A condition or marker can disappear before close. Each recalculation starts from the previous candle's state, reproducing Pine's rollback principle.
- Divergence retains the original five-bar pivot confirmation and incompatible three-bar freshness limit. Consequently this branch cannot trigger. It has not been repaired silently.
- Exits do not clear the entry flag. Repeated exits can therefore occur without a new intervening entry in the same trend.
- A new trend label resets the entry flag, including repeated same-direction labels after a neutral interval.
- A trend flip does not automatically generate a separate exit marker for the prior trend.
- The stored trend persists through neutral Fusion bars. Entry/exit logic is based on that stored trend; there is no extra automatic neutral-market veto.
- The cooldown limits repeated labels in the same direction; an opposite-direction label is not subject to that same cooldown delay.
- Trend labels are not restricted by the Date Filter.
- The nine-factor Fusion scores are calculated and exposed for checking, but do not gate the trend labels or Pro signals in the supplied source.
- All WPR periods run on the current chart timeframe. There are no higher-timeframe data requests in the supplied source.

## Appearance

Two native colored Fusion lines, the two line-style EMAs, Fast EMA crosses, five gradient bands plus the main cloud, trend labels, entry triangles, exit crosses and dotted connectors are implemented. Clouds and markers use two transparent bitmap canvases. The renderer retains a shared 500-label budget and approximately 50 connector lines, following the original declarations/defaults.

Font metrics, automatic label spacing, signal-symbol geometry, antialiasing, fill interpolation and chart layering can differ from TradingView. The visual implementation has compiled but has not yet been inspected on a running MT5 chart. Signal markers do not automatically expand the MT5 price scale; add chart margin or adjust the scale if ATR-offset markers fall outside the visible price range. The original label-size mapping is preserved in relative order: `tiny` → normal, `small` → large, `normal` → huge.

## Alerts

All six signal conditions are available independently. Popup, push and email delivery are initially **off**, avoiding unexpected notifications on installation. Enable the channels you want. Push/email also require the terminal's own messaging setup.

**InpAlertAtBarClose** initially delivers alerts from the most recently closed bar. Set it false for live-bar alerts, once per condition per candle. This affects delivery only; the chart itself continues recalculating live. Attaching/reinitializing the indicator does not replay historical alerts. An intrabar notification cannot be recalled if its marker later disappears.

## Compare with TradingView

1. Add `validation/AlphaX_Vision_TradingView_Diagnostics.pine` to your own TradingView Pine Editor and chart. It contains the unchanged original script followed by 34 diagnostic plots. This file has not been compiled in TradingView yet.
2. Confirm that its input settings match the MT5 indicator.
3. Export TradingView chart data with the diagnostic plots included. Use UTC UNIX timestamps if offered; ISO timestamps must include their UTC offset. Export just one instance of the diagnostic indicator.
4. In MT5, enable **InpExportCsv**. The filename must be unique per chart. Its default is `AlphaX_Vision_comparison.csv`, written under **File → Open Data Folder → MQL5 → Files**. It exports closed candles, the actual selected volume, and 34 diagnostic values. Initialization or a history rebuild recreates this file.
5. Run:

```text
python validation/compare_exports.py tradingview.csv AlphaX_Vision_comparison.csv --report comparison.json
```

The report checks matching timestamps, OHLCV, all six signal flags, confidence scores, trend state and intermediate calculations. Flags and discrete states require exact equality; continuous values use explicit floating-point tolerances. Missing columns, data differences and sample mismatches are reported. Non-overlapping timestamps are counted separately; a pass covers only the overlapping range. Do not use a warm-up cutoff to hide recurring signal/state differences.

TradingView exports may round values. If that prevents a useful numeric comparison, increase the export precision in the diagnostic copy and repeat. Matching exported bar closes does not validate intrabar tick sequences or alert delivery.

## Validation status

- MetaEditor 5 build 6230: indicator compiled with **0 errors / 0 warnings**.
- The MQL5 validation script also compiled with **0 errors / 0 warnings**.
- The comparison utility has automated tests; see `docs/VALIDATION.md` for the recorded result.
- A separate portable MT5 instance was created without account credentials or order access. It loaded both the validation script and an independent minimal startup probe but did not execute either. No runtime assertions, screenshots or numerical parity claims are inferred from that launch.
- The test-window capture attempts returned `FrameArrived timed out` / `window capture timed out`. No visual inspection was possible.
- A genuine TradingView-versus-MT5 comparison still needs matching exported datasets.

The package includes `validation/AlphaX_Validation.mq5` for a terminal that can execute scripts. Its checks cover a 6,000-bar fixture, settings variants, date boundaries, current-bar rollback, dataset-start isolation, clock rules, indicator buffers and a chart screenshot. It creates a custom symbol named `AXVISION_TEST` and an offline chart; it contains no order-placement code. It has **not passed or failed its runtime assertions yet**.

## Reference

Original publication: https://www.tradingview.com/script/WBUG3lyw-A-L-P-H-A-X-Vision-Smart-Entry-Exit-Signals/

Original supplied source is preserved as `source/AlphaX_Vision_Original.pine`.

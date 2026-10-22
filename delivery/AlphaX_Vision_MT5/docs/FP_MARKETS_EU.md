# FP Markets EU configuration

The user identified FP Markets EU, the MT5 instrument **XAUUSD.cy**, and the **1-minute (M1)** timeframe. The exact account server and the TradingView provider/feed remain unconfirmed. The MT5 symbol suffix does not establish which TradingView provider is being used.

## Gold M1 presets

Open **XAUUSD.cy → M1** in MT5, open the indicator properties and select **Inputs → Load**. A `.set` file changes indicator inputs; it does not select the chart symbol or timeframe.

Choose one of these calculation presets:

| Setting | `FP_Markets_EU_XAUUSDcy_M1_Published.set` | `FP_Markets_EU_Original_Source.set` |
|---|---:|---:|
| Fusion length | 40 | 122 |
| Displayed EMA periods | 21 / 55 / 200 | 21 / 55 / 120 |
| WPR periods | 11 / 48 / 180 | 21 / 55 / 120 |
| Trend-detection lookback | 25 | 20 |
| Minimum confidence | 35% | 14% |
| Trend gate / strict mode | Enabled / enabled | Enabled / enabled |
| Label cooldown | 25 bars | 25 bars |

The published preset follows the user's Gold M1 settings message and the previously reviewed publication's settings reference. Fusion length 40, displayed slow EMA 200 and trend-detection lookback 25 come from that publication. They are identified explicitly because they differ from the attached source.

Both presets set the remaining calculation controls back to the supplied source values, disable its optional Date Filter, and include the FP Markets clock settings explained below. Tick volume and broker-midnight VWAP remain initial choices awaiting comparison with the actual TradingView feed. These are settings profiles, not changes to the algorithm or claims of measured optimization/performance. Alert delivery choices and theme colors are retained.

The supplied Pine code continues to recalculate on the open candle. The description's claim that all signals are confirmed at candle close is not implemented by that source. The presets do not add a confirmation gate or change the preserved divergence/exit behavior. Candle-close alert delivery is separately controlled by `InpAlertAtBarClose`.

## Load the time preset

1. Open the AlphaX Vision indicator properties in MT5.
2. Select **Inputs → Load**.
3. Select `FP_Markets_EU_Time_Alignment.set` from this package.
4. Confirm `InpBrokerClock = AX_US_DST` and `InpWinterUtcOffsetMinutes = 120`.

This is a partial preset. It changes only the two broker-clock inputs; your other indicator settings remain as configured. To reproduce the supplied Pine defaults, reset the indicator inputs first, then load this time preset.

FP Markets' official FAQ documents GMT+2/GMT+3 server time to follow New York close:

https://www.fpmarkets.com/en-au/education/faq/

The choice of **US DST** follows from that New York-close alignment. It is an inference from the broker documentation and has not been verified against this user's exact EU account server or historical data. The EU regulatory entity is not itself evidence that the server follows European DST dates.

The preset therefore uses UTC+02:00 in US winter and UTC+03:00 in US summer. The code applies the corresponding offset separately to each historical bar. US and European DST transitions differ, so selecting EU DST simply because the account is European can misalign the session confidence calculations during the intervening weeks.

## Settings still awaiting the TradingView chart

- Exact TradingView symbol including provider/exchange prefix, such as `OANDA:XAUUSD`. `XAUUSD.cy` is the confirmed MT5 symbol only.
- TradingView candle type (standard candles are the comparison baseline).
- VWAP session boundary used by that TradingView symbol.
- Whether the TradingView volume series matches the broker's tick volume or actual trade volume.

This preset does not alter VWAP or volume inputs. Broker clock alignment alone does not establish identical signals across different feeds. The original indicator logic and compiled binary are unchanged. Runtime and cross-platform validation remain open as recorded in `VALIDATION.md`.

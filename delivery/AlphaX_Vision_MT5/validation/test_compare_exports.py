import csv
import tempfile
import unittest
from pathlib import Path
from compare_exports import compare, read_csv, DIAGNOSTICS


COLUMNS = ["time", "open", "high", "low", "close", "volume", "AX_FusionSlow", "AX_FusionFast",
           "AX_BuyConfidence", "AX_SellConfidence", "AX_TrendBull", "AX_TrendBear", "AX_LongEntry",
           "AX_ShortEntry", "AX_LongExit", "AX_ShortExit", "AX_RSI"]
EXTRA_COLUMNS = sorted(DIAGNOSTICS - set(COLUMNS))
COLUMNS += EXTRA_COLUMNS


class ExportComparisonTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.a, self.b = self.root / "tv.csv", self.root / "mt.csv"
        self.rows = [[1792627200, 100, 102, 99, 101, 1000, 100.5, 100.8, 50, 25, 1, 0, 1, 0, 0, 0, ""],
                     [1792627260, 101, 103, 100, 102, 1200, 100.7, 101.1, 55, 20, 0, 0, 0, 0, 0, 0, 60]]
        for row in self.rows:
            row.extend([0] * len(EXTRA_COLUMNS))
        self.write(self.a)
        self.write(self.b)

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, path, rows=None, columns=None):
        with path.open("w", encoding="utf-8", newline="") as stream:
            writer = csv.writer(stream)
            writer.writerow(columns or COLUMNS)
            writer.writerows(self.rows if rows is None else rows)

    def test_matching_data_and_missing_numeric_values(self):
        result = compare(self.a, self.b)
        self.assertTrue(result["passed"])
        self.assertEqual(result["matched_bars"], 2)

    def test_signal_difference_is_exact(self):
        rows = [row.copy() for row in self.rows]
        rows[0][12] = 1.00000000001
        self.write(self.a, rows)
        result = compare(self.a, self.b)
        self.assertFalse(result["passed"])
        self.assertEqual(result["first_mismatches"][0]["column"], "AX_LongEntry")

    def test_input_difference_reported(self):
        rows = [row.copy() for row in self.rows]
        rows[1][5] += 1
        self.write(self.a, rows)
        self.assertEqual(compare(self.a, self.b)["input_data_mismatches"], 1)

    def test_missing_diagnostic_rejected(self):
        idx = COLUMNS.index("AX_RSI")
        columns = [column for column in COLUMNS if column != "AX_RSI"]
        self.write(self.a, [row[:idx] + row[idx+1:] for row in self.rows], columns)
        self.assertIn("AX_RSI", compare(self.a, self.b)["missing_columns"])

    def test_iso_and_millisecond_timestamps(self):
        rows = [row.copy() for row in self.rows]
        rows[0][0] = "2026-10-22T00:00:00+00:00"
        rows[1][0] *= 1000
        # The numeric fixture's timestamp is deliberately used to form the ISO value.
        import datetime as dt
        rows[0][0] = dt.datetime.fromtimestamp(self.rows[0][0], dt.timezone.utc).isoformat()
        self.write(self.a, rows)
        self.assertTrue(compare(self.a, self.b)["passed"])

    def test_duplicate_timestamps_rejected(self):
        self.write(self.a, [self.rows[0], self.rows[0]])
        with self.assertRaisesRegex(ValueError, "duplicate timestamp"):
            read_csv(self.a)

    def test_no_overlap_does_not_pass(self):
        rows = [row.copy() for row in self.rows]
        for row in rows:
            row[0] += 86400
        self.write(self.a, rows)
        self.assertFalse(compare(self.a, self.b)["passed"])

    def test_naive_iso_rejected(self):
        rows = [row.copy() for row in self.rows]
        rows[0][0] = "2026-10-22T00:00:00"
        self.write(self.a, rows)
        with self.assertRaisesRegex(ValueError, "UTC offset"):
            read_csv(self.a)

    def test_blank_and_numeric_mismatch(self):
        rows = [row.copy() for row in self.rows]
        rows[0][COLUMNS.index("AX_RSI")] = 0
        self.write(self.a, rows)
        self.assertFalse(compare(self.a, self.b)["passed"])


if __name__ == "__main__":
    unittest.main()

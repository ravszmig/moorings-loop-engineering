package com.example.stays.rates;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.time.Month;
import org.junit.jupiter.api.Test;

class RateTableTest {

  private final RateTable table = RateTable.load();

  @Test
  void peakMonthsCost3000Pence() {
    for (Month month : new Month[] {Month.JANUARY, Month.JUNE, Month.SEPTEMBER, Month.DECEMBER}) {
      assertEquals(new NightlyRate(month, "peak", 3000), table.rateFor(month));
    }
  }

  @Test
  void shoulderMonthsCost80PercentOfPeak() {
    for (Month month : new Month[] {Month.APRIL, Month.MAY, Month.OCTOBER}) {
      assertEquals(new NightlyRate(month, "shoulder", 2400), table.rateFor(month));
    }
  }

  @Test
  void tableMissingAMonthIsRejected() {
    String oneMonth = "{\"month\": \"JANUARY\", \"season\": \"peak\", \"nightlyPence\": 3000}";
    assertThrows(IllegalStateException.class, () -> RateTable.parse(oneMonth));
  }
}

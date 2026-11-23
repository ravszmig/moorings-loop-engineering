package com.example.stays.pricing;

import static org.junit.jupiter.api.Assertions.assertEquals;

import com.example.stays.rates.RateTable;
import java.time.LocalDate;
import org.junit.jupiter.api.Test;

/** M-101: each night is priced by its own date, not by the arrival date. */
class ShoulderSeasonAcceptanceTest {

  private final StayPricer pricer = new StayPricer(RateTable.load());

  @Test
  void stayFromShoulderIntoPeakPricesEachNightBySeason() {
    // 30 May and 31 May are shoulder (2400p), 1 June is peak (3000p), 2 June is departure.
    assertEquals(7800, pricer.quotePence(LocalDate.of(2026, 5, 30), LocalDate.of(2026, 6, 2)));
  }

  @Test
  void stayFromPeakIntoShoulderPricesEachNightBySeason() {
    // 30 September is peak (3000p), 1 October is shoulder (2400p), 2 October is departure.
    assertEquals(5400, pricer.quotePence(LocalDate.of(2026, 9, 30), LocalDate.of(2026, 10, 2)));
  }
}

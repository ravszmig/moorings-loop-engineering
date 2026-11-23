package com.example.stays.pricing;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.example.stays.rates.RateTable;
import java.time.LocalDate;
import org.junit.jupiter.api.Test;

class StayPricerTest {

  private final StayPricer pricer = new StayPricer(RateTable.load());

  @Test
  void peakStayChargesPeakRateEachNight() {
    assertEquals(9000, pricer.quotePence(LocalDate.of(2026, 6, 10), LocalDate.of(2026, 6, 13)));
  }

  @Test
  void mayStayChargesShoulderRateEachNight() {
    assertEquals(4800, pricer.quotePence(LocalDate.of(2026, 5, 10), LocalDate.of(2026, 5, 12)));
  }

  @Test
  void octoberIsShoulderSeason() {
    assertEquals(2400, pricer.quotePence(LocalDate.of(2026, 10, 5), LocalDate.of(2026, 10, 6)));
  }

  @Test
  void departureDateIsNotCharged() {
    assertEquals(3000, pricer.quotePence(LocalDate.of(2026, 6, 1), LocalDate.of(2026, 6, 2)));
  }

  @Test
  void lastNightOfShoulderMonthIsShoulder() {
    assertEquals(2400, pricer.quotePence(LocalDate.of(2026, 5, 31), LocalDate.of(2026, 6, 1)));
  }

  @Test
  void stayAcrossTwoPeakMonthsStaysPeak() {
    assertEquals(6000, pricer.quotePence(LocalDate.of(2026, 6, 30), LocalDate.of(2026, 7, 2)));
  }

  @Test
  void leapDayIsANight() {
    assertEquals(6000, pricer.quotePence(LocalDate.of(2028, 2, 28), LocalDate.of(2028, 3, 1)));
  }

  @Test
  void sameDayDepartureIsRejected() {
    LocalDate day = LocalDate.of(2026, 6, 1);
    assertThrows(IllegalArgumentException.class, () -> pricer.quotePence(day, day));
  }

  @Test
  void departureBeforeArrivalIsRejected() {
    assertThrows(IllegalArgumentException.class,
        () -> pricer.quotePence(LocalDate.of(2026, 6, 2), LocalDate.of(2026, 6, 1)));
  }
}

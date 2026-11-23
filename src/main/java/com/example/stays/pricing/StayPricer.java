package com.example.stays.pricing;

import com.example.stays.rates.RateTable;
import java.time.LocalDate;

/** Prices a stay night by night. The departure date is not a night of the stay. */
public final class StayPricer {

  private final RateTable rates;

  public StayPricer(RateTable rates) {
    this.rates = rates;
  }

  public long quotePence(LocalDate arrival, LocalDate departure) {
    if (!departure.isAfter(arrival)) {
      throw new IllegalArgumentException("Departure must be after arrival");
    }
    long total = 0;
    for (LocalDate night = arrival; night.isBefore(departure); night = night.plusDays(1)) {
      total += rates.rateFor(arrival.getMonth()).nightlyPence();
    }
    return total;
  }
}

package com.example.stays.rates;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.time.Month;
import java.util.EnumMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Nightly rates read from the generated {@code generated/rates.json} on the classpath. */
public final class RateTable {

  static final String RESOURCE = "/generated/rates.json";

  // The file is written only by RatesGenerator, so its one-row-per-month layout is fixed.
  // A JSON library would be a dependency for a twelve-line file.
  private static final Pattern ROW = Pattern.compile(
      "\\{\"month\": \"([A-Z]+)\", \"season\": \"([a-z]+)\", \"nightlyPence\": (\\d+)}");

  private final Map<Month, NightlyRate> rates;

  private RateTable(Map<Month, NightlyRate> rates) {
    this.rates = rates;
  }

  public static RateTable load() {
    try (InputStream in = RateTable.class.getResourceAsStream(RESOURCE)) {
      if (in == null) {
        throw new IllegalStateException("Missing classpath resource " + RESOURCE);
      }
      return parse(new String(in.readAllBytes(), StandardCharsets.UTF_8));
    } catch (IOException e) {
      throw new UncheckedIOException(e);
    }
  }

  public static RateTable parse(String json) {
    Map<Month, NightlyRate> rates = new EnumMap<>(Month.class);
    Matcher row = ROW.matcher(json);
    while (row.find()) {
      Month month = Month.valueOf(row.group(1));
      rates.put(month, new NightlyRate(month, row.group(2), Long.parseLong(row.group(3))));
    }
    if (rates.size() != Month.values().length) {
      throw new IllegalStateException("Rate table must cover all 12 months, found " + rates.size());
    }
    return new RateTable(rates);
  }

  public NightlyRate rateFor(Month month) {
    return rates.get(month);
  }
}

package com.example.stays.rates;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import org.junit.jupiter.api.Test;

class GeneratedRatesTest {

  private static final Path SOURCE = Path.of("rates/rates.csv");
  private static final Path GENERATED = Path.of("src/main/resources/generated/rates.json");

  @Test
  void committedJsonMatchesTheSource() throws IOException {
    String expected = RatesGenerator.render(Files.readAllLines(SOURCE, StandardCharsets.UTF_8));
    assertEquals(expected, Files.readString(GENERATED, StandardCharsets.UTF_8),
        "Run node scripts/generate-rates.mjs after editing rates/rates.csv");
  }

  @Test
  void monthInTwoSeasonsIsRejected() {
    List<String> csv = List.of(RatesGenerator.HEADER,
        "peak,3000,JANUARY FEBRUARY MARCH JUNE JULY AUGUST SEPTEMBER NOVEMBER DECEMBER MAY",
        "shoulder,2400,APRIL MAY OCTOBER");
    assertThrows(IllegalArgumentException.class, () -> RatesGenerator.render(csv));
  }

  @Test
  void monthWithNoSeasonIsRejected() {
    List<String> csv = List.of(RatesGenerator.HEADER, "shoulder,2400,APRIL MAY OCTOBER");
    assertThrows(IllegalArgumentException.class, () -> RatesGenerator.render(csv));
  }
}

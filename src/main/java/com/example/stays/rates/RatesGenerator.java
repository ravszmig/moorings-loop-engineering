package com.example.stays.rates;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Month;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;

/**
 * Turns {@code rates/rates.csv} into {@code src/main/resources/generated/rates.json}.
 * The output depends only on the CSV, so a regenerated file is byte-for-byte comparable.
 */
public final class RatesGenerator {

  static final String HEADER = "season,nightly_pence,months";

  private RatesGenerator() {
  }

  public static String render(List<String> csvLines) {
    if (csvLines.isEmpty() || !csvLines.get(0).equals(HEADER)) {
      throw new IllegalArgumentException("First line must be: " + HEADER);
    }
    Map<Month, NightlyRate> byMonth = new EnumMap<>(Month.class);
    for (String line : csvLines.subList(1, csvLines.size())) {
      if (line.isBlank()) {
        continue;
      }
      String[] cells = line.split(",", -1);
      if (cells.length != 3) {
        throw new IllegalArgumentException("Expected 3 columns: " + line);
      }
      String season = cells[0].strip();
      long pence = Long.parseLong(cells[1].strip());
      if (!season.matches("[a-z]+") || pence <= 0) {
        throw new IllegalArgumentException("Bad season or price: " + line);
      }
      for (String name : cells[2].strip().split(" +")) {
        Month month = Month.valueOf(name);
        if (byMonth.put(month, new NightlyRate(month, season, pence)) != null) {
          throw new IllegalArgumentException("Month listed twice: " + month);
        }
      }
    }
    if (byMonth.size() != Month.values().length) {
      throw new IllegalArgumentException("Every month needs exactly one season");
    }
    StringBuilder json = new StringBuilder()
        .append("{\n")
        .append("  \"generatedFrom\": \"rates/rates.csv\",\n")
        .append("  \"regenerate\": \"node scripts/generate-rates.mjs\",\n")
        .append("  \"months\": [\n");
    for (NightlyRate rate : byMonth.values()) {
      json.append("    {\"month\": \"").append(rate.month())
          .append("\", \"season\": \"").append(rate.season())
          .append("\", \"nightlyPence\": ").append(rate.nightlyPence())
          .append(rate.month() == Month.DECEMBER ? "}\n" : "},\n");
    }
    return json.append("  ]\n}\n").toString();
  }

  /** {@code <csv> <json>} writes the JSON; {@code --check <csv> <json>} exits 1 if it is stale. */
  public static void main(String[] args) throws IOException {
    boolean check = args.length == 3 && args[0].equals("--check");
    if (args.length != (check ? 3 : 2)) {
      System.err.println("usage: RatesGenerator [--check] <rates.csv> <rates.json>");
      System.exit(2);
    }
    Path csv = Path.of(args[check ? 1 : 0]);
    Path json = Path.of(args[check ? 2 : 1]);
    String rendered = render(Files.readAllLines(csv, StandardCharsets.UTF_8));
    if (!check) {
      Files.writeString(json, rendered, StandardCharsets.UTF_8);
      return;
    }
    if (!Files.exists(json) || !Files.readString(json, StandardCharsets.UTF_8).equals(rendered)) {
      System.err.println(json + " is stale. Run node scripts/generate-rates.mjs.");
      System.exit(1);
    }
    System.out.println(json + " matches " + csv);
  }
}

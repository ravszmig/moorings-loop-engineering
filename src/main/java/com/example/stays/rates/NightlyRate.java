package com.example.stays.rates;

import java.time.Month;

public record NightlyRate(Month month, String season, long nightlyPence) {
}

package com.example.stays.booking;

public sealed interface BookingResult {

  record Accepted(Booking booking) implements BookingResult {
  }

  record Rejected(String reason) implements BookingResult {
  }
}

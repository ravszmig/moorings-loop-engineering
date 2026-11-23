package com.example.stays.booking;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

/** In-memory bookings, per room, in the order they were accepted. */
public final class RoomCalendar {

  private final List<Booking> bookings = new ArrayList<>();

  public BookingResult book(String room, LocalDate arrival, LocalDate departure) {
    if (room == null || room.isBlank()) {
      return new BookingResult.Rejected("Room is required");
    }
    if (!departure.isAfter(arrival)) {
      return new BookingResult.Rejected("Departure must be after arrival");
    }
    Booking booking = new Booking(room, arrival, departure);
    bookings.add(booking);
    return new BookingResult.Accepted(booking);
  }

  public List<Booking> bookingsFor(String room) {
    return bookings.stream().filter(b -> b.room().equals(room)).toList();
  }
}

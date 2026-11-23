package com.example.stays.booking;

import java.time.LocalDate;

/** A room held from arrival up to, but not including, departure. */
public record Booking(String room, LocalDate arrival, LocalDate departure) {
}

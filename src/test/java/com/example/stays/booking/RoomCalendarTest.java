package com.example.stays.booking;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;

import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.Test;

class RoomCalendarTest {

  private static final LocalDate JUNE_1 = LocalDate.of(2026, 6, 1);
  private static final LocalDate JUNE_4 = LocalDate.of(2026, 6, 4);
  private static final LocalDate JUNE_6 = LocalDate.of(2026, 6, 6);

  private final RoomCalendar calendar = new RoomCalendar();

  @Test
  void freeRoomIsBooked() {
    BookingResult result = calendar.book("garden", JUNE_1, JUNE_4);
    Booking booking = new Booking("garden", JUNE_1, JUNE_4);
    assertEquals(new BookingResult.Accepted(booking), result);
    assertEquals(List.of(booking), calendar.bookingsFor("garden"));
  }

  @Test
  void nextGuestMayArriveOnTheDepartureDate() {
    calendar.book("garden", JUNE_1, JUNE_4);
    assertInstanceOf(BookingResult.Accepted.class, calendar.book("garden", JUNE_4, JUNE_6));
    assertEquals(2, calendar.bookingsFor("garden").size());
  }

  @Test
  void differentRoomsDoNotAffectEachOther() {
    calendar.book("garden", JUNE_1, JUNE_4);
    assertInstanceOf(BookingResult.Accepted.class, calendar.book("loft", JUNE_1, JUNE_4));
    assertEquals(1, calendar.bookingsFor("loft").size());
  }

  @Test
  void emptyStayIsRejected() {
    assertEquals(new BookingResult.Rejected("Departure must be after arrival"),
        calendar.book("garden", JUNE_1, JUNE_1));
    assertEquals(List.of(), calendar.bookingsFor("garden"));
  }

  @Test
  void blankRoomIsRejected() {
    assertInstanceOf(BookingResult.Rejected.class, calendar.book(" ", JUNE_1, JUNE_4));
  }
}

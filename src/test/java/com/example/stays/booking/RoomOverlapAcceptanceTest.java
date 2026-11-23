package com.example.stays.booking;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;

import java.time.LocalDate;
import org.junit.jupiter.api.Test;

/** M-102: a room cannot hold two bookings for the same night. */
class RoomOverlapAcceptanceTest {

  private static final LocalDate JUNE_1 = LocalDate.of(2026, 6, 1);
  private static final LocalDate JUNE_3 = LocalDate.of(2026, 6, 3);
  private static final LocalDate JUNE_4 = LocalDate.of(2026, 6, 4);
  private static final LocalDate JUNE_6 = LocalDate.of(2026, 6, 6);

  private final RoomCalendar calendar = new RoomCalendar();

  @Test
  void overlappingStayInTheSameRoomIsRejected() {
    calendar.book("garden", JUNE_1, JUNE_4);
    assertInstanceOf(BookingResult.Rejected.class, calendar.book("garden", JUNE_3, JUNE_6));
    assertEquals(1, calendar.bookingsFor("garden").size());
  }

  @Test
  void stayInsideAnExistingStayIsRejected() {
    calendar.book("garden", JUNE_1, JUNE_6);
    assertInstanceOf(BookingResult.Rejected.class, calendar.book("garden", JUNE_3, JUNE_4));
  }

  @Test
  void backToBackStaysAreStillAccepted() {
    calendar.book("garden", JUNE_1, JUNE_4);
    assertInstanceOf(BookingResult.Accepted.class, calendar.book("garden", JUNE_4, JUNE_6));
  }
}

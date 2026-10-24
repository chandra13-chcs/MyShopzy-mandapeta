class BusinessHours {
  const BusinessHours._();

  static const timezone = 'Asia/Kolkata';
  static const openingHour = 7;
  static const closingHour = 22;
  static const openingLabel = '7:00 AM';
  static const closingLabel = '10:00 PM';

  static bool isOpenAt(DateTime now) {
    final localBusinessTime = now.toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    final minutesSinceMidnight =
        localBusinessTime.hour * 60 + localBusinessTime.minute;
    return minutesSinceMidnight >= openingHour * 60 &&
        minutesSinceMidnight < closingHour * 60;
  }
}

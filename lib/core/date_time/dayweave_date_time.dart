/// A local calendar date with no timezone or time-of-day semantics.
class LocalDate {
  const LocalDate(this.year, this.month, this.day);

  factory LocalDate.today() {
    final now = DateTime.now();
    return LocalDate(now.year, now.month, now.day);
  }

  factory LocalDate.parse(String value) {
    final parts = value.split('-').map(int.parse).toList(growable: false);
    if (parts.length != 3) throw FormatException('Expected YYYY-MM-DD.', value);
    return LocalDate(parts[0], parts[1], parts[2]);
  }

  final int year;
  final int month;
  final int day;

  String get iso => '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  DateTime get asLocalDateTime => DateTime(year, month, day);

  LocalDate addDays(int days) {
    final next = asLocalDateTime.add(Duration(days: days));
    return LocalDate(next.year, next.month, next.day);
  }

  @override
  String toString() => iso;

  @override
  bool operator ==(Object other) => other is LocalDate && other.iso == iso;

  @override
  int get hashCode => iso.hashCode;
}

/// A timestamp that represents an instant, serialized as an ISO-8601 UTC value.
class DayweaveTimestamp {
  const DayweaveTimestamp(this.value);

  factory DayweaveTimestamp.now() => DayweaveTimestamp(DateTime.now().toUtc());
  factory DayweaveTimestamp.parse(String value) => DayweaveTimestamp(DateTime.parse(value).toUtc());

  final DateTime value;

  String get iso => value.toUtc().toIso8601String();
}

int localMinutes(String value) {
  final parts = value.split(':').map(int.parse).toList(growable: false);
  if (parts.length != 2 || parts[0] < 0 || parts[0] > 23 || parts[1] < 0 || parts[1] > 59) {
    throw FormatException('Expected a local HH:mm value.', value);
  }
  return parts[0] * 60 + parts[1];
}

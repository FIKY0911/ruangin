/// The API sends ISO-8601 with the campus offset (`+07:00`). `DateTime.parse`
/// returns those in UTC, so convert to device-local time before formatting.
DateTime parseApiDate(Object? raw) => DateTime.parse(raw as String).toLocal();

DateTime? parseApiDateOrNull(Object? raw) =>
    raw == null ? null : parseApiDate(raw);

/// Sent to the API: UTC with a `Z` suffix (the server converts to campus time).
String toApiDate(DateTime d) => d.toUtc().toIso8601String();

import '../data/models/account.dart';

/// Edit permission (P05) is decided by the server and exposed as
/// `Session.canEdit`. Reporting an empty room (P09) is student-only.
bool canReportEmptyRoom(Account account) => account.role == UserRole.mahasiswa;

/// The confirmation queue (`GET /reports`) is for lecturers and officers.
bool canReviewReports(Account account) => account.isEditor;

import '../data/models/account.dart';
import '../data/models/session.dart';

/// P05 rule: lecturers edit only their own sessions, officers only sessions
/// whose prodi is within their scope, students never.
bool canEditSession(Account account, Session session) => switch (account.role) {
      UserRole.mahasiswa => false,
      UserRole.dosen => account.lecturerId == session.lecturerId,
      UserRole.petugas => account.scopeProdi.contains(session.prodi),
    };

bool canReportEmptyRoom(Account account) => account.role == UserRole.mahasiswa;

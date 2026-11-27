import '../core/formatters.dart';
import '../data/models/session.dart';

/// Pure presentation-agnostic status rules (PRD §1, §9).
///
/// - Cancelled             -> "Batal"
/// - Has attendance record -> "Tercatat · Sinkron absensi HH.MM"
/// - Otherwise             -> "Belum terkonfirmasi" (never "Batal")
extension SessionStatusText on Session {
  String get statusLabel => switch (status) {
        SessionStatus.batal => 'Batal',
        SessionStatus.tercatat =>
          'Tercatat · Sinkron absensi ${formatTime(attendance!.recordedAt)}',
        SessionStatus.belumTerkonfirmasi => 'Belum terkonfirmasi',
      };

  /// Card/headline label without the sync time (beranda_tanpa_peringatan.png,
  /// detail_sesi_tercatat.png).
  String get statusShortLabel => switch (status) {
        SessionStatus.batal => 'Batal',
        SessionStatus.tercatat => 'Tercatat',
        SessionStatus.belumTerkonfirmasi => 'Belum terkonfirmasi',
      };

  String get statusExplanation => switch (status) {
        SessionStatus.tercatat =>
          'Kehadiran kelas tercatat di sistem absensi. "Tercatat" bukan berarti '
              'dosen sedang ada di ruangan sekarang.',
        SessionStatus.belumTerkonfirmasi =>
          'Belum ada catatan absensi untuk sesi ini. Ini bukan berarti batal — '
              'cek lagi mendekati jam mulai.',
        SessionStatus.batal => 'Sesi dibatalkan oleh dosen/petugas.',
      };
}

const scheduleDisclaimer =
    'Ruangin menampilkan jadwal mengajar, bukan jaminan dosen bisa ditemui.';

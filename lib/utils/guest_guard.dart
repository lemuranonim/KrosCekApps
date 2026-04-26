// lib/utils/guest_guard.dart
//
// GUEST ROLE GUARD — Read-only access enforcement
// Gunakan di seluruh screen/form untuk memblokir aksi write bagi role Guest.
//
// Cara pakai:
//   1. Cek bool   : GuestGuard.isGuest(session)
//   2. Block aksi : GuestGuard.blockIfGuest(context, session)  → return false = boleh lanjut
//   3. Wrap widget: GuestGuard.wrapButton(context, session, child: ElevatedButton(...))
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../services/session_manager.dart';   // ActiveSession
import '../theme/app_theme.dart';

class GuestGuard {
  GuestGuard._();

  // ── Deteksi ───────────────────────────────────────────────
  static bool isGuest(ActiveSession? session) =>
      session?.role.toLowerCase() == 'guest';

  // ── Snackbar "Akses Ditolak" ──────────────────────────────
  static void _showDenied(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Akses ditolak — akun Guest hanya dapat melihat data.',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: AdvantaColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  /// Tampilkan snackbar & return true jika Guest (caller harus return/bail-out).
  /// Return false jika bukan Guest (boleh lanjut).
  static bool blockIfGuest(BuildContext context, ActiveSession? session) {
    if (isGuest(session)) {
      _showDenied(context);
      return true;   // diblokir
    }
    return false;    // lanjut
  }

  /// Wrap tombol/widget aksi: jika Guest, ganti onTap dengan _showDenied
  /// dan beri visual disabled + ikon kunci.
  static Widget wrapButton({
    required BuildContext context,
    required ActiveSession? session,
    required Widget child,
  }) {
    if (!isGuest(session)) return child;
    return Opacity(
      opacity: 0.45,
      child: AbsorbPointer(
        child: Tooltip(
          message: 'Akun Guest — read-only',
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              child,
              Positioned(
                top: 4, right: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AdvantaColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded,
                      color: Colors.white, size: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Banner informatif untuk ditampilkan di atas form/screen bagi Guest.
  static Widget banner() => const _GuestBanner();
}

// ── Banner widget ─────────────────────────────────────────
class _GuestBanner extends StatelessWidget {
  const _GuestBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AdvantaColors.error.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdvantaColors.error.withAlpha(70)),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined,
              color: AdvantaColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mode Read-Only — Akun Guest tidak dapat menambah, '
                  'mengedit, atau menghapus data.',
              style: TextStyle(
                color: AdvantaColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
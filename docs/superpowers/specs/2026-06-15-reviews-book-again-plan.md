# Reviews Finish + Book-Again Move Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In the history list of `MyBookingsScreen`, completed appointments show a bottom "Оставить отзыв" button (disabled "Отзыв оставлен" if already reviewed), while "Записаться снова" moves to a top icon button.

**Architecture:** Keep UI changes inside `MyBookingsScreen` by extracting a small stateful card widget that checks `hasReviewForAppointment` per item. Reuse existing `ReviewCreateScreen`, extending it to accept optional `Appointment` metadata and return a success flag.

**Tech Stack:** Flutter, Provider, existing `ApiService`/`AppStyles`.

---

### Task 1: Make `ReviewCreateScreen` return success flag

**Files:**
- Modify: `lib/screens/client/review_create_screen.dart:7-55`

- [ ] **Step 1: Return a success flag on submission**

In `_submit`, after the API returns success:

```dart
if (ok) {
  _showSnack('Отзыв отправлен на модерацию');
  if (mounted) Navigator.pop(context, true);
} else {
  _showSnack('Не удалось отправить отзыв', isError: true);
}
```

- [ ] **Step 2: Run analyzer on the file**

Run:

```bash
/Users/lan1t/development/flutter/bin/dart analyze lib/screens/client/review_create_screen.dart
```

Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/client/review_create_screen.dart
git commit -m "feat(reviews): return success flag from ReviewCreateScreen"
```

---

### Task 2: Extract a stateful history card and move the buttons

**Files:**
- Modify: `lib/screens/client/my_bookings_screen.dart:100-269`

- [ ] **Step 1: Add a private stateful widget `_HistoryAppointmentCard`**

At the bottom of `my_bookings_screen.dart`, add:

```dart
class _HistoryAppointmentCard extends StatefulWidget {
  final Appointment appointment;
  final List<Service> services;
  final CatalogProvider catalogProvider;

  const _HistoryAppointmentCard({
    required this.appointment,
    required this.services,
    required this.catalogProvider,
  });

  @override
  State<_HistoryAppointmentCard> createState() => _HistoryAppointmentCardState();
}

class _HistoryAppointmentCardState extends State<_HistoryAppointmentCard> {
  Future<bool>? _hasReviewFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _hasReviewFuture = context.read<ApiService>().hasReviewForAppointment(
          widget.appointment.id,
        );
  }

  Future<void> _openReview() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewCreateScreen(
          appointmentId: widget.appointment.id,
        ),
      ),
    );
    if (result == true && mounted) {
      setState(_load);
    }
  }

  void _bookAgain() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingWizardScreen(templateAppointment: widget.appointment),
      ),
    );
  }

  Widget _buildTopRow(BuildContext context) {
    final a = widget.appointment;
    final color = AppStyles.statusColor(a.status);
    final bgColor = AppStyles.statusBgColor(a.status);

    return Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(AppStyles.statusIcon(a.status), color: color, size: 20),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.catalogProvider.washTypeName(a.washTypeId),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppStyles.adaptiveTextPrimary(context),
              ),
            ),
            Row(children: [
              Text(
                '${a.carModel} · ${a.carNumber}',
                style: AppStyles.bodySmall.copyWith(
                  color: AppStyles.adaptiveTextSecondary(context),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppStyles.adaptivePrimaryBg(context),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Бокс №${a.box_index + 1}',
                  style: const TextStyle(
                    color: AppStyles.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
      IconButton(
        onPressed: _bookAgain,
        tooltip: 'Записаться снова',
        icon: const Icon(Icons.refresh, size: 20),
        color: AppStyles.primary,
      ),
    ]);
  }

  Widget _buildBottomButton(BuildContext context) {
    final a = widget.appointment;

    if (a.status == 'cancelled') {
      return Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: _bookAgain,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Записаться снова'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppStyles.primary,
            side: const BorderSide(color: AppStyles.primary),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return FutureBuilder<bool>(
      future: _hasReviewFuture,
      builder: (context, snapshot) {
        final hasReview = snapshot.data == true;
        final disabledColor = AppStyles.adaptiveTextSecondary(context);

        return Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: hasReview ? null : _openReview,
            icon: Icon(
              hasReview ? Icons.check : Icons.rate_review,
              size: 16,
              color: hasReview ? disabledColor : AppStyles.primary,
            ),
            label: Text(
              hasReview ? 'Отзыв оставлен' : 'Оставить отзыв',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: hasReview ? disabledColor : AppStyles.primary,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: hasReview ? disabledColor : AppStyles.primary,
              side: BorderSide(color: hasReview ? disabledColor : AppStyles.primary),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;

    return GestureDetector(
      onTap: () {
        context.read<AppointmentProvider>().markAsSeen(a.id);
        if (a.isModifiedByAdmin || a.isModifiedByWasher) {
          context.read<AppointmentProvider>().clearModifiedFlag(a.id);
        }
        _showDetail(context, a, widget.services);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppStyles.cardDecorationFor(context),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopRow(context),
            const SizedBox(height: 12),
            Container(height: 1, color: AppStyles.adaptiveBorder(context)),
            const SizedBox(height: 12),
            _buildTimePriceRow(context),
            const SizedBox(height: 12),
            Container(height: 1, color: AppStyles.adaptiveBorder(context)),
            const SizedBox(height: 10),
            _buildBottomButton(context),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Refactor `_BookingsList` to use the new widget**

Replace the `Container(...)` inside `_BookingsList.itemBuilder` with:

```dart
return _HistoryAppointmentCard(
  appointment: a,
  services: services.cast<Service>(),
  catalogProvider: catalogProvider,
);
```

Remove the old inline card body, the `showBookAgain` branch, and any now-unused imports.

- [ ] **Step 3: Extract `_buildTimePriceRow` helper if needed**

Move the existing time/price `Row` from `_BookingsList` into `_HistoryAppointmentCard` as `_buildTimePriceRow(BuildContext context)`. Keep logic identical.

- [ ] **Step 4: Run analyzer**

```bash
/Users/lan1t/development/flutter/bin/dart analyze lib/screens/client/my_bookings_screen.dart lib/screens/client/review_create_screen.dart
```

Expected: No issues (pre-existing deprecations in other files are acceptable).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/client/my_bookings_screen.dart lib/screens/client/review_create_screen.dart
git commit -m "feat(bookings): move book-again to top, add review button for completed appointments"
```

---

### Task 3: Final verification and push

- [ ] **Step 1: Run dart format**

```bash
/Users/lan1t/development/flutter/bin/dart format lib/screens/client/my_bookings_screen.dart lib/screens/client/review_create_screen.dart
```

- [ ] **Step 2: Run analyzer again**

```bash
/Users/lan1t/development/flutter/bin/dart analyze lib/screens/client/my_bookings_screen.dart lib/screens/client/review_create_screen.dart
```

Expected: No issues.

- [ ] **Step 3: Push**

```bash
git push origin feature/shift-drag-drop
```

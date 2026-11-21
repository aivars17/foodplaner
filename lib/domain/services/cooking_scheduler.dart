/// Deterministic cooking-schedule planner.
///
/// Sequences a batch of dishes across two shared resources — a single cook
/// (hands-on prep, serialized) and a single oven (serialized) — to minimize the
/// makespan. Because oven cooking can overlap later prep, the total time is
/// much less than the naive sum of all times.
///
/// This is the offline, no-AI counterpart to [PromptBuilder.cookingSchedule]:
/// the app can show an instant plan and optionally refine it with the AI.
class ScheduleDish {
  final String name;
  final int prepMinutes; // hands-on prep on the single cook resource
  final int cookMinutes; // oven time, used only when [usesOven] is true
  final bool usesOven;

  const ScheduleDish({
    required this.name,
    this.prepMinutes = 0,
    this.cookMinutes = 0,
    this.usesOven = false,
  });
}

/// One scheduled action that begins [startMinutes] minutes in.
class CookingStep {
  final int startMinutes;
  final String dish;
  final String action;

  const CookingStep({
    required this.startMinutes,
    required this.dish,
    required this.action,
  });
}

/// The result of scheduling a set of dishes.
class CookingSchedule {
  final List<CookingStep> steps;
  final int totalMinutes; // makespan

  const CookingSchedule({required this.steps, required this.totalMinutes});

  static const empty = CookingSchedule(steps: [], totalMinutes: 0);
}

class CookingScheduler {
  const CookingScheduler();

  /// Build a deterministic schedule for [dishes]. Ties on start time break by
  /// input order, so equal inputs always yield equal schedules.
  CookingSchedule schedule(Iterable<ScheduleDish> dishes) {
    final input = dishes.toList();
    if (input.isEmpty) return CookingSchedule.empty;

    var emission = 0;
    var prepFreeAt = 0;
    var ovenFreeAt = 0;
    var total = 0;

    // (emission order, step) so the final sort is stable even though
    // List.sort is not guaranteed stable.
    final steps = <(int, CookingStep)>[];

    for (final dish in input) {
      final prep = dish.prepMinutes < 0 ? 0 : dish.prepMinutes;
      final cook = dish.usesOven && dish.cookMinutes > 0 ? dish.cookMinutes : 0;

      // Prep is serialized on the single cook.
      final prepStart = prepFreeAt;
      final prepDone = prepStart + prep;
      prepFreeAt = prepDone;

      // The oven starts after this dish's own prep AND after the previous oven
      // slot finishes.
      final cookStart = cook > 0 && ovenFreeAt > prepDone ? ovenFreeAt : prepDone;
      final finish = cookStart + cook;
      total = finish > total ? finish : total;

      steps.add((
        emission++,
        CookingStep(
          startMinutes: prepStart,
          dish: dish.name,
          action: prep > 0 ? 'Ruošti $prep min' : 'Pasiruošimas',
        ),
      ));

      if (cook > 0) {
        ovenFreeAt = finish;
        steps.add((
          emission++,
          CookingStep(
            startMinutes: cookStart,
            dish: dish.name,
            action: 'Krosnis $cook min',
          ),
        ));
      }
    }

    steps.sort((a, b) {
      final byStart = a.$2.startMinutes.compareTo(b.$2.startMinutes);
      return byStart != 0 ? byStart : a.$1.compareTo(b.$1);
    });

    return CookingSchedule(
      steps: steps.map((s) => s.$2).toList(),
      totalMinutes: total,
    );
  }
}

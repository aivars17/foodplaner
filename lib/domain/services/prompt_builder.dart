import '../../models/household.dart';

/// A system+user prompt pair ready to send to Ollama.
class Prompt {
  final String system;
  final String user;
  final bool json;

  const Prompt({required this.system, required this.user, this.json = true});
}

/// Builds structured prompts that ask Ollama to return JSON. The model is
/// configured with `format: json`, so we ask for strict JSON shapes.
class PromptBuilder {
  const PromptBuilder();

  static const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  String _dietaryLine(HouseholdSettings s) {
    final diet = <String>{...s.dietary};
    for (final m in s.members) {
      diet.addAll(m.dietary);
    }
    if (diet.isEmpty) return 'Jokių dietos apribojimų.';
    return 'Dietos apribojimai: ${diet.join(", ")}.';
  }

  /// Generate a full week plan.
  Prompt mealPlan({
    required HouseholdSettings settings,
    int days = 7,
    List<String> mealTypes = _mealTypes,
  }) {
    final mealTypeText = mealTypes.join(", ");
    final onHand = settings.onHand.isEmpty
        ? 'nėra'
        : settings.onHand.join(', ');

    final system = [
      'Tu — profesionalus mitybos planuotojas. Atsakink TIK vienu galiojančiu JSON objektu.',
      'JSON struktūra:',
      r'{"meals":[{"dayOfWeek":0,"mealType":"dinner","dishes":[{"kind":"main|side","name":"","covers":4,"recipe":{"ingredients":[{"name":"","amount":"","unit":"","storeCategory":""}],"steps":[""]}],"notes":""}]}]}',
      'Taisyklės:',
      '- dayOfWeek: 0=pradžia (pvz. pirmadienis) ... ${days - 1}.',
      '- Kiekvienam valgio laikui duok 1 pagrindinį patiekalą (kind="main") ir 2 garnyrų variantus (kind="side").',
      '- kiekvieno patiekalo "covers" = ${settings.defaultServings} (males).',
      '- ingredientų unit naudoju: "g", "kg", "ml", "l", "tsk.", "vnt.", "sv.".',
      '- "storeCategory" vienas iš: "Daržovės","Mėsos","Saldyklevė","Drovė / Prieskoniai","Kita".',
      '- "steps" — aiškūs, trumpi ruošimo žingsniai lietuviškai.',
    ].join('\n');

    final user = [
      'Sukurk ${days} dienų savaitės mitybos planą.',
      'Valgio laikai: $mealTypeText.',
      'Šeimos narių skaičius: ${settings.memberCount}.',
      'Numatytos porcijos: ${settings.defaultServings}.',
      _dietaryLine(settings),
      'Jau turimi ingredientai (nesudėk jų, jei tinka): $onHand.',
      'Atsakymą sukurk tik JSON. Nebeparašyk nieko daugiau.',
    ].join('\n');

    return Prompt(system: system, user: user, json: true);
  }

  /// Generate a single dish for the remaining family members of a slot.
  Prompt dishForRemaining({
    required HouseholdSettings settings,
    required int dayOfWeek,
    required String mealType,
    required int covers,
  }) {
    final system = [
      'Tu — profesionalus virtuvės patarėjas. Atsakink TIK vienu galiojančiu JSON objektu.',
      'Struktūra: {"kind":"main","name":"","covers":${covers},"recipe":{"ingredients":[{"name":"","amount":"","unit":"","storeCategory":""}],"steps":[""]},"notes":""}.',
      '- "covers" turi būti ${covers}.',
      '- ingredientų unit: "g","kg","ml","l","tsk.","vnt.","sv.".',
      '- "steps" — aiškūs ruošimo žingsniai lietuviškai.',
    ].join('\n');

    final user = [
      'Sukurk ${covers} žmonių ${mealType} patiekalą ${_dayName(dayOfWeek)}.',
      'Šeima: ${settings.memberCount} žmonės. Numatyta: ${settings.defaultServings}.',
      _dietaryLine(settings),
      'Jau turimi: ${settings.onHand.isEmpty ? "nėra" : settings.onHand.join(", ")}.',
      'Atsakymą sukurk tik JSON.',
    ].join('\n');

    return Prompt(system: system, user: user, json: true);
  }

  /// Generate extra side-dish variants for a main dish.
  Prompt sideVariants({required String mainName, int count = 2}) {
    final system = [
      'Atsakink TIK vienu galiojančiu JSON masyvu.',
      'Kiekvienas elementas: {"kind":"side","name":"","covers":1,"recipe":{"ingredients":[{"name":"","amount":"","unit":"","storeCategory":""}],"steps":[""]}}.',
    ].join('\n');
    final user = [
      'Sugeneruok $count skirtingų garnyrų variantų patiekalui: "$mainName".',
      'Kiekvienas garnyras — savarankiškas patiekalas su pilnu ingredientų sąrašu ir žingsniais.',
      'Atsakymą sukurk tik JSON masyvą.',
    ].join('\n');
    return Prompt(system: system, user: user, json: true);
  }

  /// Build a cooking schedule that sequences dishes to minimize total time.
  Prompt cookingSchedule(List<String> dishNames) {
    final system = [
      'Atsakink TIK vienu JSON objektu: {"schedule":[{"startMinutes":0,"dish":"","action":""}]}',
      '- "startMinutes" — minutes nuo pradžios, kada pradėti; "action" — trumpa instrukcija.',
    ].join('\n');
    final user = [
      'Sudėk šiuos patiekalus optimalią ruošimo eilę (kad bendras laikas būtų kuo mažesnis, krosnys nenaudotų vienu metu):',
      for (var i = 0; i < dishNames.length; i++) '${i + 1}. ${dishNames[i]}',
      'Atsakymą sukurk tik JSON.',
    ].join('\n');
    return Prompt(system: system, user: user, json: true);
  }

  static String _dayName(int dayOfWeek) {
    const days = ['Pirmadienis', 'Antradienis', 'Trečiadienis',
      'Ketvirtadienis', 'Penktadienis', 'Šeštadienis', 'Sekmadienis'];
    if (dayOfWeek < 0 || dayOfWeek >= days.length) return 'dieną';
    return days[dayOfWeek];
  }
}

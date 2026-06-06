# Production Prep Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add car brand/model autocomplete, fix dark mode across all screens, and optimize performance by splitting the god-provider and adding const constructors.

**Architecture:** Local JSON catalog for instant car autocomplete; systematic migration of all screens from static `AppStyles`/`Colors` to adaptive `AppStyles.*For(context)` helpers; split `AppProvider` into `AppointmentProvider`, `CatalogProvider`, `NoteProvider`, `FavoriteProvider` to reduce rebuild scope.

**Tech Stack:** Flutter (Provider, GetIt, SharedPreferences, Material 3), Dart, Python/FastAPI backend (unchanged for this plan).

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `assets/data/car_catalog.json` | Create | Local car brand → models catalog |
| `lib/services/car_catalog_service.dart` | Create | Loads JSON, exposes search APIs |
| `lib/widgets/car_autocomplete_field.dart` | Create | Reusable Autocomplete field for brand/model |
| `lib/providers/appointment_provider.dart` | Create | Extracted from `AppProvider`: appointments, busy slots, pagination |
| `lib/providers/catalog_provider.dart` | Create | Extracted from `AppProvider`: services, wash types, promos |
| `lib/providers/note_provider.dart` | Create | Extracted from `AppProvider`: notes, unread counts |
| `lib/providers/favorite_provider.dart` | Create | Extracted from `AppProvider`: favorites |
| `lib/app_styles.dart` | Modify | Fix goldButton, remove withOpacity, keep adaptive helpers |
| `lib/config/app_styles.dart` | Delete | Stale duplicate without adaptive methods |
| `lib/config/app_theme.dart` | Delete | Stale unused light theme duplicate |
| `lib/main.dart` | Modify | Fix SystemUiOverlayStyle, update MultiProvider, replace withOpacity |
| `lib/screens/client/booking_wizard_screen.dart` | Modify | Split car field into brand+model autocompletes |
| `lib/screens/shared/profile_screen.dart` | Modify | Split car field into brand+model autocompletes |
| `lib/screens/admin/add_edit_appointment_screen.dart` | Modify | Split car field into brand+model autocompletes |
| `lib/screens/client/client_home_screen.dart` | Modify | Dark theme colors |
| `lib/screens/client/my_bookings_screen.dart` | Modify | Dark theme colors |
| `lib/screens/auth/login_screen.dart` | Modify | Dark theme colors |
| `lib/screens/auth/register_screen.dart` | Modify | Dark theme colors |
| `lib/screens/admin/admin_schedule_screen.dart` | Modify | Dark theme colors |
| `lib/screens/admin/appointments_screen.dart` | Modify | Dark theme colors |
| `lib/screens/admin/add_edit_service_screen.dart` | Modify | Dark theme colors |
| `lib/screens/admin/statistics_screen.dart` | Modify | Dark theme colors |
| `lib/screens/admin/notes_screen.dart` | Modify | Dark theme colors |
| `lib/screens/admin/logs_screen.dart` | Modify | Dark theme colors |
| `lib/screens/shared/appointment_detail_widget.dart` | Modify | Dark theme colors |
| `lib/screens/shared/promo_detail_screen.dart` | Modify | Dark theme colors |
| `lib/screens/shared/service_detail_screen.dart` | Modify | Dark theme colors |
| `lib/providers/app_provider.dart` | Modify | Thin facade after extraction |
| `lib/core/service_locator.dart` | Modify | Register new providers if needed |
| `test/services/car_catalog_service_test.dart` | Create | Unit tests for catalog parsing/search |
| `test/widgets/car_autocomplete_test.dart` | Create | Widget tests for autocomplete interaction |
| `test/mocks.dart` | Modify | Add mocks for new providers |

---

## Task 1: Global Cleanup

**Files:**
- Delete: `lib/config/app_styles.dart`
- Delete: `lib/config/app_theme.dart`
- Modify: `lib/main.dart`
- Modify: `lib/app_styles.dart`

- [ ] **Step 1: Delete stale duplicate files**

```bash
rm lib/config/app_styles.dart lib/config/app_theme.dart
```

- [ ] **Step 2: Fix SystemUiOverlayStyle in main.dart**

Open `lib/main.dart`. Find the hardcoded block (around line 50):

```dart
SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark, // ← always dark
));
```

Replace with a reactive version inside `LanWashApp.build` (wrap `MaterialApp` with `AnnotatedRegion`):

```dart
@override
Widget build(BuildContext context) {
  return Consumer<ThemeProvider>(
    builder: (context, themeProvider, child) {
      final isDark = themeProvider.themeMode == ThemeMode.dark ||
          (themeProvider.themeMode == ThemeMode.system &&
              MediaQuery.platformBrightnessOf(context) == Brightness.dark);
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        child: MaterialApp(
          // ... existing MaterialApp properties
        ),
      );
    },
  );
}
```

- [ ] **Step 3: Migrate withOpacity → withValues in app_styles.dart**

Open `lib/app_styles.dart`. Replace all `withOpacity(` with `withValues(alpha:`.

Use this bash command to verify none remain:

```bash
grep -n "withOpacity" lib/app_styles.dart || echo "Clean"
```

Expected: no output (or only in comments).

- [ ] **Step 4: Fix goldButton in app_styles.dart**

Find:

```dart
static BoxDecoration get goldButton => primaryButton; // or identical colors
```

Replace with:

```dart
static BoxDecoration get goldButton => BoxDecoration(
      color: gold,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: gold.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
```

- [ ] **Step 5: Run flutter analyze**

```bash
flutter analyze lib/app_styles.dart lib/main.dart
```

Expected: zero errors.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "cleanup: remove stale theme duplicates, fix SystemUiOverlayStyle, withOpacity→withValues"
```

---

## Task 2: Car Catalog Data & Service

**Files:**
- Create: `assets/data/car_catalog.json`
- Create: `lib/services/car_catalog_service.dart`
- Create: `test/services/car_catalog_service_test.dart`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add asset entry to pubspec.yaml**

Open `pubspec.yaml`. In the `flutter:` → `assets:` section, add:

```yaml
  assets:
    - assets/data/car_catalog.json
```

If there is no `assets:` section under `flutter:`, add it.

- [ ] **Step 2: Create car_catalog.json**

Create `assets/data/car_catalog.json` with this structure (fill with real data; start with top 50 brands to keep file manageable, expand later):

```json
[
  {
    "brand": "Toyota",
    "models": ["4Runner", "Alphard", "Auris", "Avalon", "Camry", "Corolla", "C-HR", "Highlander", "Hilux", "Land Cruiser", "Land Cruiser Prado", "RAV4", "Prius", "Supra", "Tacoma", "Tundra", "Venza", "Yaris"]
  },
  {
    "brand": "BMW",
    "models": ["1 Series", "2 Series", "3 Series", "4 Series", "5 Series", "6 Series", "7 Series", "8 Series", "X1", "X2", "X3", "X4", "X5", "X6", "X7", "XM", "i3", "i4", "i7", "iX", "M3", "M4", "M5", "Z4"]
  },
  {
    "brand": "Mercedes-Benz",
    "models": ["A-Class", "B-Class", "C-Class", "CLA", "CLS", "E-Class", "G-Class", "GLA", "GLB", "GLC", "GLE", "GLS", "S-Class", "SL", "SLC", "EQA", "EQB", "EQC", "EQE", "EQS", "AMG GT", "V-Class"]
  },
  {
    "brand": "Audi",
    "models": ["A1", "A3", "A4", "A5", "A6", "A7", "A8", "Q2", "Q3", "Q4 e-tron", "Q5", "Q7", "Q8", "e-tron", "e-tron GT", "TT", "R8", "RS3", "RS4", "RS5", "RS6", "RS7", "RS Q8"]
  },
  {
    "brand": "Hyundai",
    "models": ["Accent", "Creta", "Elantra", "Genesis Coupe", "Getz", "i30", "Ioniq", "Kona", "Palisade", "Santa Fe", "Solaris", "Sonata", "Tucson", "Venue", "Verna", "i40", "ix35"]
  },
  {
    "brand": "Kia",
    "models": ["Carens", "Carnival", "Ceed", "Cerato", "EV6", "Forte", "K5", "Mohave", "Optima", "Picanto", "Rio", "Seltos", "Sorento", "Soul", "Sportage", "Stinger", "Telluride", "Venga"]
  },
  {
    "brand": "Volkswagen",
    "models": ["Amarok", "Arteon", "Atlas", "Beetle", "Bora", "Caddy", "Golf", "ID.3", "ID.4", "ID.5", "ID.6", "Jetta", "Passat", "Polo", "T-Roc", "Tiguan", "Touareg", "Transporter", "Up!"]
  },
  {
    "brand": "Skoda",
    "models": ["Fabia", "Kamiq", "Karoq", "Kodiaq", "Octavia", "Rapid", "Scala", "Superb", "Yeti"]
  },
  {
    "brand": "Nissan",
    "models": ["Almera", "Altima", "Ariya", "Juke", "Leaf", "Micra", "Murano", "Navara", "Note", "Pathfinder", "Patrol", "Qashqai", "Rogue", "Sentra", "Teana", "Terrano", "Tiida", "X-Trail", "Z"]
  },
  {
    "brand": "Mazda",
    "models": ["2", "3", "6", "CX-3", "CX-30", "CX-5", "CX-60", "CX-9", "MX-30", "MX-5", "RX-8"]
  },
  {
    "brand": "Lexus",
    "models": ["CT", "ES", "GS", "GX", "IS", "LC", "LM", "LS", "LX", "NX", "RC", "RX", "RZ", "UX"]
  },
  {
    "brand": "Honda",
    "models": ["Accord", "City", "Civic", "CR-V", "Fit", "HR-V", "Insight", "Jazz", "Odyssey", "Passport", "Pilot", "Ridgeline"]
  },
  {
    "brand": "Ford",
    "models": ["Bronco", "EcoSport", "Edge", "Escape", "Explorer", "F-150", "Fiesta", "Focus", "Fusion", "Galaxy", "Kuga", "Maverick", "Mondeo", "Mustang", "Puma", "Ranger", "S-Max", "Transit"]
  },
  {
    "brand": "Chevrolet",
    "models": ["Aveo", "Blazer", "Bolt", "Camaro", "Captiva", "Cobalt", "Colorado", "Cruze", "Equinox", "Impala", "Lacetti", "Malibu", "Niva", "Orlando", "Silverado", "Spark", "Suburban", "Tahoe", "Trailblazer", "Traverse"]
  },
  {
    "brand": "Renault",
    "models": ["Arkana", "Captur", "Clio", "Duster", "Fluence", "Kadjar", "Kangoo", "Kaptur", "Koleos", "Laguna", "Logan", "Megane", "Sandero", "Scenic", "Symbol", "Talisman", "Twingo"]
  },
  {
    "brand": "Peugeot",
    "models": ["107", "108", "2008", "206", "207", "208", "3008", "301", "307", "308", "406", "407", "408", "5008", "508", "Boxer", "Expert", "Partner", "Rifter"]
  },
  {
    "brand": "Citroen",
    "models": ["Berlingo", "C1", "C3", "C3 Aircross", "C4", "C4 Cactus", "C5", "C5 Aircross", "C-Elysee", "Jumper", "Jumpy", "SpaceTourer"]
  },
  {
    "brand": "Volvo",
    "models": ["C30", "C40", "C70", "S60", "S80", "S90", "V40", "V60", "V90", "XC40", "XC60", "XC90", "EX30", "EX90"]
  },
  {
    "brand": "Subaru",
    "models": ["BRZ", "Crosstrek", "Forester", "Impreza", "Legacy", "Levorg", "Outback", "Solterra", "WRX", "XV"]
  },
  {
    "brand": "Mitsubishi",
    "models": ["ASX", "Carisma", "Colt", "Eclipse Cross", "Galant", "L200", "Lancer", "Mirage", "Outlander", "Pajero", "Pajero Sport", "Space Star"]
  },
  {
    "brand": "Suzuki",
    "models": ["Baleno", "Escudo", "Grand Vitara", "Ignis", "Jimny", "Swift", "SX4", "Vitara", "XL7"]
  },
  {
    "brand": "Daewoo",
    "models": ["Gentra", "Lacetti", "Lanos", "Leganza", "Matiz", "Nexia", "Nubira"]
  },
  {
    "brand": "Lada (ВАЗ)",
    "models": ["2101", "2107", "2110", "2114", "Granta", "Kalina", "Largus", "Niva", "Niva Travel", "Priora", "Vesta", "XRAY"]
  },
  {
    "brand": "Chery",
    "models": ["Amulet", "Arrizo", "Bonus", "Cross EA", "Fora", "M11", "QQ", "Tiggo", "Tiggo 4", "Tiggo 7", "Tiggo 8", "Tiggo 8 Pro", "Very"]
  },
  {
    "brand": "Geely",
    "models": ["Atlas", "Atlas Pro", "Belgee", "Binyue", "Coolray", "Emgrand", "Emgrand EC7", "Emgrand X7", "Geometry C", "Monjaro", "Okavango", "Tugella"]
  },
  {
    "brand": "Haval",
    "models": ["Dargo", "F7", "F7x", "H2", "H5", "H6", "H9", "Jolion", "M6"]
  },
  {
    "brand": "Porsche",
    "models": ["911", "718 Boxster", "718 Cayman", "Cayenne", "Cayenne Coupe", "Macan", "Panamera", "Taycan"]
  },
  {
    "brand": "Infiniti",
    "models": ["EX", "FX", "G", "JX", "M", "Q30", "Q50", "Q60", "Q70", "QX30", "QX50", "QX55", "QX60", "QX70", "QX80"]
  },
  {
    "brand": "Acura",
    "models": ["ILX", "Integra", "MDX", "NSX", "RDX", "TLX", "ZDX"]
  },
  {
    "brand": "Jeep",
    "models": ["Cherokee", "Compass", "Gladiator", "Grand Cherokee", "Patriot", "Renegade", "Wrangler"]
  },
  {
    "brand": "Land Rover",
    "models": ["Defender", "Discovery", "Discovery Sport", "Freelander", "Range Rover", "Range Rover Evoque", "Range Rover Sport", "Range Rover Velar"]
  },
  {
    "brand": "Jaguar",
    "models": ["E-Pace", "F-Pace", "F-Type", "I-Pace", "S-Type", "XE", "XF", "XJ", "X-Type"]
  },
  {
    "brand": "Cadillac",
    "models": ["ATS", "CT4", "CT5", "CT6", "CTS", "Escalade", "SRX", "XT4", "XT5", "XT6", "XTS"]
  },
  {
    "brand": "Lincoln",
    "models": ["Aviator", "Corsair", "MKC", "MKS", "MKX", "MKZ", "Nautilus", "Navigator", "Town Car"]
  },
  {
    "brand": "Dodge",
    "models": ["Caliber", "Challenger", "Charger", "Durango", "Grand Caravan", "Journey", "Neon", "Ram"]
  },
  {
    "brand": "Chrysler",
    "models": ["200", "300C", "Pacifica", "PT Cruiser", "Sebring", "Town & Country", "Voyager"]
  },
  {
    "brand": "Tesla",
    "models": ["Model 3", "Model S", "Model X", "Model Y", "Cybertruck", "Roadster"]
  },
  {
    "brand": "BYD",
    "models": ["Atto 3", "Dolphin", "Frigate 07", "Han", "Qin", "Seal", "Song", "Tang", "Yuan"]
  },
  {
    "brand": "Great Wall",
    "models": ["Deer", "Hover", "Pegasus", "Safe", "Sailor", "Sing", "Socool", "Wingle"]
  },
  {
    "brand": "Opel",
    "models": ["Astra", "Combo", "Corsa", "Crossland", "Grandland", "Insignia", "Meriva", "Mokka", "Vectra", "Vivaro", "Zafira"]
  },
  {
    "brand": "SEAT",
    "models": ["Alhambra", "Arona", "Ateca", "Ibiza", "Leon", "Tarraco", "Toledo"]
  },
  {
    "brand": "Fiat",
    "models": ["500", "500L", "500X", "Bravo", "Doblo", "Ducato", "Linea", "Panda", "Scudo", "Tipo"]
  },
  {
    "brand": "MINI",
    "models": ["Clubman", "Convertible", "Cooper", "Countryman", "Coupe", "Paceman", "Roadster"]
  },
  {
    "brand": "Smart",
    "models": ["Forfour", "Fortwo", "Roadster", "#1", "#3"]
  },
  {
    "brand": "Datsun",
    "models": ["mi-DO", "on-DO", "redi-GO", "Go"]
  },
  {
    "brand": "Ravon",
    "models": ["Gentra", "Nexia", "R2", "R4"]
  },
  {
    "brand": "UAZ",
    "models": ["Hunter", "Patriot", "Pickup", "Profil", "Simbir"]
  },
  {
    "brand": "GAZ",
    "models": ["2217", "2705", "3102", "3110", "Siber", "Sobol", "Volga"]
  },
  {
    "brand": "Genesis",
    "models": ["G70", "G80", "G90", "GV60", "GV70", "GV80"]
  },
  {
    "brand": "Alfa Romeo",
    "models": ["147", "156", "159", "4C", "Brera", "Giulia", "Giulietta", "MiTo", "Stelvio", "Tonale"]
  }
]
```

- [ ] **Step 3: Create CarCatalogService**

Create `lib/services/car_catalog_service.dart`:

```dart
import 'dart:convert';
import 'package:flutter/services.dart';

class CarBrand {
  final String name;
  final List<String> models;

  const CarBrand({required this.name, required this.models});

  factory CarBrand.fromJson(Map<String, dynamic> json) {
    return CarBrand(
      name: json['brand'] as String,
      models: (json['models'] as List<dynamic>).cast<String>(),
    );
  }
}

class CarCatalogService {
  List<CarBrand>? _brands;
  List<String>? _allBrandNames;
  final Map<String, List<String>> _modelsByBrand = {};

  Future<void> load() async {
    if (_brands != null) return;
    final raw = await rootBundle.loadString('assets/data/car_catalog.json');
    final list = jsonDecode(raw) as List<dynamic>;
    _brands = list.map((e) => CarBrand.fromJson(e as Map<String, dynamic>)).toList();
    _allBrandNames = _brands!.map((b) => b.name).toList();
    for (final brand in _brands!) {
      _modelsByBrand[brand.name] = brand.models;
    }
  }

  List<String> searchBrands(String query) {
    if (_allBrandNames == null) return [];
    final q = query.toLowerCase();
    return _allBrandNames!.where((b) => b.toLowerCase().startsWith(q)).toList();
  }

  List<String> searchModels(String brand, String query) {
    final models = _modelsByBrand[brand];
    if (models == null) return [];
    final q = query.toLowerCase();
    return models.where((m) => m.toLowerCase().startsWith(q)).toList();
  }

  List<String> get allBrandNames => _allBrandNames ?? [];
  List<String> modelsForBrand(String brand) => _modelsByBrand[brand] ?? [];
}
```

- [ ] **Step 4: Register in service locator**

Open `lib/core/service_locator.dart`. Add:

```dart
import 'package:lanwash/services/car_catalog_service.dart';
// ...
getIt.registerSingleton<CarCatalogService>(CarCatalogService());
```

- [ ] **Step 5: Pre-load catalog on app start**

Open `lib/main.dart`. In `LanWashAppState.initState()` or right before `runApp`, load the catalog:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupLocator();
  await getIt<CarCatalogService>().load();
  // ... rest of main
}
```

- [ ] **Step 6: Write unit tests**

Create `test/services/car_catalog_service_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanwash/services/car_catalog_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      const json = '[{"brand":"Toyota","models":["Camry","Corolla"]}]';
      return ByteData.sublistView(Uint8List.fromList(utf8.encode(json)));
    });
  });

  test('load and search brands', () async {
    final svc = CarCatalogService();
    await svc.load();
    expect(svc.searchBrands('to'), ['Toyota']);
    expect(svc.searchBrands('xx'), isEmpty);
  });

  test('search models by brand', () async {
    final svc = CarCatalogService();
    await svc.load();
    expect(svc.searchModels('Toyota', 'ca'), ['Camry']);
    expect(svc.searchModels('Toyota', 'xx'), isEmpty);
  });
}
```

- [ ] **Step 7: Run tests**

```bash
flutter test test/services/car_catalog_service_test.dart
```

Expected: all pass.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: add local car catalog JSON and CarCatalogService"
```

---

## Task 3: Reusable Car Autocomplete Widget

**Files:**
- Create: `lib/widgets/car_autocomplete_field.dart`
- Create: `test/widgets/car_autocomplete_test.dart`

- [ ] **Step 1: Create CarAutocompleteField**

Create `lib/widgets/car_autocomplete_field.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lanwash/app_styles.dart';
import 'package:lanwash/services/car_catalog_service.dart';

class CarAutocompleteField extends StatelessWidget {
  final String label;
  final String? hint;
  final IconData icon;
  final TextEditingController controller;
  final List<String> Function(String) optionsBuilder;
  final bool enabled;
  final void Function(String)? onSelected;
  final String? Function(String?)? validator;

  const CarAutocompleteField({
    super.key,
    required this.label,
    this.hint,
    required this.icon,
    required this.controller,
    required this.optionsBuilder,
    this.enabled = true,
    this.onSelected,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
        return optionsBuilder(textEditingValue.text);
      },
      onSelected: (selection) {
        controller.text = selection;
        onSelected?.call(selection);
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          enabled: enabled,
          validator: validator,
          decoration: AppStyles.inputDecorationFor(context, label, hint: hint, icon: icon),
          textCapitalization: TextCapitalization.words,
          onChanged: (v) => controller.text = v,
          onFieldSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: AppStyles.adaptiveCard(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    title: Text(
                      option,
                      style: TextStyle(color: AppStyles.adaptiveTextPrimary(context)),
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Write widget test**

Create `test/widgets/car_autocomplete_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanwash/widgets/car_autocomplete_field.dart';

void main() {
  testWidgets('CarAutocompleteField renders and suggests', (tester) async {
    final ctrl = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CarAutocompleteField(
            label: 'Brand',
            icon: Icons.directions_car,
            controller: ctrl,
            optionsBuilder: (q) => ['Toyota', 'Tesla'].where((b) => b.toLowerCase().startsWith(q.toLowerCase())),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'To');
    await tester.pump();

    expect(find.text('Toyota'), findsOneWidget);
    expect(find.text('Tesla'), findsOneWidget);

    await tester.tap(find.text('Toyota'));
    await tester.pump();

    expect(ctrl.text, 'Toyota');
  });
}
```

- [ ] **Step 3: Run test**

```bash
flutter test test/widgets/car_autocomplete_test.dart
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add CarAutocompleteField widget"
```

---

## Task 4: Integrate Autocomplete into Booking Wizard

**Files:**
- Modify: `lib/screens/client/booking_wizard_screen.dart`

- [ ] **Step 1: Add imports and split car field**

Open `lib/screens/client/booking_wizard_screen.dart`.

Add imports:

```dart
import 'package:lanwash/services/car_catalog_service.dart';
import 'package:lanwash/widgets/car_autocomplete_field.dart';
```

In `_ServiceState` (or the relevant state class), add two controllers:

```dart
late final TextEditingController _brandCtrl;
late final TextEditingController _modelCtrl;
String? _selectedBrand;
```

In `initState`, split existing `carCtrl` value:

```dart
@override
void initState() {
  super.initState();
  final existingCar = widget.user?.carModel ?? '';
  final parts = existingCar.split(' ');
  _brandCtrl = TextEditingController(text: parts.isNotEmpty ? parts.first : '');
  _modelCtrl = TextEditingController(text: parts.length > 1 ? parts.sublist(1).join(' ') : '');
  _selectedBrand = _brandCtrl.text.isNotEmpty ? _brandCtrl.text : null;
}
```

Dispose both controllers.

- [ ] **Step 2: Replace car TextFormField with two CarAutocompleteFields**

Find the existing `TextFormField` for car (around line 817). Replace with:

```dart
CarAutocompleteField(
  label: 'Марка авто',
  icon: Icons.directions_car_outlined,
  controller: _brandCtrl,
  optionsBuilder: (q) => getIt<CarCatalogService>().searchBrands(q),
  onSelected: (brand) {
    setState(() => _selectedBrand = brand);
    _modelCtrl.clear();
  },
  validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите марку' : null,
),
const SizedBox(height: 12),
CarAutocompleteField(
  label: 'Модель авто',
  hint: _selectedBrand == null ? 'Сначала выберите марку' : null,
  icon: Icons.settings_outlined,
  controller: _modelCtrl,
  enabled: _selectedBrand != null,
  optionsBuilder: (q) {
    if (_selectedBrand == null) return [];
    return getIt<CarCatalogService>().searchModels(_selectedBrand!, q);
  },
  validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите модель' : null,
),
```

- [ ] **Step 3: Combine brand+model for submission**

Find where `carCtrl.text` is passed to the provider/API. Replace with:

```dart
final carModel = '${_brandCtrl.text.trim()} ${_modelCtrl.text.trim()}';
```

Pass `carModel` instead of the old single controller value.

- [ ] **Step 4: Run flutter analyze**

```bash
flutter analyze lib/screens/client/booking_wizard_screen.dart
```

Expected: zero errors.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: split car input into brand+model autocomplete in booking wizard"
```

---

## Task 5: Integrate Autocomplete into Profile & Admin Screens

**Files:**
- Modify: `lib/screens/shared/profile_screen.dart`
- Modify: `lib/screens/admin/add_edit_appointment_screen.dart`

- [ ] **Step 1: Profile screen**

Open `lib/screens/shared/profile_screen.dart`.

Replace the single `_carModelCtrl` field with `_brandCtrl` + `_modelCtrl` + `_selectedBrand`, identical pattern to Task 4.

Use `CarAutocompleteField` for both inputs. On save, combine:

```dart
final carModel = '${_brandCtrl.text.trim()} ${_modelCtrl.text.trim()}';
```

- [ ] **Step 2: Admin add/edit appointment screen**

Open `lib/screens/admin/add_edit_appointment_screen.dart`.

Do the identical split: two controllers, two `CarAutocompleteField`s, combine on save.

- [ ] **Step 3: Run flutter analyze for both files**

```bash
flutter analyze lib/screens/shared/profile_screen.dart lib/screens/admin/add_edit_appointment_screen.dart
```

Expected: zero errors.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add brand+model autocomplete to profile and admin appointment screens"
```

---

## Task 6: Dark Theme — Client Screens (Part 1)

**Files:**
- Modify: `lib/screens/client/booking_wizard_screen.dart`
- Modify: `lib/screens/client/client_home_screen.dart`

- [ ] **Step 1: booking_wizard_screen.dart — audit static colors**

Search for these patterns in the file:
- `AppStyles.cardDecoration`
- `AppStyles.inputDecoration(`
- `AppStyles.textPrimary`
- `AppStyles.textSecondary`
- `Colors.white`
- `Colors.black`
- `withOpacity`

Replace each occurrence with the adaptive equivalent from the spec table.

Example replacement:

```dart
// BEFORE
Container(
  decoration: AppStyles.cardDecoration,
  child: Text('Hello', style: AppStyles.textPrimary),
)

// AFTER
Container(
  decoration: AppStyles.cardDecorationFor(context),
  child: Text('Hello', style: TextStyle(color: AppStyles.adaptiveTextPrimary(context))),
)
```

- [ ] **Step 2: client_home_screen.dart — audit static colors**

Same process as Step 1. Grep for static patterns and replace with adaptive equivalents.

- [ ] **Step 3: Run flutter analyze**

```bash
flutter analyze lib/screens/client/booking_wizard_screen.dart lib/screens/client/client_home_screen.dart
```

Expected: zero errors.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "fix(dark-theme): migrate client booking and home screens to adaptive colors"
```

---

## Task 7: Dark Theme — Client Screens (Part 2) + Auth

**Files:**
- Modify: `lib/screens/client/my_bookings_screen.dart`
- Modify: `lib/screens/shared/appointment_detail_widget.dart`
- Modify: `lib/screens/shared/promo_detail_screen.dart`
- Modify: `lib/screens/shared/service_detail_screen.dart`
- Modify: `lib/screens/auth/login_screen.dart`
- Modify: `lib/screens/auth/register_screen.dart`

- [ ] **Step 1: Migrate each file**

For each file in the list above, run the same audit-and-replace process:

```bash
# Verify what needs changing
grep -n "AppStyles.cardDecoration\|AppStyles.inputDecoration(\|AppStyles.textPrimary\|AppStyles.textSecondary\|Colors.white\|Colors.black\|withOpacity" lib/screens/client/my_bookings_screen.dart
```

Replace all occurrences with adaptive equivalents.

- [ ] **Step 2: Run flutter analyze on all six files**

```bash
flutter analyze \
  lib/screens/client/my_bookings_screen.dart \
  lib/screens/shared/appointment_detail_widget.dart \
  lib/screens/shared/promo_detail_screen.dart \
  lib/screens/shared/service_detail_screen.dart \
  lib/screens/auth/login_screen.dart \
  lib/screens/auth/register_screen.dart
```

Expected: zero errors.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "fix(dark-theme): migrate my bookings, detail screens, and auth to adaptive colors"
```

---

## Task 8: Dark Theme — Admin Screens

**Files:**
- Modify: `lib/screens/admin/admin_schedule_screen.dart`
- Modify: `lib/screens/admin/appointments_screen.dart`
- Modify: `lib/screens/admin/add_edit_service_screen.dart`
- Modify: `lib/screens/admin/statistics_screen.dart`
- Modify: `lib/screens/admin/notes_screen.dart`
- Modify: `lib/screens/admin/logs_screen.dart`
- Modify: `lib/screens/admin/reports_shell_screen.dart` (and other admin files if they exist)

- [ ] **Step 1: Batch audit admin screens**

```bash
grep -rln "AppStyles.cardDecoration\|AppStyles.inputDecoration(\|AppStyles.textPrimary\|AppStyles.textSecondary\|Colors.white\|Colors.black\|withOpacity" lib/screens/admin/
```

This lists all admin files still using static colors. For each file, replace with adaptive equivalents.

- [ ] **Step 2: Verify no static patterns remain anywhere in lib/screens/**

```bash
grep -rln "AppStyles.cardDecoration\b" lib/screens/ || echo "Clean"
grep -rln "AppStyles.inputDecoration(" lib/screens/ || echo "Clean"
grep -rln "\.withOpacity(" lib/screens/ || echo "Clean"
```

Expected: `Clean` for all three.

- [ ] **Step 3: Run flutter analyze on admin folder**

```bash
flutter analyze lib/screens/admin/
```

Expected: zero errors.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "fix(dark-theme): migrate all admin screens to adaptive colors"
```

---

## Task 9: Split AppProvider — Extract AppointmentProvider

**Files:**
- Create: `lib/providers/appointment_provider.dart`
- Modify: `lib/providers/app_provider.dart`
- Modify: `lib/main.dart`
- Modify: `test/mocks.dart`

- [ ] **Step 1: Create AppointmentProvider**

Create `lib/providers/appointment_provider.dart`. Move all appointment-related state, methods, and pagination cache from `AppProvider` into this new class.

Key items to move:
- `List<Appointment> _appointments`
- `List<DateTime> _cacheDates`, `_cacheAppointments`, `_cacheTotalPages`
- `DateTime? _selectedDate`
- `bool _isLoadingAppointments`
- Methods: `fetchAppointments`, `addAppointment`, `updateAppointment`, `deleteAppointment`, `cancelAppointment`, `fetchBusySlots`, `setSelectedDate`, prefetch logic.

Keep `notifyListeners()` calls inside the new provider.

- [ ] **Step 2: Update AppProvider to forward/facade**

In `lib/providers/app_provider.dart`, remove the extracted fields/methods. Keep `AppProvider` as a thin ChangeNotifier that holds remaining domains (services, wash types, promos, notes, favorites) for now.

- [ ] **Step 3: Register in main.dart MultiProvider**

Open `lib/main.dart`. In the `MultiProvider` list, add:

```dart
ChangeNotifierProvider<AppointmentProvider>(create: (_) => AppointmentProvider()),
```

- [ ] **Step 4: Update test mocks**

Open `test/mocks.dart`. Add:

```dart
class MockAppointmentProvider extends Mock implements AppointmentProvider {}
```

- [ ] **Step 5: Run existing tests**

```bash
flutter test
```

Expected: all existing tests still pass (may need to update `MultiProvider` wrappers in tests that pump widgets).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: extract AppointmentProvider from AppProvider"
```

---

## Task 10: Split AppProvider — Extract CatalogProvider

**Files:**
- Create: `lib/providers/catalog_provider.dart`
- Modify: `lib/providers/app_provider.dart`
- Modify: `lib/main.dart`
- Modify: `test/mocks.dart`

- [ ] **Step 1: Create CatalogProvider**

Create `lib/providers/catalog_provider.dart`. Move from `AppProvider`:
- `List<Service> _services`
- `List<WashType> _washTypes`
- `List<Promo> _promos`
- `bool _isLoadingServices`, `_isLoadingWashTypes`, `_isLoadingPromos`
- Methods: `fetchServices`, `fetchWashTypes`, `fetchPromos`, `toggleFavoriteService`, `toggleFavoriteExtra`, etc. (anything related to catalog items).

- [ ] **Step 2: Update AppProvider, main.dart, mocks**

Same pattern as Task 9. Remove from `AppProvider`, register in `MultiProvider`, add mock.

- [ ] **Step 3: Run tests**

```bash
flutter test
```

Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: extract CatalogProvider from AppProvider"
```

---

## Task 11: Split AppProvider — Extract NoteProvider & FavoriteProvider

**Files:**
- Create: `lib/providers/note_provider.dart`
- Create: `lib/providers/favorite_provider.dart`
- Modify: `lib/providers/app_provider.dart`
- Modify: `lib/main.dart`
- Modify: `test/mocks.dart`

- [ ] **Step 1: Create NoteProvider**

Move notes + unread counts from `AppProvider`.

- [ ] **Step 2: Create FavoriteProvider**

Move favorites logic from `AppProvider` (if not already moved to `CatalogProvider`). If favorites are tightly coupled to catalog, keep them in `CatalogProvider` and skip `FavoriteProvider`.

- [ ] **Step 3: Update wiring and tests**

Register both in `main.dart`, add mocks, run `flutter test`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: extract NoteProvider and FavoriteProvider from AppProvider"
```

---

## Task 12: Const Audit & Final Verification

**Files:**
- All `lib/screens/**/*.dart`
- All `lib/widgets/**/*.dart`

- [ ] **Step 1: Add const where possible**

Run the Dart linter for const-related lints:

```bash
flutter analyze --fatal-infos
```

Address any `prefer_const_constructors`, `prefer_const_literals_to_create_immutables`, or `prefer_const_declarations` warnings by adding `const`.

Common targets:
- `SizedBox(height: 12)` → `const SizedBox(height: 12)`
- `EdgeInsets.all(16)` → `const EdgeInsets.all(16)`
- `BorderRadius.circular(12)` (in `const` contexts) — may need `const BorderRadius.all(Radius.circular(12))`
- `BoxDecoration()` without variables → `const BoxDecoration()`

- [ ] **Step 2: Run full test suite**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 3: Run flutter analyze project-wide**

```bash
flutter analyze
```

Expected: zero errors, zero warnings (or only warnings unrelated to this work).

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "perf: const audit and final cleanup for production prep"
```

---

## Self-Review Checklist

- [ ] **Spec coverage:** Every section of the design doc (car autocomplete, dark theme, provider split, const audit) has at least one task.
- [ ] **No placeholders:** No "TBD", "TODO", or vague steps remain.
- [ ] **Type consistency:** `CarCatalogService`, `CarAutocompleteField`, and provider names match across all tasks.
- [ ] **File paths:** All paths use the exact project structure (`lib/screens/client/`, `lib/providers/`, etc.).
- [ ] **Test coverage:** Each new service/widget has a corresponding test file.

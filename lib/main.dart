import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:expressions/expressions.dart';

// ==============================================================================
// Модель обязательного расхода
class MandatoryExpense {
  String description;
  double amount;
  MandatoryExpense({required this.description, required this.amount});

  Map<String, dynamic> toJson() => {'description': description, 'amount': amount};

  factory MandatoryExpense.fromJson(Map<String, dynamic> json) =>
      MandatoryExpense(description: json['description'], amount: (json['amount'] as num).toDouble());
}

// ==============================================================================
// Точка входа
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU');
  final prefs = await SharedPreferences.getInstance();
  final themeIndex = prefs.getInt('themeMode') ?? 0;
  runApp(MyApp(initialThemeMode: ThemeMode.values[themeIndex]));
}

// ==============================================================================

class MyApp extends StatefulWidget {
  final ThemeMode initialThemeMode;
  const MyApp({super.key, required this.initialThemeMode});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool? _hasData;
  late ValueNotifier<ThemeMode> themeNotifier;

  @override
  void initState() {
    super.initState();
    themeNotifier = ValueNotifier(widget.initialThemeMode);
    _checkHasData();
  }

  Future<void> _checkHasData() async {
    final prefs = await SharedPreferences.getInstance();
    final hasBudget = prefs.containsKey('budget');
    final hasExpenses = prefs.containsKey('expenses');
    final hasStartDay = prefs.containsKey('startDayOfMonth');
    setState(() {
      _hasData = hasBudget && hasExpenses && hasStartDay;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasData == null) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Cash & Coffee',
          locale: const Locale('ru', 'RU'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ru', 'RU'),
          ],
          theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.lightGreen,
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          iconTheme: IconThemeData(color: Color(0xFF313D65)),
          titleTextStyle: TextStyle(
            color: Color(0xFF313D65),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardColor: const Color(0xFFF5F4EF),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF313D65)),
          bodyMedium: TextStyle(color: Color(0xFF313D65)),
          titleLarge: TextStyle(color: Color(0xFF313D65), fontWeight: FontWeight.bold),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF222421),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF222421),
          iconTheme: IconThemeData(color: Color(0xFF72695A)),
          titleTextStyle: TextStyle(
            color: Color(0xFF72695A),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardColor: const Color(0xFF72695A),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF72695A)),
          bodyMedium: TextStyle(color: Color(0xFF72695A)),
          titleLarge: TextStyle(color: Color(0xFF72695A), fontWeight: FontWeight.bold),
        ),
      ),
      themeMode: mode,
      home: _hasData!
          ? CalendarScreenLoader(themeNotifier: themeNotifier)
          : BudgetInputScreen(themeNotifier: themeNotifier),
        );
      },
    );
  }
}

// ==============================================================================
// Экран для ввода бюджета и расходов

class BudgetInputScreen extends StatefulWidget {
  final ValueNotifier<ThemeMode> themeNotifier;
  const BudgetInputScreen({super.key, required this.themeNotifier});

  @override
  State<BudgetInputScreen> createState() => _BudgetInputScreenState();
}

class _BudgetInputScreenState extends State<BudgetInputScreen> {
  final TextEditingController _budgetController = TextEditingController();
  final List<MandatoryExpense> _expenses = [];
  int _startDayOfMonth = 1;

  @override
  void initState() {
    super.initState();
    _addExpense();
  }

  void _addExpense() {
    setState(() {
      _expenses.add(MandatoryExpense(description: '', amount: 0));
    });
  }

  double get totalMandatory => _expenses.fold(0, (sum, e) => sum + (e.amount));

  bool _validateInputs() {
    if (double.tryParse(_budgetController.text) == null) {
      _showError('Введите корректный бюджет');
      return false;
    }
    for (var e in _expenses) {
      if (e.description.trim().isEmpty) {
        _showError('Введите описание для всех обязательных расходов');
        return false;
      }
      if (e.amount <= 0) {
        _showError('Введите сумму больше 0 для всех обязательных расходов');
        return false;
      }
    }
    return true;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _saveAndGoToCalendar() async {
    final prefs = await SharedPreferences.getInstance();
    final budget = double.parse(_budgetController.text);
    await prefs.setDouble('budget', budget);
    await prefs.setInt('startDayOfMonth', _startDayOfMonth);
    List<String> expensesJson = _expenses.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('expenses', expensesJson);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CalendarScreenLoader(themeNotifier: widget.themeNotifier),
      ),
    );
  }

  Future<void> _selectStartDay() async {
    final controller = TextEditingController(text: _startDayOfMonth.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите день начала месяца (когда у тебя приходит зп)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'День (1-31)'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val >= 1 && val <= 31) {
                Navigator.pop(context, val);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Введите корректный день')),
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() {
        _startDayOfMonth = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFE7D1C5) : const Color(0xFF313D65);
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
            title: Text(
          'Введите бюджет и расходы',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFE7D1C5)
              : const Color(0xFF313D65),
          ),
        ),
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFE7D1C5)
            : const Color(0xFF313D65),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.light
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
            onPressed: () {
              widget.themeNotifier.value =
                  widget.themeNotifier.value == ThemeMode.light
                      ? ThemeMode.dark
                      : ThemeMode.light;
              SharedPreferences.getInstance().then((prefs) {
                prefs.setInt('themeMode', ThemeMode.values.indexOf(widget.themeNotifier.value));
              });
            },
          ),
        ],
      ),
      body: Center(
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: DefaultTextStyle(
      style: TextStyle(color: textColor),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Какой у вас бюджет на месяц?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: SizedBox(
              width: screenWidth / 3,
              child: TextField(
                controller: _budgetController,
                decoration: InputDecoration(
                  labelText: 'Посмотрим, какой ты Скрудж Макдак',
                  labelStyle: TextStyle(color: textColor.withOpacity(0.6)),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF72695A) // для тёмной темы
                : null, // для светлой темы — по умолчанию, как сейчас
            ),
            onPressed: _selectStartDay,
            icon: Icon(Icons.settings, color: textColor),
            label: Text(
              'Выберите день начала месяца (когда у тебя приходит зп) ($_startDayOfMonth)',
              style: TextStyle(color: textColor.withOpacity(0.8)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Введите обязательные расходы:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _expenses.length,
            itemBuilder: (context, index) {
              final exp = _expenses[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: screenWidth / 3,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Описание',
                          hintStyle: TextStyle(color: textColor.withOpacity(0.6)),
                          border: const OutlineInputBorder(),
                        ),
                        style: TextStyle(color: textColor),
                        onChanged: (v) => exp.description = v,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: screenWidth / 6,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Сумма',
                          hintStyle: TextStyle(color: textColor.withOpacity(0.6)),
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textColor),
                        onChanged: (v) {
                          exp.amount = double.tryParse(v) ?? 0;
                          setState(() {});
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, 
                      color: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF72695A) // для темной темы
                                      : const Color(0xFF313D65), // для светлой темы
                                ),
                      onPressed: () {
                        setState(() {
                          _expenses.removeAt(index);
                        });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _addExpense,
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить расход'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Сумма обязательных расходов: ${totalMandatory.toStringAsFixed(2)} ₽',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (_validateInputs()) {
                      _saveAndGoToCalendar();
                    }
                  },
                  child: const Text('Далее'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// Загрузчик данных для CalendarScreen

class CalendarScreenLoader extends StatefulWidget {
  final ValueNotifier<ThemeMode> themeNotifier;

  const CalendarScreenLoader({super.key, required this.themeNotifier});

  @override
  State<CalendarScreenLoader> createState() => _CalendarScreenLoaderState();
}

class _CalendarScreenLoaderState extends State<CalendarScreenLoader> {
  double? budget;
  int? startDayOfMonth;
  List<MandatoryExpense>? expenses;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final b = prefs.getDouble('budget');
    final s = prefs.getInt('startDayOfMonth');
    final e = prefs.getStringList('expenses');
    if (b != null && s != null && e != null) {
      setState(() {
        budget = b;
        startDayOfMonth = s;
        expenses = e.map((str) => MandatoryExpense.fromJson(jsonDecode(str))).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (budget == null || startDayOfMonth == null || expenses == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return CalendarScreen(
      initialBudget: budget!,
      initialExpenses: expenses!,
      startDayOfMonth: startDayOfMonth!,
      themeNotifier: widget.themeNotifier,
    );
  }
}

// ==============================================================================
// Экран календаря

class CalendarScreen extends StatefulWidget {
  final double initialBudget;
  final List<MandatoryExpense> initialExpenses;
  final int startDayOfMonth;
  final ValueNotifier<ThemeMode> themeNotifier;

  const CalendarScreen({
    super.key,
    required this.initialBudget,
    required this.initialExpenses,
    required this.startDayOfMonth,
    required this.themeNotifier,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late double monthlyBudget;
  late List<MandatoryExpense> expenses;
  Map<DateTime, double> _spentPerDay = {};
  late int startDayOfMonth;

  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _today = DateTime.now();

  @override
  void initState() {
    super.initState();
    monthlyBudget = widget.initialBudget;
    expenses = List.from(widget.initialExpenses);
    startDayOfMonth = widget.startDayOfMonth;
    final daysInCurrentMonth = DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day;
    final startDay = startDayOfMonth <= daysInCurrentMonth ? startDayOfMonth : daysInCurrentMonth;
    _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, startDay);
    _loadSpent();
  }

  Future<void> _loadSpent() async {
    final prefs = await SharedPreferences.getInstance();
    final spentRaw = prefs.getString('spentPerDay');
    if (spentRaw != null) {
      final map = (jsonDecode(spentRaw) as Map<String, dynamic>);
      setState(() {
        _spentPerDay = map.map((k, v) => MapEntry(DateTime.parse(k), (v as num).toDouble()));
      });
    }
  }

  Future<void> _saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('budget', monthlyBudget);
    await prefs.setInt('startDayOfMonth', startDayOfMonth);
    await prefs.setStringList('expenses', expenses.map((e) => jsonEncode(e.toJson())).toList());
    await prefs.setString(
      'spentPerDay',
      jsonEncode(_spentPerDay.map((k, v) => MapEntry(k.toIso8601String(), v))),
    );
  }
  double get mandatoryTotal => expenses.fold(0, (sum, e) => sum + e.amount);

  void nextMonth() {
    setState(() {
      final next = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
      final daysInNext = DateTime(next.year, next.month + 1, 0).day;
      final day = startDayOfMonth <= daysInNext ? startDayOfMonth : daysInNext;
      _focusedMonth = DateTime(next.year, next.month, day);
    });
    _saveAll();
  }

  void previousMonth() {
    setState(() {
      final prev = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
      final daysInPrev = DateTime(prev.year, prev.month + 1, 0).day;
      final day = startDayOfMonth <= daysInPrev ? startDayOfMonth : daysInPrev;
      _focusedMonth = DateTime(prev.year, prev.month, day);
    });
    _saveAll();
  }

  Future<void> _editSpentForDay(DateTime day) async {
  final controller = TextEditingController(
    text: _spentPerDay[day]?.toString() ?? '',
  );

  final result = await showDialog<double>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Введите сумму расходов за ${DateFormat('dd.MM.yyyy').format(day)}'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.text, // текст, чтобы можно было вводить выражения
        decoration: InputDecoration(
          labelText: 'Введите сумму или воспользуйтесь, как калькулятором',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () {
            try {
              final expression = Expression.parse(controller.text);
              final evaluator = const ExpressionEvaluator();
              final value = evaluator.eval(expression, {});
              if (value is num) {
                Navigator.pop(context, value.toDouble());
              } else {
                throw Exception('Результат не число');
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Ошибка в выражении: ${e.toString()}')),
              );
            }
          },
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );

  if (result != null) {
    setState(() {
      _spentPerDay[day] = result;
    });
    _saveAll();
  }
}


Widget _buildWeekDaysHeader() {
  final days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    decoration: BoxDecoration(
      color: isDark
          ? const Color(0xFF75635A) // Тёмная тема: золотистый
          : const Color(0xFF3E5543), // Светлая тема: синий
      borderRadius: BorderRadius.circular(6),
    ),
    margin: const EdgeInsets.symmetric(vertical: 4),
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: days
          .map(
            (d) => Expanded(
              child: Center(
                child: Text(
                  d,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFE7D1C5) // Тёмная тема: бежевый
                        : Colors.white,            // Светлая тема: белый
                  ),
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
}



  Widget _buildCalendar() {
    final daysInCurrentMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final startDay = startDayOfMonth <= daysInCurrentMonth ? startDayOfMonth : daysInCurrentMonth;

    final startDate = _focusedMonth;
    final nextMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    final daysInNextMonth = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
    final endDay = startDay <= daysInNextMonth ? startDay : daysInNextMonth;
    final endDate = DateTime(nextMonth.year, nextMonth.month, endDay).subtract(const Duration(days: 1));
    final daysCount = endDate.difference(startDate).inDays + 1;

    List<Widget> dayWidgets = [];
    int leadingEmptyCells = startDate.weekday - 1;

    for (int i = 0; i < leadingEmptyCells; i++) {
      dayWidgets.add(const Expanded(child: SizedBox()));
    }

    double dailyBaseBudget = ((monthlyBudget - mandatoryTotal) / daysCount);
    double rollover = 0;
    DateTime todayDateOnly = DateTime(_today.year, _today.month, _today.day);
    DateTime tomorrowDateOnly = todayDateOnly.add(const Duration(days: 1));

    for (int i = 0; i < daysCount; i++) {
      DateTime currentDay = startDate.add(Duration(days: i));
      DateTime currentDayDateOnly = DateTime(currentDay.year, currentDay.month, currentDay.day);

      double budgetForDay = dailyBaseBudget + rollover;
      double spentToday = _spentPerDay[currentDayDateOnly] ?? 0;
      double diff = budgetForDay - spentToday;
      rollover = diff;

      bool showDetails = !currentDayDateOnly.isAfter(tomorrowDateOnly);

      dayWidgets.add(
        Expanded(
          child: GestureDetector(
            onTap: () => _editSpentForDay(currentDayDateOnly),
            child: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: (currentDay.weekday == DateTime.saturday || currentDay.weekday == DateTime.sunday)
                  ? (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF354B46) // Тёмная тема: зелёный
                      : const Color(0xFFD7E8D5)) // Светлая тема: светло-зелёный
                  : Theme.of(context).cardColor,

              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    currentDay.day.toString(),
                   style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Color(0xFFE7D1C5)
                        : const Color(0xFF313D65),
                  ),
                ),
                  const SizedBox(height: 4),
                  if (showDetails) ...[
                    Text(
                      '${budgetForDay.toInt()} ₽',
                      style: TextStyle(
                        
                        fontSize: 16,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFE7D1C5)
                            : const Color(0xFF313D65),
                      ),
                    ),

                    const SizedBox(height: 4),
                    Text(
                      '${spentToday.toInt()} ₽',
                      style: TextStyle(
                      
                        fontSize: 18,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFE7D1C5)
                            : const Color(0xFF313D65),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (!currentDayDateOnly.isAtSameMomentAs(tomorrowDateOnly))
                      Text(
                        diff >= 0 ? '+${diff.toInt()}' : '${diff.toInt()}',
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? (diff >= 0
                                  ? const Color.fromARGB(255, 174, 212, 124) // для положительных в тёмной теме
                                  : const Color.fromARGB(255, 251, 122, 102)) // для отрицательных в тёмной теме
                              : (diff >= 0
                                  ? const Color(0xFF346E4F) // для положительных в светлой теме
                                  : const Color(0xFF652918)), // для отрицательных в светлой теме
                        ),
                      ),

                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    while (dayWidgets.length % 7 != 0) {
      dayWidgets.add(const Expanded(child: SizedBox()));
    }

    List<Widget> rows = [];
    for (int i = 0; i < dayWidgets.length; i += 7) {
      rows.add(Row(children: dayWidgets.sublist(i, i + 7)));
    }

    return Column(children: rows);
  }

  Future<void> _editBudget() async {
    final controller = TextEditingController(text: monthlyBudget.toStringAsFixed(2));
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменить бюджет'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Бюджет (₽)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                Navigator.pop(context, val);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Введите корректное число')),
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() {
        monthlyBudget = result;
      });
      _saveAll();
    }
  }

  Future<void> _editExpenses() async {
    List<MandatoryExpense> editedExpenses = expenses
        .map(
          (e) => MandatoryExpense(description: e.description, amount: e.amount),
        )
        .toList();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            double total() => editedExpenses.fold(0, (sum, e) => sum + e.amount);

            void addExpense() {
              setStateDialog(() {
                editedExpenses.add(
                  MandatoryExpense(description: '', amount: 0),
                );
              });
            }

            void removeExpense(int index) {
              setStateDialog(() {
                editedExpenses.removeAt(index);
              });
            }

            return AlertDialog(
              title: const Text('Изменить обязательные расходы'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...editedExpenses.asMap().entries.map((entry) {
                        int idx = entry.key;
                        MandatoryExpense exp = entry.value;
                        final descriptionController = TextEditingController(text: exp.description);
                        final amountController = TextEditingController(text: exp.amount.toString());
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  decoration: const InputDecoration(
                                    hintText: 'Описание',
                                    border: OutlineInputBorder(),
                                  ),
                                  controller: descriptionController,
                                  onChanged: (v) {
                                    exp.description = v;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  decoration: const InputDecoration(
                                    hintText: 'Сумма',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  controller: amountController,
                                  onChanged: (v) {
                                    exp.amount = double.tryParse(v) ?? 0;
                                    setStateDialog(() {});
                                  },
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF72695A) // для темной темы
                                      : const Color(0xFF313D65), // для светлой темы
                                ),
                                onPressed: () => removeExpense(idx),
                              ),
                            ],
                          ),
                        );
                      }),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: addExpense,
                          icon: const Icon(Icons.add),
                          label: const Text('Добавить расход'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Сумма обязательных расходов: ${total().toStringAsFixed(2)} ₽',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    bool valid = true;
                    for (var e in editedExpenses) {
                      if (e.description.trim().isEmpty || e.amount <= 0) {
                        valid = false;
                        break;
                      }
                    }
                    if (!valid) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Заполните все поля корректно'),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context, editedExpenses);
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    ).then((value) {
      if (value != null && value is List<MandatoryExpense>) {
        setState(() {
          expenses = value;
        });
        _saveAll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final dailyBaseBudget = ((monthlyBudget - mandatoryTotal) / daysInMonth);

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => BudgetInputScreen(themeNotifier: widget.themeNotifier)),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => BudgetInputScreen(themeNotifier: widget.themeNotifier)),
              );
            },
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF222421)
                            : const Color(0xFFFFFFFF),
          elevation: 0,
          iconTheme: IconThemeData(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF313D65),
          ),
          title: Text(
            DateFormat.yMMMM('ru').format(_focusedMonth),
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFE7D1C5)
                            : const Color(0xFF313D65),
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Theme.of(context).brightness == Brightness.light
                    ? Icons.dark_mode
                    : Icons.light_mode,
              ),
              onPressed: () {
                widget.themeNotifier.value =
                    widget.themeNotifier.value == ThemeMode.light
                        ? ThemeMode.dark
                        : ThemeMode.light;
                SharedPreferences.getInstance().then((prefs) {
                  prefs.setInt('themeMode', ThemeMode.values.indexOf(widget.themeNotifier.value));
                });
              },
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF313D65),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(
                    onTap: _editBudget,
                    child: Column(
                      children: [
                        Text(
                          'Бюджет на месяц',
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFE7D1C5)
                                : const Color(0xFF313D65),
                          ),
                        ),
                        Text(
                          '${monthlyBudget.toStringAsFixed(2)} ₽',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFE7D1C5)
                                : const Color(0xFF313D65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _editExpenses,
                    child: Column(
                      children: [
                        Text(
                          'Обязательные расходы',
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFE7D1C5)
                                : const Color(0xFF313D65),
                          ),
                        ),
                        Text(
                          '${mandatoryTotal.toStringAsFixed(2)} ₽',
                          style: TextStyle(
                           
                            fontSize: 18,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFE7D1C5)
                                : const Color(0xFF313D65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
            children: [
              Text(
                'Бюджет на день',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFE7D1C5)
                      : const Color(0xFF313D65),
                ),
              ),
                      Text(
                '${dailyBaseBudget.toStringAsFixed(2)} ₽',
                style: TextStyle(
                  
                  fontSize: 18,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFE7D1C5)
                      : const Color(0xFF313D65),
                ),
              ),
            ],
                  ),
                ],
              ),
            ),
            Padding(
  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFE7D1C5)
              : const Color(0xFF313D65),
        ),
        onPressed: previousMonth,
      ),
      Text(
        DateFormat.yMMMM('ru').format(_focusedMonth),
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFE7D1C5)
              : const Color(0xFF313D65),
        ),
      ),
      IconButton(
        icon: Icon(
          Icons.arrow_forward,
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFE7D1C5)
              : const Color(0xFF313D65),
        ),
        onPressed: nextMonth,
      ),
    ],
  ),
),

            _buildWeekDaysHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: _buildCalendar(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

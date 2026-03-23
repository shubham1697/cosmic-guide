import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/starry_background.dart';

class KundliScreen extends StatefulWidget {
  const KundliScreen({super.key});

  @override
  State<KundliScreen> createState() => _KundliScreenState();
}

class _KundliScreenState extends State<KundliScreen> {
  final _nameController1 = TextEditingController();
  final _nameController2 = TextEditingController();
  DateTime? _dob1;
  DateTime? _dob2;
  TimeOfDay? _time1;
  TimeOfDay? _time2;
  final _placeController1 = TextEditingController();
  final _placeController2 = TextEditingController();
  dynamic _result;
  bool _isCalculating = false;

  @override
  void dispose() {
    _nameController1.dispose();
    _nameController2.dispose();
    _placeController1.dispose();
    _placeController2.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFirst) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(1995),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accent,
              surface: AppColors.card,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        if (isFirst) {
          _dob1 = date;
        } else {
          _dob2 = date;
        }
      });
    }
  }

  Future<void> _pickTime(bool isFirst) async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accent,
              surface: AppColors.card,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        if (isFirst) {
          _time1 = time;
        } else {
          _time2 = time;
        }
      });
    }
  }

  Future<void> _calculateKundli() async {
    setState(() => _isCalculating = true);
    final result = await ApiService.calculateKundli(
      name1: _nameController1.text,
      birthDate1: DateFormat('yyyy-MM-dd').format(_dob1!),
      birthTime1: _time1 != null
          ? '${_time1!.hour}:${_time1!.minute.toString().padLeft(2, '0')}'
          : null,
      birthPlace1: _placeController1.text.isNotEmpty
          ? _placeController1.text
          : null,
      name2: _nameController2.text,
      birthDate2: DateFormat('yyyy-MM-dd').format(_dob2!),
      birthTime2: _time2 != null
          ? '${_time2!.hour}:${_time2!.minute.toString().padLeft(2, '0')}'
          : null,
      birthPlace2: _placeController2.text.isNotEmpty
          ? _placeController2.text
          : null,
    );
    if (mounted) {
      setState(() {
        _result = result;
        _isCalculating = false;
      });
    }
  }

  bool get _isFormValid =>
      _nameController1.text.isNotEmpty &&
      _nameController2.text.isNotEmpty &&
      _dob1 != null &&
      _dob2 != null &&
      _placeController1.text.isNotEmpty &&
      _placeController2.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return StarryBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Kundli Matching', style: GoogleFonts.playfairDisplay()),
          backgroundColor: Colors.transparent,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Gun Milan',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ashta Koota compatibility analysis',
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 32),
              _buildPersonForm(
                'Person 1',
                _nameController1,
                _dob1,
                _time1,
                _placeController1,
                true,
              ),
              const SizedBox(height: 20),
              _buildPersonForm(
                'Person 2',
                _nameController2,
                _dob2,
                _time2,
                _placeController2,
                false,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isFormValid && !_isCalculating)
                      ? _calculateKundli
                      : null,
                  icon: _isCalculating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(Icons.calculate),
                  label: Text(
                    _isCalculating ? 'Calculating...' : 'Calculate Kundli',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_result != null) _buildResultSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonForm(
    String label,
    TextEditingController nameController,
    DateTime? dob,
    TimeOfDay? time,
    TextEditingController placeController,
    bool isFirst,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mysticTeal.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.mysticTeal,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nameController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Full Name',
              prefixIcon: Icon(Icons.person, color: AppColors.textMuted),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(isFirst),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.textMuted.withAlpha(51),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dob != null
                              ? '${dob.day}/${dob.month}/${dob.year}'
                              : 'Birth Date',
                          style: TextStyle(
                            color: dob != null
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickTime(isFirst),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.textMuted.withAlpha(51),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          time != null ? time.format(context) : 'Birth Time',
                          style: TextStyle(
                            color: time != null
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: placeController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Birth Place',
              prefixIcon: Icon(Icons.location_on, color: AppColors.textMuted),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection() {
    final kootaMaxScores = {
      'Varna': 1,
      'Vashya': 2,
      'Tara': 3,
      'Yoni': 4,
      'Graha Maitri': 5,
      'Gana': 6,
      'Bhakoot': 7,
      'Nadi': 8,
    };

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppColors.gradientCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.mysticTeal.withAlpha(77)),
          ),
          child: Column(
            children: [
              Text(
                '${_result.totalScore}/${_result.maxScore}',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: _result.totalScore >= 24
                      ? AppColors.health
                      : AppColors.accent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _result.compatibility,
                style: TextStyle(
                  color: _result.totalScore >= 24
                      ? AppColors.health
                      : AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),
              ...(_result.kootaScores as Map<String, int>).entries.map((entry) {
                final max = kootaMaxScores[entry.key] ?? 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: entry.value / max,
                            backgroundColor: AppColors.surface,
                            color: entry.value == max
                                ? AppColors.health
                                : AppColors.accent,
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${entry.value}/$max',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_result.hasManglikDosha) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withAlpha(77)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber, color: AppColors.error),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Manglik Dosha detected. Consult an astrologer for remedies.',
                    style: TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: AppColors.mysticTeal,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Analysis',
                    style: TextStyle(
                      color: AppColors.mysticTeal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _result.analysis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

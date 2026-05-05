import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';

/// A text field that fetches city suggestions from the Open-Meteo Geocoding
/// API and requires the user to select a city from the dropdown list.
///
/// [onCitySelected] is called with the selected city string when the user
/// picks an option, or with `null` when the field is cleared / the user
/// starts typing without having confirmed a selection.
class CityAutocompleteField extends StatefulWidget {
  final String? initialValue;
  final String hintText;
  final ValueChanged<String?> onCitySelected;
  final ValueChanged<String>? onRawTextChanged;

  /// When true, shows an error border if text is present but no city has been
  /// confirmed from the suggestions list.
  final bool showValidationError;

  const CityAutocompleteField({
    super.key,
    this.initialValue,
    this.hintText = 'Search city…',
    required this.onCitySelected,
    this.onRawTextChanged,
    this.showValidationError = false,
  });

  @override
  State<CityAutocompleteField> createState() => _CityAutocompleteFieldState();
}

class _CityAutocompleteFieldState extends State<CityAutocompleteField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  bool _loading = false;
  bool _isDirty = false; // true = user typed without confirming a selection
  List<String> _options = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
      _controller.text = widget.initialValue!;
      // Pre-filled value is treated as already confirmed.
    }
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    widget.onRawTextChanged?.call(text);
    if (text.isEmpty) {
      widget.onCitySelected(null);
      setState(() {
        _isDirty = false;
        _options = [];
        _loading = false;
      });
      _debounce?.cancel();
      return;
    }

    // Mark as dirty — user is editing, so any previous confirmed selection is gone.
    if (!_isDirty) {
      setState(() => _isDirty = true);
      widget.onCitySelected(null);
    }

    _debounce?.cancel();
    if (text.length < 2) return;

    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _fetchCities(text),
    );
  }

  Future<void> _fetchCities(String query) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final uri = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search'
        '?name=${Uri.encodeComponent(query)}&count=8&language=en&format=json',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final results = (data['results'] as List?) ?? [];
        final options = results.map<String>((dynamic r) {
          final map = r as Map<String, dynamic>;
          final parts = <String>[map['name'] as String];
          final admin1 = map['admin1'] as String?;
          if (admin1 != null && admin1 != map['name']) {
            parts.add(admin1);
          }
          parts.add(map['country'] as String);
          return parts.join(', ');
        }).toList();
        setState(() {
          _options = options;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectCity(String city) {
    _controller.removeListener(_onTextChanged);
    _controller.text = city;
    _controller.selection = TextSelection.collapsed(offset: city.length);
    _controller.addListener(_onTextChanged);

    setState(() {
      _isDirty = false;
      _options = [];
      _loading = false;
    });
    widget.onCitySelected(city);
    _focusNode.unfocus();
    _debounce?.cancel();
  }

  void _clearField() {
    _controller.clear();
    widget.onCitySelected(null);
    setState(() {
      _isDirty = false;
      _options = [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasError =
        widget.showValidationError && _isDirty && _controller.text.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: const Icon(
              Icons.location_on_outlined,
              color: AppColors.accent,
            ),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    ),
                  )
                : (_controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.textMuted,
                            size: 18,
                          ),
                          onPressed: _clearField,
                        )
                      : null),
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.textMuted.withAlpha(77)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError
                    ? Colors.orange.withAlpha(180)
                    : AppColors.textMuted.withAlpha(77),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError ? Colors.orange : AppColors.accent,
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: const [
                Icon(Icons.info_outline, color: Colors.orange, size: 13),
                SizedBox(width: 4),
                Text(
                  'Please select a city from the suggestions list',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ],
            ),
          ),
        if (_options.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.textMuted.withAlpha(51)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(60),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              shrinkWrap: true,
              itemCount: _options.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: AppColors.textMuted.withAlpha(30)),
              itemBuilder: (_, i) => ListTile(
                dense: true,
                leading: const Icon(
                  Icons.place_outlined,
                  color: AppColors.accent,
                  size: 18,
                ),
                title: Text(
                  _options[i],
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                onTap: () => _selectCity(_options[i]),
              ),
            ),
          ),
      ],
    );
  }
}

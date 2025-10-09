import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class GenerativeFilterOptions extends StatefulWidget {
  final String? selectedSeason;
  final List<String> seasonsList;
  final Function(String?) onSeasonChanged;

  final List<String> selectedWeekOfGenerative;
  final List<String> weekOfGenerativeList;
  final Function(List<String>) onWeekOfGenerativeChanged;

  final List<String> selectedFA;
  final List<String> faNames;
  final Function(List<String>) onFAChanged;

  final List<String> selectedFIs;
  final List<String> fiNames;
  final Function(List<String>) onFIChanged;

  final VoidCallback onResetAll;
  final VoidCallback onApplyFilters;

  final bool initialShowDiscardedFase;
  final Function(bool) onShowDiscardedFaseChanged;

  const GenerativeFilterOptions({
    super.key,
    this.selectedSeason,
    required this.seasonsList,
    required this.onSeasonChanged,
    required this.selectedWeekOfGenerative,
    required this.weekOfGenerativeList,
    required this.onWeekOfGenerativeChanged,
    required this.selectedFA,
    required this.faNames,
    required this.onFAChanged,
    required this.selectedFIs,
    required this.fiNames,
    required this.onFIChanged,
    required this.onResetAll,
    required this.onApplyFilters,
    required this.initialShowDiscardedFase, // Parameter baru
    required this.onShowDiscardedFaseChanged, // Callback baru
  });

  @override
  State<GenerativeFilterOptions> createState() => _GenerativeFilterOptionsState();
}

class _GenerativeFilterOptionsState extends State<GenerativeFilterOptions> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late bool _localShowDiscardedFase;

  String? _selectedSeason;
  List<String> _selectedWeeks = [];
  List<String> _selectedFA = [];
  List<String> _selectedFIs = [];

  @override
  void initState() {
    super.initState();

    _selectedSeason = widget.selectedSeason;
    _selectedWeeks = List.from(widget.selectedWeekOfGenerative); // Buat salinan
    _selectedFA = List.from(widget.selectedFA); // Buat salinan
    _selectedFIs = List.from(widget.selectedFIs); // Buat salinan
    _localShowDiscardedFase = widget.initialShowDiscardedFase;

    // Set up animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(51),
                blurRadius: 15,
                spreadRadius: 5,
              ),
            ],
          ),
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 16),

              // Header with animation
              _buildHeader(),

              // Filter content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    top: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                    left: 24,
                    right: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Filter count
                      _buildFilterCount(),
                      const SizedBox(height: 24),

                      _buildFilterSection(
                        title: 'FASE Status',
                        subtitle: 'Include fields marked as "Discard"',
                        child: _buildShowDiscardedFaseFilter(),
                      ),
                      const SizedBox(height: 32),

                      // Season filter
                      _buildFilterSection(
                        title: 'Season',
                        subtitle: 'Select growing season',
                        child: _buildSeasonFilter(),
                      ),
                      const SizedBox(height: 32),

                      // Week filter
                      _buildFilterSection(
                        title: 'Week of Generative',
                        subtitle: 'Filter by specific week',
                        child: _buildWeekFilter(),
                      ),
                      const SizedBox(height: 32),

                      // FA filter
                      _buildFilterSection(
                        title: 'Field Assistant (FA)',
                        subtitle: 'Filter by field personnel',
                        child: _buildFAFilter(),
                      ),
                      const SizedBox(height: 32),

                      // FI filter
                      _buildFilterSection(
                        title: 'Field Inspector (FI)',
                        subtitle: 'Filter by field inspector',
                        child: _buildFIFilter(),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // Action buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade800],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withAlpha(76),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.filter_alt_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter Options',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedOpacity(
                  opacity: _hasActiveFilters() ? 1.0 : 0.7,
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _hasActiveFilters()
                        ? 'Active filters applied'
                        : 'No filters currently active',
                    style: TextStyle(
                      color: Colors.white.withAlpha(204),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCount() {
    int count = 0;
    if (_selectedSeason != null) count++;
    if (_selectedWeeks.isNotEmpty) count++;
    if (_selectedFA.isNotEmpty) count++;
    if (_selectedFIs.isNotEmpty) count++;
    if (_localShowDiscardedFase) count++;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: count > 0 ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: count > 0 ? Colors.green.shade300 : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            count > 0 ? Icons.filter_list_alt : Icons.filter_alt_off,
            color: count > 0 ? Colors.green.shade700 : Colors.grey.shade700,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              count > 0
                  ? '$count filter${count > 1 ? 's' : ''} active'
                  : 'No filters active',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: count > 0 ? Colors.green.shade700 : Colors.grey.shade700,
              ),
            ),
          ),
          if (count > 0)
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedSeason = null;
                  _selectedWeeks.clear();
                  _selectedFA.clear();
                  _selectedFIs.clear();
                  _localShowDiscardedFase = false; // Reset ke default
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Clear All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return _selectedSeason != null ||
        _selectedWeeks.isNotEmpty ||
        _selectedFA.isNotEmpty ||
        _selectedFIs.isNotEmpty ||
        _localShowDiscardedFase; //Jika ingin switch "Show Discard FASE" dianggap sebagai filter aktif
  }

  Widget _buildFilterSection({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildSeasonFilter() {
    return _buildDropdownFilter(
      value: _selectedSeason,
      items: ['All'] + widget.seasonsList,
      icon: Icons.calendar_today,
      hintText: 'Select Growing Season',
      onChanged: (value) {
        setState(() {
          _selectedSeason = value == 'All' ? null : value;
        });
      },
    );
  }

  Widget _buildWeekFilter() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
        gradient: LinearGradient(
          colors: [
            Colors.white,
            _selectedWeeks.isNotEmpty ? Colors.green.shade50 : Colors.grey.shade50
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(
          color: _selectedWeeks.isNotEmpty ? Colors.green.shade300 : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Row(
            children: [
              Icon(
                Icons.date_range,
                color: _selectedWeeks.isNotEmpty ? Colors.green.shade700 : Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedWeeks.isEmpty
                      ? 'Select Week of Generative'
                      : '${_selectedWeeks.length} Week${_selectedWeeks.length > 1 ? 's' : ''} selected',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: _selectedWeeks.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                    color: _selectedWeeks.isNotEmpty ? Colors.green.shade700 : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _selectedWeeks.isNotEmpty ? Colors.green.shade100 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.expand_more,
              color: _selectedWeeks.isNotEmpty ? Colors.green.shade700 : Colors.grey.shade700,
              size: 16,
            ),
          ),
          children: [
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(12),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Week list with scrollbar
                  Flexible(
                    child: Scrollbar(
                      thumbVisibility: true,
                      radius: const Radius.circular(8),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(8),
                        shrinkWrap: true,
                        itemCount: widget.weekOfGenerativeList.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = widget.weekOfGenerativeList[index];
                          final isSelected = _selectedWeeks.contains(item);

                          return CheckboxListTile(
                            title: Text(
                              item,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.green.shade700 : Colors.black87,
                              ),
                            ),
                            value: isSelected,
                            activeColor: Colors.green.shade600,
                            checkColor: Colors.white,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedWeeks.add(item);
                                } else {
                                  _selectedWeeks.remove(item);
                                }
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            visualDensity: VisualDensity.compact,
                            tileColor: isSelected ? Colors.green.withAlpha(15) : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Quick selection buttons
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedWeeks = List.from(widget.weekOfGenerativeList);
                            });
                          },
                          icon: Icon(Icons.select_all, color: Colors.green.shade700, size: 16),
                          label: Text(
                            'Select All',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedWeeks.clear();
                            });
                          },
                          icon: Icon(Icons.deselect, color: Colors.red.shade700, size: 16),
                          label: Text(
                            'Clear All',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String? value,
    required List<String> items,
    required IconData icon,
    required String hintText,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
        gradient: LinearGradient(
          colors: [Colors.white, value != null ? Colors.green.shade50 : Colors.grey.shade50],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(
          color: value != null ? Colors.green.shade300 : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton2<String>(
          value: value,
          hint: Row(
            children: [
              Icon(icon, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hintText,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          isExpanded: true,
          buttonStyleData: ButtonStyleData(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          iconStyleData: IconStyleData(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: value != null ? Colors.green.shade100 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.expand_more,
                color: value != null ? Colors.green.shade700 : Colors.grey.shade700,
                size: 16,
              ),
            ),
          ),
          dropdownStyleData: DropdownStyleData(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            offset: const Offset(0, -10),
            scrollbarTheme: ScrollbarThemeData(
              radius: const Radius.circular(8),
              thickness: WidgetStateProperty.all(6),
              thumbVisibility: WidgetStateProperty.all(true),
            ),
          ),
          menuItemStyleData: MenuItemStyleData(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            selectedMenuItemBuilder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: child,
              );
            },
          ),
          items: items.map((item) => DropdownMenuItem<String>(
            value: item,
            child: Row(
              children: [
                Icon(
                  icon,
                  color: value == item ? Colors.green.shade700 : Colors.grey.shade700,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: value == item ? FontWeight.bold : FontWeight.normal,
                      color: value == item ? Colors.green.shade700 : Colors.black87,
                    ),
                  ),
                ),
                if (value == item)
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
              ],
            ),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildFAFilter() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
        gradient: LinearGradient(
          colors: [
            Colors.white,
            _selectedFA.isNotEmpty ? Colors.green.shade50 : Colors.grey.shade50
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(
          color: _selectedFA.isNotEmpty ? Colors.green.shade300 : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Row(
            children: [
              Icon(
                Icons.group,
                color: _selectedFA.isNotEmpty ? Colors.green.shade700 : Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedFA.isEmpty
                      ? 'Select Field Assistants'
                      : '${_selectedFA.length} FA${_selectedFA.length > 1 ? 's' : ''} selected',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: _selectedFA.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                    color: _selectedFA.isNotEmpty ? Colors.green.shade700 : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _selectedFA.isNotEmpty ? Colors.green.shade100 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.expand_more,
              color: _selectedFA.isNotEmpty ? Colors.green.shade700 : Colors.grey.shade700,
              size: 16,
            ),
          ),
          children: [
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(12),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // FA list with scrollbar
                  Flexible(
                    child: Scrollbar(
                      thumbVisibility: true,
                      radius: const Radius.circular(8),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(8),
                        shrinkWrap: true,
                        itemCount: widget.faNames.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = widget.faNames[index];
                          final isSelected = _selectedFA.contains(item);

                          return CheckboxListTile(
                            title: Text(
                              item,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.green.shade700 : Colors.black87,
                              ),
                            ),
                            value: isSelected,
                            activeColor: Colors.green.shade600,
                            checkColor: Colors.white,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedFA.add(item);
                                } else {
                                  _selectedFA.remove(item);
                                }
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            visualDensity: VisualDensity.compact,
                            tileColor: isSelected ? Colors.green.withAlpha(15) : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Quick selection buttons
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedFA = List.from(widget.faNames);
                            });
                          },
                          icon: Icon(Icons.select_all, color: Colors.green.shade700, size: 16),
                          label: Text(
                            'Select All',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedFA.clear();
                            });
                          },
                          icon: Icon(Icons.deselect, color: Colors.red.shade700, size: 16),
                          label: Text(
                            'Clear All',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFIFilter() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
        gradient: LinearGradient(
          colors: [
            Colors.white,
            _selectedFIs.isNotEmpty ? Colors.green.shade50 : Colors.grey.shade50
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(
          color: _selectedFIs.isNotEmpty ? Colors.green.shade300 : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: _selectedFIs.isNotEmpty ? Colors.green.shade700 : Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedFIs.isEmpty
                      ? 'Select Field Inspector'
                      : '${_selectedFIs.length} FI${_selectedFIs.length > 1 ? 's' : ''} selected',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: _selectedFIs.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                    color: _selectedFIs.isNotEmpty ? Colors.green.shade700 : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _selectedFIs.isNotEmpty ? Colors.green.shade100 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.expand_more,
              color: _selectedFIs.isNotEmpty ? Colors.green.shade700 : Colors.grey.shade700,
              size: 16,
            ),
          ),
          children: [
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(12),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // FI list with scrollbar
                  Flexible(
                    child: Scrollbar(
                      thumbVisibility: true,
                      radius: const Radius.circular(8),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(8),
                        shrinkWrap: true,
                        itemCount: widget.fiNames.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = widget.fiNames[index];
                          final isSelected = _selectedFIs.contains(item);

                          return CheckboxListTile(
                            title: Text(
                              item,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.green.shade700 : Colors.black87,
                              ),
                            ),
                            value: isSelected,
                            activeColor: Colors.green.shade600,
                            checkColor: Colors.white,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedFIs.add(item);
                                } else {
                                  _selectedFIs.remove(item);
                                }
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            visualDensity: VisualDensity.compact,
                            tileColor: isSelected ? Colors.green.withAlpha(15) : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Quick selection buttons
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedFIs = List.from(widget.fiNames);
                            });
                          },
                          icon: Icon(Icons.select_all, color: Colors.green.shade700, size: 16),
                          label: Text(
                            'Select All',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedFIs.clear();
                            });
                          },
                          icon: Icon(Icons.deselect, color: Colors.red.shade700, size: 16),
                          label: Text(
                            'Clear All',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShowDiscardedFaseFilter() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
        gradient: LinearGradient(
          colors: [
            Colors.white,
            _localShowDiscardedFase ? Colors.orange.shade50 : Colors.grey.shade50
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(
          color: _localShowDiscardedFase ? Colors.orange.shade300 : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: SwitchListTile(
        title: Row(
          children: [
            Icon(
              _localShowDiscardedFase ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              color: _localShowDiscardedFase ? Colors.orange.shade700 : Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'Show Discard',
              style: TextStyle(
                fontSize: 16,
                fontWeight: _localShowDiscardedFase ? FontWeight.w600 : FontWeight.normal,
                color: _localShowDiscardedFase ? Colors.orange.shade700 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
        value: _localShowDiscardedFase,
        onChanged: (bool value) {
          setState(() {
            _localShowDiscardedFase = value;
          });
          // Panggil callback untuk memberitahu parent (GenerativeScreen) tentang perubahan ini,
          // sehingga parent bisa mengupdate state _showDiscardedFaseItems miliknya saat "Apply" ditekan.
          widget.onShowDiscardedFaseChanged(value); // Ini akan dipanggil saat "Apply"
        },
        activeThumbColor: Colors.orange.shade600,
        activeTrackColor: Colors.orange.shade200,
        inactiveThumbColor: Colors.grey.shade400,
        inactiveTrackColor: Colors.grey.shade200,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          // Cancel button
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(context); // Just close without applying
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green.shade700,
                side: BorderSide(color: Colors.green.shade700, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Apply button
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                // Panggil semua callback 'onChanged' dengan nilai lokal saat ini
                widget.onSeasonChanged(_selectedSeason);
                widget.onWeekOfGenerativeChanged(_selectedWeeks);
                widget.onFAChanged(_selectedFA);
                widget.onFIChanged(_selectedFIs);
                widget.onShowDiscardedFaseChanged(_localShowDiscardedFase); // << Panggil callback ini

                widget.onApplyFilters(); // Beritahu parent untuk menerapkan filter
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _hasActiveFilters() ? Icons.filter_list_alt : Icons.done,
                    size: 18, color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Apply Filters',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

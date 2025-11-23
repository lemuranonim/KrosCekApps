// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class PspVegetativeFilterOptions extends StatefulWidget {
  final String? selectedSeason;
  final List<String> seasonsList;
  final Function(String?) onSeasonChanged;

  final List<String> selectedWeekOfPspVegetative;
  final List<String> weekOfPspVegetativeList;
  final Function(List<String>) onWeekOfPspVegetativeChanged;

  final List<String> selectedFA;
  final List<String> faNames;
  final Function(List<String>) onFAChanged;

  final List<String> selectedFI;
  final List<String> fiNames;
  final Function(List<String>) onFIChanged;

  final VoidCallback onResetAll;
  final VoidCallback onApplyFilters;

  const PspVegetativeFilterOptions({
    super.key,
    this.selectedSeason,
    required this.seasonsList,
    required this.onSeasonChanged,
    required this.selectedWeekOfPspVegetative,
    required this.weekOfPspVegetativeList,
    required this.onWeekOfPspVegetativeChanged,
    required this.selectedFA,
    required this.faNames,
    required this.onFAChanged,
    required this.selectedFI,
    required this.fiNames,
    required this.onFIChanged,
    required this.onResetAll,
    required this.onApplyFilters,
  });

  @override
  State<PspVegetativeFilterOptions> createState() => _PspVegetativeFilterOptionsState();
}

class _PspVegetativeFilterOptionsState extends State<PspVegetativeFilterOptions> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String? _selectedSeason;
  List<String> _selectedWeeks = [];
  List<String> _selectedFA = [];
  List<String> _selectedFIs = [];

  // --- Theme Colors ---
  final Color _primaryPurple = Colors.purple.shade800;
  final Color _secondaryPurple = Colors.purple.shade600;

  @override
  void initState() {
    super.initState();

    _selectedSeason = widget.selectedSeason;
    _selectedWeeks = List.from(widget.selectedWeekOfPspVegetative);
    _selectedFA = List.from(widget.selectedFA);
    _selectedFIs = List.from(widget.selectedFI);

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
            color: Colors.grey.shade50, // Light background
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
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
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              _buildHeader(),

              // Content
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
                      _buildFilterCount(),
                      const SizedBox(height: 24),
                      _buildFilterSection(
                        title: 'Season',
                        subtitle: 'Select growing season',
                        child: _buildSeasonFilter(),
                      ),
                      const SizedBox(height: 24),
                      _buildFilterSection(
                        title: 'Week of Psp Vegetative',
                        subtitle: 'Filter by specific weeks',
                        child: _buildWeekFilter(),
                      ),
                      const SizedBox(height: 24),
                      _buildFilterSection(
                        title: 'Field Assistant (FA)',
                        subtitle: 'Filter by field personnel',
                        child: _buildFAFilter(),
                      ),
                      const SizedBox(height: 24),
                      _buildFilterSection(
                        title: 'Field Inspector (FI)',
                        subtitle: 'Filter by Field Inspector',
                        child: _buildFIFilter(),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

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
          colors: [_primaryPurple, _secondaryPurple],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryPurple.withOpacity(0.3),
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
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.tune_rounded,
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
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
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
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white),
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: count > 0 ? Colors.purple.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: count > 0 ? _secondaryPurple.withOpacity(0.5) : Colors.grey.shade300,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Icon(
            count > 0 ? Icons.filter_list_alt : Icons.filter_alt_off_rounded,
            color: count > 0 ? _primaryPurple : Colors.grey.shade500,
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
                fontWeight: FontWeight.w600,
                color: count > 0 ? _primaryPurple : Colors.grey.shade700,
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
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Clear All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _primaryPurple,
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
        _selectedFIs.isNotEmpty;
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
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildSeasonFilter() {
    return _buildDropdownFilter(
      value: _selectedSeason,
      items: ['All'] + widget.seasonsList,
      icon: Icons.calendar_today_rounded,
      hintText: 'Select Growing Season',
      onChanged: (value) {
        setState(() {
          _selectedSeason = value == 'All' ? null : value;
        });
      },
    );
  }

  Widget _buildWeekFilter() {
    return _buildMultiSelectFilter(
      title: 'Weeks',
      selectedItems: _selectedWeeks,
      allItems: widget.weekOfPspVegetativeList,
      onChanged: (selected) {
        setState(() => _selectedWeeks = selected);
      },
      icon: Icons.date_range_rounded,
    );
  }

  Widget _buildFAFilter() {
    return _buildMultiSelectFilter(
      title: 'Field Assistants',
      selectedItems: _selectedFA,
      allItems: widget.faNames,
      onChanged: (selected) {
        setState(() => _selectedFA = selected);
      },
      icon: Icons.supervisor_account_rounded,
    );
  }

  Widget _buildFIFilter() {
    return _buildMultiSelectFilter(
      title: 'Field Inspectors',
      selectedItems: _selectedFIs,
      allItems: widget.fiNames,
      onChanged: (selected) {
        setState(() => _selectedFIs = selected);
      },
      icon: Icons.fact_check_rounded,
    );
  }

  Widget _buildMultiSelectFilter({
    required String title,
    required List<String> selectedItems,
    required List<String> allItems,
    required Function(List<String>) onChanged,
    required IconData icon,
  }) {
    bool isActive = selectedItems.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isActive ? _secondaryPurple.withOpacity(0.5) : Colors.grey.shade300,
          width: 1.0,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Row(
            children: [
              Icon(
                icon,
                color: isActive ? _primaryPurple : Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isActive
                      ? '${selectedItems.length} Selected'
                      : 'Select $title',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? _primaryPurple : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          iconColor: _primaryPurple,
          collapsedIconColor: Colors.grey.shade500,
          children: [
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: allItems.length,
                        itemBuilder: (context, index) {
                          final item = allItems[index];
                          final isSelected = selectedItems.contains(item);

                          return CheckboxListTile(
                            title: Text(
                              item,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? _primaryPurple : Colors.black87,
                              ),
                            ),
                            value: isSelected,
                            activeColor: _primaryPurple,
                            checkColor: Colors.white,
                            dense: true,
                            onChanged: (bool? value) {
                              List<String> newSelection = List.from(selectedItems);
                              if (value == true) {
                                newSelection.add(item);
                              } else {
                                newSelection.remove(item);
                              }
                              onChanged(newSelection);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => onChanged(List.from(allItems)),
                          child: Text('Select All', style: TextStyle(color: _secondaryPurple)),
                        ),
                        TextButton(
                          onPressed: () => onChanged([]),
                          child: Text('Clear', style: TextStyle(color: Colors.red.shade400)),
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
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: value != null ? _secondaryPurple.withOpacity(0.5) : Colors.grey.shade300,
          width: 1.0,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton2<String>(
          value: value,
          hint: Row(
            children: [
              Icon(icon, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 12),
              Text(
                hintText,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
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
          iconStyleData: const IconStyleData(
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
          ),
          dropdownStyleData: DropdownStyleData(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            offset: const Offset(0, -4),
          ),
          menuItemStyleData: MenuItemStyleData(
            selectedMenuItemBuilder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: child,
              );
            },
          ),
          items: items.map((item) => DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              style: TextStyle(
                fontSize: 14,
                color: value == item ? _primaryPurple : Colors.black87,
                fontWeight: value == item ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          )).toList(),
          onChanged: onChanged,
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
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryPurple,
                side: BorderSide(color: _primaryPurple.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                widget.onSeasonChanged(_selectedSeason);
                widget.onWeekOfPspVegetativeChanged(_selectedWeeks);
                widget.onFAChanged(_selectedFA);
                widget.onFIChanged(_selectedFIs);
                widget.onApplyFilters();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 4,
                shadowColor: _primaryPurple.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Apply Filters',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
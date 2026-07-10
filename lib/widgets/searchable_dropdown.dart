import 'package:flutter/material.dart';

// Global dropdown manager to ensure only one dropdown is open at a time
class _DropdownManager {
  static _SearchableDropdownState? _currentOpenDropdown;

  static void openDropdown(_SearchableDropdownState dropdown) {
    if (_currentOpenDropdown != null && _currentOpenDropdown != dropdown) {
      _currentOpenDropdown!._forceHideDropdown();
    }
    _currentOpenDropdown = dropdown;
  }

  static void closeDropdown(_SearchableDropdownState dropdown) {
    if (_currentOpenDropdown == dropdown) {
      _currentOpenDropdown = null;
    }
  }
}

class SearchableDropdown extends StatefulWidget {
  final String? value;
  final List<String> items;
  final String hintText;
  final String labelText;
  final IconData? prefixIcon;
  final Color primaryColor;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;
  final bool enabled;

  const SearchableDropdown({
    super.key,
    this.value,
    required this.items,
    required this.hintText,
    required this.labelText,
    this.prefixIcon,
    this.primaryColor = const Color(0xFF007BFF),
    required this.onChanged,
    this.validator,
    this.enabled = true,
  });

  @override
  State<SearchableDropdown> createState() => _SearchableDropdownState();
}

class _SearchableDropdownState extends State<SearchableDropdown> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _filteredItems = [];
  bool _isDropdownOpen = false;
  bool _isDropdownAbove = false; // Track dropdown position
  bool _justSelected = false; // Flag to prevent immediate reopening
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _controller.text = widget.value ?? '';
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(SearchableDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _controller.text = widget.value ?? '';
    }
    if (widget.items != oldWidget.items) {
      _filteredItems = widget.items;
      _filterItems(_controller.text);
    }
  }

  void _onTextChanged() {
    _filterItems(_controller.text);
    if (!_isDropdownOpen &&
        _controller.text.isNotEmpty &&
        _focusNode.hasFocus &&
        mounted) {
      // Add a small delay to prevent rapid IME toggling
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted && _focusNode.hasFocus && !_isDropdownOpen) {
          _showDropdown();
        }
      });
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && !_justSelected) {
      // Add a small delay to ensure the widget is properly mounted
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted &&
            _focusNode.hasFocus &&
            !_isDropdownOpen &&
            !_justSelected) {
          _showDropdown();
        }
      });
    } else {
      // Add a small delay to allow for tap events to complete
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_focusNode.hasFocus && _isDropdownOpen) {
          _hideDropdown();
        }
      });
    }
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        // Case-insensitive filtering with better matching
        final lowerQuery = query.toLowerCase().trim();
        _filteredItems = widget.items.where((item) {
          final lowerItem = item.toLowerCase().trim();
          // Check if item starts with query (priority) or contains query
          return lowerItem.startsWith(lowerQuery) ||
              lowerItem.contains(lowerQuery);
        }).toList();

        // Sort results: exact matches first, then starts with, then contains
        _filteredItems.sort((a, b) {
          final lowerA = a.toLowerCase().trim();
          final lowerB = b.toLowerCase().trim();

          // Exact match gets highest priority
          if (lowerA == lowerQuery && lowerB != lowerQuery) return -1;
          if (lowerB == lowerQuery && lowerA != lowerQuery) return 1;

          // Starts with gets second priority
          final aStartsWith = lowerA.startsWith(lowerQuery);
          final bStartsWith = lowerB.startsWith(lowerQuery);

          if (aStartsWith && !bStartsWith) return -1;
          if (bStartsWith && !aStartsWith) return 1;

          // Otherwise maintain alphabetical order
          return a.compareTo(b);
        });
      }
    });
    _updateOverlay();
  }

  void _showDropdown() {
    if (_isDropdownOpen || !widget.enabled || !mounted || _justSelected) return;

    // Use the dropdown manager to ensure only one dropdown is open
    _DropdownManager.openDropdown(this);

    _isDropdownOpen = true;

    // Ensure the widget is fully rendered before creating overlay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isDropdownOpen) {
        try {
          // Check if overlay is available
          final overlay = Overlay.of(context, rootOverlay: false);
          if (overlay.mounted) {
            // Add a small delay to ensure render box is ready
            Future.delayed(const Duration(milliseconds: 50), () {
              if (mounted && _isDropdownOpen) {
                final RenderBox? renderBox =
                    context.findRenderObject() as RenderBox?;
                if (renderBox != null && renderBox.hasSize) {
                  _overlayEntry = _createOverlayEntry();
                  if (_overlayEntry != null) {
                    overlay.insert(_overlayEntry!);
                  }
                } else {
                  // If render box is not ready, try again after a short delay
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted && _isDropdownOpen) {
                      try {
                        _overlayEntry = _createOverlayEntry();
                        if (_overlayEntry != null && overlay.mounted) {
                          overlay.insert(_overlayEntry!);
                        }
                      } catch (e) {
                        // If overlay insertion fails, reset state
                        _isDropdownOpen = false;
                        _overlayEntry = null;
                      }
                    }
                  });
                }
              }
            });
          } else {
            // Overlay not available, reset state
            _isDropdownOpen = false;
          }
        } catch (e) {
          // If overlay access fails, reset state
          _isDropdownOpen = false;
        }
      }
    });
  }

  void _hideDropdown() {
    if (!_isDropdownOpen) return;

    _DropdownManager.closeDropdown(this);
    _isDropdownOpen = false;

    try {
      _overlayEntry?.remove();
    } catch (e) {
      // Ignore errors during overlay removal
    } finally {
      _overlayEntry = null;
    }

    // Force a rebuild to update UI state
    if (mounted) {
      setState(() {});
    }
  }

  // Force hide method for the dropdown manager
  void _forceHideDropdown() {
    if (_isDropdownOpen) {
      _isDropdownOpen = false;
      try {
        _overlayEntry?.remove();
      } catch (e) {
        // Ignore errors during overlay removal
      } finally {
        _overlayEntry = null;
      }

      // Use post-frame callback to avoid setState during build
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
      }
    }
  }

  void _updateOverlay() {
    if (_isDropdownOpen && _overlayEntry != null && mounted) {
      try {
        // Check if overlay is still available
        final overlay = Overlay.of(context, rootOverlay: false);
        if (overlay.mounted) {
          // Remove the old overlay and create a new one with updated position
          _overlayEntry!.remove();
          _overlayEntry = null;

          // Add a small delay to ensure proper cleanup before recreating
          Future.delayed(const Duration(milliseconds: 10), () {
            if (mounted && _isDropdownOpen) {
              try {
                _overlayEntry = _createOverlayEntry();
                if (_overlayEntry != null && overlay.mounted) {
                  overlay.insert(_overlayEntry!);
                  // Trigger rebuild to update input field styling
                  setState(() {});
                }
              } catch (e) {
                // If overlay insertion fails, reset state
                _isDropdownOpen = false;
                _overlayEntry = null;
              }
            }
          });
        } else {
          // Overlay not available, reset state
          _isDropdownOpen = false;
          _overlayEntry = null;
        }
      } catch (e) {
        // If overlay access fails, reset state
        _isDropdownOpen = false;
        _overlayEntry = null;
      }
    }
  }

  OverlayEntry? _createOverlayEntry() {
    if (!mounted) return null;

    // Use the current context's render box to get position and size
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return null;
    }

    final textFieldSize = renderBox.size;
    final textFieldPosition = renderBox.localToGlobal(Offset.zero);
    final dropdownHeight = (_filteredItems.length * 48.0).clamp(48.0, 200.0);

    // Get screen dimensions and keyboard height
    final screenSize = MediaQuery.of(context).size;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final availableHeight = screenSize.height - keyboardHeight;

    // Calculate if dropdown should appear above or below
    final spaceBelow =
        availableHeight - (textFieldPosition.dy + textFieldSize.height);
    final spaceAbove = textFieldPosition.dy;
    final shouldShowAbove =
        spaceBelow < dropdownHeight && spaceAbove > dropdownHeight;

    // Store dropdown position for input field styling
    _isDropdownAbove = shouldShowAbove;

    // Adjust dropdown height if needed
    final adjustedDropdownHeight = shouldShowAbove
        ? dropdownHeight.clamp(48.0, spaceAbove - 10)
        : dropdownHeight.clamp(48.0, spaceBelow - 10);

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Invisible barrier to detect taps outside
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                _hideDropdown();
                _focusNode.unfocus();
              },
              child: Container(color: Colors.transparent),
            ),
          ),
          // The actual dropdown using CompositedTransformFollower to track the input field
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(
              0,
              shouldShowAbove
                  ? -adjustedDropdownHeight + 1 // Show above with 1px overlap
                  : textFieldSize.height - 1, // Show below with 1px overlap
            ),
            child: SizedBox(
              width: textFieldSize.width,
            child: Material(
              elevation: 0,
              borderRadius: shouldShowAbove
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    )
                  : const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
              color: Colors.white,
              child: Container(
                width: textFieldSize.width,
                height: adjustedDropdownHeight,
                decoration: BoxDecoration(
                  borderRadius: shouldShowAbove
                      ? const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        )
                      : const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                  border: shouldShowAbove
                      ? const Border(
                          top: BorderSide(color: Color(0xFFE5E7EB)),
                          left: BorderSide(color: Color(0xFFE5E7EB)),
                          right: BorderSide(color: Color(0xFFE5E7EB)),
                        )
                      : const Border(
                          left: BorderSide(color: Color(0xFFE5E7EB)),
                          right: BorderSide(color: Color(0xFFE5E7EB)),
                          bottom: BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: _filteredItems.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No options found',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          final isSelected = item == widget.value;

                          return InkWell(
                            onTap: () {
                              _selectItem(item);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? widget.primaryColor.withValues(alpha: 0.1)
                                    : Colors.transparent,
                                borderRadius: index == _filteredItems.length - 1
                                    ? const BorderRadius.only(
                                        bottomLeft: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? widget.primaryColor
                                            : const Color(0xFF1F2937),
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check,
                                      size: 18,
                                      color: widget.primaryColor,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectItem(String item) {
    // Set flag to prevent immediate reopening
    _justSelected = true;

    // Immediately set the dropdown state to closed to prevent any race conditions
    if (_isDropdownOpen) {
      _isDropdownOpen = false;

      // Remove overlay immediately
      try {
        _overlayEntry?.remove();
      } catch (e) {
        // Ignore errors during overlay removal
      } finally {
        _overlayEntry = null;
      }

      // Notify dropdown manager
      _DropdownManager.closeDropdown(this);
    }

    // Update the controller and notify parent
    _controller.text = item;
    widget.onChanged(item);

    // Unfocus to close keyboard and ensure dropdown stays closed
    _focusNode.unfocus();

    // Reset the flag after a delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _justSelected = false;
      }
    });

    // Force a rebuild to update UI state
    if (mounted) {
      setState(() {});
    }
  }

  // Add method to handle text field submission (when user presses enter or done)
  void _handleSubmitted(String value) {
    if (value.trim().isEmpty) return;

    // Find the best match from filtered items
    if (_filteredItems.isNotEmpty) {
      final trimmedValue = value.trim();

      // First try to find exact match (case insensitive)
      String? exactMatch = _filteredItems.firstWhere(
        (item) => item.toLowerCase().trim() == trimmedValue.toLowerCase(),
        orElse: () => '',
      );

      if (exactMatch.isNotEmpty) {
        _selectItem(exactMatch);
        return;
      }

      // If no exact match, use the first filtered item (best match)
      _selectItem(_filteredItems.first);
    }
  }

  @override
  void dispose() {
    _DropdownManager.closeDropdown(this);
    _hideDropdown();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(
          children: [
            if (widget.prefixIcon != null) ...[
              Icon(widget.prefixIcon, size: 20, color: widget.primaryColor),
              const SizedBox(width: 8),
            ],
            Text(
              widget.labelText,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          onFieldSubmitted: _handleSubmitted,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
            suffixIcon: Icon(
              _isDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              color: const Color(0xFF6B7280),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE5E7EB),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: _isDropdownOpen
                  ? (_isDropdownAbove
                        ? const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          )
                        : const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ))
                  : BorderRadius.circular(12),
              borderSide: BorderSide(
                color: widget.value != null
                    ? widget.primaryColor
                    : const Color(0xFFE5E7EB),
                width: widget.value != null ? 2 : 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: _isDropdownOpen
                  ? (_isDropdownAbove
                        ? const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          )
                        : const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ))
                  : BorderRadius.circular(12),
              borderSide: BorderSide(color: widget.primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1F2937),
          ),
          validator: widget.validator,
          onTap: () {
            // Prevent multiple rapid taps and respect selection flag
            if (!mounted || _justSelected) return;

            if (!_focusNode.hasFocus) {
              _focusNode.requestFocus();
            }

            // Add delay to prevent IME conflicts
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted &&
                  !_isDropdownOpen &&
                  _focusNode.hasFocus &&
                  !_justSelected) {
                _showDropdown();
              }
            });
          },
        ),
      ],
    ),
    );
  }
}

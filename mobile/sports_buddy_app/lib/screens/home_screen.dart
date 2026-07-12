import 'package:flutter/material.dart';

import '../services/sports_api.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.api,
    required this.initialUser,
    required this.onLogout,
  });

  final SportsApi api;
  final Map<String, dynamic>? initialUser;
  final Future<void> Function() onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<String> _presetSports = [
    'Tennis',
    'Badminton',
    'Cricket',
    'Football',
    'Basketball',
    'Pickleball',
  ];

  static const List<String> _presetCities = [
    'Mangalore',
    'Bengaluru',
    'Mumbai',
    'Delhi',
    'Hyderabad',
    'Chennai',
  ];

  final List<String> _supportedCities = [..._presetCities];
  final List<String> _supportedSports = [..._presetSports];

  static const List<String> _weekdayOptions = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  final _city = TextEditingController();
  final _sport = TextEditingController();
  final _availability = TextEditingController();
  final _discoverSearch = TextEditingController();
  final _connectionsSearch = TextEditingController();
  final _sessionsSearch = TextEditingController();
  final _globalSearch = TextEditingController();
  String _searchCityFilter = 'All';
  String _searchSportFilter = 'All';

  String _skill = 'beginner';
  final Set<String> _selectedSports = <String>{};
  bool _profileLoading = false;
  bool _suggestionsLoading = false;
  bool _connectionsLoading = false;
  bool _sessionsLoading = false;
  int _currentTabIndex = 0;
  String? _status;
  DateTime? _lastRefreshedAt;
  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> _incomingRequests = [];
  List<Map<String, dynamic>> _outgoingRequests = [];
  List<Map<String, dynamic>> _buddies = [];
  List<Map<String, dynamic>> _mySessionPlans = [];
  List<Map<String, dynamic>> _discoverSessionPlans = [];
  final Set<String> _sendingRequestIds = <String>{};
  final Set<String> _cancelingRequestIds = <String>{};
  final Set<String> _removingBuddyIds = <String>{};
  final Set<String> _safetyActionUserIds = <String>{};
  final Set<String> _messagingBuddyIds = <String>{};
  final Set<String> _joiningPlanIds = <String>{};
  final Set<String> _leavingPlanIds = <String>{};
  final Set<String> _updatingPlanIds = <String>{};

  @override
  void initState() {
    super.initState();
    _hydrateProfile();
    _loadSupportedCities();
    _loadSupportedSports();
    _loadSuggestions();
    _loadConnections();
    _loadSessionPlans();
  }

  Future<void> _loadSupportedCities() async {
    try {
      final cities = await widget.api.supportedCities();
      if (!mounted || cities.isEmpty) {
        return;
      }

      setState(() {
        _supportedCities
          ..clear()
          ..addAll(cities);

        final currentCity = _city.text.trim();
        if (currentCity.isNotEmpty) {
          final canonical = _canonicalPresetCity(currentCity);
          _city.text = canonical;
        }
      });
    } catch (_) {
      // Keep fallback preset list when backend metadata is unavailable.
    }
  }

  Future<void> _loadSupportedSports() async {
    try {
      final sports = await widget.api.supportedSports();
      if (!mounted || sports.isEmpty) {
        return;
      }

      setState(() {
        _supportedSports
          ..clear()
          ..addAll(sports);

        final currentSelected = _selectedSports.toList();
        _selectedSports
          ..clear()
          ..addAll(
            currentSelected
                .map(_canonicalSport)
                .where((sport) => sport.isNotEmpty),
          );

        final primary = _canonicalSport(_sport.text.trim());
        _sport.text = primary;
      });
    } catch (_) {
      // Keep fallback preset list when backend metadata is unavailable.
    }
  }

  void _hydrateProfile() {
    final user = widget.initialUser;
    if (user == null) {
      return;
    }

    _city.text = (user['city'] ?? '').toString();
    final sports = _normalizedSportsFrom(user['sports'], user['sport']);
    _selectedSports
      ..clear()
      ..addAll(
        sports
            .map(_canonicalSport)
            .where((sport) => sport.isNotEmpty),
      );
    _sport.text = sports.isNotEmpty ? _canonicalSport(sports.first) : '';
    _skill = (user['skillLevel'] ?? 'beginner').toString();

    final days = ((user['availabilityDays'] ?? []) as List)
        .map((d) => d.toString())
        .join(',');
    _availability.text = days;
  }

  Future<bool> _saveProfile() async {
    final selectedCity = _canonicalPresetCity(_city.text.trim());
    if (selectedCity.isEmpty) {
      setState(() {
        _status = 'Please choose a city from the available list';
      });
      return false;
    }

    final primarySport = _sport.text.trim();
    final sports = <String>[
      if (primarySport.isNotEmpty && _selectedSports.contains(primarySport))
        primarySport,
      ...(_selectedSports.where((sport) => sport != primarySport).toList()
        ..sort()),
    ];
    if (sports.isEmpty) {
      setState(() {
        _status = 'Please select at least one sport';
      });
      return false;
    }

    setState(() {
      _profileLoading = true;
      _status = null;
    });

    try {
      await widget.api.updateProfile(
        city: selectedCity,
        sports: sports,
        skillLevel: _skill,
        availabilityDays: _availability.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
      );

      setState(() {
        _status = 'Profile updated';
      });

      await _loadSuggestions();
      return true;
    } catch (e) {
      setState(() {
        _status = e.toString().replaceFirst('Exception: ', '');
      });
      return false;
    } finally {
      setState(() {
        _profileLoading = false;
      });
    }
  }

  Set<String> _availabilitySet() {
    return _availability.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  List<String> _normalizedSportsFrom(dynamic sportsValue, dynamic sportValue) {
    final normalized = <String>{};

    if (sportsValue is List) {
      for (final value in sportsValue) {
        final sport = value.toString().trim();
        if (sport.isNotEmpty) {
          normalized.add(sport);
        }
      }
    }

    final legacySport = (sportValue ?? '').toString().trim();
    if (legacySport.isNotEmpty) {
      normalized.add(legacySport);
    }

    final result = normalized.toList()..sort();
    return result;
  }

  String _sportsLabelFrom(dynamic sportsValue, dynamic sportValue) {
    final sports = _normalizedSportsFrom(sportsValue, sportValue);
    return sports.isEmpty ? '-' : sports.join(', ');
  }

  String _userHandleFromEmail(dynamic emailValue) {
    final email = (emailValue ?? '').toString().trim();
    final atIndex = email.indexOf('@');
    if (atIndex <= 0) {
      return '';
    }

    final local = email.substring(0, atIndex).trim();
    if (local.isEmpty) {
      return '';
    }
    return '@$local';
  }

  String _normalizedSessionStatus(dynamic value) {
    return (value ?? '').toString().trim().toLowerCase();
  }

  String _sessionStatusLabel(String normalizedStatus) {
    switch (normalizedStatus) {
      case 'open':
        return 'Open';
      case 'confirmed':
        return 'Confirmed';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  String _sessionStatusHint(String normalizedStatus) {
    switch (normalizedStatus) {
      case 'completed':
        return 'Session finished';
      case 'cancelled':
        return 'Plan cancelled';
      case 'confirmed':
        return 'Ready to play';
      case 'open':
        return 'Accepting players';
      default:
        return 'Status unavailable';
    }
  }

  Color _sessionStatusBackgroundColor(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'open':
        return Colors.green.shade100;
      case 'confirmed':
        return Colors.blue.shade100;
      case 'completed':
        return scheme.surfaceContainerHighest;
      case 'cancelled':
        return Colors.red.shade100;
      default:
        return scheme.surfaceContainerHighest;
    }
  }

  Color _sessionStatusForegroundColor(BuildContext context, String status) {
    switch (status) {
      case 'open':
        return Colors.green.shade900;
      case 'confirmed':
        return Colors.blue.shade900;
      case 'completed':
        return Theme.of(context).colorScheme.onSurfaceVariant;
      case 'cancelled':
        return Colors.red.shade900;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  Widget _buildSessionStatusChip(BuildContext context, String status) {
    final bg = _sessionStatusBackgroundColor(context, status);
    final fg = _sessionStatusForegroundColor(context, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _sessionStatusLabel(status),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStateChip(
    BuildContext context, {
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildConnectionStateChip(BuildContext context, String state) {
    switch (state) {
      case 'incoming':
        return _buildStateChip(
          context,
          label: 'Incoming',
          background: Colors.orange.shade100,
          foreground: Colors.orange.shade900,
        );
      case 'pending':
        return _buildStateChip(
          context,
          label: 'Pending',
          background: Colors.amber.shade100,
          foreground: Colors.amber.shade900,
        );
      case 'connected':
        return _buildStateChip(
          context,
          label: 'Connected',
          background: Colors.green.shade100,
          foreground: Colors.green.shade900,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSuggestionStateChip(BuildContext context, String state) {
    switch (state) {
      case 'available':
        return _buildStateChip(
          context,
          label: 'Available',
          background: Colors.teal.shade100,
          foreground: Colors.teal.shade900,
        );
      case 'requested':
        return _buildStateChip(
          context,
          label: 'Requested',
          background: Colors.amber.shade100,
          foreground: Colors.amber.shade900,
        );
      case 'incoming':
        return _buildStateChip(
          context,
          label: 'Incoming',
          background: Colors.orange.shade100,
          foreground: Colors.orange.shade900,
        );
      case 'connected':
        return _buildStateChip(
          context,
          label: 'Connected',
          background: Colors.green.shade100,
          foreground: Colors.green.shade900,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  int _sessionStatusRank(String normalizedStatus) {
    switch (normalizedStatus) {
      case 'open':
        return 0;
      case 'confirmed':
        return 1;
      case 'completed':
        return 2;
      case 'cancelled':
        return 3;
      default:
        return 4;
    }
  }

  int _scheduledAtEpochMillis(Map<String, dynamic> plan) {
    final value = (plan['scheduledAt'] ?? '').toString().trim();
    if (value.isEmpty) {
      return 1 << 30;
    }

    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return 1 << 30;
    }
    return parsed.millisecondsSinceEpoch;
  }

  void _markRefreshed() {
    _lastRefreshedAt = DateTime.now();
  }

  String _relativeRefreshLabel() {
    final value = _lastRefreshedAt;
    if (value == null) {
      return '';
    }

    final seconds = DateTime.now().difference(value).inSeconds;
    if (seconds < 60) {
      return 'Updated just now';
    }

    final minutes = seconds ~/ 60;
    if (minutes < 60) {
      return 'Updated ${minutes}m ago';
    }

    final hours = minutes ~/ 60;
    return 'Updated ${hours}h ago';
  }

  bool _sportsContainQuery(
    dynamic sportsValue,
    dynamic sportValue,
    String query,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return true;
    }

    return _normalizedSportsFrom(sportsValue, sportValue).any(
      (sport) => sport.toLowerCase().contains(normalizedQuery),
    );
  }

  bool _sportsMatchFilter(
    dynamic sportsValue,
    dynamic sportValue,
    String sportFilter,
  ) {
    if (sportFilter == 'All') {
      return true;
    }

    final normalizedFilter = sportFilter.trim().toLowerCase();
    return _normalizedSportsFrom(sportsValue, sportValue).any(
      (sport) => sport.toLowerCase() == normalizedFilter,
    );
  }

  String _canonicalSport(String sport) {
    final normalized = sport.trim().toLowerCase();
    for (final preset in _supportedSports) {
      if (preset.toLowerCase() == normalized) {
        return preset;
      }
    }
    return '';
  }

  String _canonicalPresetCity(String city) {
    final normalized = city.trim().toLowerCase();
    for (final preset in _supportedCities) {
      if (preset.toLowerCase() == normalized) {
        return preset;
      }
    }
    return '';
  }

  bool _isSportSelected(String sport) {
    return _selectedSports.contains(_canonicalSport(sport));
  }

  String _selectedSportsSummary() {
    final sports = _selectedSports.toList()..sort();
    return sports.isEmpty ? 'None selected' : sports.join(', ');
  }

  void _toggleAvailabilityDay(String day) {
    final values = _availabilitySet();
    if (values.contains(day)) {
      values.remove(day);
    } else {
      values.add(day);
    }

    _availability.text = _weekdayOptions
        .where(values.contains)
        .join(',');
  }

  bool _isProfileReadyForSuggestions() {
    return _city.text.trim().isNotEmpty &&
        _selectedSports.isNotEmpty &&
        _availabilitySet().isNotEmpty;
  }

  String _missingProfileFieldsForSuggestions() {
    final missing = <String>[];
    if (_city.text.trim().isEmpty) {
      missing.add('city');
    }
    if (_selectedSports.isEmpty) {
      missing.add('sports');
    }
    if (_availabilitySet().isEmpty) {
      missing.add('availability');
    }
    return missing.join(', ');
  }

  Future<void> _loadSuggestions() async {
    if (!_isProfileReadyForSuggestions()) {
      setState(() {
        _suggestions = [];
        _suggestionsLoading = false;
      });
      return;
    }

    setState(() {
      _suggestionsLoading = true;
    });

    try {
      final data = await widget.api.suggestions();
      final list = data
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      if (!mounted) {
        return;
      }
      setState(() {
        _suggestions = list;
        _markRefreshed();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _suggestions = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _suggestionsLoading = false;
        });
      }
    }
  }

  Future<void> _loadConnections() async {
    setState(() {
      _connectionsLoading = true;
    });

    try {
      final incoming = await widget.api.incomingRequests();
      final outgoing = await widget.api.outgoingRequests();
      final buddies = await widget.api.buddies();

      setState(() {
        _incomingRequests = incoming;
        _outgoingRequests = outgoing;
        _buddies = buddies;
        _markRefreshed();
      });
    } catch (_) {
      setState(() {
        _incomingRequests = [];
        _outgoingRequests = [];
        _buddies = [];
      });
    } finally {
      setState(() {
        _connectionsLoading = false;
      });
    }
  }

  Future<void> _loadSessionPlans() async {
    setState(() {
      _sessionsLoading = true;
    });

    try {
      final mine = await widget.api.mySessionPlans();
      final discover = await widget.api.discoverSessionPlans();
      if (!mounted) {
        return;
      }

      setState(() {
        _mySessionPlans = mine;
        _discoverSessionPlans = discover;
        _markRefreshed();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _mySessionPlans = [];
        _discoverSessionPlans = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _sessionsLoading = false;
        });
      }
    }
  }

  Future<void> _createSessionPlanFromBuddy(Map<String, dynamic> buddy) async {
    String selectedArea = _canonicalPresetCity(
      (buddy['city'] ?? '').toString(),
    );
    if (selectedArea.isEmpty) {
      selectedArea = _canonicalPresetCity(_city.text.trim());
    }
    if (selectedArea.isEmpty) {
      selectedArea = _supportedCities.first;
    }
    final buddySports = _normalizedSportsFrom(buddy['sports'], buddy['sport']);
    final sportController = TextEditingController(
      text: buddySports.isNotEmpty ? buddySports.first : '',
    );
    String selectedSport = sportController.text.trim().isNotEmpty
        ? sportController.text.trim()
        : (_sport.text.trim().isNotEmpty
              ? _sport.text.trim()
              : _supportedSports[0]);

    if (!_supportedSports
        .any((sport) => sport.toLowerCase() == selectedSport.toLowerCase())) {
      selectedSport = _supportedSports[0];
    }
    sportController.text = selectedSport;

    final maxPlayersController = TextEditingController(text: '4');
    DateTime selectedDateTime = DateTime.now().add(const Duration(hours: 2));

    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Plan a game'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedArea,
                  items: _supportedCities
                      .map(
                        (city) => DropdownMenuItem(
                          value: city,
                          child: Text(city),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedArea = value;
                      });
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Area (city)'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedSport,
                  items: _supportedSports
                      .map(
                        (sport) => DropdownMenuItem(
                          value: sport,
                          child: Text(sport),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedSport = value;
                        sportController.text = value;
                      });
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Sport (game)'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _supportedSports
                      .map(
                        (sport) => ChoiceChip(
                          label: Text(sport),
                          selected: selectedSport.toLowerCase() ==
                              sport.toLowerCase(),
                          onSelected: (_) {
                            setDialogState(() {
                              selectedSport = sport;
                              sportController.text = sport;
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: maxPlayersController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Max players'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Time: ${selectedDateTime.toLocal().toString().substring(0, 16)}',
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 30),
                          ),
                          initialDate: selectedDateTime,
                        );
                        if (date == null || !ctx.mounted) {
                          return;
                        }
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                        );
                        if (time == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedDateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      },
                      child: const Text('Pick'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (approved != true) {
      sportController.dispose();
      maxPlayersController.dispose();
      return;
    }

    try {
      final maxPlayers = int.tryParse(maxPlayersController.text.trim()) ?? 0;
      await widget.api.createSessionPlan(
        scheduledAt: selectedDateTime,
        area: selectedArea,
        sport: sportController.text.trim(),
        skillLevel: _skill,
        maxPlayers: maxPlayers,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Session plan created';
      });
      await _loadSessionPlans();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      sportController.dispose();
      maxPlayersController.dispose();
    }
  }

  Future<void> _joinPlan(String planId) async {
    setState(() {
      _joiningPlanIds.add(planId);
    });

    try {
      await widget.api.joinSessionPlan(planId: planId);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Joined session plan';
      });
      await _loadSessionPlans();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _joiningPlanIds.remove(planId);
        });
      }
    }
  }

  Future<void> _leavePlan(String planId) async {
    setState(() {
      _leavingPlanIds.add(planId);
    });

    try {
      await widget.api.leaveSessionPlan(planId: planId);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Left session plan';
      });
      await _loadSessionPlans();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _leavingPlanIds.remove(planId);
        });
      }
    }
  }

  Future<void> _updatePlanStatus(String planId, String status) async {
    setState(() {
      _updatingPlanIds.add(planId);
    });

    try {
      await widget.api.updateSessionPlanStatus(planId: planId, status: status);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Session status updated to ${_sessionStatusLabel(_normalizedSessionStatus(status))}';
      });
      await _loadSessionPlans();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _updatingPlanIds.remove(planId);
        });
      }
    }
  }

  Future<void> _sendRequest(String receiverId) async {
    setState(() {
      _sendingRequestIds.add(receiverId);
    });

    try {
      await widget.api.sendConnectionRequest(receiverId: receiverId);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Connection request sent';
      });
      await _loadConnections();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _sendingRequestIds.remove(receiverId);
        });
      }
    }
  }

  Future<void> _respondRequest(String requestId, String action) async {
    try {
      await widget.api.respondToRequest(requestId: requestId, action: action);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = action == 'accept'
            ? 'Request accepted'
            : 'Request rejected';
      });
      await _loadConnections();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _cancelOutgoingRequest(String requestId) async {
    setState(() {
      _cancelingRequestIds.add(requestId);
    });

    try {
      await widget.api.cancelOutgoingRequest(requestId: requestId);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Outgoing request cancelled';
      });
      await _loadConnections();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _cancelingRequestIds.remove(requestId);
        });
      }
    }
  }

  Future<void> _removeBuddy(String buddyId) async {
    setState(() {
      _removingBuddyIds.add(buddyId);
    });

    try {
      await widget.api.removeBuddy(buddyId: buddyId);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Buddy removed';
      });
      await _loadConnections();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _removingBuddyIds.remove(buddyId);
        });
      }
    }
  }

  Future<void> _blockUser(String userId) async {
    setState(() {
      _safetyActionUserIds.add(userId);
    });

    try {
      await widget.api.blockUser(userId: userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'User blocked';
      });
      await _loadSuggestions();
      await _loadConnections();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _safetyActionUserIds.remove(userId);
        });
      }
    }
  }

  Future<void> _reportUser(String userId) async {
    final reason = await _pickReportReason();
    if (reason == null) {
      return;
    }

    setState(() {
      _safetyActionUserIds.add(userId);
    });

    try {
      await widget.api.reportUser(userId: userId, reason: reason);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Report submitted';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _safetyActionUserIds.remove(userId);
        });
      }
    }
  }

  Future<String?> _pickReportReason() async {
    final reasons = <String, String>{
      'harassment': 'Harassment',
      'inappropriate_behavior': 'Inappropriate behavior',
      'fraud': 'Fraud',
      'spam': 'Spam',
      'other': 'Other',
    };

    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Report user'),
        children: reasons.entries
            .map(
              (entry) => SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(entry.key),
                child: Text(entry.value),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _onSafetyAction(String action, String userId) async {
    if (action == 'block') {
      await _blockUser(userId);
      return;
    }

    if (action == 'report') {
      await _reportUser(userId);
    }
  }

  Widget _buildSafetyMenu({
    required String userId,
    required bool enabled,
  }) {
    return PopupMenuButton<String>(
      tooltip: 'Safety actions',
      enabled: userId.isNotEmpty && enabled,
      onSelected: (value) => _onSafetyAction(value, userId),
      itemBuilder: (_) => const [
        PopupMenuItem<String>(
          value: 'report',
          child: Text('Report user'),
        ),
        PopupMenuItem<String>(
          value: 'block',
          child: Text('Block user'),
        ),
      ],
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined),
            SizedBox(width: 4),
            Text('Safety'),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptMessageContent(String buddyName) async {
    final controller = TextEditingController();

    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Message $buddyName'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Share time/place or contact details',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  Future<void> _showRecentMessages(String buddyId, String buddyName) async {
    try {
      final messages = await widget.api.buddyMessages(buddyId: buddyId);
      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Recent with $buddyName'),
          content: SizedBox(
            width: 360,
            child: messages.isEmpty
                ? const Text('No messages yet')
                : ListView.separated(
                    shrinkWrap: true,
                    itemBuilder: (_, index) {
                      final message = messages[index];
                      final senderName =
                          (message['sender']?['name'] ?? 'Unknown').toString();
                      final content = (message['content'] ?? '').toString();
                      return Text('$senderName: $content');
                    },
                    separatorBuilder: (_, _) => const Divider(height: 12),
                    itemCount: messages.length,
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _messageBuddy(String buddyId, String buddyName) async {
    final content = await _promptMessageContent(buddyName);
    if (content == null) {
      return;
    }

    setState(() {
      _messagingBuddyIds.add(buddyId);
    });

    try {
      await widget.api.sendBuddyMessage(buddyId: buddyId, content: content);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Message sent';
      });
      await _showRecentMessages(buddyId, buddyName);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _messagingBuddyIds.remove(buddyId);
        });
      }
    }
  }

  bool _isConnected(String userId) {
    return _buddies.any((buddy) => buddy['id']?.toString() == userId);
  }

  bool _hasOutgoingRequest(String userId) {
    return _outgoingRequests.any(
      (request) => request['receiver']?['id']?.toString() == userId,
    );
  }

  bool _hasIncomingRequestFrom(String userId) {
    return _incomingRequests.any(
      (request) => request['sender']?['id']?.toString() == userId,
    );
  }

  bool _isUserInPlan(Map<String, dynamic> plan) {
    return plan['joined'] == true;
  }

  int _planParticipantCount(Map<String, dynamic> plan) {
    final value = plan['participantsCount'];
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _refreshCurrentTab() async {
    switch (_currentTabIndex) {
      case 0:
        await _loadSuggestions();
        break;
      case 1:
        await _loadConnections();
        break;
      case 2:
        await _loadSessionPlans();
        break;
      default:
        await _loadSuggestions();
        await _loadConnections();
        await _loadSessionPlans();
    }
  }

  Widget _buildStatusBanner() {
    final refreshLabel = _relativeRefreshLabel();
    if (_status == null && refreshLabel.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_status != null) Text(_status!),
              if (_status != null && refreshLabel.isNotEmpty)
                const SizedBox(height: 6),
              if (refreshLabel.isNotEmpty)
                Text(
                  refreshLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDiscoverTabChildren(BuildContext context) {
    final gateMessage = !_isProfileReadyForSuggestions()
        ? 'Complete profile before Discover: ${_missingProfileFieldsForSuggestions()}.'
        : null;
    final discoverQuery = _discoverSearch.text.trim().toLowerCase();
    final seenSuggestionIds = <String>{};
    final filteredSuggestions = _suggestions.where((s) {
      final userId = s['user']?['id']?.toString() ?? '';
      if (userId.isNotEmpty) {
        if (_isConnected(userId) || seenSuggestionIds.contains(userId)) {
          return false;
        }
        seenSuggestionIds.add(userId);
      }

      if (discoverQuery.isEmpty) {
        return true;
      }

      final name = (s['user']?['name'] ?? '').toString().toLowerCase();
      final city = (s['user']?['city'] ?? '').toString().toLowerCase();
      return name.contains(discoverQuery) ||
          _sportsContainQuery(
            s['user']?['sports'],
            s['user']?['sport'],
            discoverQuery,
          ) ||
          city.contains(discoverQuery);
    }).toList();

    return [
      _buildStatusBanner(),
      TextField(
        controller: _discoverSearch,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          labelText: 'Search suggestions',
          hintText: 'Name, sport, city',
        ),
      ),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Suggested Buddies',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          TextButton(
            onPressed: (_suggestionsLoading || gateMessage != null)
                ? null
                : _loadSuggestions,
            child: const Text('Refresh'),
          ),
        ],
      ),
      if (gateMessage != null)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(gateMessage),
          ),
        )
      else if (_suggestionsLoading)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_suggestions.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No suggestions yet. Save city, sports, and availability in profile to unlock matches.',
            ),
          ),
        )
      else if (filteredSuggestions.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('No suggestions match your search. Try clearing filters or changing keywords.'),
          ),
        )
      else
        ...filteredSuggestions.map((s) {
          final userId = s['user']?['id']?.toString() ?? '';
          final userHandle = _userHandleFromEmail(s['user']?['email']);
          final isConnected = userId.isNotEmpty && _isConnected(userId);
          final hasOutgoing = userId.isNotEmpty && _hasOutgoingRequest(userId);
          final hasIncoming =
              userId.isNotEmpty && _hasIncomingRequestFrom(userId);
          final isSending =
              userId.isNotEmpty && _sendingRequestIds.contains(userId);
          final isSafetyBusy =
              userId.isNotEmpty && _safetyActionUserIds.contains(userId);
            final suggestionState = isConnected
              ? 'connected'
              : hasOutgoing
              ? 'requested'
              : hasIncoming
              ? 'incoming'
              : 'available';

          Widget actionButton;
          if (isConnected) {
            actionButton = const FilledButton(
              onPressed: null,
              child: Text('Connected'),
            );
          } else if (hasOutgoing) {
            actionButton = const OutlinedButton(
              onPressed: null,
              child: Text('Requested'),
            );
          } else if (hasIncoming) {
            actionButton = const OutlinedButton(
              onPressed: null,
              child: Text('View Requests'),
            );
          } else {
            actionButton = FilledButton(
              onPressed: (isSending || userId.isEmpty || isSafetyBusy)
                  ? null
                  : () => _sendRequest(userId),
              child: Text(isSending ? 'Sending...' : 'Send Request'),
            );
          }

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (s['user']?['name'] ?? 'Unknown').toString(),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (userHandle.isNotEmpty)
                              Text(
                                userHandle,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        radius: 16,
                        child: Text('${s['score']}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildSuggestionStateChip(context, suggestionState),
                  const SizedBox(height: 6),
                  Text(
                    '${_sportsLabelFrom(s['user']?['sports'], s['user']?['sport'])} in ${s['user']?['city'] ?? '-'}',
                  ),
                  const SizedBox(height: 4),
                  Text('Reasons: ${(s['reasons'] as List).join(', ')}'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: actionButton),
                      _buildSafetyMenu(
                        userId: userId,
                        enabled: !isSafetyBusy,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
    ];
  }

  List<Widget> _buildConnectionsTabChildren(BuildContext context) {
    final connectionsQuery = _connectionsSearch.text.trim().toLowerCase();

    final filteredIncoming = _incomingRequests.where((request) {
      if (connectionsQuery.isEmpty) {
        return true;
      }
      final name =
          (request['sender']?['name'] ?? '').toString().toLowerCase();
      return name.contains(connectionsQuery);
    }).toList();

    final filteredOutgoing = _outgoingRequests.where((request) {
      if (connectionsQuery.isEmpty) {
        return true;
      }
      final name =
          (request['receiver']?['name'] ?? '').toString().toLowerCase();
      return name.contains(connectionsQuery);
    }).toList();

    final filteredBuddies = _buddies.where((buddy) {
      if (connectionsQuery.isEmpty) {
        return true;
      }
      final name = (buddy['name'] ?? '').toString().toLowerCase();
      final city = (buddy['city'] ?? '').toString().toLowerCase();
      return name.contains(connectionsQuery) ||
          _sportsContainQuery(
            buddy['sports'],
            buddy['sport'],
            connectionsQuery,
          ) ||
          city.contains(connectionsQuery);
    }).toList();

    return [
      _buildStatusBanner(),
      TextField(
        controller: _connectionsSearch,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          labelText: 'Search connections',
          hintText: 'Name, sport, city',
        ),
      ),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Connection Requests',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          TextButton(
            onPressed: _connectionsLoading ? null : _loadConnections,
            child: const Text('Refresh'),
          ),
        ],
      ),
      if (_connectionsLoading)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator()),
        )
      else ...[
        if (filteredIncoming.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No incoming requests'),
            ),
          )
        else
          ...filteredIncoming.map((request) {
            final senderId = request['sender']?['id']?.toString() ?? '';
            final isSafetyBusy =
                senderId.isNotEmpty && _safetyActionUserIds.contains(senderId);

            return Card(
              child: ListTile(
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        (request['sender']?['name'] ?? 'Unknown').toString(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildConnectionStateChip(context, 'incoming'),
                  ],
                ),
                subtitle: const Text('Respond to accept or reject'),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: 'Reject',
                      onPressed: () =>
                          _respondRequest(request['id'].toString(), 'reject'),
                      icon: const Icon(Icons.close),
                    ),
                    IconButton(
                      tooltip: 'Accept',
                      onPressed: () =>
                          _respondRequest(request['id'].toString(), 'accept'),
                      icon: const Icon(Icons.check),
                    ),
                    _buildSafetyMenu(
                      userId: senderId,
                      enabled: !isSafetyBusy,
                    ),
                  ],
                ),
              ),
            );
          }),
        if (filteredOutgoing.isNotEmpty)
          ...filteredOutgoing.map((request) {
            final requestId = request['id']?.toString() ?? '';
            final receiverId = request['receiver']?['id']?.toString() ?? '';
            final isCanceling =
                requestId.isNotEmpty && _cancelingRequestIds.contains(requestId);
            final isSafetyBusy =
                receiverId.isNotEmpty && _safetyActionUserIds.contains(receiverId);

            return Card(
              child: ListTile(
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        (request['receiver']?['name'] ?? 'Unknown').toString(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildConnectionStateChip(context, 'pending'),
                  ],
                ),
                subtitle: const Text('Waiting for response'),
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    TextButton(
                      onPressed: (requestId.isEmpty || isCanceling)
                          ? null
                          : () => _cancelOutgoingRequest(requestId),
                      child: Text(isCanceling ? 'Cancelling...' : 'Cancel'),
                    ),
                    _buildSafetyMenu(
                      userId: receiverId,
                      enabled: !isSafetyBusy,
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
      const SizedBox(height: 14),
      Text(
        'Connected Buddies',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      if (filteredBuddies.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('No connected buddies match your search.'),
          ),
        )
      else
        ...filteredBuddies.map((buddy) {
          final buddyId = buddy['id']?.toString() ?? '';
          final buddyName = (buddy['name'] ?? 'Unknown').toString();
          final buddyHandle = _userHandleFromEmail(buddy['email']);
          final isRemoving =
              buddyId.isNotEmpty && _removingBuddyIds.contains(buddyId);
          final isSafetyBusy =
              buddyId.isNotEmpty && _safetyActionUserIds.contains(buddyId);
          final isMessaging =
              buddyId.isNotEmpty && _messagingBuddyIds.contains(buddyId);

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (buddy['name'] ?? 'Unknown').toString(),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (buddyHandle.isNotEmpty)
                              Text(
                                buddyHandle,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildConnectionStateChip(context, 'connected'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_sportsLabelFrom(buddy['sports'], buddy['sport'])} in ${buddy['city'] ?? '-'}',
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: (buddyId.isEmpty || isMessaging)
                            ? null
                            : () => _messageBuddy(buddyId, buddyName),
                        child: Text(isMessaging ? 'Sending...' : 'Message'),
                      ),
                      OutlinedButton(
                        onPressed: buddyId.isEmpty
                            ? null
                            : () => _createSessionPlanFromBuddy(buddy),
                        child: const Text('Plan a Game'),
                      ),
                      IconButton(
                        tooltip: 'Recent messages',
                        onPressed: buddyId.isEmpty
                            ? null
                            : () => _showRecentMessages(buddyId, buddyName),
                        icon: const Icon(Icons.chat_bubble_outline),
                      ),
                      TextButton(
                        onPressed: (buddyId.isEmpty || isRemoving)
                            ? null
                            : () => _removeBuddy(buddyId),
                        child: Text(isRemoving ? 'Removing...' : 'Remove'),
                      ),
                      _buildSafetyMenu(
                        userId: buddyId,
                        enabled: !isSafetyBusy,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
    ];
  }

  List<Widget> _buildSessionsTabChildren(BuildContext context) {
    final sessionsQuery = _sessionsSearch.text.trim().toLowerCase();

    final filteredMyPlans = _mySessionPlans.where((plan) {
      if (sessionsQuery.isEmpty) {
        return true;
      }
      final area = (plan['area'] ?? '').toString().toLowerCase();
      final sport = (plan['sport'] ?? '').toString().toLowerCase();
      return area.contains(sessionsQuery) || sport.contains(sessionsQuery);
    }).toList();

    final filteredDiscoverPlans = _discoverSessionPlans.where((plan) {
      if (sessionsQuery.isEmpty) {
        return true;
      }
      final area = (plan['area'] ?? '').toString().toLowerCase();
      final sport = (plan['sport'] ?? '').toString().toLowerCase();
      return area.contains(sessionsQuery) || sport.contains(sessionsQuery);
    }).toList();

    filteredMyPlans.sort((a, b) {
      final statusCompare = _sessionStatusRank(
        _normalizedSessionStatus(a['status']),
      ).compareTo(
        _sessionStatusRank(_normalizedSessionStatus(b['status'])),
      );
      if (statusCompare != 0) {
        return statusCompare;
      }

      return _scheduledAtEpochMillis(a).compareTo(_scheduledAtEpochMillis(b));
    });

    filteredDiscoverPlans.sort((a, b) {
      final statusCompare = _sessionStatusRank(
        _normalizedSessionStatus(a['status']),
      ).compareTo(
        _sessionStatusRank(_normalizedSessionStatus(b['status'])),
      );
      if (statusCompare != 0) {
        return statusCompare;
      }

      return _scheduledAtEpochMillis(a).compareTo(_scheduledAtEpochMillis(b));
    });

    return [
      _buildStatusBanner(),
      TextField(
        controller: _sessionsSearch,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          labelText: 'Search session plans',
          hintText: 'Sport or area',
        ),
      ),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Session Plans',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          TextButton(
            onPressed: _sessionsLoading ? null : _loadSessionPlans,
            child: const Text('Refresh'),
          ),
        ],
      ),
      if (_sessionsLoading)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator()),
        )
      else ...[
        if (filteredMyPlans.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No plans match your search. Try a different sport/area keyword.'),
            ),
          )
        else
          ...filteredMyPlans.map((plan) {
            final planId = (plan['id'] ?? '').toString();
            final status = _normalizedSessionStatus(plan['status']);
            final area = (plan['area'] ?? '-').toString();
            final sport = (plan['sport'] ?? '-').toString();
            final count = _planParticipantCount(plan);
            final maxPlayers = (plan['maxPlayers'] ?? 0) as int;
            final isInPlan = _isUserInPlan(plan);
            final canLeave =
                isInPlan && status != 'completed' && status != 'cancelled';
            final isLeaving =
                planId.isNotEmpty && _leavingPlanIds.contains(planId);
            final isUpdating =
                planId.isNotEmpty && _updatingPlanIds.contains(planId);
            final subtitleText =
                '${_sessionStatusHint(status)} | Players: $count/$maxPlayers';

            return Card(
              child: ListTile(
                title: Row(
                  children: [
                    Expanded(child: Text('$sport at $area')),
                    const SizedBox(width: 8),
                    _buildSessionStatusChip(context, status),
                  ],
                ),
                subtitle: Text(subtitleText),
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    if (canLeave)
                      TextButton(
                        onPressed: (planId.isEmpty || isLeaving)
                            ? null
                            : () => _leavePlan(planId),
                        child: Text(isLeaving ? 'Leaving...' : 'Leave'),
                      ),
                    PopupMenuButton<String>(
                      tooltip: 'Update status',
                      enabled: planId.isNotEmpty && !isUpdating,
                      onSelected: (value) => _updatePlanStatus(planId, value),
                      itemBuilder: (_) => const [
                        PopupMenuItem<String>(
                          value: 'open',
                          child: Text('Set Open'),
                        ),
                        PopupMenuItem<String>(
                          value: 'confirmed',
                          child: Text('Set Confirmed'),
                        ),
                        PopupMenuItem<String>(
                          value: 'completed',
                          child: Text('Set Completed'),
                        ),
                        PopupMenuItem<String>(
                          value: 'cancelled',
                          child: Text('Set Cancelled'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 8),
        Text(
          'Discover from buddies',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (filteredDiscoverPlans.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No discoverable plans match your search. Pull to refresh or try broader filters.'),
            ),
          )
        else
          ...filteredDiscoverPlans.map((plan) {
            final planId = (plan['id'] ?? '').toString();
            final status = _normalizedSessionStatus(plan['status']);
            final area = (plan['area'] ?? '-').toString();
            final sport = (plan['sport'] ?? '-').toString();
            final count = _planParticipantCount(plan);
            final maxPlayers = (plan['maxPlayers'] ?? 0) as int;
            final canJoin = status == 'open' || status == 'confirmed';
            final isJoining =
                planId.isNotEmpty && _joiningPlanIds.contains(planId);
            final subtitleText =
                '${_sessionStatusHint(status)} | Players: $count/$maxPlayers';

            return Card(
              child: ListTile(
                title: Row(
                  children: [
                    Expanded(child: Text('$sport at $area')),
                    const SizedBox(width: 8),
                    _buildSessionStatusChip(context, status),
                  ],
                ),
                subtitle: Text(subtitleText),
                trailing: FilledButton(
                  onPressed: (planId.isEmpty || isJoining || !canJoin)
                      ? null
                      : () => _joinPlan(planId),
                  child: Text(
                    isJoining
                        ? 'Joining...'
                        : canJoin
                        ? 'Join'
                        : 'Closed',
                  ),
                ),
              ),
            );
          }),
      ],
    ];
  }

  List<Widget> _buildProfileTabChildren(
    BuildContext context, {
    VoidCallback? onEditorChanged,
    Future<void> Function()? onSave,
  }) {
    return [
      _buildStatusBanner(),
      Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Profile',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _city,
                decoration: const InputDecoration(labelText: 'City'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _supportedCities
                    .map(
                      (city) => ChoiceChip(
                        label: Text(city),
                        selected:
                            _city.text.trim().toLowerCase() == city.toLowerCase(),
                        onSelected: (_) {
                          setState(() {
                            _city.text = city;
                          });
                          onEditorChanged?.call();
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 10),
              Text(
                'Sports (multi-select)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Selected: ${_selectedSportsSummary()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _supportedSports
                    .map(
                      (sport) => FilterChip(
                        label: Text(sport),
                        selected: _isSportSelected(sport),
                        onSelected: (selected) {
                          setState(() {
                            final canonical = _canonicalSport(sport);
                            if (selected) {
                              _selectedSports.add(canonical);
                            } else {
                              _selectedSports.remove(canonical);
                            }

                            final sorted = _selectedSports.toList()..sort();
                            _sport.text = sorted.isNotEmpty ? sorted.first : '';
                          });
                          onEditorChanged?.call();
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _skill,
                items: const [
                  DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
                  DropdownMenuItem(
                    value: 'intermediate',
                    child: Text('Intermediate'),
                  ),
                  DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _skill = v;
                    });
                    onEditorChanged?.call();
                  }
                },
                decoration: const InputDecoration(labelText: 'Skill'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _availability,
                decoration: const InputDecoration(
                  labelText: 'Availability days',
                  hintText: 'Mon, Wed, Fri',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _weekdayOptions
                    .map(
                      (day) => FilterChip(
                        label: Text(day),
                        selected: _availabilitySet().contains(day),
                        onSelected: (_) {
                          setState(() {
                            _toggleAvailabilityDay(day);
                          });
                          onEditorChanged?.call();
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _profileLoading
                    ? null
                    : () async {
                        if (onSave != null) {
                          await onSave();
                        } else {
                          await _saveProfile();
                        }
                        onEditorChanged?.call();
                      },
                child: Text(_profileLoading ? 'Saving...' : 'Save profile'),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Future<void> _openProfileEditor() async {
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'Edit profile',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                ..._buildProfileTabChildren(
                  context,
                  onEditorChanged: () => setModalState(() {}),
                  onSave: () async {
                    final ok = await _saveProfile();
                    if (ok && ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSearchTabChildren(BuildContext context) {
    final query = _globalSearch.text.trim().toLowerCase();

    final allCities = {
      ..._supportedCities,
      ..._suggestions
          .map((s) => (s['user']?['city'] ?? '').toString().trim())
          .where((c) => c.isNotEmpty),
      ..._buddies
          .map((b) => (b['city'] ?? '').toString().trim())
          .where((c) => c.isNotEmpty),
      ..._mySessionPlans
          .map((p) => (p['area'] ?? '').toString().trim())
          .where((a) => a.isNotEmpty),
      ..._discoverSessionPlans
          .map((p) => (p['area'] ?? '').toString().trim())
          .where((a) => a.isNotEmpty),
    }.toList()
      ..sort();

    final allSports = {
      ..._supportedSports,
      ..._suggestions
          .expand(
            (s) => _normalizedSportsFrom(
              s['user']?['sports'],
              s['user']?['sport'],
            ),
          )
          .where((s) => s.isNotEmpty),
      ..._buddies
          .expand((b) => _normalizedSportsFrom(b['sports'], b['sport']))
          .where((s) => s.isNotEmpty),
      ..._mySessionPlans
          .map((p) => (p['sport'] ?? '').toString().trim())
          .where((s) => s.isNotEmpty),
      ..._discoverSessionPlans
          .map((p) => (p['sport'] ?? '').toString().trim())
          .where((s) => s.isNotEmpty),
    }.toList()
      ..sort();

    final matchedSuggestions = _suggestions.where((s) {
      final sportsValue = s['user']?['sports'];
      final sportValue = s['user']?['sport'];
      final cityValue = (s['user']?['city'] ?? '').toString();

      if (_searchCityFilter != 'All' &&
          cityValue.toLowerCase() != _searchCityFilter.toLowerCase()) {
        return false;
      }

      if (!_sportsMatchFilter(sportsValue, sportValue, _searchSportFilter)) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }
      final name = (s['user']?['name'] ?? '').toString().toLowerCase();
      final city = cityValue.toLowerCase();
      return name.contains(query) ||
          _sportsContainQuery(sportsValue, sportValue, query) ||
          city.contains(query);
    }).toList();

    final matchedBuddies = _buddies.where((b) {
      final sportsValue = b['sports'];
      final sportValue = b['sport'];
      final cityValue = (b['city'] ?? '').toString();

      if (_searchCityFilter != 'All' &&
          cityValue.toLowerCase() != _searchCityFilter.toLowerCase()) {
        return false;
      }

      if (!_sportsMatchFilter(sportsValue, sportValue, _searchSportFilter)) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }
      final name = (b['name'] ?? '').toString().toLowerCase();
      final city = cityValue.toLowerCase();
      return name.contains(query) ||
          _sportsContainQuery(sportsValue, sportValue, query) ||
          city.contains(query);
    }).toList();

    final matchedPlans = [..._mySessionPlans, ..._discoverSessionPlans].where((p) {
      final sportValue = (p['sport'] ?? '').toString();
      final areaValue = (p['area'] ?? '').toString();

      if (_searchCityFilter != 'All' &&
          areaValue.toLowerCase() != _searchCityFilter.toLowerCase()) {
        return false;
      }

      if (_searchSportFilter != 'All' &&
          sportValue.toLowerCase() != _searchSportFilter.toLowerCase()) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }
      final sport = sportValue.toLowerCase();
      final area = areaValue.toLowerCase();
      return sport.contains(query) || area.contains(query);
    }).toList();

    return [
      _buildStatusBanner(),
      TextField(
        controller: _globalSearch,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          labelText: 'Global search',
          hintText: 'Name, sport, city, area',
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _searchCityFilter,
              items: ['All', ...allCities]
                  .map(
                    (city) => DropdownMenuItem(
                      value: city,
                      child: Text(city),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _searchCityFilter = value;
                  });
                }
              },
              decoration: const InputDecoration(labelText: 'Location filter'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _searchSportFilter,
              items: ['All', ...allSports]
                  .map(
                    (sport) => DropdownMenuItem(
                      value: sport,
                      child: Text(sport),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _searchSportFilter = value;
                  });
                }
              },
              decoration: const InputDecoration(labelText: 'Game filter'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Text('Suggestions', style: Theme.of(context).textTheme.titleMedium),
      if (matchedSuggestions.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text('No matching suggestions'),
          ),
        )
      else
        ...matchedSuggestions.map(
          (s) => Card(
            child: ListTile(
              onTap: () {
                final name =
                    (s['user']?['name'] ?? '').toString();
                setState(() {
                  _currentTabIndex = 0;
                  _discoverSearch.text = name;
                });
              },
              title: Text((s['user']?['name'] ?? 'Unknown').toString()),
              subtitle: Text(
                '${_sportsLabelFrom(s['user']?['sports'], s['user']?['sport'])} in ${s['user']?['city'] ?? '-'}',
              ),
              trailing: const Icon(Icons.open_in_new),
            ),
          ),
        ),
      const SizedBox(height: 8),
      Text('Connected Buddies', style: Theme.of(context).textTheme.titleMedium),
      if (matchedBuddies.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text('No matching buddies'),
          ),
        )
      else
        ...matchedBuddies.map(
          (b) => Card(
            child: ListTile(
              onTap: () {
                final name = (b['name'] ?? '').toString();
                setState(() {
                  _currentTabIndex = 1;
                  _connectionsSearch.text = name;
                });
              },
              title: Text((b['name'] ?? 'Unknown').toString()),
              subtitle: Text(
                '${_sportsLabelFrom(b['sports'], b['sport'])} in ${b['city'] ?? '-'}',
              ),
              trailing: const Icon(Icons.open_in_new),
            ),
          ),
        ),
      const SizedBox(height: 8),
      Text('Session Plans', style: Theme.of(context).textTheme.titleMedium),
      if (matchedPlans.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text('No matching session plans'),
          ),
        )
      else
        ...matchedPlans.map(
          (p) => Card(
            child: ListTile(
              onTap: () {
                final sport = (p['sport'] ?? '').toString();
                setState(() {
                  _currentTabIndex = 2;
                  _sessionsSearch.text = sport;
                });
              },
              title: Text('${p['sport'] ?? '-'} at ${p['area'] ?? '-'}'),
              subtitle: Text(
                _sessionStatusHint(_normalizedSessionStatus(p['status'])),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSessionStatusChip(
                    context,
                    _normalizedSessionStatus(p['status']),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.open_in_new),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  String _currentTabTitle() {
    switch (_currentTabIndex) {
      case 0:
        return 'Discover';
      case 1:
        return 'Connections';
      case 2:
        return 'Sessions';
      default:
        return 'Search';
    }
  }

  List<Widget> _currentTabChildren(BuildContext context) {
    switch (_currentTabIndex) {
      case 0:
        return _buildDiscoverTabChildren(context);
      case 1:
        return _buildConnectionsTabChildren(context);
      case 2:
        return _buildSessionsTabChildren(context);
      default:
        return _buildSearchTabChildren(context);
    }
  }

  @override
  void dispose() {
    _city.dispose();
    _sport.dispose();
    _availability.dispose();
    _discoverSearch.dispose();
    _connectionsSearch.dispose();
    _sessionsSearch.dispose();
    _globalSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTabTitle()),
        actions: [
          IconButton(
            onPressed: _openProfileEditor,
            icon: const Icon(Icons.person_outline),
            tooltip: 'Edit profile',
          ),
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshCurrentTab,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: _currentTabChildren(context),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Connections',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Sessions',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
        ],
      ),
    );
  }
}

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
  final _city = TextEditingController();
  final _sport = TextEditingController();
  final _availability = TextEditingController();

  String _skill = 'beginner';
  bool _profileLoading = false;
  bool _suggestionsLoading = false;
  String? _status;
  List<Map<String, dynamic>> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _hydrateProfile();
    _loadSuggestions();
  }

  void _hydrateProfile() {
    final user = widget.initialUser;
    if (user == null) {
      return;
    }

    _city.text = (user['city'] ?? '').toString();
    _sport.text = (user['sport'] ?? '').toString();
    _skill = (user['skillLevel'] ?? 'beginner').toString();

    final days = ((user['availabilityDays'] ?? []) as List)
        .map((d) => d.toString())
        .join(',');
    _availability.text = days;
  }

  Future<void> _saveProfile() async {
    setState(() {
      _profileLoading = true;
      _status = null;
    });

    try {
      await widget.api.updateProfile(
        city: _city.text.trim(),
        sport: _sport.text.trim(),
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
    } catch (e) {
      setState(() {
        _status = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _profileLoading = false;
      });
    }
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _suggestionsLoading = true;
    });

    try {
      final data = await widget.api.suggestions();
      final list = data
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      setState(() {
        _suggestions = list;
      });
    } catch (_) {
      setState(() {
        _suggestions = [];
      });
    } finally {
      setState(() {
        _suggestionsLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _city.dispose();
    _sport.dispose();
    _availability.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sports Buddy'),
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSuggestions,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                    const SizedBox(height: 10),
                    TextField(
                      controller: _sport,
                      decoration: const InputDecoration(labelText: 'Sport'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _skill,
                      items: const [
                        DropdownMenuItem(
                          value: 'beginner',
                          child: Text('Beginner'),
                        ),
                        DropdownMenuItem(
                          value: 'intermediate',
                          child: Text('Intermediate'),
                        ),
                        DropdownMenuItem(
                          value: 'advanced',
                          child: Text('Advanced'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _skill = v;
                          });
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
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _profileLoading ? null : _saveProfile,
                      child: Text(_profileLoading ? 'Saving...' : 'Save profile'),
                    ),
                    if (_status != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_status!),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Suggested Buddies',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: _suggestionsLoading ? null : _loadSuggestions,
                  child: const Text('Refresh'),
                ),
              ],
            ),
            if (_suggestionsLoading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_suggestions.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No suggestions yet. Complete profile details to see matches.',
                  ),
                ),
              )
            else
              ..._suggestions.map(
                (s) => Card(
                  child: ListTile(
                    title: Text((s['user']?['name'] ?? 'Unknown').toString()),
                    subtitle: Text(
                      '${s['user']?['sport'] ?? '-'} in ${s['user']?['city'] ?? '-'}\n'
                      'Reasons: ${(s['reasons'] as List).join(', ')}',
                    ),
                    isThreeLine: true,
                    trailing: CircleAvatar(
                      child: Text('${s['score']}'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
  bool _connectionsLoading = false;
  String? _status;
  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> _incomingRequests = [];
  List<Map<String, dynamic>> _outgoingRequests = [];
  List<Map<String, dynamic>> _buddies = [];
  final Set<String> _sendingRequestIds = <String>{};
  final Set<String> _cancelingRequestIds = <String>{};
  final Set<String> _removingBuddyIds = <String>{};
  final Set<String> _safetyActionUserIds = <String>{};

  @override
  void initState() {
    super.initState();
    _hydrateProfile();
    _loadSuggestions();
    _loadConnections();
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
                (s) {
                  final userId = s['user']?['id']?.toString() ?? '';
                  final isConnected = userId.isNotEmpty && _isConnected(userId);
                  final hasOutgoing =
                      userId.isNotEmpty && _hasOutgoingRequest(userId);
                  final hasIncoming =
                      userId.isNotEmpty && _hasIncomingRequestFrom(userId);
                  final isSending =
                      userId.isNotEmpty && _sendingRequestIds.contains(userId);
                  final isSafetyBusy =
                    userId.isNotEmpty && _safetyActionUserIds.contains(userId);

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
                      child: Text('Respond in Requests'),
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
                    child: ListTile(
                      title: Text((s['user']?['name'] ?? 'Unknown').toString()),
                      subtitle: Text(
                        '${s['user']?['sport'] ?? '-'} in ${s['user']?['city'] ?? '-'}\n'
                        'Reasons: ${(s['reasons'] as List).join(', ')}',
                      ),
                      isThreeLine: true,
                      trailing: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 170),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              child: Text('${s['score']}'),
                            ),
                            const SizedBox(height: 8),
                            actionButton,
                            PopupMenuButton<String>(
                              tooltip: 'Safety actions',
                              enabled: userId.isNotEmpty && !isSafetyBusy,
                              onSelected: (value) =>
                                  _onSafetyAction(value, userId),
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
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 14),
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
              if (_incomingRequests.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No incoming requests'),
                  ),
                )
              else
                ..._incomingRequests.map(
                  (request) {
                    final senderId = request['sender']?['id']?.toString() ?? '';
                    final isSafetyBusy =
                        senderId.isNotEmpty &&
                        _safetyActionUserIds.contains(senderId);

                    return Card(
                      child: ListTile(
                        title: Text(
                          (request['sender']?['name'] ?? 'Unknown').toString(),
                        ),
                        subtitle: const Text('Incoming request'),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              tooltip: 'Reject',
                              onPressed: () => _respondRequest(
                                request['id'].toString(),
                                'reject',
                              ),
                              icon: const Icon(Icons.close),
                            ),
                            IconButton(
                              tooltip: 'Accept',
                              onPressed: () => _respondRequest(
                                request['id'].toString(),
                                'accept',
                              ),
                              icon: const Icon(Icons.check),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Safety actions',
                              enabled: senderId.isNotEmpty && !isSafetyBusy,
                              onSelected: (value) =>
                                  _onSafetyAction(value, senderId),
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
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              if (_outgoingRequests.isNotEmpty)
                ..._outgoingRequests.map(
                  (request) {
                    final requestId = request['id']?.toString() ?? '';
                    final receiverId =
                        request['receiver']?['id']?.toString() ?? '';
                    final isCanceling =
                        requestId.isNotEmpty &&
                        _cancelingRequestIds.contains(requestId);
                    final isSafetyBusy =
                        receiverId.isNotEmpty &&
                        _safetyActionUserIds.contains(receiverId);

                    return Card(
                      child: ListTile(
                        title: Text(
                          (request['receiver']?['name'] ?? 'Unknown').toString(),
                        ),
                        subtitle: const Text('Outgoing request (pending)'),
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            TextButton(
                              onPressed: (requestId.isEmpty || isCanceling)
                                  ? null
                                  : () => _cancelOutgoingRequest(requestId),
                              child: Text(
                                isCanceling ? 'Cancelling...' : 'Cancel',
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Safety actions',
                              enabled: receiverId.isNotEmpty && !isSafetyBusy,
                              onSelected: (value) =>
                                  _onSafetyAction(value, receiverId),
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
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
            const SizedBox(height: 14),
            Text(
              'Connected Buddies',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (_buddies.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No connected buddies yet.'),
                ),
              )
            else
              ..._buddies.map(
                (buddy) {
                  final buddyId = buddy['id']?.toString() ?? '';
                  final isRemoving =
                      buddyId.isNotEmpty && _removingBuddyIds.contains(buddyId);
                  final isSafetyBusy =
                      buddyId.isNotEmpty && _safetyActionUserIds.contains(buddyId);

                  return Card(
                    child: ListTile(
                      title: Text((buddy['name'] ?? 'Unknown').toString()),
                      subtitle: Text(
                        '${buddy['sport'] ?? '-'} in ${buddy['city'] ?? '-'}',
                      ),
                      leading: const Icon(Icons.people),
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          TextButton(
                            onPressed: (buddyId.isEmpty || isRemoving)
                                ? null
                                : () => _removeBuddy(buddyId),
                            child: Text(isRemoving ? 'Removing...' : 'Remove'),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Safety actions',
                            enabled: buddyId.isNotEmpty && !isSafetyBusy,
                            onSelected: (value) =>
                                _onSafetyAction(value, buddyId),
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
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

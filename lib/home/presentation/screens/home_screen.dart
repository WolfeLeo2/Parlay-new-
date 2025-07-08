import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:avatar_stack/animated_avatar_stack.dart';
import 'package:avatar_stack/positions.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'dart:async'; // Import the async library for Timer


// Mock current user
const String currentUserAvatar = 'https://randomuser.me/api/portraits/men/10.jpg';
const String currentUserName = 'You';

// Riverpod provider for selected poll index
final selectedPollIndexProvider = StateProvider<int>((ref) => 0);

// New Riverpod provider for selected group ID
final selectedGroupIdProvider = StateProvider<String>((ref) => mockGroups.first['id']!);

// GridItem model to represent each item in the grid
class GridItem {
  final String id;
  final String type; // e.g., 'recap', 'poll', 'trip', 'documents', 'add'
  int span; // Number of columns the item spans (1 or 2)
  bool showDeleteIcon; // Whether to show the delete icon

  GridItem({
    required this.id,
    required this.type,
    this.span = 1,
    this.showDeleteIcon = false,
  });

  // Create a copy of the GridItem with some fields updated
  GridItem copyWith({
    String? id,
    String? type,
    int? span,
    bool? showDeleteIcon,
  }) {
    return GridItem(
      id: id ?? this.id,
      type: type ?? this.type,
      span: span ?? this.span,
      showDeleteIcon: showDeleteIcon ?? this.showDeleteIcon,
    );
  }
}

// Riverpod provider for the list of grid items
final gridItemsProvider = StateProvider<List<GridItem>>((ref) => [
  GridItem(id: 'poll_initial', type: 'poll'),
  GridItem(id: 'trip_initial', type: 'trip'),
  GridItem(id: 'documents_initial', type: 'documents'),
  GridItem(id: 'add_initial', type: 'add'),
]);

// Mock group data with specific content for each group
final List<Map<String, dynamic>> mockGroups = [
  {
    'id': 'group_smiths',
    'name': 'The Smiths',
    'pollTitle': 'Dinner Out',
    'pollOptions': [
      {'label': 'Pizza', 'avatars': ['https://randomuser.me/api/portraits/men/1.jpg', 'https://randomuser.me/api/portraits/women/2.jpg',], 'names': ['Alex', 'Sam']},
      {'label': 'Mexican', 'avatars': ['https://randomuser.me/api/portraits/women/3.jpg',], 'names': ['Jamie']},
      {'label': 'Japanese', 'avatars': [], 'names': []},
    ],
    'tripDetails': {
      'image': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=400&q=80',
      'title': 'Sardinia Trip',
      'daysRemaining': 38,
    },
    'avatarUrls': [
      'https://randomuser.me/api/portraits/men/1.jpg',
      'https://randomuser.me/api/portraits/women/2.jpg',
      'https://randomuser.me/api/portraits/women/3.jpg',
      'https://randomuser.me/api/portraits/men/4.jpg', // Add extra for demo
    ],
    'recapDetails': {'qtnas': 1, 'tasks': 2, 'replies': 5},
    'documentCount': 15,
  },
  {
    'id': 'group_fellowship',
    'name': 'The Fellowship',
    'pollTitle': 'Meal Ideas',
    'pollOptions': [
      {'label': 'Second Breakfast', 'avatars': ['https://randomuser.me/api/portraits/men/5.jpg',], 'names': ['Frodo']},
      {'label': 'Elevenses', 'avatars': ['https://randomuser.me/api/portraits/men/6.jpg', 'https://randomuser.me/api/portraits/men/7.jpg',], 'names': ['Sam', 'Pippin']},
      {'label': 'Dinner', 'avatars': [], 'names': []},
    ],
    'tripDetails': {
      'image': 'https://images.unsplash.com/photo-1502602898669-a355a4f34245?auto=format&fit=crop&w=400&q=80',
      'title': 'Journey to Mordor',
      'daysRemaining': 365,
    },
     'avatarUrls': [
      'https://randomuser.me/api/portraits/men/5.jpg',
      'https://randomuser.me/api/portraits/men/6.jpg',
      'https://randomuser.me/api/portraits/men/7.jpg',
      'https://randomuser.me/api/portraits/men/8.jpg', // Add extra for demo
    ],
    'recapDetails': {'qtnas': 0, 'tasks': 1, 'replies': 10},
    'documentCount': 7,
  },
  {
    'id': 'group_avengers',
    'name': 'Avengers Assemble',
    'pollTitle': 'Chores',
    'pollOptions': [
      {'label': 'Team Meeting', 'avatars': ['https://randomuser.me/api/portraits/men/9.jpg', 'https://randomuser.me/api/portraits/women/10.jpg',], 'names': ['Tony', 'Natasha']},
      {'label': 'Training Session that is quite long', 'avatars': ['https://randomuser.me/api/portraits/men/11.jpg',], 'names': ['Steve']},
      {'label': 'Another Long Option to Test Scrolling and Wrapping', 'avatars': [], 'names': []},
      {'label': 'Yet Another Option', 'avatars': [], 'names': []},
    ],
    'tripDetails': {
      'image': 'https://images.unsplash.com/photo-1503023345310-bd7c1de61c5d?auto=format&fit=crop&w=800&q=60', // Replaced broken URL
      'title': 'Saving the World',
      'daysRemaining': 1,
    },
     'avatarUrls': [
      'https://randomuser.me/api/portraits/men/9.jpg',
      'https://randomuser.me/api/portraits/women/10.jpg',
      'https://randomuser.me/api/portraits/men/11.jpg',
      'https://randomuser.me/api/portraits/men/12.jpg', // Add extra for demo
    ],
    'recapDetails': {'qtnas': 3, 'tasks': 5, 'replies': 2},
    'documentCount': 42,
  },
];

// Mock poll data (without avatars for current user) - Removed as not used
// final List<Map<String, dynamic>> _basePollOptions = [
//   {
//     'label': 'Pizza',
//     'avatars': [
//       'https://randomuser.me/api/portraits/men/1.jpg',
//       'https://randomuser.me/api/portraits/women/2.jpg',
//     ],
//     'names': ['Alex', 'Sam'],
//   },
//   {
//     'label': 'Mexican',
//     'avatars': [
//       'https://randomuser.me/api/portraits/women/3.jpg',
//     ],
//     'names': ['Jamie'],
//   },\n//   {
//     'label': 'Japanese',
//     'avatars': [],
//     'names': [],
//   },
// ];

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedPollIndexProvider);
    final selectedGroupId = ref.watch(selectedGroupIdProvider);

    // Get the currently selected group object
    final selectedGroup = mockGroups.firstWhere(
      (group) => group['id'] == selectedGroupId,
      orElse: () => mockGroups.first,
    );

    // Use the poll options from the selected group
    final List<Map<String, dynamic>> groupPollOptions = List<Map<String, dynamic>>.from(selectedGroup['pollOptions'] as List);

    // Clone poll options and add current user avatar/name to selected option
    final pollOptions = List<Map<String, dynamic>>.generate(groupPollOptions.length, (i) {
      final option = Map<String, dynamic>.from(groupPollOptions[i]);
      final avatars = List<String>.from(option['avatars'] as List);
      final names = List<String>.from(option['names'] as List);
      if (i == selectedIndex && !avatars.contains(currentUserAvatar)) {
        avatars.add(currentUserAvatar);
        names.add(currentUserName);
      } else if (i != selectedIndex && avatars.contains(currentUserAvatar)) {
        avatars.remove(currentUserAvatar);
        names.remove(currentUserName);
      }
      option['avatars'] = avatars;
      option['names'] = names;
      return option;
    });

    // Get trip details from the selected group
    final Map<String, dynamic> tripDetails = Map<String, dynamic>.from(selectedGroup['tripDetails'] as Map);

    // Get recap details from the selected group
    final Map<String, int> recapDetails = Map<String, int>.from(selectedGroup['recapDetails'] as Map);

    // Get document count from the selected group
    final int documentCount = selectedGroup['documentCount'] as int;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: const Color(0xFFF7F6F2),
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F6F2),
        body: Stack(
          children: [
            SafeArea(
              top: true,
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Header(),
                  const SizedBox(height: 0), // Reduced from 12
                  _RecapCard(recapDetails: recapDetails), // Static recap card
                  const SizedBox(height: 20), // Increased from 8
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28.0),
                    child: Text('Threads', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 16, letterSpacing: 0.2)),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      // Wrap GridView in a StateulWidget to manage timer
                      child: _ReorderableGridContainer(
                        pollOptions: pollOptions,
                        selectedIndex: selectedIndex,
                        selectedGroupId: selectedGroupId,
                        tripDetails: tripDetails,
                        recapDetails: recapDetails,
                        documentCount: documentCount,
                      ),
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
}

// Stateful widget to manage the timer for hiding delete icons
class _ReorderableGridContainer extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> pollOptions;
  final int selectedIndex;
  final String selectedGroupId;
  final Map<String, dynamic> tripDetails;
  final Map<String, int> recapDetails;
  final int documentCount;

  const _ReorderableGridContainer({
    required this.pollOptions,
    required this.selectedIndex,
    required this.selectedGroupId,
    required this.tripDetails,
    required this.recapDetails,
    required this.documentCount,
    super.key,
  });

  @override
  ConsumerState<_ReorderableGridContainer> createState() => _ReorderableGridContainerState();
}

class _ReorderableGridContainerState extends ConsumerState<_ReorderableGridContainer> {
  Timer? _hideIconTimer;

  @override
  void dispose() {
    _hideIconTimer?.cancel();
    super.dispose();
  }

  // Function to start the timer to hide icons
  void _startHideTimer() {
    _hideIconTimer?.cancel(); // Cancel any existing timer
    _hideIconTimer = Timer(const Duration(seconds: 5), () {
      // Hide all delete icons after the timer expires
      ref.read(gridItemsProvider.notifier).update((state) {
        final newState = List<GridItem>.from(state);
        for (var item in newState) {
          item.showDeleteIcon = false; // Set flag to false for all items
        }
        return newState; // Return modified list
      });
    });
  }

  // Function to hide all icons immediately
  void _hideIconsImmediately() {
     _hideIconTimer?.cancel(); // Cancel timer if running
     ref.read(gridItemsProvider.notifier).update((state) {
        final newState = List<GridItem>.from(state);
        for (var item in newState) {
          item.showDeleteIcon = false; // Set flag to false for all items
        }
        return newState; // Return modified list
     });
  }

  @override
  Widget build(BuildContext context) {
    final gridItems = ref.watch(gridItemsProvider);

    // Check if any delete icon is currently shown
    final bool anyIconShown = gridItems.any((item) => item.showDeleteIcon);
    // If any icon is shown and there's no active timer, start the timer
    if (anyIconShown && (_hideIconTimer == null || !_hideIconTimer!.isActive)) {
       _startHideTimer();
    } else if (!anyIconShown) {
      // If no icon is shown, cancel the timer (in case it was about to hide)
      _hideIconTimer?.cancel();
    }

    return Stack(
      children: [
        // Transparent GestureDetector to hide delete icons when tapped outside
        Positioned.fill(
          child: GestureDetector(
            onTap: _hideIconsImmediately, // Hide icons immediately on tap outside
            // This is important to ensure taps don't interfere with grid item taps
            behavior: HitTestBehavior.translucent,
          ),
        ),
        // Use ReorderableGridView from the reorderable_grid_view package
        ReorderableGridView.builder(
          itemCount: gridItems.length,
          itemBuilder: (context, index) {
            final item = gridItems[index];
            
            // Build the appropriate card widget based on item type
            Widget cardWidget;
            switch (item.type) {
              case 'poll':
                cardWidget = PollCard(
                  id: item.id, 
                  type: item.type, 
                  pollOptions: widget.pollOptions, 
                  selectedIndex: widget.selectedIndex, 
                  ref: ref, 
                  selectedGroupId: widget.selectedGroupId, 
                  showDeleteIcon: item.showDeleteIcon
                );
                break;
              case 'trip':
                cardWidget = _TripCard(
                  id: item.id, 
                  type: item.type, 
                  tripDetails: widget.tripDetails, 
                  selectedGroupId: widget.selectedGroupId, 
                  showDeleteIcon: item.showDeleteIcon
                );
                break;
              case 'documents':
                cardWidget = _DocumentsCard(
                  id: item.id, 
                  type: item.type, 
                  documentCount: widget.documentCount, 
                  selectedGroupId: widget.selectedGroupId, 
                  showDeleteIcon: item.showDeleteIcon
                );
                break;
              case 'add':
                return _AddCard(key: ValueKey('add_card'));
              default:
                cardWidget = Container();
            }
            
            // Wrap in GestureDetector for interactions
            return GestureDetector(
              key: ValueKey(item.id),
              onLongPress: () {
                _hideIconTimer?.cancel();
                ref.read(gridItemsProvider.notifier).update((state) {
                  final newState = List<GridItem>.from(state);
                  for (var i = 0; i < newState.length; i++) {
                    if (i != index) {
                      newState[i] = newState[i].copyWith(showDeleteIcon: false);
                    }
                  }
                  if (item.type != 'add') {
                    newState[index] = newState[index].copyWith(
                      showDeleteIcon: !newState[index].showDeleteIcon
                    );
                  }
                  return newState;
                });
              },
              onDoubleTap: () {
                if (item.type != 'add') {
                  _hideIconsImmediately();
                  ref.read(gridItemsProvider.notifier).update((state) {
                    final newState = List<GridItem>.from(state);
                    final index = newState.indexWhere((gridItem) => gridItem.id == item.id);
                    if (index != -1) {
                      final currentItem = newState[index];
                      final newSpan = currentItem.span == 1 ? 2 : 1;
                      newState[index] = currentItem.copyWith(span: newSpan);
                    }
                    return newState;
                  });
                }
              },
              child: item.span == 2 
                ? SizedBox(
                    width: double.infinity,
                    child: cardWidget,
                  )
                : cardWidget,
            );
          },
          onReorder: (oldIndex, newIndex) {
            ref.read(gridItemsProvider.notifier).update((state) {
              final newState = List<GridItem>.from(state);
              final item = newState.removeAt(oldIndex);
              newState.insert(newIndex, item);
              
              // Move add card to the end if it's not already there
              final addCardIndex = newState.indexWhere((item) => item.type == 'add');
              if (addCardIndex != -1 && addCardIndex != newState.length - 1) {
                final addCardItem = newState.removeAt(addCardIndex);
                newState.add(addCardItem);
              }
              
              // Hide delete icons after reorder
              for (var item in newState) {
                item.showDeleteIcon = false;
              }
              
              return newState;
            });
            _hideIconTimer?.cancel();
          },
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
        ),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the currently selected group name from the provider based on ID
    final selectedGroupId = ref.watch(selectedGroupIdProvider);
    final selectedGroup = mockGroups.firstWhere(
      (group) => group['id'] == selectedGroupId,
      orElse: () => mockGroups.first, // Fallback
    );

    // Use the avatar URLs from the selected group
    final List<String> avatarUrls = List<String>.from(selectedGroup['avatarUrls'] as List);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Leo M.', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 18)),
                const SizedBox(height: 2),
                // Tappable section for group name and refresh icon
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (BuildContext context) {
                        return _GroupSelectionModal(); // Call the new modal widget
                      },
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Display selected group name (using placeholder for now)
                      Text(
                        selectedGroup['name']!,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(CupertinoIcons.refresh_thick, size: 18, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text('Recap', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 15)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Animated Avatars
          AnimatedAvatarStack(
            height: 32,
            width: 90,
            avatars: [for (final url in avatarUrls) NetworkImage(url)],
            borderColor: Colors.white,
            borderWidth: 2.0,
            settings: RestrictedPositions(
              maxCoverage: 0.45,
              minCoverage: 0.45,
              align: StackAlign.left,
            ),
            infoWidgetBuilder: (context, surplus) => Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '+$surplus',
                    style: const TextStyle(fontSize: 13, color: Colors.black, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecapCard extends StatelessWidget {
  final Map<String, int> recapDetails;
  
  const _RecapCard({
    required this.recapDetails,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 28.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 17,
              offset: const Offset(0, 4.5),
            ),
          ],
        ),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 22.0, // Increased from 20.0
              color: Colors.black,
              height: 1.45,
              fontWeight: FontWeight.w400,
            ),
            children: [
              const TextSpan(text: 'Today you got '),
              WidgetSpan(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: Icon(CupertinoIcons.question_circle_fill, 
                  color: Colors.pink, 
                  size: 22.0, // Increased from 20.0
                ),
              )),
              TextSpan(
                text: ' ${recapDetails['qtnas']} QTNA, ',
                style: const TextStyle(fontWeight: FontWeight.w700) // Bolder
              ),
              TextSpan(
                text: '${recapDetails['tasks']} tasks ',
                style: const TextStyle(fontWeight: FontWeight.w700) // Bolder
              ),
              WidgetSpan(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: Icon(CupertinoIcons.check_mark_circled_solid, 
                  color: Colors.amber, 
                  size: 22.0, // Increased from 20.0
                ),
              )),
              const TextSpan(text: ', and '),
              TextSpan(
                text: "Summer Trip", 
                style: const TextStyle(fontWeight: FontWeight.w700) // Bolder
              ),
              const TextSpan(text: ' has '),
              TextSpan(
                text: '${recapDetails['replies']} replies', 
                style: const TextStyle(fontWeight: FontWeight.w700) // Bolder
              ),
              WidgetSpan(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: Icon(CupertinoIcons.reply, 
                  color: Colors.blue, 
                  size: 22.0, // Increased from 20.0
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class PollCard extends ConsumerWidget {
  final String id;
  final String type;
  final List<Map<String, dynamic>> pollOptions;
  final int selectedIndex;
  final WidgetRef ref;
  final String selectedGroupId;
  final bool showDeleteIcon;
  
  const PollCard({
    required this.id, 
    required this.type, 
    required this.pollOptions, 
    required this.selectedIndex, 
    required this.ref, 
    required this.selectedGroupId, 
    required this.showDeleteIcon, 
    super.key
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6D6),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(CupertinoIcons.lightbulb_fill, color: Colors.amber[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      ' ${mockGroups.firstWhere((group) => group['id'] == selectedGroupId, orElse: () => {'pollTitle': 'Poll'})['pollTitle']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                  ],
                ),
                if (showDeleteIcon)
                  GestureDetector(
                    onTap: () {
                      ref.read(gridItemsProvider.notifier).update((state) {
                        state.removeWhere((item) => item.id == id);
                        return List.from(state);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 16, color: Colors.red),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: pollOptions.length,
                itemBuilder: (context, i) {
                  return _PollOption(
                    text: pollOptions[i]['label'] as String,
                    selected: i == selectedIndex,
                    avatars: pollOptions[i]['avatars'] as List<String>,
                    names: pollOptions[i]['names'] as List<String>,
                    index: i,
                    selectedIndex: selectedIndex,
                    ref: ref,
                    selectedGroupId: selectedGroupId,
                    showDeleteIcon: showDeleteIcon,
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PollOption extends StatelessWidget {
  final String text;
  final bool selected;
  final List<String> avatars;
  final List<String> names;
  final int index;
  final int selectedIndex;
  final WidgetRef ref;
  final String selectedGroupId;
  final bool showDeleteIcon; // Added showDeleteIcon parameter
  const _PollOption({required this.text, required this.selected, required this.avatars, required this.names, required this.index, required this.selectedIndex, required this.ref, required this.selectedGroupId, required this.showDeleteIcon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
         // If delete icon is shown, tapping the option should not open the modal
         if (!showDeleteIcon) {
            showModalBottomSheet(
              context: context,
              builder: (_) => _VotersModal(option: text, avatars: avatars, names: names, selectedGroupId: selectedGroupId),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
            );
         }
      },
      onLongPress: () {
        if (index == selectedIndex) {
          HapticFeedback.mediumImpact();
          return;
        }
        // If delete icon is shown, long pressing the option should not select it
        if (!showDeleteIcon) {
           ref.read(selectedPollIndexProvider.notifier).state = index;
           HapticFeedback.heavyImpact();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Icon(
              selected ? CupertinoIcons.circle_filled : CupertinoIcons.circle,
              color: selected ? Colors.brown : Colors.grey[400],
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            if (avatars.isNotEmpty) ...[
              const SizedBox(width: 10),
              AnimatedAvatarStack(
                height: 20,
                width: 50,
                avatars: [for (final url in avatars) NetworkImage(url)],
                borderColor: Colors.white,
                borderWidth: 1.5,
                settings: RestrictedPositions(
                  maxCoverage: 0.45,
                  minCoverage: 0.45,
                  align: StackAlign.left,
                ),
                infoWidgetBuilder: (context, surplus) => Center(
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '+$surplus',
                        style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VotersModal extends StatelessWidget {
  final String option;
  final List<String> avatars;
  final List<String> names;
  final String selectedGroupId;
  const _VotersModal({required this.option, required this.avatars, required this.names, required this.selectedGroupId});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Voted for $option', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 18),
          if (avatars.isEmpty)
            const Text('No one has voted for this option yet.'),
          if (avatars.isNotEmpty)
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: List.generate(avatars.length, (i) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _avatar(avatars[i], size: 32),
                  const SizedBox(width: 8),
                  Text(names[i], style: const TextStyle(fontSize: 16)),
                ],
              )),
            ),
        ],
      ),
    );
  }
}

class _TripCard extends ConsumerWidget {
  final String id;
  final String type;
  final Map<String, dynamic> tripDetails;
  final String selectedGroupId;
  final bool showDeleteIcon;
  
  const _TripCard({
    required this.id, 
    required this.type, 
    required this.tripDetails, 
    required this.selectedGroupId, 
    required this.showDeleteIcon, 
    super.key
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('', style: TextStyle(fontSize: 0)), // Spacer
                if (showDeleteIcon)
                  GestureDetector(
                    onTap: () {
                      ref.read(gridItemsProvider.notifier).update((state) {
                        state.removeWhere((item) => item.id == id);
                        return List.from(state);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 16, color: Colors.red),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      tripDetails['image'] as String,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(CupertinoIcons.airplane, color: Colors.black, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              tripDetails['title'] as String, 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
            ),
            Text(
              'in ${tripDetails['daysRemaining']} days', 
              style: const TextStyle(color: Colors.grey, fontSize: 14)
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentsCard extends ConsumerWidget {
  final String id;
  final String type;
  final int documentCount;
  final String selectedGroupId;
  final bool showDeleteIcon;
  const _DocumentsCard({required this.id, required this.type, required this.documentCount, required this.selectedGroupId, required this.showDeleteIcon, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(CupertinoIcons.folder, color: Colors.blue, size: 36),
                if (showDeleteIcon)
                  GestureDetector(
                    onTap: () {
                      ref.read(gridItemsProvider.notifier).update((state) {
                        state.removeWhere((item) => item.id == id);
                        return List.from(state);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 16, color: Colors.red),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('$documentCount files', style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _AddCard extends StatelessWidget {
  const _AddCard({super.key});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Show modal to select card type to add
        showModalBottomSheet(
          context: context,
          builder: (BuildContext context) {
            return _AddCardModal(); // Call the new modal widget
          },
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Icon(CupertinoIcons.add, color: Colors.grey, size: 36),
        ),
      ),
    );
  }
}

// New widget for adding a card
class _AddCardModal extends ConsumerWidget {
  const _AddCardModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // List of available card types to add (excluding recap and add card)
    final List<String> availableCardTypes = ['poll', 'trip', 'documents'];

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add a Card',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16.0),
          // List of card types to add
          Consumer(
            builder: (context, ref, _) {
              final gridItems = ref.watch(gridItemsProvider);
              final existingCardTypes = gridItems.map((item) => item.type).toSet();

              return ListView.builder(
                shrinkWrap: true,
                itemCount: availableCardTypes.length,
                itemBuilder: (context, index) {
                  final cardType = availableCardTypes[index];
                  final alreadyExists = existingCardTypes.contains(cardType);

                  return ListTile(
                    title: Text(cardType.replaceFirst(cardType[0], cardType[0].toUpperCase())),
                    enabled: !alreadyExists,
                    subtitle: alreadyExists ? const Text('Already added') : null,
                    onTap: () {
                      if (alreadyExists) return;

                      ref.read(gridItemsProvider.notifier).update((state) {
                        final newState = List<GridItem>.from(state);
                        final newGridItem = GridItem(id: DateTime.now().toIso8601String(), type: cardType);
                        
                        final addCardIndex = newState.indexWhere((item) => item.type == 'add');
                        if (addCardIndex != -1) {
                          newState.insert(addCardIndex, newGridItem);
                        } else {
                          newState.add(newGridItem);
                        }
                        return newState;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}



Widget _avatar(String url, {double size = 16}) => Padding(
      padding: const EdgeInsets.only(left: 2.0),
      child: CircleAvatar(radius: size / 2, backgroundImage: NetworkImage(url)),
    );

// New widget for group selection modal
class _GroupSelectionModal extends ConsumerWidget {
  const _GroupSelectionModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select a Group',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16.0),
          // List of mock groups
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: mockGroups.length,
              itemBuilder: (context, index) {
                final group = mockGroups[index];
                return ListTile(
                  title: Text(group['name']!),
                  onTap: () {
                    ref.read(selectedGroupIdProvider.notifier).state = group['id']!;
                    Navigator.pop(context); // Close the modal
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
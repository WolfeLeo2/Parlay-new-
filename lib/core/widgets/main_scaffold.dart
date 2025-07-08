import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parlay/core/widgets/bottom_nav_bar.dart';
import 'package:parlay/features/chat/presentation/screens/chat_list_screen.dart';
import 'package:parlay/home/presentation/screens/home_screen.dart';

class MainScaffold extends StatefulWidget {
  final int initialIndex;

  const MainScaffold({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late int _currentIndex;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F2),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Stack(
          children: [
            // Main content
            Positioned.fill(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  HomeScreen(),
                  ChatListScreen(),
                  Center(child: Text('Calendar')), // Placeholder
                  Center(child: Text('Files')),    // Placeholder
                ],
              ),
            ),
            
            // Floating navigation bar
            Positioned(
              left: 0,
              right: 0,
              bottom: mediaQuery.viewInsets.bottom > 0 
                  ? mediaQuery.viewInsets.bottom + 8 // Add extra space when keyboard is visible
                  : 24, // Space from bottom
              child: Center(
                child: BottomNavBar(
                  currentIndex: _currentIndex,
                  onTap: _onItemTapped,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

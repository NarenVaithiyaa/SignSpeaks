import 'package:flutter/material.dart';

void main() {
  runApp(const SignSpeaksApp());
}

class SignSpeaksApp extends StatelessWidget {
  const SignSpeaksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SignSpeaks',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 1; // Default to Home (Index 1)

  final List<Widget> _pages = const [HistoryPage(), HomePage(), SettingsPage()];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      // This creates the "projected" middle button look using a Floating Action Button
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        backgroundColor: _selectedIndex == 1
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.secondaryContainer,
        foregroundColor: _selectedIndex == 1
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSecondaryContainer,
        elevation: 4.0,
        onPressed: () => _onItemTapped(1),
        child: const Icon(Icons.home, size: 32),
      ),
      // Docks the floating button into the center of the bottom bar
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // History Button (Left)
              Expanded(
                child: InkWell(
                  onTap: () => _onItemTapped(0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        color: _selectedIndex == 0
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                      Text(
                        'History',
                        style: TextStyle(
                          fontSize: 12,
                          color: _selectedIndex == 0
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Expanded(
                child: SizedBox(),
              ), // Empty space for the docked FAB
              // Settings Button (Right)
              Expanded(
                child: InkWell(
                  onTap: () => _onItemTapped(2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.settings,
                        color: _selectedIndex == 2
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                      Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 12,
                          color: _selectedIndex == 2
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Live Camera',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Column(
        children: [
          // 3/4 of the page for Live Camera Feed
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, color: Colors.white54, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Live Camera Feed (Dummy)',
                      style: TextStyle(color: Colors.white54, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 1/4 of the page for Live English Translation
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.blue.shade50, // Subtle blue hint
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Translation:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blueGrey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Hello, how are you today?', // Dummy data
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
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

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Translation History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: ListView.builder(
        itemCount: 10, // Dummy history count
        itemBuilder: (context, index) {
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blue,
              child: Icon(Icons.history, color: Colors.white),
            ),
            title: Text(
              'Dummy Translation ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Recorded on ${DateTime.now().toLocal().toString().split(' ')[0]}',
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          );
        },
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.person, color: Colors.blue),
            title: Text(
              'Account Profile',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.language, color: Colors.blue),
            title: Text(
              'Language Preferences',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.notifications, color: Colors.blue),
            title: Text(
              'Notifications',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.help, color: Colors.blue),
            title: Text(
              'Help & Support',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

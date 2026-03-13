import 'package:bantay/screens/contacts.dart';
import 'package:bantay/screens/home_screen.dart';
// import 'package:bantay/screens/map_screen.dart';
import 'package:bantay/screens/onboarding.dart';
import 'package:bantay/screens/routes_list_screen.dart';
import 'package:flutter/material.dart';
import '../widget/bottomNavBar.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => DashboardState();
}

class DashboardState extends State<Dashboard> {
  int _selectedIndex = 1;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await OnboardingScreen.showIfFirstLaunch(context);
    });
  }

  static const List<Widget> _pages = <Widget>[
    ContactScreen(),
    HomeScreen(),
    RoutesListScreen(),
    // MapScreen(),
    // DownloadScreen(),
  ];

  void onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // final service = context.watch<MonitoringService>();
    // final status = service.state.status;
    return SafeArea(
      top: false,
      // bottom: false,
      child: Scaffold(
        backgroundColor: Color.fromRGBO(22, 16, 26, 1),
        body: _pages[_selectedIndex],
        bottomNavigationBar: CustomNavBar(
          currentIndex: _selectedIndex,
          onTap: (index) => onItemTapped(index),
        ),
      ),
    );
  }
}

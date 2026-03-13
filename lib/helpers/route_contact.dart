import 'package:bantay/database/contacts_database.dart';
import 'package:bantay/database/route_database.dart';
import 'package:bantay/screens/dashboard.dart';
import 'package:flutter/material.dart';

Future<bool> _canEnableProtection(BuildContext context) async {
  final routes = await RouteDatabase.instance.getAllRoutes();
  final contacts = await ContactsDatabase.instance.getAllContacts();

  if (routes.isEmpty) {
    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("No Safe Routes"),
            content: const Text(
              "Please add at least one safe route to enable Auto-Protect.",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  final dashboardState =
                      context.findAncestorStateOfType<DashboardState>();
                  dashboardState?.onItemTapped(
                    2,
                  ); // navigate to Safe Routes page
                  Navigator.pop(context);
                },
                child: const Text("Add Route"),
              ),
            ],
          ),
    );
    return false;
  }

  if (contacts.isEmpty) {
    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("No Emergency Contact"),
            content: const Text(
              "Please add at least one emergency contact to enable Auto-Protect.",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  final dashboardState =
                      context.findAncestorStateOfType<DashboardState>();
                  dashboardState?.onItemTapped(0); // navigate to Contacts page
                  Navigator.pop(context);
                },
                child: const Text("Add Contact"),
              ),
            ],
          ),
    );
    return false;
  }

  return true; // All checks passed
}

Future<bool> canEnableProtection(BuildContext context) async {
  return await _canEnableProtection(context);
}

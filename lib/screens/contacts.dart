import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/contacts_database.dart';
import '../models/emergency_contact.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  List<EmergencyContact> _contacts = [];
  bool _isLoading = true;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  // late Color _assignedColor;
  @override
  void initState() {
    super.initState();
    _loadContacts();
    _phoneController.addListener(() => setState(() {}));
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final contacts = await ContactsDatabase.instance.getAllContacts();
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
      _isLoading = false;
    });
  }

  Future<void> _addContact() async {
    if (!_isValidInput()) {
      return;
    }

    final newContact = EmergencyContact(
      name: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
    );

    await ContactsDatabase.instance.insertContact(newContact);

    _nameController.clear();
    _phoneController.clear();

    Navigator.pop(context);
    _loadContacts(); // ✅ reload from DB
  }

  Future<void> _deleteContact(EmergencyContact contact) async {
    await ContactsDatabase.instance.deleteContact(contact.id!);
    _loadContacts();
  }

  Color generateRandomColor(int id) {
    final random = math.Random(id);

    // Alpha (opacity) is always 255 (fully opaque)
    // Red, Green, Blue values are random from 0 to 255
    return Color.fromARGB(
      255,
      random.nextInt(256), // R value
      random.nextInt(256), // G value
      random.nextInt(256), // B value
    );
  }

  bool _isValidInput() {
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    return name.isNotEmpty && phone.startsWith('09') && phone.length == 11;
  }

  bool _isPhoneValid() {
    final phone = _phoneController.text.trim();
    return phone.startsWith('09') && phone.length == 11;
  }

  bool _isPhoneDuplicate() {
    final phone = _phoneController.text.trim();
    return _contacts.any((c) => c.phoneNumber == phone);
  }

  bool _isNameDuplicate() {
    final name = _nameController.text.trim();
    return _contacts.any((c) => c.name.toLowerCase() == name.toLowerCase());
  }

  void _showAddDialog() {
    _nameController.clear();
    _phoneController.clear();
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            // ← wrap with this
            builder:
                (context, setState) => AlertDialog(
                  title: const Text("Add Emergency Contact"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Name field
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: "Name",
                          prefixIcon: const Icon(Icons.person),
                          suffixIcon:
                              _isNameDuplicate()
                                  ? const Icon(
                                    Icons.warning,
                                    color: Colors.orange,
                                  )
                                  : _nameController.text.trim().isNotEmpty
                                  ? const Icon(Icons.check, color: Colors.green)
                                  : null,
                          helperText:
                              _isNameDuplicate() ? "Name already exists" : null,
                          helperStyle: const TextStyle(color: Colors.orange),
                          border: const OutlineInputBorder(),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.green),
                          ),
                        ),
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),

                      // Phone field
                      TextField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: "Phone Number",
                          hintText: "09123456789",
                          prefixIcon: const Icon(Icons.phone),
                          // prefixIconColor: Colors.green,
                          suffixIcon:
                              _isPhoneDuplicate()
                                  ? const Icon(
                                    Icons.warning,
                                    color: Colors.orange,
                                  )
                                  : _isPhoneValid()
                                  ? const Icon(Icons.check, color: Colors.green)
                                  : null,
                          helperText:
                              _isPhoneDuplicate()
                                  ? "Number is already added"
                                  : "Enter valid phone number",
                          helperStyle: TextStyle(
                            color:
                                _isPhoneDuplicate()
                                    ? Colors.orange
                                    : Colors.grey,
                          ),
                          border: const OutlineInputBorder(),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.green),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        maxLength: 11,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: _isValidInput() ? _addContact : null,
                      child: const Text("Save", selectionColor: Colors.green),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showDeleteConfirmation(EmergencyContact contact) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Contact'),
            content: Text('Are you sure you want to delete "${contact.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteContact(contact);
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80.0,
        title: const Text(
          'Emergency Contacts',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 25,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromRGBO(22, 16, 26, 1),

                Color.fromRGBO(10, 14, 25, 1),
              ],
              stops: [0.4, 0.6],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              transform: GradientRotation(math.pi / 2.385),
            ),
          ),
        ),
      ),
      backgroundColor: Color.fromRGBO(10, 14, 25, 1),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              const SizedBox(width: 20),
              const Text(
                "Trusted Contacts",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color.fromRGBO(93, 108, 134, 1),
                ),
              ),
              const Spacer(),
              Transform.scale(
                scale: 0.7,
                child: FloatingActionButton(
                  backgroundColor: const Color.fromRGBO(33, 20, 29, 1),
                  foregroundColor: Color.fromRGBO(229, 64, 64, 1),
                  onPressed: _showAddDialog,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.add),
                ),
              ),
              const SizedBox(width: 20),
            ],
          ),
          const SizedBox(height: 8),
          // 👇 Expanded gives ListView a bounded height
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _contacts.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 80,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No contacts added yet',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap + to add contacts',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: _contacts.length,
                      itemBuilder: (context, index) {
                        final contact = _contacts[index];
                        return Card(
                          color: const Color.fromARGB(255, 18, 26, 44),
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color: Color.fromRGBO(
                                136,
                                152,
                                177,
                                1,
                              ), // <-- Your desired border color
                              width: .3, // <-- Your desired border width
                            ),
                            borderRadius: BorderRadius.circular(
                              18.0,
                            ), // Optional: for rounded corners
                          ),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),

                          child: ListTile(
                            title: Text(
                              contact.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'Roboto',
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                const Icon(
                                  Icons.phone_outlined,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  contact.phoneNumber,
                                  style: const TextStyle(
                                    fontSize: 12,

                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            leading: Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                color: generateRandomColor(contact.id!),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  contact.name[0],
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // IconButton(
                                //   icon: Icon(
                                //     Icons.star,
                                //     color:
                                //         contact.isPrimary
                                //             ? Colors.amber
                                //             : Colors.grey,
                                //   ),
                                //   tooltip: 'Set as primary',
                                //   onPressed: () => _setPrimary(contact),
                                // ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Color.fromARGB(139, 244, 67, 54),
                                  ),
                                  onPressed:
                                      () => _showDeleteConfirmation(contact),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),

      // floatingActionButton: FloatingActionButton(
      //   onPressed: _showAddDialog,
      //   child: const Icon(Icons.add),
      // ),
    );
  }
}

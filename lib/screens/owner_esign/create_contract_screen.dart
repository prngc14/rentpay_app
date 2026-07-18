import 'package:flutter/material.dart';

class CreateContractScreen extends StatefulWidget {
  const CreateContractScreen({super.key});

  @override
  State<CreateContractScreen> createState() =>
      _CreateContractScreenState();
}

class _CreateContractScreenState extends State<CreateContractScreen> {
  final _tenantController = TextEditingController();
  final _roomController = TextEditingController();
  final _rentController = TextEditingController();
  final _termsController = TextEditingController();

  DateTime? startDate;
  DateTime? endDate;

  bool useESign = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Rental Contract"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            TextField(
              controller: _tenantController,
              decoration: const InputDecoration(
                labelText: "Tenant Name",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: _roomController,
              decoration: const InputDecoration(
                labelText: "Room / Property",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: _rentController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Monthly Rent",
                prefixText: "₱ ",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Colors.grey),
              ),
              title: Text(
                startDate == null
                    ? "Select Contract Start Date"
                    : startDate.toString().split(" ")[0],
              ),
              trailing: const Icon(Icons.calendar_today),
            ),

            const SizedBox(height: 15),

            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Colors.grey),
              ),
              title: Text(
                endDate == null
                    ? "Select Contract End Date"
                    : endDate.toString().split(" ")[0],
              ),
              trailing: const Icon(Icons.calendar_today),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: _termsController,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: "Terms and Conditions",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            SwitchListTile(
              value: useESign,
              onChanged: (value) {
                setState(() {
                  useESign = value;
                });
              },
              title: const Text("Use Digital Contract with E-Signature"),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                child: const Text("Generate Contract"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';

/// The warehouse operator explicitly chooses segregated stock destinations.
/// Successful intake is not a Quality approval or a cylinder refill release.
class ReturnableIntakeChoice {
  const ReturnableIntakeChoice({
    required this.receivingLocationId,
    required this.quarantineLocationId,
    required this.notes,
  });

  final String receivingLocationId;
  final String quarantineLocationId;
  final String notes;
}

Future<ReturnableIntakeChoice?> askReturnableIntake(
  BuildContext context,
  List<Map<String, dynamic>> locations,
) async {
  final receiving = locations
      .where((row) => row['location_type'] == 'receiving')
      .toList();
  final quarantine = locations
      .where((row) => row['location_type'] == 'quarantine')
      .toList();
  if (receiving.isEmpty || quarantine.isEmpty) {
    throw StateError(
      'Create active receiving and quarantine stock locations in Warehouse first.',
    );
  }

  var receivingId = receiving.first['id'] as String;
  var quarantineId = quarantine.first['id'] as String;
  final notes = TextEditingController();
  try {
    return await showDialog<ReturnableIntakeChoice>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Receive returned cylinders'),
          content: SizedBox(
            width: 470,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Receive the closed pickup from the vehicle. Good and empty '
                    'assets go to receiving for inspection. Damaged or rejected '
                    'assets go to quarantine. This does not release them for refill.',
                  ),
                  const SizedBox(height: FactorySpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: receivingId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Good / empty asset receiving',
                    ),
                    items: receiving
                        .map((row) => DropdownMenuItem(
                              value: row['id'] as String,
                              child: Text(
                                '${row['code']} · ${row['name']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => receivingId = value);
                      }
                    },
                  ),
                  const SizedBox(height: FactorySpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: quarantineId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Damaged / rejected quarantine',
                    ),
                    items: quarantine
                        .map((row) => DropdownMenuItem(
                              value: row['id'] as String,
                              child: Text(
                                '${row['code']} · ${row['name']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => quarantineId = value);
                      }
                    },
                  ),
                  const SizedBox(height: FactorySpacing.md),
                  TextField(
                    controller: notes,
                    maxLines: 2,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Receipt notes (optional)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                ReturnableIntakeChoice(
                  receivingLocationId: receivingId,
                  quarantineLocationId: quarantineId,
                  notes: notes.text.trim(),
                ),
              ),
              child: const Text('Confirm warehouse intake'),
            ),
          ],
        ),
      ),
    );
  } finally {
    notes.dispose();
  }
}

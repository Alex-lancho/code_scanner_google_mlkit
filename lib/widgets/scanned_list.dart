import 'package:flutter/material.dart';

class ScannedList extends StatelessWidget {
  final List<String> scannedCodes;

  const ScannedList({Key? key, required this.scannedCodes}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Códigos Escaneados',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (scannedCodes.isEmpty)
            const Text('No hay códigos escaneados aún.')
          else
            SizedBox(
              height: 120,
              child: ListView.builder(
                itemCount: scannedCodes.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(scannedCodes[index]),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: UjiTinggi(),
    ));

class UjiTinggi extends StatelessWidget {
  const UjiTinggi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('ISAN',
                style: TextStyle(
                    fontFamily: 'DejaVu Sans', fontSize: 90,
                    fontWeight: FontWeight.w900, height: 1.0,
                    color: Color(0xFFFF2A3B))),
            SizedBox(height: 60),
            Text('ISAN',
                style: TextStyle(
                    fontFamily: 'DejaVu Sans', fontSize: 90,
                    fontWeight: FontWeight.w900, height: 1.15,
                    color: Color(0xFFFF2A3B))),
          ],
        ),
      ),
    );
  }
}

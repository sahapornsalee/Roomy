import 'package:flutter/material.dart';

Widget buildOwnerBottomNav(BuildContext context, int currentIndex) {
  return BottomNavigationBar(
    type: BottomNavigationBarType.fixed,
    selectedItemColor: const Color(0xFF1DB954), // สีเขียว Roomy
    unselectedItemColor: Colors.grey,
    currentIndex: currentIndex,
    items: const [
      BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "ภาพรวม"),
      BottomNavigationBarItem(
        icon: Icon(Icons.apartment),
        label: "จัดการตึก/ห้อง",
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.payment),
        label: "บัญชีและการเงิน",
      ),
      BottomNavigationBarItem(icon: Icon(Icons.build), label: "งานแจ้งซ่อม"),
    ],
    onTap: (index) {
      // ป้องกันการกดหน้าเดิมซ้ำ
      if (index == currentIndex) return;

      switch (index) {
        case 0:
          Navigator.pushReplacementNamed(context, '/owner_home');
          break;
        case 1:
          Navigator.pushReplacementNamed(context, '/owner_building_mgmt');
          break;
        case 2:
          Navigator.pushReplacementNamed(context, '/owner_finance');
          break;
        case 3:
          Navigator.pushReplacementNamed(
            context,
            '/owner_repairs',
          ); // หน้างานแจ้งซ่อม
          break;
      }
    },
  );
}

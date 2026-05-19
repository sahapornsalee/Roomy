// lib/widgets/tenant_bottom_nav.dart
import 'package:flutter/material.dart';
// 🌟 [นำเข้าใหม่]: เรียกใช้คลาสหน้าจอฝั่งผู้เช่าโดยตรง เพื่อความเสถียรสูงสุดในทุกระบบ
import '../screens/tenant/tenant_home.dart';
import '../screens/tenant/tenant_payment.dart';
import '../screens/tenant/tenant_repairs.dart';
import '../screens/tenant/tenant_booking.dart';

Widget buildTenantBottomNav(BuildContext context, int currentIndex) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, -5),
        ),
      ],
    ),
    child: BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF1DB954), // สีเขียว Roomy
      unselectedItemColor: Colors.grey.shade400,
      currentIndex: currentIndex,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
      items: const [
        BottomNavigationBarItem(
          icon: Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Icon(Icons.home_outlined),
          ),
          activeIcon: Icon(Icons.home_filled),
          label: "หน้าแรก",
        ),
        BottomNavigationBarItem(
          icon: Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Icon(Icons.account_balance_wallet_outlined),
          ),
          activeIcon: Icon(Icons.account_balance_wallet),
          label: "ชำระเงิน",
        ),
        BottomNavigationBarItem(
          icon: Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Icon(Icons.build_outlined),
          ),
          activeIcon: Icon(Icons.build),
          label: "แจ้งซ่อม",
        ),
        BottomNavigationBarItem(
          icon: Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Icon(Icons.calendar_today_outlined),
          ),
          activeIcon: Icon(Icons.calendar_today),
          label: "จองส่วนกลาง",
        ),
      ],
      onTap: (index) {
        if (index == currentIndex) return;

        // 🌟 [แก้ไขสำเร็จ]: สลับหน้าจอด้วยวัตถุคลาสตรง ไม่พึ่งพาระบบชื่อ ป้องกันหน้าจอดำ 100%
        switch (index) {
          case 0:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TenantHome()),
            );
            break;
          case 1:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TenantPayment()),
            );
            break;
          case 2:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TenantRepairs()),
            );
            break;
          case 3:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TenantBooking()),
            );
            break;
        }
      },
    ),
  );
}

// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// --- นำเข้าหน้าจอหลัก (Guest & Auth) ---
import 'screens/guest_home.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';

// --- นำเข้าหน้าจอฝั่งเจ้าของ (Owner) ---
import 'screens/owner/owner_home.dart';
import 'screens/owner/owner_building_mgmt.dart';
import 'screens/owner/owner_finance.dart';
import 'screens/owner/owner_repairs.dart';

// --- นำเข้าหน้าจอฝั่งผู้เช่า (Tenant) ---
import 'screens/tenant/tenant_home.dart';
import 'screens/tenant/tenant_payment.dart';
import 'screens/tenant/tenant_repairs.dart';
import 'screens/tenant/tenant_booking.dart';

// --- นำเข้าหน้าจอฝั่งแม่บ้าน (Maid) ---
import 'screens/maid/maid_home.dart';

import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ตั้งค่ารองรับภาษาไทยสำหรับวันที่
  await initializeDateFormatting('th', null);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const RoomyApp());
}

class RoomyApp extends StatelessWidget {
  const RoomyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roomy - Dorm Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'Kanit', // หรือฟอนต์ที่คุณใช้ในโปรเจกต์
      ),
      initialRoute: '/',
      // --- ระบบเส้นทาง (Routes) ทั้งหมดในแอป ---
      routes: {
        // เปลี่ยนเส้นทางหลัก '/' ไปที่ AuthWrapper เพื่อเช็คสถานะการเข้าสู่ระบบคงค้าง
        '/': (context) => const AuthWrapper(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),

        // ส่วนเจ้าของหอพัก (Owner)
        '/owner_home': (context) => const OwnerOverview(),
        '/owner_overview': (context) => const OwnerOverview(),
        '/owner_building_mgmt': (context) => const OwnerBuildingMgmt(),
        '/owner_finance': (context) => const OwnerFinance(),
        '/owner_repairs': (context) => const OwnerRepairs(),

        // ส่วนผู้เช่า (Tenant)
        '/tenant_home': (context) => const TenantHome(),
        '/tenant_payment': (context) => const TenantPayment(),
        '/tenant_repairs': (context) => const TenantRepairs(),
        '/tenant_booking': (context) => const TenantBooking(),

        // ส่วนของแม่บ้าน (Maid)
        '/maid_home': (context) => const MaidHome(),
      },
    );
  }
}

// --- ตัวจัดการล็อกอินค้างสถานะและคัดแยกหน้าแรกอัตโนมัติ (Auth Wrapper) ---
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // คอยฟังการเปลี่ยนแปลงสถานะการล็อกอินจาก Firebase Auth
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // กรณีตัวแอปกำลังดาวน์โหลดตรวจสอบสถานะความปลอดภัยค้างเก่า
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.green)),
          );
        }

        // กรณีตรวจสอบพบว่า มีประวัติการล็อกอินค้างไว้ในตัวเครื่องจริง
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .get(),
            builder: (context, userSnap) {
              if (userSnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(color: Colors.green),
                  ),
                );
              }

              if (userSnap.hasData && userSnap.data!.exists) {
                var userData = userSnap.data!.data() as Map<String, dynamic>;
                String role = userData['role'] ?? 'tenant';

                // คัดแยกหน้าแดชบอร์ดแรกสุดอัตโนมัติตามสิทธิ์ (Role) โดยตรง
                if (role == 'owner') return const OwnerOverview();
                if (role == 'maid') return const MaidHome();
                return const TenantHome(); // หน้าหลักของผู้เช่า
              }
              // ถ้ามีปัญหาเรื่องข้อมูลผู้ใช้ในระบบให้ส่งไป Login ใหม่
              return const LoginScreen();
            },
          );
        }

        // หากไม่มีข้อมูลประวัติผู้ใช้ล็อกอินค้างเครื่องไว้เลย ให้ส่งไปหน้า GuestHome
        return const GuestHome();
      },
    );
  }
}

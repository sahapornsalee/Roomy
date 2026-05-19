import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../widgets/owner_bottom_nav.dart';
import '../../widgets/owner_app_bar.dart';
// นำเข้าหน้าแจ้งซ่อมเพื่อใช้ในการเปลี่ยนหน้า
import 'owner_repairs.dart';

class OwnerOverview extends StatefulWidget {
  const OwnerOverview({super.key});

  @override
  State<OwnerOverview> createState() => _OwnerOverviewState();
}

class _OwnerOverviewState extends State<OwnerOverview> {
  final user = FirebaseAuth.instance.currentUser;
  final NumberFormat currencyFormat = NumberFormat("#,##0", "en_US");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: buildOwnerAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(),
            const SizedBox(height: 25),
            _buildFinancialOverviewCard(), // สรุปรายรับ-รายจ่ายอัตโนมัติ
            const SizedBox(height: 25),
            _buildStatGrid(),
            const SizedBox(height: 30),
            _buildBuildingOverviewSection(), // ข้อมูลตึกและห้องว่าง
            const SizedBox(height: 35),
            _buildMaintenanceShortcut(), // ส่วนงานแจ้งซ่อมแบบปุ่มกดดูทั้งหมด
            const SizedBox(height: 25),
          ],
        ),
      ),
      bottomNavigationBar: buildOwnerBottomNav(context, 0),
    );
  }

  Widget _buildWelcomeHeader() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        String name = "ผู้จัดการ";
        if (snapshot.hasData && snapshot.data!.exists) {
          name = snapshot.data!['name'] ?? name;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "สวัสดีตอนรับ",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              "คุณ$name 👋",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF101828),
              ),
            ),
          ],
        );
      },
    );
  }

  // 📊 ส่วนคำนวณรายรับ-รายจ่าย และกำไรสุทธิอัตโนมัติ
  Widget _buildFinancialOverviewCard() {
    DateTime now = DateTime.now();
    DateTime firstDayMonth = DateTime(now.year, now.month, 1);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('status', isEqualTo: 'approved')
          .where('timestamp', isGreaterThanOrEqualTo: firstDayMonth)
          .snapshots(),
      builder: (context, incomeSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('expenses')
              .where('timestamp', isGreaterThanOrEqualTo: firstDayMonth)
              .snapshots(),
          builder: (context, expenseSnap) {
            double income = 0;
            double expense = 0;

            if (incomeSnap.hasData) {
              for (var doc in incomeSnap.data!.docs) {
                income += (doc['amount'] ?? 0).toDouble();
              }
            }
            if (expenseSnap.hasData) {
              for (var doc in expenseSnap.data!.docs) {
                expense += (doc['amount'] ?? 0).toDouble();
              }
            }

            double profit = income - expense;

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF101828),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF101828).withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "กำไรสุทธิเดือนนี้ (Net Profit)",
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "฿ ${currencyFormat.format(profit)}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(
                        profit >= 0 ? Icons.trending_up : Icons.trending_down,
                        color: profit >= 0
                            ? const Color(0xFF1DB954)
                            : Colors.redAccent,
                        size: 28,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _finMiniItem(
                        "รายรับรวม",
                        income,
                        const Color(0xFF1DB954),
                      ),
                      const SizedBox(width: 20),
                      _finMiniItem("รายจ่ายรวม", expense, Colors.redAccent),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _finMiniItem(String label, double val, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "฿${currencyFormat.format(val)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid() {
    return Row(
      children: [
        _miniStatCard(
          "ห้องที่ว่างทั้งหมด",
          'rooms',
          'status',
          'ว่าง',
          Icons.door_front_door_outlined,
          const Color(0xFF1DB954),
          const Color(0xFFE8F5E9),
        ),
        const SizedBox(width: 15),
        _miniStatCard(
          "สลิปรอตรวจสอบ",
          'transactions',
          'status',
          'pending',
          Icons.pending_actions_outlined,
          const Color(0xFFD97706),
          const Color(0xFFFFF9DB),
        ),
      ],
    );
  }

  Widget _miniStatCard(
    String title,
    String col,
    String field,
    String val,
    IconData icon,
    Color color,
    Color bg,
  ) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(col)
            .where(field, isEqualTo: val)
            .snapshots(),
        builder: (context, snap) {
          int count = snap.hasData ? snap.data!.docs.length : 0;
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 12),
                Text(
                  "$count",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF101828),
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBuildingOverviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "ข้อมูลสรุปสถานะรายอาคาร",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF101828),
          ),
        ),
        const SizedBox(height: 15),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('rooms').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: LinearProgressIndicator());
            Map<String, Map<String, int>> buildingStats = {};
            for (var doc in snapshot.data!.docs) {
              String bName = doc['buildingName'] ?? "ทั่วไป";
              String status = doc['status'] ?? "ว่าง";
              buildingStats.putIfAbsent(bName, () => {'total': 0, 'vacant': 0});
              buildingStats[bName]!['total'] =
                  buildingStats[bName]!['total']! + 1;
              if (status == 'ว่าง')
                buildingStats[bName]!['vacant'] =
                    buildingStats[bName]!['vacant']! + 1;
            }
            return SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: buildingStats.length,
                itemBuilder: (context, index) {
                  String key = buildingStats.keys.elementAt(index);
                  return Container(
                    width: 180,
                    margin: const EdgeInsets.only(right: 15),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.business, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              "ตึก $key",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          "ทั้งหมด: ${buildingStats[key]!['total']} ห้อง",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          "ว่าง: ${buildingStats[key]!['vacant']} ห้อง",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1DB954),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  // 🔧 ส่วนงานแจ้งซ่อมใหม่: แสดงเป็นทางลัดเพื่อไปหน้าซ่อมบำรุง
  Widget _buildMaintenanceShortcut() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFF0F9FF),
                child: Icon(
                  Icons.build_circle_outlined,
                  color: Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "งานแจ้งซ่อมบำรุง",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "ตรวจสอบและมอบหมายงานช่าง",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                // ไปยังหน้าซ่อมบำรุง (ผ่านการเปลี่ยน Index ของ Bottom Nav หรือใช้ Navigator)
                // ในที่นี้แนะนำให้เรียกใช้ Bottom Nav Widget ให้เปลี่ยน index เป็น 3
                // หรือเปลี่ยนหน้าด้วย Navigator ทั่วไป:
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OwnerRepairs()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF101828),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                "ดูรายการแจ้งซ่อมทั้งหมด",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

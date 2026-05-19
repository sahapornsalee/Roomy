import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../widgets/tenant_bottom_nav.dart'; //
import '../../widgets/tenant_app_bar.dart'; //

class TenantHome extends StatefulWidget {
  const TenantHome({super.key});

  @override
  State<TenantHome> createState() => _TenantHomeState();
}

class _TenantHomeState extends State<TenantHome> {
  final user = FirebaseAuth.instance.currentUser; //

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), //
      appBar: buildTenantAppBar(context), //
      body: StreamBuilder<DocumentSnapshot>(
        // 1. ดึงข้อมูลส่วนตัวผู้ใช้เพื่อนำมาคัดกรองตามชื่อผู้เช่าปัจจุบัน
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(), //
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green), //
            );
          }
          var userData =
              userSnapshot.data!.data() as Map<String, dynamic>? ?? {}; //
          String tenantName = userData['name'] ?? "ผู้เช่า"; //

          return StreamBuilder<QuerySnapshot>(
            // 2. ตรวจค้นหาข้อมูลห้องพักที่ตรงกับชื่อจริงของผู้ใช้งาน
            stream: FirebaseFirestore.instance
                .collection('rooms')
                .where('tenantName', isEqualTo: tenantName)
                .limit(1)
                .snapshots(), //
            builder: (context, roomSnapshot) {
              String roomNo = "รอกำหนด"; //
              String building = "-"; //

              double rentPrice = 0.0; //
              double waterPrice = 0.0; //
              double electricPrice = 0.0; //
              double internetPrice = 0.0; //
              double otherPrice = 0.0; //

              if (roomSnapshot.hasData && roomSnapshot.data!.docs.isNotEmpty) {
                var roomDoc = roomSnapshot.data!.docs.first; //

                var roomData = roomDoc.data() as Map<String, dynamic>? ?? {}; //

                roomNo = roomData['roomNo'] ?? "N/A"; //
                building = roomData['buildingName'] ?? "-"; //

                rentPrice = (roomData['price'] ?? 0.0).toDouble(); //
                waterPrice = (roomData['waterBill'] ?? 0.0).toDouble(); //
                electricPrice = (roomData['electricBill'] ?? 0.0).toDouble(); //
                internetPrice = (roomData['internetBill'] ?? 0.0).toDouble(); //
                otherPrice = (roomData['otherBill'] ?? 0.0).toDouble(); //
              }

              double totalOutstandingBill =
                  rentPrice +
                  waterPrice +
                  electricPrice +
                  internetPrice +
                  otherPrice; //

              return StreamBuilder<QuerySnapshot>(
                // 3. เชื่อมสตรีมใบตรวจธุรกรรมสลิปจากหน้าชำระเงินมาเปรียบเทียบตัดยอด
                stream: FirebaseFirestore.instance
                    .collection('transactions')
                    .where('roomNo', isEqualTo: roomNo)
                    .snapshots(), //
                builder: (context, transSnapshot) {
                  String paymentStatus = "none"; //

                  if (transSnapshot.hasData &&
                      transSnapshot.data!.docs.isNotEmpty) {
                    var sortedTransactions = transSnapshot.data!.docs.toList()
                      ..sort((a, b) {
                        var aTime =
                            (a['timestamp'] as Timestamp?)?.toDate() ??
                            DateTime(2000); //
                        var bTime =
                            (b['timestamp'] as Timestamp?)?.toDate() ??
                            DateTime(2000); //
                        return bTime.compareTo(aTime); //
                      });

                    var latestTransaction =
                        sortedTransactions.first.data()
                            as Map<String, dynamic>; //
                    paymentStatus = latestTransaction['status'] ?? "none"; //
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20), //
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, //
                      children: [
                        _buildUserHeaderCard(tenantName, roomNo, building), //
                        const SizedBox(height: 25), //
                        _buildSmartPaymentCard(
                          totalOutstandingBill,
                          paymentStatus,
                        ), //
                        const SizedBox(height: 25), //
                        const Text(
                          "แจ้งซ่อมล่าสุด", //
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF101828), //
                          ),
                        ),
                        const SizedBox(height: 12), //
                        // 🌟 [จุดแก้ไข]: ส่งค่าตัวแปรชื่อผู้เช่า (tenantName) เข้าไปร่วมประมวลผลดักกรองรายงาน 🌟
                        _buildLatestRepairCard(roomNo, tenantName),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: buildTenantBottomNav(context, 0), //
    );
  }

  Widget _buildUserHeaderCard(String name, String room, String bldg) {
    return Container(
      width: double.infinity, //
      padding: const EdgeInsets.all(25), //
      decoration: BoxDecoration(
        color: const Color(0xFF101828), //
        borderRadius: BorderRadius.circular(30), //
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, //
        children: [
          const Text(
            "ยินดีต้อนรับกลับมา", //
            style: TextStyle(
              color: Color(0xFF1DB954), //
              fontSize: 13, //
              fontWeight: FontWeight.w500, //
            ),
          ),
          const SizedBox(height: 5), //
          Text(
            name, //
            style: const TextStyle(
              color: Colors.white, //
              fontSize: 24, //
              fontWeight: FontWeight.bold, //
            ),
          ),
          const SizedBox(height: 25), //
          Row(
            children: [
              _infoBox(Icons.home_outlined, "ห้องของคุณ", room), //
              const SizedBox(width: 15), //
              _infoBox(Icons.business_outlined, "อาคาร", "ตึก $bldg"), //
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmartPaymentCard(double totalBill, String status) {
    Color cardBgColor; //
    Color textColor; //
    IconData icon; //
    String statusLabel; //
    double displayedAmount; //
    String buttonText; //
    bool disableButton = false; //

    if (status == "approved") {
      cardBgColor = const Color(0xFFECFDF5); //
      textColor = const Color(0xFF10B981); //
      icon = Icons.check_circle_outline; //
      statusLabel = "ชำระเงินประจำเดือนเสร็จสิ้นแล้ว"; //
      displayedAmount = 0.0; //
      buttonText = "ดูประวัติการชำระเงิน"; //
    } else if (status == "pending") {
      cardBgColor = const Color(0xFFFFFBEB); //
      textColor = const Color(0xFFD97706); //
      icon = Icons.hourglass_empty_rounded; //
      statusLabel = "อยู่ระหว่างรอเจ้าของหอตรวจสอบสลิป"; //
      displayedAmount = totalBill; //
      buttonText = "ตรวจสอบสถานะธุรกรรม"; //
    } else {
      cardBgColor = const Color(0xFFFFF1F2); //
      textColor = const Color(0xFFE11D48); //
      icon = Icons.info_outline; //
      statusLabel =
          "ยอดค้างชำระประจำเดือน (${DateFormat('MMMM', 'th').format(DateTime.now())})"; //
      displayedAmount = totalBill; //
      buttonText = "ชำระเงินทันที >"; //
      if (totalBill <= 0) disableButton = true; //
    }

    return Container(
      width: double.infinity, //
      padding: const EdgeInsets.all(20), //
      decoration: BoxDecoration(
        color: cardBgColor, //
        borderRadius: BorderRadius.circular(25), //
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: textColor, size: 20), //
              const SizedBox(width: 8), //
              Text(
                statusLabel, //
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ), //
              ),
            ],
          ),
          const SizedBox(height: 10), //
          Text(
            "฿${NumberFormat('#,###.00').format(displayedAmount)}", //
            style: const TextStyle(
              fontSize: 36, //
              fontWeight: FontWeight.bold, //
              color: Color(0xFF101828), //
            ),
          ),
          const SizedBox(height: 20), //
          SizedBox(
            width: double.infinity, //
            child: ElevatedButton(
              onPressed: disableButton
                  ? null
                  : () {
                      Navigator.pushReplacementNamed(
                        context,
                        '/tenant_payment',
                      ); //
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF101828), //
                padding: const EdgeInsets.symmetric(vertical: 15), //
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15), //
                ),
              ),
              child: Text(
                buttonText, //
                style: const TextStyle(
                  color: Colors.white, //
                  fontWeight: FontWeight.bold, //
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 🌟 [ปรับปรุงใหม่]: ระบบคัดกรองประวัติใบงานแจ้งซ่อมเฉพาะของตัวเอง (Tenant Strict Scope Filter) 🌟 ---
  Widget _buildLatestRepairCard(String roomNo, String tenantName) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('repairs')
          .where(
            'roomNo',
            isEqualTo: roomNo,
          ) // โหลดใบงานทั้งหมดของห้องนี้ขึ้นมาตรวจสอบก่อน
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyRepairCard();
        }

        //ทำการกรองฝั่ง Client เพื่อป้องกันปัญหาดัก Index บัญชี Firestore ล่มกลางคัน
        var myPersonalRepairs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>? ?? {};
          // ดักสแกนข้อมูล: ต้องผูกกับชื่อผู้เช่า หรือ UID ตัวเอง และต้องไม่ใช่ประเภทงานล้างห้องทำความสะอาดของแม่บ้าน
          return (data['reportedBy'] == tenantName ||
                  data['tenantName'] == tenantName ||
                  data['uid'] == user?.uid) &&
              data['type'] != "ทำความสะอาด" &&
              data['title'] != "ทำความสะอาด";
        }).toList();

        if (myPersonalRepairs.isEmpty) {
          return _buildEmptyRepairCard();
        }

        // เรียงลำดับหาใบงานส่งแจ้งซ่อมชิ้นล่าสุดด้วยคลาสภาษา Dart ดั้งเดิม (จากใหม่ไปเก่า)
        myPersonalRepairs.sort((a, b) {
          var aData = a.data() as Map<String, dynamic>? ?? {};
          var bData = b.data() as Map<String, dynamic>? ?? {};
          var aTime =
              (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000); //
          var bTime =
              (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000); //
          return bTime.compareTo(aTime); //
        });

        var repair = myPersonalRepairs.first.data() as Map<String, dynamic>;
        String status = repair['status'] ?? "รอดำเนินการ"; //

        return Container(
          padding: const EdgeInsets.all(20), //
          decoration: BoxDecoration(
            color: Colors.white, //
            borderRadius: BorderRadius.circular(25), //
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
              ), //
            ],
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero, //
                title: Text(
                  repair['title'] ?? "ปัญหาทั่วไป", //
                  style: const TextStyle(
                    fontWeight: FontWeight.bold, //
                    fontSize: 16, //
                  ),
                ),
                subtitle: Text(
                  "ผู้รับผิดชอบ: ${repair['assignedPerson'] ?? 'รอมอบหมายงาน'}", //
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, //
                    vertical: 4, //
                  ),
                  decoration: BoxDecoration(
                    color: status == "เสร็จสิ้น"
                        ? const Color(0xFFECFDF5) //
                        : const Color(0xFFFEF3C7), //
                    borderRadius: BorderRadius.circular(8), //
                  ),
                  child: Text(
                    status, //
                    style: TextStyle(
                      color: status == "เสร็จสิ้น"
                          ? const Color(0xFF10B981) //
                          : const Color(0xFFD97706), //
                      fontSize: 10, //
                      fontWeight: FontWeight.bold, //
                    ),
                  ),
                ),
              ),
              const Divider(height: 30), //
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(
                  context,
                  '/tenant_repairs',
                ), //
                child: const Text(
                  "ดูประวัติทั้งหมด ↻", //
                  style: TextStyle(
                    color: Colors.grey, //
                    fontWeight: FontWeight.bold, //
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // วิดเจ็ตกล่องข้อความแจ้งเตือนเมื่อไม่มีรายการคำร้องส่งซ่อมของตนเอง
  Widget _buildEmptyRepairCard() {
    return Container(
      width: double.infinity, //
      padding: const EdgeInsets.all(25), //
      decoration: BoxDecoration(
        color: Colors.white, //
        borderRadius: BorderRadius.circular(25), //
      ),
      child: const Center(
        child: Text(
          "ไม่มีประวัติการแจ้งซ่อมแซมภายในห้องพักที่คุณส่งคำร้อง",
          style: TextStyle(color: Colors.grey, fontSize: 13), //
        ),
      ),
    );
  }

  Widget _infoBox(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12), //
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1), //
          borderRadius: BorderRadius.circular(15), //
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, //
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white, size: 14), //
                const SizedBox(width: 5), //
                Text(
                  label, //
                  style: const TextStyle(color: Colors.grey, fontSize: 10), //
                ),
              ],
            ),
            const SizedBox(height: 5), //
            Text(
              value, //
              style: const TextStyle(
                color: Colors.white, //
                fontWeight: FontWeight.bold, //
                fontSize: 14, //
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../widgets/owner_bottom_nav.dart';
import '../../widgets/owner_app_bar.dart';

class OwnerFinance extends StatefulWidget {
  const OwnerFinance({super.key});

  @override
  State<OwnerFinance> createState() => _OwnerFinanceState();
}

class _OwnerFinanceState extends State<OwnerFinance> {
  int _currentSection = 0; // 0 = บัญชีและการเงิน, 1 = จัดการรายชื่อบุคลากร

  String _selectedRoleView =
      'tenant'; // tenant (ผู้เช่าทั้งหมด), maid (แม่บ้าน), tech (ช่างซ่อมแซม)
  String _selectedTenantFilter = "ผู้เช่าทั้งหมด";

  String _selectedFilter = "รายรับทั้งหมด";
  final TextEditingController _noteController = TextEditingController();
  final NumberFormat currencyFormat = NumberFormat("#,##0.00", "en_US");

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String? phone) {
    if (phone == null || phone.trim().isEmpty) return "ไม่ได้ระบุเบอร์โทร";
    String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length == 10) {
      return "${clean.substring(0, 3)}-${clean.substring(3, 6)}-${clean.substring(6)}";
    }
    return phone;
  }

  String _convertToDirectLink(String driveUrl) {
    if (driveUrl.contains("drive.google.com")) {
      try {
        String fileId = driveUrl.contains("/d/")
            ? driveUrl.split("/d/")[1].split("/")[0]
            : driveUrl.split("id=")[1].split("&")[0];
        return "https://drive.google.com/uc?export=view&id=$fileId";
      } catch (e) {
        return driveUrl;
      }
    }
    return driveUrl;
  }

  // หน้าต่างตรวจสอบสลิปเงินฝั่งรายรับ
  void _showTransactionDetailModal(String docId, Map<String, dynamic> data) {
    _noteController.text = data['note'] ?? "";
    DateTime date = data['timestamp'] != null
        ? (data['timestamp'] as Timestamp).toDate()
        : DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "ห้อง ${data['roomNo']}",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 30),
              const Text(
                "หลักฐานการโอนเงิน",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  _convertToDirectLink(data['slipUrl'] ?? ""),
                  height: 300,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (context, e, s) => Container(
                    height: 150,
                    color: Colors.grey[100],
                    child: const Icon(Icons.broken_image),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              _buildDetailItem(
                "วันที่โอน:",
                DateFormat('dd MMMM yyyy', 'th').format(date),
              ),
              _buildDetailItem("โอนค่าอะไร:", data['type'] ?? "ไม่ระบุ"),
              _buildDetailItem(
                "ยอดเงิน:",
                "฿${data['amount']}",
                isBold: true,
                color: const Color(0xFF1DB954),
              ),
              const Divider(height: 30),
              const Text(
                "บันทึกเพิ่มเติม/เหตุผล (เช่น จ่ายไม่ครบ, ยอดครบแล้ว)",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: "พิมพ์หมายเหตุที่นี่...",
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              if (data['status'] == 'pending')
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          FirebaseFirestore.instance
                              .collection('transactions')
                              .doc(docId)
                              .update({
                                'status': 'rejected',
                                'note': _noteController.text,
                              });
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text("ไม่อนุมัติ"),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          FirebaseFirestore.instance
                              .collection('transactions')
                              .doc(docId)
                              .update({
                                'status': 'approved',
                                'note': _noteController.text,
                              });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF101828),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text(
                          "อนุมัติรายการ",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Center(
                  child: Text(
                    "บันทึกสถานะ: ${data['status'] == 'approved' ? 'อนุมัติเรียบร้อย' : 'ไม่อนุมัติ'}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // หน้าต่างพรีวิวฝั่งใบแจ้งหนี้รายจ่าย
  void _showExpenseDetailModal(Map<String, dynamic> data) {
    DateTime date = data['timestamp'] != null
        ? (data['timestamp'] as Timestamp).toDate()
        : DateTime.now();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "บิลรายจ่าย ห้อง ${data['roomNo'] ?? 'ส่วนกลาง'}",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildDetailItem("ประเภทบิล:", "รายจ่ายหอพัก (ระบบส่วนกลาง)"),
            _buildDetailItem(
              "รายการรายละเอียด:",
              data['title'] ?? "ค่าซ่อมแซม",
            ),
            _buildDetailItem(
              "ประเภทงานความสะอาด/ซ่อม:",
              data['type'] ?? "งานซ่อม",
            ),
            _buildDetailItem(
              "วันที่บันทึกยอด:",
              DateFormat('dd MMMM yyyy HH:mm', 'th').format(date),
            ),
            const Divider(height: 20),
            _buildDetailItem(
              "ยอดรวมหักจ่ายสุทธิ:",
              "฿${currencyFormat.format(data['amount'] ?? 0.0)}",
              isBold: true,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF101828),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "ปิดหน้าต่างพรีวิว",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTenantDetailModal(Map<String, dynamic> user, String currentRoom) {
    var parking = user['parkingRequest'] as Map<String, dynamic>? ?? {};
    var emergency = user['emergencyContact'] as Map<String, dynamic>? ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(25),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "ข้อมูลสัญญา & รายละเอียดผู้เช่า",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 25),
              _infoModalRow("ชื่อ-นามสกุล:", user['name'] ?? "-"),
              _infoModalRow(
                "ห้องพักปัจจุบัน:",
                currentRoom,
                valueColor: const Color(0xFF1DB954),
              ),
              _infoModalRow(
                "เบอร์โทรศัพท์:",
                _formatPhoneNumber(user['phone']),
              ),
              _infoModalRow("Line ID:", user['lineId'] ?? "-"),
              _infoModalRow("อีเมลล็อกอิน:", user['email'] ?? "-"),
              _infoModalRow(
                "จำนวนผู้พักอาศัย:",
                "${user['residentCount'] ?? 1} คน",
              ),
              _infoModalRow(
                "คีย์การ์ดที่ถืออยู่:",
                "${user['extraKeycards'] ?? 1} ใบ",
              ),
              const SizedBox(height: 20),
              const Text(
                "ข้อมูลการใช้สิทธิ์ที่จอดรถ",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(height: 8),
              _infoModalRow(
                "•  จำนวนรถยนต์:",
                "${parking['carCount'] ?? 0} คัน",
              ),
              _infoModalRow(
                "•  จำนวนจักรยานยนต์:",
                "${parking['motorcycleCount'] ?? 0} คัน",
              ),
              const SizedBox(height: 20),
              const Text(
                "ผู้ติดต่อฉุกเฉิน (Emergency Contact)",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(height: 8),
              _infoModalRow("•   ชื่อผู้ติดต่อ:", emergency['name'] ?? "-"),
              _infoModalRow(
                "•  ความสัมพันธ์:",
                emergency['relationship'] ?? "-",
              ),
              _infoModalRow(
                "•  เบอร์โทรฉุกเฉิน:",
                _formatPhoneNumber(emergency['phone']),
              ),
              const SizedBox(height: 20),
              const Text(
                "รายละเอียดเพิ่มเติม:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              Text(
                user['additionalDetails'] ?? "ไม่มีข้อมูลเพิ่มเติม",
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _showMaidDetailModal(Map<String, dynamic> maidData) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildAvatarWidget(
                  Icons.cleaning_services_outlined,
                  const Color(0xFFF0F9FF),
                  const Color(0xFF0284C7),
                ),
                const SizedBox(width: 15),
                const Text(
                  "รายละเอียดบุคลากรแม่บ้าน",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF101828),
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            _infoModalRow("ชื่อ-นามสกุลพนักงาน:", maidData['name'] ?? "-"),
            _infoModalRow(
              "เบอร์โทรศัพท์ติดต่อ:",
              _formatPhoneNumber(maidData['phone']),
            ),
            _infoModalRow("Line ID ประจำตัว:", maidData['lineId'] ?? "-"),
            _infoModalRow("อีเมลในระบบแอป:", maidData['email'] ?? "-"),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "ปิดหน้าต่างพรีวิว",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOwnerEditTenantKeycardsModal(
    String docId,
    Map<String, dynamic> tenantData,
    int initialKeycards,
  ) {
    int localKeycards = initialKeycards;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 25,
                left: 25,
                right: 25,
                top: 25,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "จัดการสิทธิ์คีย์การ์ด:",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  Text(
                    "${tenantData['name']} ห้อง ${tenantData['roomNo'] ?? 'A101'}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF101828),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "ปรับเปลี่ยนสิทธิ์จำนวนคีย์การ์ดเสริมประจำห้องชุดพักอาศัยของคุณ",
                    style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                  ),
                  const Divider(height: 25),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 15,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "จำนวนคีย์การ์ดรวมระบบกุญแจ",
                          style: TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              children: [
                                Icon(
                                  Icons.credit_card_outlined,
                                  size: 40,
                                  color: Colors.grey.shade400,
                                ),
                                Positioned(
                                  right: -5,
                                  bottom: -5,
                                  child: Icon(
                                    Icons.credit_card,
                                    size: 40,
                                    color: const Color(
                                      0xFF101828,
                                    ).withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 15),
                            Text(
                              "$localKeycards",
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF101828),
                              ),
                            ),
                            const Text(
                              " ใบ",
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF101828),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              side: const BorderSide(color: Colors.redAccent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: localKeycards > 1
                                ? () => setModalState(() => localKeycards--)
                                : null,
                            child: const Icon(Icons.remove, color: Colors.red),
                          ),
                        ),
                        Text(
                          "$localKeycards",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF101828),
                          ),
                        ),
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: const Color(0xFF1DB954),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () =>
                                setModalState(() => localKeycards++),
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    "* รวมคีย์การ์ดหลัก 1 ใบ และเสริม ${localKeycards > 1 ? localKeycards - 1 : 0} ใบ",
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF101828),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(docId)
                            .update({'extraKeycards': localKeycards});
                        if (ctx.mounted) Navigator.pop(ctx);
                        setState(() {});
                      },
                      child: const Text(
                        "บันทึกการอัปเดตคีย์การ์ด",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOwnerEditTechFullModal(
    String docId,
    Map<String, dynamic> techData,
  ) {
    final nameC = TextEditingController(text: techData['name'] ?? "");
    final phoneC = TextEditingController(text: techData['phone'] ?? "");
    final lineC = TextEditingController(text: techData['lineId'] ?? "");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                "แก้ไขข้อมูลช่างซ่อมบำรุงเต็มรูปแบบ",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF101828),
                ),
              ),
              const Divider(height: 25),
              _buildModernTextFieldWidget(
                nameC,
                "ชื่อ-นามสกุลช่างเทคนิคประจำทีม",
                Icons.badge_outlined,
              ),
              _buildModernTextFieldWidget(
                phoneC,
                "เบอร์โทรศัพท์ติดต่อสายตรง",
                Icons.phone_android_outlined,
                isNum: true,
              ),
              _buildModernTextFieldWidget(
                lineC,
                "ระบุไอดีไลน์ช่าง (Line ID)",
                Icons.chat_bubble_outline,
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () async {
                    if (nameC.text.trim().isNotEmpty) {
                      await FirebaseFirestore.instance
                          .collection('technicians')
                          .doc(docId)
                          .update({
                            'name': nameC.text.trim(),
                            'phone': phoneC.text.trim(),
                            'lineId': lineC.text.trim(),
                          });
                      if (ctx.mounted) Navigator.pop(ctx);
                      setState(() {});
                    }
                  },
                  child: const Text(
                    "บันทึกการแก้ไขข้อมูลช่างทั้งหมด",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteUser(String collectionName, String docId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ยืนยันการลบข้อมูล"),
        content: Text(
          "คุณแน่ใจหรือไม่ที่จะลบรายชื่อของ '$name' ออกจากระบบหอพักอย่างถาวร?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ยกเลิก"),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection(collectionName)
                  .doc(docId)
                  .delete();
              Navigator.pop(context);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("ลบข้อมูลสำเร็จเรียบร้อยแล้ว"),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                setState(() {});
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              "ยืนยันลบ",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: buildOwnerAppBar(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSegmentedTabs(),
          Expanded(
            child: _currentSection == 0
                ? _buildFinanceSection()
                : _buildPeopleManagementSection(),
          ),
        ],
      ),
      bottomNavigationBar: buildOwnerBottomNav(context, 2),
    );
  }

  Widget _buildSegmentedTabs() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            _segmentItem(
              0,
              "บัญชีและการเงิน",
              Icons.account_balance_wallet_outlined,
            ),
            _segmentItem(1, "จัดการรายชื่อบุคลากร", Icons.group_outlined),
          ],
        ),
      ),
    );
  }

  Widget _segmentItem(int index, String title, IconData icon) {
    bool isSelected = _currentSection == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentSection = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF101828) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isSelected ? Colors.white : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinanceSection() {
    DateTime now = DateTime.now();
    DateTime firstDayMonth = DateTime(now.year, now.month, 1);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('status', isEqualTo: 'approved')
          .where('timestamp', isGreaterThanOrEqualTo: firstDayMonth)
          .snapshots(),
      builder: (context, incomeSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('expenses')
              .where('timestamp', isGreaterThanOrEqualTo: firstDayMonth)
              .snapshots(),
          builder: (context, expenseSnapshot) {
            double income = 0;
            double expense = 0;

            if (incomeSnapshot.hasData) {
              for (var doc in incomeSnapshot.data!.docs) {
                income += (doc['amount'] ?? 0).toDouble();
              }
            }
            if (expenseSnapshot.hasData) {
              for (var doc in expenseSnapshot.data!.docs) {
                expense += (doc['amount'] ?? 0).toDouble();
              }
            }

            double profit = income - expense;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101828),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "กระแสเงินคงเหลือเดือนนี้",
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "฿ ${currencyFormat.format(profit)}",
                          style: TextStyle(
                            color: profit >= 0
                                ? const Color(0xFF1DB954)
                                : Colors.redAccent,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(color: Colors.white12, height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "รายรับรวม (+)",
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    "฿${currencyFormat.format(income)}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "รายจ่ายสะสม (-)",
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    "฿${currencyFormat.format(expense)}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  _buildCountHeader(
                    "รอตรวจสอบสลิปโอนเงิน",
                    'pending',
                    color: const Color(0xFFFEF3C7),
                    textCol: const Color(0xFFD97706),
                  ),
                  const SizedBox(height: 12),
                  _buildPendingList(),
                  const SizedBox(height: 35),

                  const Text(
                    "รายงานความเคลื่อนไหวบัญชี",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  _buildSeparatedFilterButtons(),

                  const SizedBox(height: 15),
                  _buildHistoryList(),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSeparatedFilterButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildCustomChip(
          "รายรับทั้งหมด",
          Icons.trending_up,
          const Color(0xFF1DB954),
        ),
        _buildCustomChip(
          "รายจ่ายทั้งหมด",
          Icons.trending_down,
          Colors.redAccent,
        ),
        _buildCustomChip(
          "รายรับที่ไม่อนุมัติ",
          Icons.cancel_outlined,
          Colors.grey,
        ),
      ],
    );
  }

  Widget _buildCustomChip(String filterName, IconData icon, Color activeColor) {
    bool isSelected = _selectedFilter == filterName;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : activeColor),
          const SizedBox(width: 6),
          Text(filterName),
        ],
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF101828),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: isSelected ? Colors.white : const Color(0xFF475569),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
        ),
      ),
      showCheckmark: false,
      onSelected: (valid) {
        setState(() => _selectedFilter = filterName);
      },
    );
  }

  Widget _buildPeopleManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(child: _roleChip('tenant', "👥 ผู้เช่าทั้งหมด")),
              const SizedBox(width: 8),
              Expanded(child: _roleChip('maid', "🧹 แม่บ้าน")),
              const SizedBox(width: 8),
              Expanded(child: _roleChip('tech', "🔧 ช่างซ่อมแซม")),
            ],
          ),
        ),
        const SizedBox(height: 15),
        if (_selectedRoleView == 'tenant')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 1.2),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedTenantFilter,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.arrow_drop_down_circle_outlined,
                    color: Colors.blueGrey,
                  ),
                  style: const TextStyle(
                    color: Color(0xFF101828),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  items:
                      [
                            "ผู้เช่าทั้งหมด",
                            "ผู้เช่าที่มีห้องพักอาศัย (Active)",
                            "ผู้เช่าที่จองห้องพักค้างไว้ (Booking)",
                            "ผู้เช่าไอดีว่าง / ไม่มีห้องพัก (Empty)",
                          ]
                          .map(
                            (str) =>
                                DropdownMenuItem(value: str, child: Text(str)),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _selectedTenantFilter = v!),
                ),
              ),
            ),
          ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('rooms').snapshots(),
            builder: (context, roomSnapshot) {
              Map<String, String> roomStatuses = {};
              Map<String, String> tenantRoomNo = {};
              Map<String, String> nameToRoomNo = {};
              Map<String, String> bookerToRoomNo = {};

              if (roomSnapshot.hasData) {
                for (var doc in roomSnapshot.data!.docs) {
                  var rData = doc.data() as Map<String, dynamic>;
                  String rNo = rData['roomNo']?.toString() ?? "";
                  String rStatus = rData['status']?.toString() ?? "ว่าง";
                  String tUid = rData['tenantUid']?.toString() ?? "";
                  String tName = rData['tenantName']?.toString() ?? "";
                  String bName =
                      (rData['bookingName'] ?? rData['reservedBy'])
                          ?.toString() ??
                      "";

                  if (rNo.isNotEmpty) {
                    roomStatuses[rNo] = rStatus;
                    if (tUid.isNotEmpty) tenantRoomNo[tUid] = rNo;
                    if (tName.isNotEmpty) nameToRoomNo[tName] = rNo;
                    if (bName.isNotEmpty) bookerToRoomNo[bName] = rNo;
                  }
                }
              }

              if (_selectedRoleView == 'tech') {
                return _buildTechnicianList();
              } else if (_selectedRoleView == 'maid') {
                return _buildMaidList();
              } else {
                return _buildFilteredTenantsList(
                  roomStatuses,
                  tenantRoomNo,
                  nameToRoomNo,
                  bookerToRoomNo,
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _roleChip(String role, String label) {
    bool isSelected = _selectedRoleView == role;
    return ChoiceChip(
      label: Container(
        width: double.infinity,
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.black,
            fontSize: 12,
          ),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF101828),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      showCheckmark: false,
      onSelected: (s) => setState(() => _selectedRoleView = role),
    );
  }

  Widget _buildFilteredTenantsList(
    Map<String, String> roomStatuses,
    Map<String, String> tenantRoomNo,
    Map<String, String> nameToRoomNo,
    Map<String, String> bookerToRoomNo,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'tenant')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF1DB954)),
          );
        var docs = snapshot.data!.docs;
        if (docs.isEmpty)
          return _buildEmptyStateWidget("ไม่พบข้อมูลรายชื่อผู้เช่าในหอพัก");

        var filteredDocs = docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String uId = doc.id;
          String uName = data['name'] ?? "";
          String rNo =
              tenantRoomNo[uId] ??
              nameToRoomNo[uName] ??
              bookerToRoomNo[uName] ??
              data['roomNo']?.toString() ??
              "";
          String actualRoomStatus = roomStatuses[rNo] ?? "ว่าง";

          if (_selectedTenantFilter == "ผู้เช่าที่มีห้องพักอาศัย (Active)") {
            return rNo.isNotEmpty && actualRoomStatus == "มีผู้เช่า";
          } else if (_selectedTenantFilter ==
              "ผู้เช่าที่จองห้องพักค้างไว้ (Booking)") {
            return rNo.isNotEmpty && actualRoomStatus == "จองแล้ว";
          } else if (_selectedTenantFilter ==
              "ผู้เช่าไอดีว่าง / ไม่มีห้องพัก (Empty)") {
            return rNo.isEmpty ||
                (actualRoomStatus != "มีผู้เช่า" &&
                    actualRoomStatus != "จองแล้ว");
          } else {
            return true;
          }
        }).toList();

        if (filteredDocs.isEmpty)
          return _buildEmptyStateWidget(
            "ไม่มีรายชื่อข้อมูลผู้เช่าในเงื่อนไขดร็อปดาวน์นี้",
          );

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            var doc = filteredDocs[index];
            var userData = doc.data() as Map<String, dynamic>;
            String name = userData['name'] ?? "ไม่ระบุชื่อ";
            String phone = userData['phone'] ?? "";
            String rNo =
                tenantRoomNo[doc.id] ??
                nameToRoomNo[name] ??
                bookerToRoomNo[name] ??
                userData['roomNo']?.toString() ??
                "";
            int extraCards = userData['extraKeycards'] is int
                ? userData['extraKeycards']
                : (int.tryParse(userData['extraKeycards']?.toString() ?? "1") ??
                      1);

            String currentRoomStatus = roomStatuses[rNo] ?? "ว่าง";
            String badgeLabel = "ไอดีว่าง";
            Color badgeBg = const Color(0xFFF1F5F9);
            Color badgeText = Colors.grey;

            if (rNo.isNotEmpty && currentRoomStatus == "มีผู้เช่า") {
              badgeLabel = "ห้อง $rNo (อยู่พักอาศัย)";
              badgeBg = const Color(0xFFECFDF5);
              badgeText = const Color(0xFF10B981);
            } else if (rNo.isNotEmpty && currentRoomStatus == "จองแล้ว") {
              badgeLabel = "ห้อง $rNo (จองค้างไว้)";
              badgeBg = const Color(0xFFFFFBEB);
              badgeText = const Color(0xFFD97706);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showOwnerEditTenantKeycardsModal(
                  doc.id,
                  userData,
                  extraCards,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildAvatarWidget(
                        Icons.person,
                        const Color(0xFFE0F2FE),
                        const Color(0xFF0369A1),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF101828),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "📞 ${_formatPhoneNumber(phone)}  |  💬 Line: ${userData['lineId'] ?? '-'}",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _buildInlineBadge(
                                  badgeLabel,
                                  badgeBg,
                                  badgeText,
                                ),
                                _buildInlineBadge(
                                  "🎫 คีย์การ์ด $extraCards ใบ",
                                  const Color(0xFFEEF2F6),
                                  const Color(0xFF475569),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.zoom_in_outlined,
                          color: Colors.blue,
                          size: 24,
                        ),
                        onPressed: () => _showTenantDetailModal(
                          userData,
                          rNo.isNotEmpty ? "ห้อง $rNo" : "ยังไม่มีห้องพัก",
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_forever_outlined,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () =>
                            _confirmDeleteUser('users', doc.id, name),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMaidList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'maid')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;
        if (docs.isEmpty)
          return _buildEmptyStateWidget("ไม่พบข้อมูลรายชื่อแม่บ้านในระบบ");
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var userData = doc.data() as Map<String, dynamic>;
            String name = userData['name'] ?? "ไม่ระบุชื่อ";
            String phone = userData['phone'] ?? "";
            String lineId = userData['lineId'] ?? "ไม่ระบุ";
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showMaidDetailModal(userData),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildAvatarWidget(
                        Icons.cleaning_services_outlined,
                        const Color(0xFFF0F9FF),
                        const Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF101828),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "📞 เบอร์โทร: ${_formatPhoneNumber(phone)}",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              "💬 Line ID: $lineId",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_forever_outlined,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () =>
                            _confirmDeleteUser('users', doc.id, name),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTechnicianList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('technicians').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;
        if (docs.isEmpty)
          return _buildEmptyStateWidget("ไม่พบข้อมูลรายชื่อช่างซ่อมในระบบ");
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var techData = doc.data() as Map<String, dynamic>;
            String name = techData['name'] ?? "ช่างประจำหอ";
            String phone = techData['phone'] ?? "";
            String lineId = techData['lineId'] ?? "-";
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showOwnerEditTechFullModal(doc.id, techData),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildAvatarWidget(
                        Icons.engineering_outlined,
                        const Color(0xFFFFF7ED),
                        const Color(0xFFEA580C),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF101828),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "🛠️ ทะเบียน: ช่างเทคนิคประจำอาคารส่วนกลาง\n📞 โทร: ${_formatPhoneNumber(phone)}  |  💬 Line: $lineId",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_forever_outlined,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () =>
                            _confirmDeleteUser('technicians', doc.id, name),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAvatarWidget(IconData icon, Color bg, Color iconColor) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      );

  Widget _buildInlineBadge(String text, Color bg, Color textTheme) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: textTheme,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _buildModernTextFieldWidget(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNum = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: TextField(
      controller: controller,
      keyboardType: isNum ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 15,
          horizontal: 16,
        ),
      ),
    ),
  );

  Widget _buildEmptyStateWidget(String msg) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.folder_open_outlined, size: 45, color: Colors.grey.shade400),
        const SizedBox(height: 10),
        Text(msg, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      ],
    ),
  );

  Widget _buildDetailItem(
    String l,
    String v, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l, style: const TextStyle(color: Colors.grey)),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountHeader(
    String title,
    String status, {
    required Color color,
    required Color textCol,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "$count รายการ",
                  style: TextStyle(
                    color: textCol,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPendingList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        var docs = snapshot.data!.docs;
        if (docs.isEmpty)
          return const Text(
            "ไม่มีรายการรอตรวจสอบ",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          );
        return Column(
          children: docs.map((doc) {
            var data = doc.data() as Map<String, dynamic>;
            DateTime date = data['timestamp'] != null
                ? (data['timestamp'] as Timestamp).toDate()
                : DateTime.now();
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ห้อง ${data['roomNo'] ?? 'N/A'}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "โอนเมื่อ: ${DateFormat('dd พ.ค. yyyy', 'th').format(date)}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _smallBtn(
                    "ตรวจสอบ",
                    Colors.grey[100]!,
                    Colors.black,
                    () => _showTransactionDetailModal(doc.id, data),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildHistoryList() {
    if (_selectedFilter == "รายจ่ายทั้งหมด") {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('expenses')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();
          var docs = snapshot.data!.docs;
          if (docs.isEmpty)
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  "ไม่มีข้อมูลในหมวดหมู่นี้",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            );

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                var data = docs[index].data() as Map<String, dynamic>;
                DateTime date = data['timestamp'] != null
                    ? (data['timestamp'] as Timestamp).toDate()
                    : DateTime.now();
                return ListTile(
                  onTap: () => _showExpenseDetailModal(data),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFEF2F2),
                    child: Icon(Icons.build, color: Colors.red, size: 16),
                  ),
                  title: Text(
                    data['title'] ?? "บิลค่าซ่อมแซมห้องพัก",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    "ห้อง ${data['roomNo'] ?? '-'} | วันที่: ${DateFormat('dd พ.ค. yyyy', 'th').format(date)}",
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Text(
                    "- ฿${currencyFormat.format(data['amount'] ?? 0.0)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    } else {
      Query query = FirebaseFirestore.instance
          .collection('transactions')
          .orderBy('timestamp', descending: true);
      if (_selectedFilter == "รายรับทั้งหมด") {
        query = query.where('status', isEqualTo: 'approved');
      } else if (_selectedFilter == "รายรับที่ไม่อนุมัติ") {
        query = query.where('status', isEqualTo: 'rejected');
      }

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: query.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            var docs = snapshot.data!.docs;
            if (docs.isEmpty)
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    "ไม่มีข้อมูลในหมวดหมู่นี้",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              );

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                var data = docs[index].data() as Map<String, dynamic>;
                bool isApp = data['status'] == 'approved';
                return ListTile(
                  onTap: () =>
                      _showTransactionDetailModal(docs[index].id, data),
                  leading: CircleAvatar(
                    backgroundColor: isApp
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFFEF2F2),
                    child: Icon(
                      isApp ? Icons.check : Icons.close,
                      color: isApp ? Colors.green : Colors.red,
                      size: 16,
                    ),
                  ),
                  title: Text(
                    "ห้อง ${data['roomNo']}",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    data['type'] ?? "ค่าเช่า/ส่วนกลาง",
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Text(
                    "${isApp ? '+' : ''} ฿${currencyFormat.format(data['amount'] ?? 0.0)}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isApp ? Colors.green : Colors.red,
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    }
  }

  // 🌟 [กู้คืนสำเร็จ]: ปุ่มลัดขนาดเล็กสำหรับงานตรวจสอบรายการสลิปโอนเงิน
  Widget _smallBtn(String l, Color bg, Color t, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          l,
          style: TextStyle(color: t, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _infoModalRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

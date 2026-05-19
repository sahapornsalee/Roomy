import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // 🌟 [เพิ่มใหม่]: สำหรับเปิดลิงก์ Google Drive ภายนอกแอป
import '../../widgets/tenant_bottom_nav.dart'; //
import '../../widgets/tenant_app_bar.dart'; //

class TenantPayment extends StatefulWidget {
  const TenantPayment({super.key});

  @override
  State<TenantPayment> createState() => _TenantPaymentState();
}

class _TenantPaymentState extends State<TenantPayment> {
  int _activeTab = 0; // 0 = ชำระเงิน, 1 = ประวัติย้อนหลัง

  final TextEditingController _slipUrlController = TextEditingController(); //
  final user = FirebaseAuth.instance.currentUser; //

  // โครงสร้างบันทึกสถานะการเช็กเลือกรายการชำระเงินแบบยืดหยุ่น
  final Map<String, bool> _transactionTypes = {};

  @override
  void dispose() {
    _slipUrlController.dispose();
    super.dispose(); //
  }

  // แปลงลิงก์ Google Drive เป็น Direct Link สำหรับเปิดพรีวิวรูปภาพสลิป
  String _convertToDirectLink(String driveUrl) {
    if (driveUrl.contains("drive.google.com")) {
      try {
        String id = driveUrl.contains("/d/")
            ? driveUrl.split("/d/")[1].split("/")[0]
            : driveUrl.split("id=")[1].split("&")[0]; //
        return "https://drive.google.com/uc?export=view&id=$id"; //
      } catch (e) {
        return driveUrl; //
      }
    }
    return driveUrl; //
  }

  // 🌟 [เพิ่มใหม่]: ฟังก์ชันเปิดคลัง Google Drive ส่วนกลางดึงค่าลิงก์เชื่อมโยงมาจาก Firestore แอดมิน 🌟
  Future<void> _launchCentralGoogleDrive() async {
    try {
      var configDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('config')
          .get(); //
      if (configDoc.exists && configDoc.data()?['driveUrl'] != null) {
        final Uri url = Uri.parse(
          configDoc.data()!['driveUrl'].toString().trim(),
        ); //
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication); //
        } else {
          throw "Could not launch $url"; //
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "กรุณาแจ้งเจ้าของหอพักให้ตั้งค่าลิงก์คลังไดรฟ์ส่วนกลางในระบบก่อนใช้งาน",
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("เกิดข้อผิดพลาดในการเปิดไดรฟ์คลังกลาง: $e"),
            backgroundColor: Colors.redAccent, //
          ),
        );
      }
    }
  }

  // อัลกอริทึมสร้างรหัสพัสดุ PromptPay ล็อกยอดเงินจริงตามมาตรฐาน EMVCo
  String _generatePromptPayPayload(String rawPromptPayId, double amount) {
    String sanitizedId = rawPromptPayId.replaceAll(RegExp(r'[^0-9]'), ''); //

    if (sanitizedId.length != 10 && sanitizedId.length != 13) {
      sanitizedId = "0839741459"; // บัญชีพร้อมเพย์เริ่มต้นระบบหลัก
    }

    String targetSection = ""; //
    if (sanitizedId.length == 10) {
      targetSection = "01130066${sanitizedId.substring(1)}"; //
    } else {
      targetSection = "0213$sanitizedId"; //
    }

    String merchantValue = "0016A000000677010111$targetSection"; //
    String payload =
        "000201"
        "010212"
        "29${merchantValue.length.toString().padLeft(2, '0')}$merchantValue"
        "5303764"; //

    String amountStr = amount.toStringAsFixed(2); //
    payload +=
        "54${amountStr.length.toString().padLeft(2, '0')}$amountStr"
        "5802TH"
        "6304"; //

    int crc = 0xFFFF; //
    for (int i = 0; i < payload.length; i++) {
      crc ^= (payload.codeUnitAt(i) << 8); //
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF; //
        } else {
          crc = (crc << 1) & 0xFFFF; //
        }
      }
    }

    String checksum = crc.toRadixString(16).toUpperCase().padLeft(4, '0'); //
    return payload + checksum; //
  }

  // ฟังก์ชันส่งหลักฐานแจ้งโอนเงินไปยัง Firestore โดยบันทึกยอดเงินคำนวณจริง
  Future<void> _submitPayment(
    String roomNo,
    double finalCalculatedAmount,
    List<String> selectedCategories,
  ) async {
    if (finalCalculatedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("กรุณาเลือกรายการที่ต้องการชำระเงินอย่างน้อย 1 รายการ"),
          backgroundColor: Colors.orange, //
        ),
      );
      return; //
    }

    if (_slipUrlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("กรุณาวางลิงก์สลิปโอนเงิน"),
          backgroundColor: Colors.orange, //
        ),
      );
      return; //
    }

    await FirebaseFirestore.instance.collection('transactions').add({
      'roomNo': roomNo,
      'amount':
          finalCalculatedAmount, // ยอดล็อกอัตโนมัติจากระบบห้ามผู้เช่าแก้เอง
      'slipUrl': _slipUrlController.text.trim(), //
      'status': 'pending', //
      'timestamp': FieldValue.serverTimestamp(), //
      'type': selectedCategories.join(
        ', ',
      ), // บันทึกประเภทธุรกรรมจริงที่เลือกชำระ
      'tenantUid': user?.uid, //
      'note': '', //
    });

    _slipUrlController.clear(); //
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("ส่งหลักฐานเรียบร้อยแล้ว รอดำเนินการตรวจสอบ"),
          backgroundColor: Colors.green, //
        ),
      );
      setState(() => _activeTab = 1); //
    }
  }

  void _showHistoryDetailModal(Map<String, dynamic> data) {
    String status = data['status'] ?? "pending"; //
    DateTime paymentDate = data['timestamp'] != null
        ? (data['timestamp'] as Timestamp).toDate()
        : DateTime.now(); //

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)), //
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(25), //
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, //
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, //
                children: [
                  const Text(
                    "รายละเอียดประวัติบิล", //
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF101828), //
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close), //
                  ),
                ],
              ),
              const SizedBox(height: 10), //
              _buildStatusBadge(status), //
              const Divider(height: 35), //

              _infoDetailRow(
                "หมายเลขห้องพัก:",
                "ห้อง ${data['roomNo'] ?? 'N/A'}",
              ), //
              _infoDetailRow(
                "ยอดชำระสุทธิ:",
                "฿${NumberFormat('#,###').format(data['amount'] ?? 0)}",
              ), //
              _infoDetailRow(
                "ประเภทธุรกรรมที่จ่าย:",
                data['type'] ?? "ค่าเช่าหอพัก",
              ), //
              _infoDetailRow(
                "วันที่ส่งหลักฐาน:",
                DateFormat('dd MMM yyyy HH:mm น.', 'th').format(paymentDate),
              ), //

              const SizedBox(height: 25), //
              const Text(
                "บันทึกเพิ่มเติมจากเจ้าของหอพัก:", //
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                  fontSize: 14, //
                ),
              ),
              const SizedBox(height: 8), //
              Container(
                width: double.infinity, //
                padding: const EdgeInsets.all(15), //
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC), //
                  borderRadius: BorderRadius.circular(15), //
                  border: Border.all(color: Colors.grey.shade100), //
                ),
                child: Text(
                  (data['note'] != null &&
                          data['note'].toString().trim().isNotEmpty)
                      ? data['note']
                      : "ไม่มีบันทึกหรือข้อความตอบกลับจากผู้ดูแลในบิลใบนี้", //
                  style: TextStyle(
                    fontSize: 14,
                    color: data['note'] != null
                        ? Colors.black87
                        : Colors.grey, //
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 25), //
              if (data['slipUrl'] != null &&
                  data['slipUrl'].toString().isNotEmpty) ...[
                const Text(
                  "รูปภาพหลักฐานสลิปโอนเงินของคุณ:", //
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                    fontSize: 14, //
                  ),
                ),
                const SizedBox(height: 12), //
                ClipRRect(
                  borderRadius: BorderRadius.circular(20), //
                  child: Image.network(
                    _convertToDirectLink(data['slipUrl']), //
                    width: double.infinity, //
                    fit: BoxFit.contain, //
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 100,
                      width: double.infinity,
                      color: Colors.grey[100], //
                      child: const Center(
                        child: Text(
                          "ไม่สามารถดึงรูปภาพสลิปได้", //
                          style: TextStyle(color: Colors.grey, fontSize: 12), //
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 30), //
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoDetailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8), //
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, //
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ), //
        Text(
          value, //
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), //
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), //
      appBar: buildTenantAppBar(context, title: "การชำระเงิน"), //
      body: Column(
        children: [
          _buildTabs(), //
          Expanded(
            child: _activeTab == 0
                ? _buildPaymentView()
                : _buildHistoryView(), //
          ),
        ],
      ),
      bottomNavigationBar: buildTenantBottomNav(context, 1), //
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.all(20), //
      child: Container(
        padding: const EdgeInsets.all(5), //
        decoration: BoxDecoration(
          color: Colors.white, //
          borderRadius: BorderRadius.circular(15), //
          border: Border.all(color: Colors.grey.shade200), //
        ),
        child: Row(
          children: [
            _tabItem(0, "ชำระเงิน"),
            _tabItem(1, "ประวัติย้อนหลัง"),
          ], //
        ),
      ),
    );
  }

  Widget _tabItem(int index, String title) {
    bool isSelected = _activeTab == index; //
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index), //
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12), //
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF1F5F9) : Colors.transparent, //
            borderRadius: BorderRadius.circular(10), //
          ),
          child: Center(
            child: Text(
              title, //
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF101828) : Colors.grey, //
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentView() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .snapshots(), //
      builder: (context, userSnap) {
        if (!userSnap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.green), //
          );
        }
        String name = userSnap.data!['name'] ?? ""; //

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('rooms')
              .where('tenantName', isEqualTo: name)
              .limit(1)
              .snapshots(), //
          builder: (context, roomSnap) {
            if (!roomSnap.hasData || roomSnap.data!.docs.isEmpty) {
              return const Center(
                child: Text("ไม่พบข้อมูลบิลและห้องพักของคุณ"), //
              );
            }
            var roomData =
                roomSnap.data!.docs.first.data() as Map<String, dynamic>; //
            String roomNo = roomData['roomNo'] ?? "N/A"; //

            double rentPrice = (roomData['price'] ?? 0.0).toDouble(); //
            double waterPrice = (roomData['waterBill'] ?? 0.0).toDouble(); //
            double electricPrice = (roomData['electricBill'] ?? 0.0)
                .toDouble(); //
            double internetPrice = (roomData['internetBill'] ?? 0.0)
                .toDouble(); //
            double parkingPrice = (roomData['parkingBill'] ?? 0.0)
                .toDouble(); //
            double otherPrice = (roomData['otherBill'] ?? 0.0).toDouble(); //

            return StreamBuilder<QuerySnapshot>(
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
                  paymentStatus =
                      sortedTransactions.first['status'] ?? "none"; //
                }

                if (paymentStatus == "approved") {
                  return _buildLockStateCard(
                    icon: Icons.check_circle_rounded,
                    iconColor: const Color(0xFF10B981),
                    title: "ชำระเงินประจำเดือนเรียบร้อยแล้ว",
                    description:
                        "ระบบได้รับการอนุมัติใบเสร็จรับเงินประจำเดือนนี้เรียบร้อยแล้ว ขอบคุณที่ใช้บริการครับ ท่านสามารถตรวจสอบรายละเอียดบิลทั้งหมดได้ที่แท็บประวัติย้อนหลัง",
                  ); //
                } else if (paymentStatus == "pending") {
                  return _buildLockStateCard(
                    icon: Icons.hourglass_top_rounded,
                    iconColor: const Color(0xFFD97706),
                    title: "อยู่ระหว่างการรอตรวจสอบสลิป",
                    description:
                        "คุณได้ทำการส่งหลักฐานใบโอนเงินเข้ามาในระบบเรียบร้อยแล้ว เพื่อป้องกันความผิดพลาดทางบัญชี ระบบได้ทำการซ่อนคิวอาร์โค้ดชำระเงินชั่วคราว กรุณารอเจ้าของอนุมัติรายการครับ",
                  ); //
                }

                double totalCalculatedAmount = 0; //
                List<String> selectedCategories = []; //

                if (rentPrice > 0) {
                  _transactionTypes['ค่าเช่าห้อง'] ??= true; //
                  if (_transactionTypes['ค่าเช่าห้อง'] == true) {
                    totalCalculatedAmount += rentPrice; //
                    selectedCategories.add('ค่าเช่าห้อง'); //
                  }
                }
                if (waterPrice > 0) {
                  _transactionTypes['ค่าน้ำประปา'] ??= false; //
                  if (_transactionTypes['ค่าน้ำประปา'] == true) {
                    totalCalculatedAmount += waterPrice; //
                    selectedCategories.add('ค่าน้ำประปา'); //
                  }
                }
                if (electricPrice > 0) {
                  _transactionTypes['ค่าไฟฟ้า'] ??= false; //
                  if (_transactionTypes['ค่าไฟฟ้า'] == true) {
                    totalCalculatedAmount += electricPrice; //
                    selectedCategories.add('ค่าไฟฟ้า'); //
                  }
                }
                if (internetPrice > 0) {
                  _transactionTypes['ค่าอินเทอร์เน็ต'] ??= false; //
                  if (_transactionTypes['ค่าอินเทอร์เน็ต'] == true) {
                    totalCalculatedAmount += internetPrice; //
                    selectedCategories.add('ค่าอินเทอร์เน็ต'); //
                  }
                }
                if (parkingPrice > 0) {
                  _transactionTypes['ค่าที่จอดรถ'] ??= false; //
                  if (_transactionTypes['ค่าที่จอดรถ'] == true) {
                    totalCalculatedAmount += parkingPrice; //
                    selectedCategories.add('ค่าที่จอดรถ'); //
                  }
                }
                if (otherPrice > 0) {
                  _transactionTypes['อื่นๆ'] ??= false; //
                  if (_transactionTypes['อื่นๆ'] == true) {
                    totalCalculatedAmount += otherPrice; //
                    selectedCategories.add('อื่นๆ'); //
                  }
                }

                double totalOutstanding =
                    rentPrice +
                    waterPrice +
                    electricPrice +
                    internetPrice +
                    parkingPrice +
                    otherPrice; //

                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('settings')
                      .doc('config')
                      .snapshots(), //
                  builder: (context, configSnap) {
                    String ownerPromptPay = "0839741459"; //
                    String centralBankName = "krungthai"; //
                    String centralAccountNo = "6794339781"; //
                    String centralAccountName = "sahaporn"; //

                    if (configSnap.hasData && configSnap.data!.exists) {
                      var configData =
                          configSnap.data!.data() as Map<String, dynamic>; //
                      if (configData['promptPayId'] != null &&
                          configData['promptPayId']
                              .toString()
                              .trim()
                              .isNotEmpty) {
                        ownerPromptPay = configData['promptPayId']
                            .toString()
                            .trim(); //
                      }
                      centralBankName =
                          configData['bankName'] ?? centralBankName; //
                      centralAccountNo =
                          configData['bankAccountNo'] ?? centralAccountNo; //
                      centralAccountName =
                          configData['bankAccountName'] ??
                          centralAccountName; //
                    }

                    String promptPayQrRaw = _generatePromptPayPayload(
                      ownerPromptPay,
                      totalCalculatedAmount,
                    ); //
                    String qrEngineUrl =
                        "https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${Uri.encodeComponent(promptPayQrRaw)}"; //

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20), //
                      child: Container(
                        padding: const EdgeInsets.all(22), //
                        decoration: BoxDecoration(
                          color: Colors.white, //
                          borderRadius: BorderRadius.circular(30), //
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02), //
                              blurRadius: 10, //
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, //
                          children: [
                            Center(
                              child: Column(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: Color(0xFFE8F5E9), //
                                    child: Icon(
                                      Icons.receipt_long_outlined, //
                                      color: Color(0xFF1DB954), //
                                    ),
                                  ),
                                  const SizedBox(height: 10), //
                                  Text(
                                    "ห้อง $roomNo • รายการบิลประจำเดือน", //
                                    style: const TextStyle(
                                      fontSize: 16, //
                                      fontWeight: FontWeight.bold, //
                                    ),
                                  ),
                                  const SizedBox(height: 4), //
                                  Text(
                                    "รวมยอดค้างชำระทั้งหมด: ฿${NumberFormat('#,###').format(totalOutstanding)}", //
                                    style: const TextStyle(
                                      color: Colors.grey, //
                                      fontSize: 12, //
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 30), //

                            const Text(
                              "1. เลือกรายการธุรกรรมที่ต้องการชำระเงิน :", //
                              style: TextStyle(
                                fontWeight: FontWeight.bold, //
                                fontSize: 13, //
                                color: Colors.blueGrey, //
                              ),
                            ),
                            const SizedBox(height: 8), //

                            _buildDynamicCheckboxTile(
                              'ค่าเช่าห้อง',
                              'ค่าเช่าห้อง',
                              rentPrice,
                            ), //
                            _buildDynamicCheckboxTile(
                              'ค่าน้ำประปา',
                              'ค่าน้ำประปา',
                              waterPrice,
                            ), //
                            _buildDynamicCheckboxTile(
                              'ค่าไฟฟ้า',
                              'ค่าไฟฟ้า',
                              electricPrice,
                            ), //
                            _buildDynamicCheckboxTile(
                              'ค่าอินเทอร์เน็ต',
                              'ค่าอินเทอร์เน็ต',
                              internetPrice,
                            ), //
                            _buildDynamicCheckboxTile(
                              'ค่าที่จอดรถ',
                              'ค่าที่จอดรถ',
                              parkingPrice,
                            ), //
                            _buildDynamicCheckboxTile(
                              'อื่นๆ',
                              'อื่นๆ',
                              otherPrice,
                            ), //

                            const SizedBox(height: 20), //

                            const Text(
                              "2. ยอดเงินรวมที่ต้องชำระในครั้งนี้ (บาท)", //
                              style: TextStyle(
                                fontWeight: FontWeight.bold, //
                                fontSize: 13, //
                                color: Colors.blueGrey, //
                              ),
                            ),
                            const SizedBox(height: 10), //
                            Container(
                              width: double.infinity, //
                              padding: const EdgeInsets.symmetric(
                                vertical: 15,
                              ), //
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC), //
                                borderRadius: BorderRadius.circular(15), //
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                ), //
                              ),
                              child: Center(
                                child: Text(
                                  "฿ ${NumberFormat('#,###.00').format(totalCalculatedAmount)}", //
                                  style: const TextStyle(
                                    fontSize: 32, //
                                    fontWeight: FontWeight.bold, //
                                    color: Color(0xFF101828), //
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 25), //
                            Container(
                              width: double.infinity, //
                              padding: const EdgeInsets.all(15), //
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC), //
                                borderRadius: BorderRadius.circular(15), //
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start, //
                                children: [
                                  Text(
                                    "ช่องทางบัญชีหอพัก: ธนาคาร $centralBankName", //
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold, //
                                      fontSize: 12, //
                                      color: Colors.blueGrey, //
                                    ),
                                  ),
                                  const SizedBox(height: 4), //
                                  Text(
                                    "เลขบัญชีรับโอน: $centralAccountNo", //
                                    style: const TextStyle(
                                      fontSize: 14, //
                                      fontWeight: FontWeight.bold, //
                                    ),
                                  ),
                                  Text(
                                    "ชื่อบัญชีผู้รับเงิน: $centralAccountName", //
                                    style: const TextStyle(
                                      fontSize: 11, //
                                      color: Colors.grey, //
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 🌟 [เพิ่มใหม่]: แผงปุ่มสำหรับสไลด์เปิดแอป Google Drive คลังส่วนกลางของหอพัก เพื่ออัปโหลดรูปภาพสลิป 🌟
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton.icon(
                                onPressed: _launchCentralGoogleDrive,
                                icon: const Icon(
                                  Icons.folder_shared_outlined,
                                  color: Colors.indigo,
                                  size: 20,
                                ),
                                label: const Text(
                                  "เปิดคลัง Google Drive เพื่ออัปโหลดสลิป",
                                  style: TextStyle(
                                    color: Colors.indigo,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: Colors.indigo.withOpacity(0.4),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  backgroundColor: const Color(0xFFEEF2F6),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20), //
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(15), //
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB), //
                                  borderRadius: BorderRadius.circular(20), //
                                  border: Border.all(
                                    color: Colors.grey.shade200, //
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Image.network(
                                      qrEngineUrl, //
                                      height: 180, //
                                      width: 180, //
                                    ),
                                    const SizedBox(height: 10), //
                                    const Text(
                                      "เปิดแอปธนาคารสแกนยอดบิลนี้เข้าบัญชีพร้อมเพย์กลางได้ทันที",
                                      style: TextStyle(
                                        color: Colors.grey, //
                                        fontSize: 10, //
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 25), //
                            TextField(
                              controller: _slipUrlController, //
                              decoration: InputDecoration(
                                hintText:
                                    "วางลิงก์สลิปโอนเงินยืนยันจาก Google Drive", //
                                prefixIcon: const Icon(Icons.link), //
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15), //
                                ),
                              ),
                            ),
                            const SizedBox(height: 15), //
                            SizedBox(
                              width: double.infinity, //
                              height: 50, //
                              child: ElevatedButton.icon(
                                onPressed: () => _submitPayment(
                                  roomNo,
                                  totalCalculatedAmount,
                                  selectedCategories,
                                ), //
                                icon: const Icon(
                                  Icons.cloud_upload_outlined, //
                                  color: Colors.white, //
                                ),
                                label: const Text(
                                  "อัปโหลดแจ้งหลักฐานสลิปโอนเงิน", //
                                  style: TextStyle(
                                    color: Colors.white, //
                                    fontWeight: FontWeight.bold, //
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF101828), //
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15), //
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLockStateCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20), //
      child: Container(
        width: double.infinity, //
        padding: const EdgeInsets.all(30), //
        decoration: BoxDecoration(
          color: Colors.white, //
          borderRadius: BorderRadius.circular(30), //
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10), //
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 20), //
            Icon(icon, size: 80, color: iconColor), //
            const SizedBox(height: 20), //
            Text(
              title, //
              style: const TextStyle(
                fontSize: 18, //
                fontWeight: FontWeight.bold, //
                color: Color(0xFF101828), //
              ),
              textAlign: TextAlign.center, //
            ),
            const SizedBox(height: 12), //
            Text(
              description, //
              style: const TextStyle(
                fontSize: 13, //
                color: Colors.grey, //
                height: 1.5, //
              ),
              textAlign: TextAlign.center, //
            ),
            const SizedBox(height: 30), //
            SizedBox(
              width: double.infinity, //
              height: 48, //
              child: ElevatedButton(
                onPressed: () => setState(() => _activeTab = 1), //
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF101828), //
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15), //
                  ),
                ),
                child: const Text(
                  "ตรวจสอบประวัติย้อนหลัง", //
                  style: TextStyle(
                    color: Colors.white, //
                    fontWeight: FontWeight.bold, //
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10), //
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicCheckboxTile(
    String typeKey,
    String typeName,
    double typePrice,
  ) {
    if (typePrice <= 0) return const SizedBox.shrink(); //

    return Container(
      margin: const EdgeInsets.only(bottom: 6), //
      child: CheckboxListTile(
        title: Text(
          typeName, //
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), //
        ),
        secondary: Text(
          "฿${NumberFormat('#,###').format(typePrice)}", //
          style: const TextStyle(
            fontWeight: FontWeight.bold, //
            color: Colors.redAccent, //
            fontSize: 14, //
          ),
        ),
        value: _transactionTypes[typeKey] ?? false, //
        activeColor: const Color(0xFF1DB954), //
        contentPadding: EdgeInsets.zero, //
        controlAffinity: ListTileControlAffinity.leading, //
        dense: true, //
        onChanged: (bool? value) {
          setState(() {
            _transactionTypes[typeKey] = value ?? false; //
          });
        },
      ),
    );
  }

  Widget _buildHistoryView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('tenantUid', isEqualTo: user?.uid)
          .orderBy('timestamp', descending: true)
          .snapshots(), //
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.green), //
          );
        }
        var docs = snapshot.data!.docs; //
        if (docs.isEmpty) {
          return const Center(child: Text("ยังไม่มีประวัติการชำระเงิน")); //
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20), //
          itemCount: docs.length, //
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>; //
            String status = data['status'] ?? "pending"; //

            return Container(
              margin: const EdgeInsets.only(bottom: 15), //
              decoration: BoxDecoration(
                color: Colors.white, //
                borderRadius: BorderRadius.circular(20), //
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(20), //
                onTap: () => _showHistoryDetailModal(data), //
                child: Padding(
                  padding: const EdgeInsets.all(15), //
                  child: ListTile(
                    contentPadding: EdgeInsets.zero, //
                    leading: CircleAvatar(
                      backgroundColor: status == 'approved'
                          ? Colors.green.shade50
                          : (status == 'rejected'
                                ? Colors.red.shade50
                                : Colors.orange.shade50), //
                      child: Icon(
                        status == 'approved'
                            ? Icons.check
                            : (status == 'rejected'
                                  ? Icons.close
                                  : Icons.access_time), //
                        color: status == 'approved'
                            ? Colors.green
                            : (status == 'rejected'
                                  ? Colors.red
                                  : Colors.orange), //
                      ),
                    ),
                    title: Text(
                      "฿${NumberFormat('#,###').format(data['amount'])}", //
                      style: const TextStyle(fontWeight: FontWeight.bold), //
                    ),
                    subtitle: Text(
                      data['timestamp'] != null
                          ? DateFormat(
                              'dd MMM yyyy',
                              'th',
                            ).format((data['timestamp'] as Timestamp).toDate())
                          : "", //
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min, //
                      children: [
                        Text(
                          status == 'approved'
                              ? "สำเร็จ"
                              : (status == 'rejected'
                                    ? "ปฏิเสธบิล"
                                    : "รอการตรวจ"), //
                          style: TextStyle(
                            color: status == 'approved'
                                ? Colors.green
                                : (status == 'rejected'
                                      ? Colors.red
                                      : Colors.orange), //
                            fontWeight: FontWeight.bold, //
                            fontSize: 12, //
                          ),
                        ),
                        const SizedBox(width: 5), //
                        const Icon(
                          Icons.chevron_right, //
                          size: 16, //
                          color: Colors.grey, //
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg; //
    Color text; //
    String label; //
    if (status == "approved") {
      bg = const Color(0xFFECFDF5); //
      text = const Color(0xFF10B981); //
      label = "สำเร็จ"; //
    } else if (status == "rejected") {
      bg = const Color(0xFFFEF2F2); //
      text = Colors.red; //
      label = "ปฏิเสธบิล"; //
    } else {
      bg = const Color(0xFFFFFBEB); //
      text = const Color(0xFFD97706); //
      label = "รอการตรวจ"; //
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), //
      decoration: BoxDecoration(
        color: bg, //
        borderRadius: BorderRadius.circular(8), //
      ),
      child: Text(
        label, //
        style: TextStyle(
          color: text, //
          fontSize: 11, //
          fontWeight: FontWeight.bold, //
        ),
      ),
    );
  }
}

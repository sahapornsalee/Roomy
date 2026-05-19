import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // 🌟 [เพิ่มใหม่]: สำหรับเปิดลิงก์ Google Drive ภายนอกแอป

class MaidHome extends StatefulWidget {
  const MaidHome({super.key});

  @override
  State<MaidHome> createState() => _MaidHomeState();
}

class _MaidHomeState extends State<MaidHome> {
  int _activeTab = 0; // 0 = ตารางงาน, 1 = ประวัติงาน
  final user = FirebaseAuth.instance.currentUser;

  String _maidName = "แม่บ้าน";
  String _maidPhone = "";
  String _maidEmail = "";
  String _maidLineId = ""; // 🌟 [เพิ่มใหม่]: ตัวแปรเก็บ Line ID ประจำตัวแม่บ้าน

  @override
  void initState() {
    super.initState();
    _fetchMaidData();
  }

  // ดึงข้อมูลแม่บ้านจาก Cloud Firestore
  Future<void> _fetchMaidData() async {
    var doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user?.uid)
        .get();
    if (doc.exists) {
      var userData = doc.data() as Map<String, dynamic>? ?? {};
      setState(() {
        _maidName = userData['name'] ?? "แม่บ้าน";
        _maidPhone = userData['phone'] ?? "";
        _maidEmail = userData['email'] ?? user?.email ?? "";
        _maidLineId =
            userData['lineId'] ?? ""; // 🌟 [เพิ่มใหม่]: ดึงค่า Line ID
      });
    }
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

  String _convertToDirectLink(String driveUrl) {
    if (driveUrl.contains("drive.google.com")) {
      try {
        String id = driveUrl.contains("/d/")
            ? driveUrl.split("/d/")[1].split("/")[0]
            : driveUrl.split("id=")[1].split("&")[0];
        return "https://drive.google.com/uc?export=view&id=$id";
      } catch (e) {
        return driveUrl;
      }
    }
    return driveUrl;
  }

  Widget _buildEditLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 8, top: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildUploadRowTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 3, bottom: 6, top: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  // 🌟 [ปรับปรุงใหม่]: ฟอร์มหน้าต่างแก้ไขข้อมูลโปรไฟล์แม่บ้านได้ครบทุกฟิลด์ข้อมูล (รวม Line ID)
  void _showAccountSettingsModal() {
    final nameController = TextEditingController(text: _maidName);
    final phoneController = TextEditingController(text: _maidPhone);
    final lineIdController = TextEditingController(
      text: _maidLineId,
    ); // คอนโทรลเลอร์ไลน์ไอดี

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
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
              const SizedBox(height: 20),
              const Text(
                "ตั้งค่าบัญชีแม่บ้าน",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF101828),
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                "จัดการข้อมูลส่วนตัวของคุณสำหรับรับงานภายในหอพัก",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 25),
              _buildEditLabel("ชื่อ-นามสกุล"),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              _buildEditLabel("เบอร์โทรศัพท์ติดต่อ"),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.phone_android_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              // 🌟 เพิ่มฟิลด์แก้ไข Line ID ประจำตัวแม่บ้าน
              _buildEditLabel("ไอดีไลน์ (Line ID)"),
              TextField(
                controller: lineIdController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.chat_bubble_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isNotEmpty) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user?.uid)
                          .update({
                            'name': nameController.text.trim(),
                            'phone': phoneController.text.trim(),
                            'lineId': lineIdController.text
                                .trim(), // อัปเดตขึ้น Firestore
                          });
                      setState(() {
                        _maidName = nameController.text.trim();
                        _maidPhone = phoneController.text.trim();
                        _maidLineId = lineIdController.text.trim();
                      });
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF101828),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    "บันทึกข้อมูลทั้งหมด",
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
      ),
    );
  }

  void _showJobDetail(Map<String, dynamic> data) {
    bool isRepair = data['type'] == "งานซ่อม" || data['title'] == "งานซ่อม";
    Map<String, dynamic> checklist = data['checklist'] ?? {};

    List<dynamic> beforePhotos = data['beforePhotos'] ?? [];
    List<dynamic> afterPhotos = data['afterPhotos'] ?? [];
    List<dynamic> billPhotos = data['billPhotos'] ?? [];

    List<String> sortedChecklistKeys = checklist.keys.toList();
    sortedChecklistKeys.sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Column(
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "รายละเอียดห้อง ${data['roomNo']}",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Divider(height: 30),
              _infoRow("ประเภทงาน:", data['type'] ?? "งานทั่วไป"),
              _infoRow("สถานะปัจจุบัน:", data['status'] ?? "รอดำเนินการ"),
              if (data['cost'] != null)
                _infoRow(
                  "รวมค่าใช้จ่ายอุปกรณ์:",
                  "฿${NumberFormat('#,###.00').format(data['cost'])}",
                ),
              _infoRow("ผู้ดูแลรับผิดชอบ:", data['assignedPerson'] ?? "-"),
              if (isRepair && data['techPhone'] != null)
                _infoRow("เบอร์โทรศัพท์ช่าง:", data['techPhone']),
              if (isRepair && data['techLineId'] != null)
                _infoRow("Line ID ช่าง:", data['techLineId']),
              const SizedBox(height: 15),

              if (!isRepair && sortedChecklistKeys.isNotEmpty) ...[
                const Text(
                  "สิ่งที่ดำเนินการทำความสะอาดไปแล้วบ้างในห้อง:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 10),
                ...sortedChecklistKeys
                    .map(
                      (k) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              checklist[k] == true
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: checklist[k] == true
                                  ? Colors.green
                                  : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              k,
                              style: TextStyle(
                                color: checklist[k] == true
                                    ? Colors.black
                                    : Colors.grey,
                                fontWeight: checklist[k] == true
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                const SizedBox(height: 20),
              ],

              const Text(
                "รายละเอียดบันทึกเพิ่มเติม:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
              Text(
                data['description'] ?? "ไม่มีข้อมูลเพิ่มเติม",
                style: const TextStyle(fontSize: 15, color: Colors.black87),
              ),
              const Divider(height: 30),

              if (beforePhotos.isNotEmpty) ...[
                const Text(
                  "📸 รูปภาพหลักฐานจุดชำรุด/เสียหาย (ก่อนซ่อม):",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                _buildHorizontalPhotoGrid(beforePhotos),
                const SizedBox(height: 15),
              ],
              if (afterPhotos.isNotEmpty) ...[
                Text(
                  isRepair
                      ? "📸 รูปภาพหลักฐานหลังการซ่อมแซมเสร็จสิ้น:"
                      : "📸 รูปภาพหลักฐานหลังทำความสะอาดห้องพัก:",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                _buildHorizontalPhotoGrid(afterPhotos),
                const SizedBox(height: 15),
              ],
              if (billPhotos.isNotEmpty) ...[
                const Text(
                  "📸 รูปภาพใบเสร็จ / บิลค่าใช้จ่ายซื้อวัสดุอุปกรณ์:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 8),
                _buildHorizontalPhotoGrid(billPhotos),
                const SizedBox(height: 15),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // หน้าต่างฟอร์มบันทึกปิดงานและรายงานบัญชีการเงินส่วนกลาง
  void _showCompleteTaskFormSheet(
    String taskId,
    Map<String, dynamic> taskData,
    bool isRepair,
  ) {
    final costController = TextEditingController(text: "");

    List<String> sheetBeforePhotos = List<String>.from(
      taskData['beforePhotos'] ?? [],
    );
    List<String> sheetAfterPhotos = List<String>.from(
      taskData['afterPhotos'] ?? [],
    );
    List<String> sheetBillPhotos = List<String>.from(
      taskData['billPhotos'] ?? [],
    );

    Map<String, dynamic> sheetChecklist = Map<String, dynamic>.from(
      taskData['checklist'] ??
          {
            'กวาดพื้น': false,
            'ถูพื้น': false,
            'ล้างห้องน้ำ': false,
            'เช็ดกระจก': false,
          },
    );

    List<String> sortedSheetKeys = sheetChecklist.keys.toList()..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            padding: const EdgeInsets.all(25),
            child: SingleChildScrollView(
              child: Column(
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
                  Text(
                    isRepair
                        ? "📋 บันทึกรายงานการซ่อมแซม"
                        : "📋 สรุปรายการล้างทำความสะอาดห้องพัก",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "ห้องหมายเลข ${taskData['roomNo']} • โปรดตรวจสอบหลักฐานให้เรียบร้อยก่อนปิดงาน",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Divider(height: 25),

                  if (!isRepair) ...[
                    const Text(
                      "✔️ เลือกสิ่งที่ดำเนินการทำความสะอาดไปบ้างในครั้งนี้ :",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 5),
                    ...sortedSheetKeys
                        .map(
                          (key) => CheckboxListTile(
                            title: Text(
                              key,
                              style: const TextStyle(fontSize: 14),
                            ),
                            value: sheetChecklist[key] ?? false,
                            activeColor: const Color(0xFF1DB954),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) => setSheetState(
                              () => sheetChecklist[key] = val ?? false,
                            ),
                          ),
                        )
                        .toList(),
                    const Divider(height: 25),
                  ],

                  if (isRepair) ...[
                    const Text(
                      "💰 ยอดรวมค่าซ่อมแซมบำรุงรักษา / ค่าวัสดุอุปกรณ์ (บาท) *",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: costController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "กรุณาระบุจำนวนเงินค่าซ่อมจริง",
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                    ),
                    const Divider(height: 25),
                  ],

                  const Text(
                    "📷 แนบลิงก์รูปภาพประกอบหลักฐานระบบ (เพิ่มได้หลายรูปภาพ) :",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF101828),
                    ),
                  ),
                  const SizedBox(height: 15),
                  SExpandingButton(
                    label: "เปิดคลัง Google Drive ระบบส่วนกลาง",
                    color: Colors.blueGrey,
                    onPressed: _launchCentralGoogleDrive,
                  ),
                  const SizedBox(height: 12),

                  if (isRepair) ...[
                    _buildUploadRowTitle(
                      "1. รูปถ่ายหลักฐานจุดชำรุดช้า/ความเสียหาย (ก่อนเข้าซ่อม)",
                    ),
                    _buildPhotoInputRow(sheetBeforePhotos, setSheetState),
                    const SizedBox(height: 15),
                  ],

                  _buildUploadRowTitle(
                    isRepair
                        ? "2. รูปถ่ายหลักฐานสภาพห้องหลังดำเนินงานซ่อมแซมเสร็จ"
                        : "1. รูปหลักฐานผลงานการล้างทำความสะอาดห้องพักรวม",
                  ),
                  _buildPhotoInputRow(sheetAfterPhotos, setSheetState),
                  const SizedBox(height: 15),

                  if (isRepair) ...[
                    _buildUploadRowTitle(
                      "3. รูปภาพบิล / ใบเสร็จแสดงค่าซื้อเครื่องมืออุปกรณ์ประกอบ *",
                    ),
                    _buildPhotoInputRow(sheetBillPhotos, setSheetState),
                    const Divider(height: 25),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DB954),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: () async {
                        double enteredCost = 0.0;
                        if (isRepair) {
                          enteredCost =
                              double.tryParse(costController.text.trim()) ??
                              0.0;
                          if (enteredCost <= 0.0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "⚠️ เกิดข้อผิดพลาด: กรุณาระบุเงินค่าใช้จ่ายวัสดุอุปกรณ์จริง (ห้ามปล่อยว่างหรือเป็น 0 บาท)",
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }
                          if (sheetBillPhotos.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "⚠️ เกิดข้อผิดพลาด: กรุณาแนบลิงก์รูปภาพบิลหรือใบเสร็จค่าใช้จ่ายวัสดุอุปกรณ์ก่อนปิดงาน",
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }
                        }

                        if (sheetAfterPhotos.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "กรุณาแนบลิงก์รูปภาพหลักฐานผลการดำเนินงานอย่างน้อย 1 รูป",
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        // 1. อัปเดตข้อมูลขึ้นคอลเลกชัน repairs ของโปรเจกต์หลัก
                        await FirebaseFirestore.instance
                            .collection('repairs')
                            .doc(taskId)
                            .update({
                              'status': 'เสร็จสิ้น',
                              'checklist': sheetChecklist,
                              'cost': enteredCost,
                              'beforePhotos': sheetBeforePhotos,
                              'afterPhotos': sheetAfterPhotos,
                              'billPhotos': sheetBillPhotos,
                            });

                        // 🌟 [เพิ่มใหม่/ระบบแชร์ข้อมูลการเงิน]: หากเป็นงานซ่อมแซมที่มีค่าใช้จ่ายจริง ยิงข้อมูลบิลรายจ่ายตรงเข้าบอร์ดเจ้าของหอพักทันที
                        if (isRepair && enteredCost > 0) {
                          String roomNo = taskData['roomNo'] ?? "";
                          await FirebaseFirestore.instance
                              .collection('expenses')
                              .add({
                                'title':
                                    'ค่าซ่อมบำรุง/ดูแล ห้อง $roomNo (${taskData['title'] ?? 'งานทั่วไป'})',
                                'amount': enteredCost,
                                'roomNo': roomNo,
                                'type': taskData['type'] ?? 'งานซ่อม',
                                'timestamp': FieldValue.serverTimestamp(),
                                'repairDocId': taskId,
                              });
                        }

                        String roomNo = taskData['roomNo'] ?? "";
                        if (roomNo.isNotEmpty) {
                          var roomQuery = await FirebaseFirestore.instance
                              .collection('rooms')
                              .where('roomNo', isEqualTo: roomNo)
                              .limit(1)
                              .get();
                          if (roomQuery.docs.isNotEmpty) {
                            var roomDoc = roomQuery.docs.first;
                            var roomData =
                                roomDoc.data() as Map<String, dynamic>;
                            String nextStatus = "ว่าง";

                            if (roomData['tenantName'] != null &&
                                roomData['tenantName']
                                    .toString()
                                    .trim()
                                    .isNotEmpty) {
                              nextStatus = "มีผู้เช่า";
                            } else if ((roomData['bookingName'] != null &&
                                    roomData['bookingName']
                                        .toString()
                                        .trim()
                                        .isNotEmpty) ||
                                (roomData['reservedBy'] != null &&
                                    roomData['reservedBy']
                                        .toString()
                                        .trim()
                                        .isNotEmpty)) {
                              nextStatus = "จองแล้ว";
                            } else {
                              nextStatus = "ว่าง";
                            }
                            await roomDoc.reference.update({
                              'status': nextStatus,
                            });
                          }
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                        setState(() {});
                      },
                      child: const Text(
                        "บันทึกรายงานข้อมูลและยืนยันปิดงาน",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalPhotoGrid(List<dynamic> photos) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        itemBuilder: (context, idx) => Container(
          width: 110,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.network(
              _convertToDirectLink(photos[idx].toString()),
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => const Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.grey),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoInputRow(
    List<String> photoList,
    StateSetter setModalState,
  ) {
    final itemController = TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photoList.isNotEmpty) ...[
          _buildHorizontalPhotoGrid(photoList),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: itemController,
                decoration: InputDecoration(
                  hintText: "วางลิงก์รูปภาพสลิปหรือสภาพห้องจากคลังไดรฟ์",
                  prefixIcon: const Icon(Icons.link, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF101828),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                if (itemController.text.trim().isNotEmpty &&
                    itemController.text.startsWith('http')) {
                  setModalState(() {
                    photoList.add(itemController.text.trim());
                    itemController.clear();
                  });
                }
              },
              child: const Text(
                "เพิ่มรูป",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _handleStatusUpdate(
    String id,
    String? status,
    bool isRepair,
    double cost,
    Map<String, dynamic> taskData,
  ) async {
    if (status != "กำลังดำเนินการ") {
      await FirebaseFirestore.instance.collection('repairs').doc(id).update({
        'status': 'กำลังดำเนินการ',
      });
      String roomNo = taskData['roomNo'] ?? "";
      String taskType = taskData['type'] ?? taskData['title'] ?? "";

      if (roomNo.isNotEmpty && taskType == "ทำความสะอาด") {
        var roomQuery = await FirebaseFirestore.instance
            .collection('rooms')
            .where('roomNo', isEqualTo: roomNo)
            .limit(1)
            .get();
        if (roomQuery.docs.isNotEmpty) {
          var roomDoc = roomQuery.docs.first;
          var roomData = roomDoc.data() as Map<String, dynamic>;
          String intermediateRoomStatus = "ทำความสะอาด";
          String dbStatus = roomData['status'] ?? "ว่าง";

          if (dbStatus == "มีผู้เช่า" || dbStatus.contains("มีผู้เช่า")) {
            intermediateRoomStatus = "ทำความสะอาด + มีผู้เช่า";
          } else if (dbStatus == "จองแล้ว" || dbStatus.contains("จองแล้ว")) {
            intermediateRoomStatus = "ทำความสะอาด + จองแล้ว";
          } else {
            intermediateRoomStatus = "ทำความสะอาด";
          }
          await roomDoc.reference.update({'status': intermediateRoomStatus});
        }
      }
    } else {
      _showCompleteTaskFormSheet(id, taskData, isRepair);
    }
  }

  Widget _buildRepairTaskCard(
    String repairId,
    Map<String, dynamic> data,
    bool isFinished,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border(
          left: BorderSide(
            color: isFinished ? Colors.green : Colors.orange,
            width: 8,
          ),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15),
        ],
      ),
      child: InkWell(
        onTap: () => _showJobDetail(data),
        borderRadius: BorderRadius.circular(25),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "ห้อง ${data['roomNo']}",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _statusBadge(data['status']),
                    ],
                  ),
                  const Text(
                    "งานซ่อมแซม / บำรุงรักษา",
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.build_circle,
                          color: Colors.orange,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "ช่างผู้รับผิดชอบงานประจำทีม:",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange,
                                ),
                              ),
                              Text(
                                data['assignedPerson'] ?? "รอมอบหมาย",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!isFinished) _buildActionButtons(repairId, data, true),
          ],
        ),
      ),
    );
  }

  Widget _buildCleaningTaskCard(
    String id,
    Map<String, dynamic> data,
    bool isFinished,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border(
          left: BorderSide(
            color: isFinished ? Colors.green : const Color(0xFF0EA5E9),
            width: 8,
          ),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15),
        ],
      ),
      child: InkWell(
        onTap: () => _showJobDetail(data),
        borderRadius: BorderRadius.circular(25),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "ห้อง ${data['roomNo']}",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _statusBadge(data['status']),
                    ],
                  ),
                  const Text(
                    "งานทำความสะอาดประจำวัน",
                    style: TextStyle(
                      color: Color(0xFF0EA5E9),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildInteractiveChecklist(id, data, isFinished),
                ],
              ),
            ),
            if (!isFinished) _buildActionButtons(id, data, false),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: const [
            Icon(Icons.business_outlined, color: Color(0xFF1DB954)),
            SizedBox(width: 8),
            Text(
              "Roomy",
              style: TextStyle(
                color: Color(0xFF101828),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_accounts, color: Colors.grey),
            onPressed: _showAccountSettingsModal,
          ),
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) Navigator.pushReplacementNamed(context, '/');
            },
            icon: const Icon(Icons.logout, color: Colors.grey),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('repairs').snapshots(),
        builder: (context, taskSnap) {
          if (!taskSnap.hasData)
            return const Center(child: CircularProgressIndicator());

          Set<String> activeCleaningRooms = taskSnap.data!.docs
              .where((d) {
                var data = d.data() as Map<String, dynamic>;
                return data['status'] != 'เสร็จสิ้น' &&
                    (data['type'] == 'ทำความสะอาด' ||
                        data['title'] == 'ทำความสะอาด');
              })
              .map(
                (d) =>
                    (d.data() as Map<String, dynamic>)['roomNo']?.toString() ??
                    "",
              )
              .toSet();

          var tasks = taskSnap.data!.docs.where((d) {
            var data = d.data() as Map<String, dynamic>;
            String assigned = data['assignedPerson'] ?? "";
            String type = data['assignmentType'] ?? "";
            bool rel = (assigned == _maidName || type == 'tech');
            return _activeTab == 0
                ? (rel && data['status'] != 'เสร็จสิ้น')
                : (rel && data['status'] == 'เสร็จสิ้น');
          }).toList();

          return Column(
            children: [
              _buildHeaderCard(tasks.length),
              if (_activeTab == 0)
                _buildAvailableCleaningJobs(activeCleaningRooms),
              Expanded(
                child: tasks.isEmpty
                    ? const Center(child: Text("ไม่มีข้อมูลงานในหน้านี้"))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: tasks.length,
                        itemBuilder: (context, i) {
                          var data = tasks[i].data() as Map<String, dynamic>;
                          bool isRepair =
                              data['type'] == "งานซ่อม" ||
                              data['title'] == "งานซ่อม";
                          return isRepair
                              ? _buildRepairTaskCard(
                                  tasks[i].id,
                                  data,
                                  _activeTab == 1,
                                )
                              : _buildCleaningTaskCard(
                                  tasks[i].id,
                                  data,
                                  _activeTab == 1,
                                );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _activeTab == 0
          ? FloatingActionButton(
              onPressed: _showCreateTaskModal,
              backgroundColor: const Color(0xFF101828),
              child: const Icon(Icons.add_task, color: Colors.white),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _activeTab,
        selectedItemColor: const Color(0xFF1DB954),
        onTap: (i) => setState(() => _activeTab = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            label: "ตารางงาน",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            label: "ประวัติงาน",
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableCleaningJobs(Set<String> takenRooms) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .where('status', isEqualTo: 'ทำความสะอาด')
          .snapshots(),
      builder: (context, roomSnap) {
        if (!roomSnap.hasData) return const SizedBox.shrink();
        var availableRooms = roomSnap.data!.docs.where((doc) {
          String roomNo = (doc.data() as Map<String, dynamic>)['roomNo'] ?? "";
          return !takenRooms.contains(roomNo);
        }).toList();

        if (availableRooms.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                "🧹 งานทำความสะอาดที่เปิดรับ",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF101828),
                ),
              ),
            ),
            SizedBox(
              height: 95,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: availableRooms.length,
                itemBuilder: (context, index) {
                  var roomData =
                      availableRooms[index].data() as Map<String, dynamic>;
                  String roomNo = roomData['roomNo'] ?? "N/A";
                  return Container(
                    width: 250,
                    margin: const EdgeInsets.only(right: 12, bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: const Color(0xFF0EA5E9).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "ห้อง $roomNo",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0284C7),
                                ),
                              ),
                              const Text(
                                "รอมอบหมายด่วน",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _acceptCleaningJob(roomNo),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0EA5E9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            "รับงาน",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _acceptCleaningJob(String roomNo) async {
    await FirebaseFirestore.instance.collection('repairs').add({
      'roomNo': roomNo,
      'title': 'ทำความสะอาด',
      'type': 'ทำความสะอาด',
      'description': 'Big Cleaning ห้องพัก',
      'status': 'รอดำเนินการ',
      'assignedPerson': _maidName,
      'assignmentType': 'maid',
      'createdAt': FieldValue.serverTimestamp(),
      'checklist': {
        'กวาดพื้น': false,
        'ถูพื้น': false,
        'ล้างห้องน้ำ': false,
        'เช็ดกระจก': false,
      },
      'beforePhotos': [],
      'afterPhotos': [],
      'billPhotos': [],
    });
  }

  Widget _buildInteractiveChecklist(
    String id,
    Map<String, dynamic> d,
    bool fin,
  ) {
    Map<String, dynamic> check = Map<String, dynamic>.from(
      d['checklist'] ??
          {
            'กวาดพื้น': false,
            'ถูพื้น': false,
            'ล้างห้องน้ำ': false,
            'เช็ดกระจก': false,
          },
    );

    List<String> deterministicKeys = check.keys.toList()..sort();

    return IgnorePointer(
      ignoring: fin,
      child: Column(
        children: deterministicKeys
            .map(
              (k) => CheckboxListTile(
                title: Text(k, style: const TextStyle(fontSize: 14)),
                value: check[k] ?? false,
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF1DB954),
                onChanged: (v) {
                  setState(() {
                    check[k] = v ?? false;
                  });
                  FirebaseFirestore.instance
                      .collection('repairs')
                      .doc(id)
                      .update({'checklist': check});
                },
              ),
            )
            .toList(),
      ),
    );
  }

  void _showCreateTaskModal() {
    String? sRoom;
    String sType = "ทำความสะอาด";
    final descC = TextEditingController();
    final costC = TextEditingController();

    String? curTechName;
    String? curTechPhone;
    String? curTechLineId;

    List<String> beforePhotosDuringCreate = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 25,
            right: 25,
            top: 25,
          ),
          child: SingleChildScrollView(
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
                  "สร้างรายการงานใหม่",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 20),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('rooms')
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const LinearProgressIndicator();
                    return DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: sRoom,
                      decoration: InputDecoration(
                        labelText: "เลือกห้องพักอาศัย *",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      items: snap.data!.docs.map((d) {
                        String rNo = d['roomNo'].toString();
                        return DropdownMenuItem(
                          value: rNo,
                          child: Text("ห้อง $rNo"),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setModalState(() {
                          sRoom = v;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text("ทำความสะอาด"),
                      selected: sType == "ทำความสะอาด",
                      onSelected: (s) =>
                          setModalState(() => sType = "ทำความสะอาด"),
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text("งานซ่อม"),
                      selected: sType == "งานซ่อม",
                      onSelected: (s) => setModalState(() => sType = "งานซ่อม"),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                if (sType == "งานซ่อม") ...[
                  _buildUploadRowTitle("🔧 เลือกมอบหมายช่างผู้รับผิดชอบระบบ"),
                  InkWell(
                    onTap: () => _showTechPicker((name, phone, lineId) {
                      setModalState(() {
                        curTechName = name;
                        curTechPhone = phone;
                        curTechLineId = lineId;
                      });
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.engineering_outlined,
                            color: Colors.blueGrey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              curTechName ??
                                  "กดเลือกช่าง (เพิ่มช่างใหม่ / ดึงช่างเดิม)",
                              style: TextStyle(
                                color: curTechName != null
                                    ? Colors.black
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  SExpandingButton(
                    label: "เปิดคลัง Google Drive ระบบส่วนกลาง",
                    color: Colors.blueGrey,
                    onPressed: _launchCentralGoogleDrive,
                  ),
                  const SizedBox(height: 15),
                  _buildUploadRowTitle(
                    "📸 แนบลิงก์รูปภาพจุดเสียหายความปลอดภัยระบบ (เพิ่มได้หลายรูป)",
                  ),
                  _buildPhotoInputRow(beforePhotosDuringCreate, setModalState),
                  const SizedBox(height: 15),
                ],

                _buildUploadRowTitle("📝 รายละเอียดประกอบเพิ่มเติม"),
                TextField(
                  controller: descC,
                  decoration: const InputDecoration(
                    labelText: "รายละเอียดข้อมูล",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (sRoom == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "กรุณาเลือกหมายเลขห้องพักอาศัยก่อนบันทึก",
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      String finalAssignedPerson = sType == "ทำความสะอาด"
                          ? _maidName
                          : (curTechName ?? _maidName);
                      String finalAssignmentType = sType == "ทำความสะอาด"
                          ? 'maid'
                          : (curTechName != null ? 'tech' : 'maid');

                      await FirebaseFirestore.instance
                          .collection('repairs')
                          .add({
                            'roomNo': sRoom,
                            'title': sType,
                            'type': sType,
                            'description': descC.text.trim(),
                            'status': 'รอดำเนินการ',
                            'assignedPerson': finalAssignedPerson,
                            'assignmentType': finalAssignmentType,
                            'createdAt': FieldValue.serverTimestamp(),
                            'cost': double.tryParse(costC.text.trim()) ?? 0.0,
                            'checklist': sType == "ทำความสะอาด"
                                ? {
                                    'กวาดพื้น': false,
                                    'ถูพื้น': false,
                                    'ล้างห้องน้ำ': false,
                                    'เช็ดกระจก': false,
                                  }
                                : null,
                            'beforePhotos': beforePhotosDuringCreate,
                            'afterPhotos': [],
                            'billPhotos': [],
                            'techPhone': curTechPhone,
                            'techLineId': curTechLineId,
                          });

                      if (ctx.mounted) Navigator.pop(ctx);
                      setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF101828),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      "สร้างงานทันที",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTechPicker(WidgetTechSelectedCallback onSelected) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 15),
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
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                "เลือกช่างผู้รับผิดชอบงานประจำทีม",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.person_add_alt_1, color: Color(0xFF1DB954)),
              ),
              title: const Text(
                "เพิ่มข้อมูลช่างคนใหม่เข้าฐานข้อมูล",
                style: TextStyle(
                  color: Color(0xFF1DB954),
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showAddNewTechForm(onSelected);
              },
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('technicians')
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData)
                    return const Center(child: CircularProgressIndicator());
                  var docs = snap.data!.docs;
                  if (docs.isEmpty)
                    return const Center(
                      child: Text("ยังไม่มีรายชื่อช่างบันทึกในระบบ"),
                    );
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      var tech = docs[i].data() as Map<String, dynamic>;
                      String name = tech['name'] ?? "ไม่ระบุชื่อ";
                      String phone = tech['phone'] ?? "-";
                      String lineId = tech['lineId'] ?? "-";
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.engineering),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text("📞 โทร: $phone | 💬 Line: $lineId"),
                        onTap: () {
                          onSelected(name, phone, lineId);
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddNewTechForm(WidgetTechSelectedCallback onSelected) {
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    final lineC = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("กรอกข้อมูลทะเบียนช่างใหม่"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              decoration: const InputDecoration(
                labelText: "ชื่อ-นามสกุลช่าง *",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneC,
              decoration: const InputDecoration(
                labelText: "เบอร์โทรศัพท์ติดต่อ *",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lineC,
              decoration: const InputDecoration(
                labelText: "ไอดีไลน์ (Line ID) *",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ยกเลิก"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameC.text.trim().isEmpty ||
                  phoneC.text.trim().isEmpty ||
                  lineC.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("กรุณากรอกข้อมูลช่างให้ครบทุกช่อง"),
                  ),
                );
                return;
              }
              await FirebaseFirestore.instance.collection('technicians').add({
                'name': nameC.text.trim(),
                'phone': phoneC.text.trim(),
                'lineId': lineC.text.trim(),
              });
              onSelected(
                nameC.text.trim(),
                phoneC.text.trim(),
                lineC.text.trim(),
              );
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF101828),
            ),
            child: const Text(
              "บันทึกข้อมูล",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Text(
          l,
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          v,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    ),
  );

  Widget _statusBadge(String? s) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: s == "เสร็จสิ้น"
          ? const Color(0xFFECFDF5)
          : const Color(0xFFFEF3C7),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      s ?? "รอดำเนินการ",
      style: TextStyle(
        color: s == "เสร็จสิ้น"
            ? const Color(0xFF10B981)
            : const Color(0xFFD97706),
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _buildHeaderCard(int c) => Container(
    width: double.infinity,
    margin: const EdgeInsets.all(20),
    padding: const EdgeInsets.all(25),
    decoration: BoxDecoration(
      color: const Color(0xFF101828),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.calendar_today, color: Colors.orange, size: 14),
                SizedBox(width: 5),
                Text(
                  "งานประจำของวันนี้",
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _activeTab == 0
                  ? "$c งานที่ต้องจัดการสุทธิ"
                  : "$c งานที่เสร็จสิ้นแล้ว",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const Icon(
          Icons.assignment_turned_in_outlined,
          color: Colors.white,
          size: 40,
        ),
      ],
    ),
  );

  Widget _buildActionButtons(
    String id,
    Map<String, dynamic> data,
    bool isRepair,
  ) {
    bool isOng = data['status'] == "กำลังดำเนินการ";
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () =>
                  _handleStatusUpdate(id, data['status'], isRepair, 0, data),
              style: ElevatedButton.styleFrom(
                backgroundColor: isOng ? Colors.green : const Color(0xFF101828),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: Text(
                isOng ? "บันทึกรายงานปิดงาน" : "เริ่มงาน",
                style: const TextStyle(
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

typedef WidgetTechSelectedCallback =
    Function(String name, String phone, String lineId);

class SExpandingButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  const SExpandingButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/owner_bottom_nav.dart';
import '../../widgets/owner_app_bar.dart';

class OwnerBuildingMgmt extends StatefulWidget {
  const OwnerBuildingMgmt({super.key});

  @override
  State<OwnerBuildingMgmt> createState() => _OwnerBuildingMgmtState();
}

class _OwnerBuildingMgmtState extends State<OwnerBuildingMgmt> {
  String? _selectedBuilding;
  String?
  _selectedTenantUid; // ตัวแปรเก็บ UID ของผู้เช่าที่เลือก เพื่อให้ถูกหลักความถูกต้องของฐานข้อมูล

  // 🌟 [เพิ่มใหม่]: ตัวแปรควบคุมระบบค้นหาห้องพักและชื่อบุคลากร
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // คอนโทรลเลอร์สำหรับจัดการข้อมูลพื้นฐานห้องพัก
  final TextEditingController _roomNoController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _lineController = TextEditingController();
  final TextEditingController _fbController = TextEditingController();
  final TextEditingController _tenantNameController = TextEditingController();
  final TextEditingController _tenantPhoneController = TextEditingController();
  final TextEditingController _photoUrlController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();

  // คอนโทรลเลอร์สำหรับดักข้อมูลสถานะชื่อผู้จองห้องพัก
  final TextEditingController _bookingNameController = TextEditingController();

  // คอนโทรลเลอร์สำหรับจัดการรายละเอียดบิลการเงินของห้องพัก
  final TextEditingController _waterBillController = TextEditingController();
  final TextEditingController _electricBillController = TextEditingController();
  final TextEditingController _internetBillController = TextEditingController();
  final TextEditingController _parkingBillController = TextEditingController();
  final TextEditingController _otherBillController = TextEditingController();
  final TextEditingController _otherBillLabelController =
      TextEditingController();

  // คอนโทรลเลอร์ตั้งค่าอัตราค่าที่จอดรถของระบบหอพักส่วนกลาง
  final TextEditingController _carBaseController = TextEditingController();
  final TextEditingController _carAddController = TextEditingController();
  final TextEditingController _motoBaseController = TextEditingController();
  final TextEditingController _motoAddController = TextEditingController();

  // คอนโทรลเลอร์สำหรับรับลิงก์รูปภาพสภาพห้องตรวจสอบ ก่อนอาศัย-หลังย้ายออก
  final TextEditingController _photoBeforeController = TextEditingController();
  final TextEditingController _photoAfterController = TextEditingController();

  // คอนโทรลเลอร์สำหรับรับค่าสร้างพื้นที่ส่วนกลางระบบหอพัก
  final TextEditingController _facilityNameController = TextEditingController();
  final TextEditingController _facilityEmojiController =
      TextEditingController();

  List<String> _currentTags = [];
  List<String> _currentPhotos = [];

  List<String> _photosBeforeMoveIn = [];
  List<String> _photosAfterMoveOut = [];

  @override
  void dispose() {
    _searchController.dispose(); // 🌟 คืนหน่วยความจำตัวค้นหา
    _roomNoController.dispose();
    _titleController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _phoneController.dispose();
    _lineController.dispose();
    _fbController.dispose();
    _tenantNameController.dispose();
    _tenantPhoneController.dispose();
    _bookingNameController.dispose();
    _photoUrlController.dispose();
    _tagController.dispose();

    _waterBillController.dispose();
    _electricBillController.dispose();
    _internetBillController.dispose();
    _parkingBillController.dispose();
    _otherBillController.dispose();
    _otherBillLabelController.dispose();

    _carBaseController.dispose();
    _carAddController.dispose();
    _motoBaseController.dispose();
    _motoAddController.dispose();

    _photoBeforeController.dispose();
    _photoAfterController.dispose();

    _facilityNameController.dispose();
    _facilityEmojiController.dispose();
    super.dispose();
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

  Future<void> _launchCentralGoogleDrive() async {
    try {
      var configDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('config')
          .get();
      if (configDoc.exists && configDoc.data()?['driveUrl'] != null) {
        final Uri url = Uri.parse(
          configDoc.data()!['driveUrl'].toString().trim(),
        );
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          throw "Could not launch $url";
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "กรุณาตั้งค่าลิงก์คลังไดรฟ์ส่วนกลางที่เฟืองแอปบาร์ก่อนใช้งาน",
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("เกิดข้อผิดพลาดในการเปิดไดรฟ์: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
    }
  }

  void _showTenantSelectionDialog(VoidCallback onSelected) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("เลือกผู้เช่าจากระบบ"),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'tenant')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              var tenants = snapshot.data!.docs;
              if (tenants.isEmpty) return const Text("ไม่พบรายชื่อผู้เช่า");
              return ListView.builder(
                shrinkWrap: true,
                itemCount: tenants.length,
                itemBuilder: (context, index) {
                  var data = tenants[index].data() as Map<String, dynamic>;
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(data['name'] ?? "ไม่ระบุชื่อ"),
                    subtitle: Text(data['email'] ?? ""),
                    onTap: () {
                      _tenantNameController.text = data['name'] ?? "";
                      _tenantPhoneController.text = data['phone'] ?? "";
                      _selectedTenantUid =
                          tenants[index].id; // เก็บค่า UID ที่ถูกต้องของผู้เช่า
                      onSelected();
                      Navigator.pop(context);
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _addBuilding() {
    TextEditingController bController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 25,
          left: 25,
          right: 25,
          top: 25,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
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
              "เพิ่มตึกใหม่",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF101828),
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              "กรอกชื่อหรือรหัสอาคารเพื่อเปิดกลุ่มบริการห้องชุดพักอาศัยชุดใหม่",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 25),
            TextField(
              controller: bController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: "ชื่อตึก / ชื่ออาคาร (เช่น ตึก A, อาคารมาลี)",
                prefixIcon: const Icon(
                  Icons.business_outlined,
                  color: Color(0xFF1DB954),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      "ยกเลิก",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (bController.text.trim().isNotEmpty) {
                        await FirebaseFirestore.instance
                            .collection('buildings')
                            .doc(bController.text.trim())
                            .set({'createdAt': FieldValue.serverTimestamp()});
                        setState(
                          () => _selectedBuilding = bController.text.trim(),
                        );
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF101828),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      "บันทึกข้อมูลตึก",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _deleteBuilding(String name) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ยืนยันการลบตึก"),
        content: Text("คุณแน่ใจหรือไม่ที่จะลบ $name? "),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("ยกเลิก"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "ยืนยันลบตึก",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('buildings')
          .doc(name)
          .delete();
      setState(() => _selectedBuilding = null);
    }
  }

  void _addRoom() {
    if (_selectedBuilding == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("กรุณาเลือกตึกก่อนสร้างห้องพัก"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    _roomNoController.clear();
    _priceController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 25,
          left: 25,
          right: 25,
          top: 25,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
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
            Text(
              "เพิ่มห้องพักใน ตึก $_selectedBuilding",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF101828),
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              "ระบุรหัสประจำเลขห้องพักและราคาเช่ารายเดือนพื้นฐานระบบหลัก",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 25),
            TextField(
              controller: _roomNoController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: "หมายเลขห้องพัก (เช่น A101, 204)",
                prefixIcon: const Icon(
                  Icons.door_front_door_outlined,
                  color: Color(0xFF1DB954),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "ราคาค่าเช่ารายเดือน (บาท)",
                prefixIcon: const Icon(
                  Icons.payments_outlined,
                  color: Color(0xFF1DB954),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      "ยกเลิก",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_roomNoController.text.trim().isNotEmpty &&
                          _priceController.text.trim().isNotEmpty) {
                        await FirebaseFirestore.instance
                            .collection('rooms')
                            .add({
                              'roomNo': _roomNoController.text.trim(),
                              'buildingName': _selectedBuilding,
                              'price':
                                  double.tryParse(
                                    _priceController.text.trim(),
                                  ) ??
                                  0.0,
                              'status': 'ว่าง',
                              'tags': [],
                              'internalPhotos': [],
                              'waterBill': 0.0,
                              'electricBill': 0.0,
                              'internetBill': 0.0,
                              'parkingBill': 0.0,
                              'otherBill': 0.0,
                              'otherBillLabel': '',
                              'photosBefore': [],
                              'photosAfter': [],
                            });
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      "เพิ่มห้องพักใหม่",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFacilityManagementModal() {
    _facilityNameController.clear();
    _facilityEmojiController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
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
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "จัดการพื้นที่ส่วนกลาง",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF101828),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text(
                "เพิ่มหรือลบสิ่งอำนวยความสะดวกเพื่อให้ผู้เช่ากดจองใช้งานผ่านแอป",
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const Divider(height: 25),
              Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: _facilityEmojiController,
                      decoration: const InputDecoration(
                        labelText: "อิโมจิ",
                        hintText: "🏊",
                        border: OutlineInputBorder(),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _facilityNameController,
                      decoration: const InputDecoration(
                        labelText: "ชื่อเรียกพื้นที่ส่วนกลาง",
                        hintText: "เช่น สระว่ายน้ำ, ห้องโยคะ",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () async {
                      if (_facilityNameController.text.trim().isNotEmpty) {
                        String emoji =
                            _facilityEmojiController.text.trim().isEmpty
                            ? "🏢"
                            : _facilityEmojiController.text.trim();
                        await FirebaseFirestore.instance
                            .collection('facilities')
                            .add({
                              'name': _facilityNameController.text.trim(),
                              'emoji': emoji,
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                        _facilityNameController.clear();
                        _facilityEmojiController.clear();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                "รายการส่วนกลางที่เปิดให้บริการปัจจุบัน :",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('facilities')
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData)
                      return const Center(child: CircularProgressIndicator());
                    var docs = snap.data!.docs;
                    if (docs.isEmpty)
                      return const Center(
                        child: Text(
                          "ยังไม่มีสิ่งอำนวยความสะดวกในคลังหอพัก",
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      );
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var fData = docs[index].data() as Map<String, dynamic>;
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          child: ListTile(
                            leading: Text(
                              fData['emoji'] ?? "🏢",
                              style: const TextStyle(fontSize: 22),
                            ),
                            title: Text(
                              fData['name'] ?? "ส่วนกลาง",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () async {
                                await docs[index].reference.delete();
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveAllData(String docId, String currentDbStatus) async {
    String finalStatus = currentDbStatus;

    if (_tenantNameController.text.trim().isNotEmpty) {
      finalStatus = "มีผู้เช่า";
    } else if (_bookingNameController.text.trim().isNotEmpty) {
      finalStatus = "จองแล้ว";
    } else {
      if (currentDbStatus == "มีผู้เช่า") {
        finalStatus = "ทำความสะอาด";
      } else {
        finalStatus = "ว่าง";
      }
    }

    Map<String, dynamic> updateData = {
      'roomNo': _roomNoController.text.trim(),
      'title': _titleController.text.trim(),
      'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
      'status': finalStatus,
      'description': _descController.text.trim(),
      'phone': _phoneController.text.trim(),
      'lineId': _lineController.text.trim(),
      'facebook': _fbController.text.trim(),
      'tags': _currentTags,
      'internalPhotos': _currentPhotos,
      'waterBill': double.tryParse(_waterBillController.text.trim()) ?? 0.0,
      'electricBill':
          double.tryParse(_electricBillController.text.trim()) ?? 0.0,
      'internetBill':
          double.tryParse(_internetBillController.text.trim()) ?? 0.0,
      'parkingBill': double.tryParse(_parkingBillController.text.trim()) ?? 0.0,
      'otherBill': double.tryParse(_otherBillController.text.trim()) ?? 0.0,
      'otherBillLabel': _otherBillLabelController.text.trim(),
      'photosBefore': _photosBeforeMoveIn,
      'photosAfter': _photosAfterMoveOut,
    };

    if (_bookingNameController.text.trim().isEmpty ||
        _tenantNameController.text.trim().isNotEmpty) {
      updateData['bookingName'] = FieldValue.delete();
      updateData['reservedBy'] = FieldValue.delete();
      updateData['bookedAt'] = FieldValue.delete();
      updateData['bookingExpiresAt'] = FieldValue.delete();

      try {
        var bookingDocs = await FirebaseFirestore.instance
            .collection('bookings')
            .where('roomNo', isEqualTo: _roomNoController.text.trim())
            .get();
        for (var doc in bookingDocs.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint("ลบข้อมูลในคอลเลกชัน bookings ผิดพลาด: $e");
      }
    } else {
      updateData['bookingName'] = _bookingNameController.text.trim();
      updateData['reservedBy'] = _bookingNameController.text.trim();
    }

    if (_tenantNameController.text.trim().isEmpty) {
      updateData['tenantName'] = "";
      updateData['tenantPhone'] = "";
      updateData['tenantUid'] = FieldValue.delete();
    } else {
      updateData['tenantName'] = _tenantNameController.text.trim();
      updateData['tenantPhone'] = _tenantPhoneController.text.trim();
      if (_selectedTenantUid != null) {
        updateData['tenantUid'] = _selectedTenantUid;
      }
    }

    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(docId)
        .update(updateData);

    await FirebaseFirestore.instance.collection('settings').doc('config').set({
      'carBaseRate': double.tryParse(_carBaseController.text.trim()) ?? 300.0,
      'carAddRate': double.tryParse(_carAddController.text.trim()) ?? 20.0,
      'motoBaseRate': double.tryParse(_motoBaseController.text.trim()) ?? 100.0,
      'motoAddRate': double.tryParse(_motoAddController.text.trim()) ?? 10.0,
    }, SetOptions(merge: true));

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: buildOwnerAppBar(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildStatusLegend(),

          // 🌟 [เพิ่มใหม่]: แถบค้นหารองรับการค้นหาเลขห้อง ชื่อผู้เช่า หรือชื่อผู้จอง
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: const InputDecoration(
                  icon: Icon(Icons.search, color: Color(0xFF1DB954)),
                  hintText: "ค้นหาหมายเลขห้อง, ชื่อผู้เช่า หรือผู้จอง...",
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 5),
          Expanded(child: _buildRoomGrid()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRoom,
        backgroundColor: const Color(0xFF101828),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: buildOwnerBottomNav(context, 1),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 25, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "อาคารและห้องพัก",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF101828),
                    ),
                  ),
                  Text(
                    "จัดการตึกและตรวจสอบข้อมูลสภาพห้องหอพัก",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showFacilityManagementModal,
                icon: const Icon(Icons.pool, size: 16, color: Colors.white),
                label: const Text(
                  "จัดการส่วนกลาง",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF101828),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade300, width: 1.5),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: _buildBuildingDropdown(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 54,
                height: 54,
                child: ElevatedButton(
                  onPressed: _addBuilding,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954),
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Icon(
                    Icons.add_business,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              if (_selectedBuilding != null) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 54,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: () => _deleteBuilding(_selectedBuilding!),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      padding: EdgeInsets.zero,
                      backgroundColor: const Color(0xFFFEF2F2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Icon(
                      Icons.delete_forever_outlined,
                      color: Colors.red,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('buildings').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        var buildings = snapshot.data!.docs;
        if (_selectedBuilding != null &&
            !buildings.any((doc) => doc.id == _selectedBuilding))
          _selectedBuilding = null;
        return DropdownButton<String>(
          value: _selectedBuilding,
          hint: const Text(
            "🔍 กดเลือกอาคาร / ตึกหอพักชุดพักอาศัย",
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.blueGrey,
          ),
          items: buildings
              .map(
                (doc) => DropdownMenuItem(
                  value: doc.id,
                  // 🛠️ [แก้ไข]: ลบพารามิเตอร์ BertramTextStyle แปลงกลับเป็นค่า TextStyle ดั้งเดิมให้คอมไพล์ผ่านสมบูรณ์
                  child: Text(
                    "🏢 ${doc.id}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF101828),
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedBuilding = v),
        );
      },
    );
  }

  void _showRoomManagementModal(
    BuildContext context,
    Map<String, dynamic> room,
    String docId,
  ) {
    _roomNoController.text = room['roomNo'] ?? "";
    _titleController.text = room['title'] ?? "";
    _priceController.text = room['price']?.toString() ?? "";
    _descController.text = room['description'] ?? "";
    _phoneController.text = room['phone'] ?? "";
    _lineController.text = room['lineId'] ?? "";
    _fbController.text = room['facebook'] ?? "";
    _tenantNameController.text = room['tenantName'] ?? "";
    _tenantPhoneController.text = room['tenantPhone'] ?? "";

    _selectedTenantUid = room['tenantUid'];
    _bookingNameController.text =
        room['bookingName'] ?? room['reservedBy'] ?? "";

    _photoUrlController.clear();
    _photoBeforeController.clear();
    _photoAfterController.clear();

    _waterBillController.text = room['waterBill']?.toString() ?? "0";
    _electricBillController.text = room['electricBill']?.toString() ?? "0";
    _internetBillController.text = room['internetBill']?.toString() ?? "0";
    _parkingBillController.text = room['parkingBill']?.toString() ?? "0";
    _otherBillController.text = room['otherBill']?.toString() ?? "0";
    _otherBillLabelController.text = room['otherBillLabel'] ?? "";

    _currentTags = List<String>.from(room['tags'] ?? []);
    _currentPhotos = List<String>.from(
      room['internalPhotos'] ?? [],
    ).where((url) => url.startsWith('http')).toList();
    _photosBeforeMoveIn = List<String>.from(
      room['photosBefore'] ?? [],
    ).where((url) => url.startsWith('http')).toList();
    _photosAfterMoveOut = List<String>.from(
      room['photosAfter'] ?? [],
    ).where((url) => url.startsWith('http')).toList();

    int tenantCarCount = 0;
    int tenantMotoCount = 0;
    bool isVehicleLoaded = false;
    String currentDbStatus = room['status'] ?? "ว่าง";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => FutureBuilder<List<dynamic>>(
            future: isVehicleLoaded
                ? Future.value([null, null])
                : Future.wait([
                    FirebaseFirestore.instance
                        .collection('settings')
                        .doc('config')
                        .get(),
                    FirebaseFirestore.instance
                        .collection('users')
                        .where(
                          'name',
                          isEqualTo: _tenantNameController.text.trim(),
                        )
                        .where('role', isEqualTo: 'tenant')
                        .limit(1)
                        .get(),
                  ]),
            builder: (context, asyncSnap) {
              if (asyncSnap.hasData &&
                  !isVehicleLoaded &&
                  asyncSnap.data![0] != null) {
                var configDoc = asyncSnap.data![0] as DocumentSnapshot;
                var tenantQuery = asyncSnap.data![1] as QuerySnapshot;

                if (configDoc.exists) {
                  var cData = configDoc.data() as Map<String, dynamic>;
                  _carBaseController.text = (cData['carBaseRate'] ?? 300.0)
                      .toStringAsFixed(0);
                  _carAddController.text = (cData['carAddRate'] ?? 20.0)
                      .toStringAsFixed(0);
                  _motoBaseController.text = (cData['motoBaseRate'] ?? 100.0)
                      .toStringAsFixed(0);
                  _motoAddController.text = (cData['motoAddRate'] ?? 10.0)
                      .toStringAsFixed(0);
                } else {
                  _carBaseController.text = "300";
                  _carAddController.text = "20";
                  _motoBaseController.text = "100";
                  _motoAddController.text = "10";
                }

                if (tenantQuery.docs.isNotEmpty) {
                  var tData =
                      tenantQuery.docs.first.data() as Map<String, dynamic>;
                  var parkingReq =
                      tData['parkingRequest'] as Map<String, dynamic>? ?? {};
                  tenantCarCount = (parkingReq['carCount'] ?? 0).toInt();
                  tenantMotoCount = (parkingReq['motorcycleCount'] ?? 0)
                      .toInt();
                }
                isVehicleLoaded = true;
              }

              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "ห้อง ${room['roomNo']}",
                          style: const TextStyle(
                            fontSize: 26,
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
                      "ข้อมูลห้องพักหลัก",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.blueGrey,
                      ),
                    ),
                    _editField("หมายเลขห้อง", _roomNoController),
                    _editField("ชื่อห้อง", _titleController),
                    _editField(
                      "ราคาค่าเช่าห้องหลัก (บาท)",
                      _priceController,
                      isNumber: true,
                    ),
                    _editField("รายละเอียดห้องพัก", _descController),
                    const Divider(height: 40),
                    const Text(
                      "รายละเอียดการเงินประจำเดือน (บิลเรียกเก็บ)",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF101828),
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "ยอดบิลส่วนนี้จะไปคำนวณและปิดล็อกฟอร์มให้ผู้เช่าสแกนจ่ายทันที",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    _editField(
                      "ค่าน้ำประปารวม (บาท)",
                      _waterBillController,
                      isNumber: true,
                    ),
                    _editField(
                      "ค่าไฟฟ้าประจำเดือน (บาท)",
                      _electricBillController,
                      isNumber: true,
                    ),
                    _editField(
                      "ค่าบริการอินเทอร์เน็ต (บาท)",
                      _internetBillController,
                      isNumber: true,
                    ),
                    const SizedBox(height: 15),
                    _editField(
                      "ค่าเช่าบริการที่จอดรถ (บาท)",
                      _parkingBillController,
                      isNumber: true,
                    ),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.directions_car_filled_outlined,
                                color: Colors.indigo,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "ข้อมูลรถผู้เช่าปัจจุบัน: รถยนต์ $tenantCarCount คัน | มอเตอร์ไซค์ $tenantMotoCount คัน",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.indigo,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          const Text(
                            "⚙️ ปรับเปลี่ยนนโยบายอัตราค่าที่จอดรถของหอพัก:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.blueGrey,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _editField(
                                  "รถยนต์คันแรก (บาท)",
                                  _carBaseController,
                                  isNumber: true,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _editField(
                                  "คันถัดไปบวกเพิ่ม (บาท)",
                                  _carAddController,
                                  isNumber: true,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _editField(
                                  "มอเตอร์ไซค์คันแรก (บาท)",
                                  _motoBaseController,
                                  isNumber: true,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _editField(
                                  "คันถัดไปบวกเพิ่ม (บาท)",
                                  _motoAddController,
                                  isNumber: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SExpandingButton(
                            label: "คำนวณค่าที่จอดรถอัตโนมัติ ⚡",
                            color: Colors.indigo,
                            onPressed: () {
                              double carBase =
                                  double.tryParse(_carBaseController.text) ??
                                  300.0;
                              double carAdd =
                                  double.tryParse(_carAddController.text) ??
                                  20.0;
                              double motoBase =
                                  double.tryParse(_motoBaseController.text) ??
                                  100.0;
                              double motoAdd =
                                  double.tryParse(_motoAddController.text) ??
                                  10.0;
                              double calculatedParkingFee = 0.0;
                              if (tenantCarCount > 0)
                                calculatedParkingFee +=
                                    carBase + ((tenantCarCount - 1) * carAdd);
                              if (tenantMotoCount > 0)
                                calculatedParkingFee +=
                                    motoBase +
                                    ((tenantMotoCount - 1) * motoAdd);
                              setModalState(() {
                                _parkingBillController.text =
                                    calculatedParkingFee.toStringAsFixed(0);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    _editField(
                      "ระบุชื่อค่าใช้จ่ายเพิ่มเติม (เช่น ค่าปรับ, ค่ากุญแจ)",
                      _otherBillLabelController,
                    ),
                    _editField(
                      "จำนวนเงินเพิ่มเติมตามชื่อระบุข้างต้น (บาท)",
                      _otherBillController,
                      isNumber: true,
                    ),

                    const Divider(height: 40),
                    const Text(
                      "จัดการข้อมูลการจองห้องพัก",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF101828),
                      ),
                    ),
                    _editField(
                      "ชื่อ-นามสกุล ผู้จองห้องพักปัจจุบัน",
                      _bookingNameController,
                    ),
                    if (_bookingNameController.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 15),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setModalState(() {
                              _bookingNameController.clear();
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "ล้างข้อมูลผู้จองสำเร็จ ระบบจะคืนสถานะห้องเป็นว่างเมื่อกดบันทึก",
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.bookmark_remove_outlined,
                            color: Colors.redAccent,
                          ),
                          label: const Text(
                            "ลบข้อมูลผู้จอง (ยกเลิกคิวจอง สลับเป็นห้องว่าง)",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                    const Divider(height: 40),
                    const Text(
                      "จัดการข้อมูลผู้เช่า",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: TextField(
                        controller: _tenantNameController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: "ชื่อผู้เช่า",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.person_search,
                              color: Colors.blue,
                            ),
                            onPressed: () => _showTenantSelectionDialog(() {
                              setModalState(() {
                                isVehicleLoaded = false;
                                _bookingNameController.clear();
                              });
                            }),
                          ),
                        ),
                      ),
                    ),
                    _editField("เบอร์โทรผู้เช่า", _tenantPhoneController),

                    if (_tenantNameController.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 5, bottom: 15),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setModalState(() {
                              _tenantNameController.clear();
                              _tenantPhoneController.clear();
                              _selectedTenantUid = null;
                              _waterBillController.text = "0";
                              _electricBillController.text = "0";
                              _internetBillController.text = "0";
                              _parkingBillController.text = "0";
                              _otherBillController.text = "0";
                              _otherBillLabelController.clear();
                              tenantCarCount = 0;
                              tenantMotoCount = 0;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "ล้างรายชื่อสำเร็จ ระบบเตรียมปรับสับสถานะไปทำความสะอาดอัตโนมัติเมื่อกดบันทึก",
                                ),
                                backgroundColor: Colors.indigo,
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.person_remove_alt_1,
                            color: Colors.redAccent,
                          ),
                          label: const Text(
                            "ล้างข้อมูลผู้เช่า (แจ้งผู้เช่าย้ายออก)",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    const Divider(height: 40),
                    const Text(
                      "รูปภาพประกอบทั่วไปภายในห้องพัก",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SExpandingButton(
                      label: "เปิดคลัง Google Drive ระบบส่วนกลาง",
                      color: Colors.blueGrey,
                      onPressed: _launchCentralGoogleDrive,
                    ),
                    const SizedBox(height: 10),
                    if (_currentPhotos.isNotEmpty) ...[
                      _buildPhotoList(_currentPhotos, setModalState),
                      const SizedBox(height: 15),
                    ],
                    _buildAddPhotoRow(
                      _photoUrlController,
                      _currentPhotos,
                      setModalState,
                    ),
                    const Divider(height: 40),
                    const Text(
                      "ตรวจสอบสภาพห้องพักความปลอดภัยระบบ",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF101828),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "📸 ด้านบน: รูปภาพสภาพห้องก่อนผู้เช่าเข้าอาศัย",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_photosBeforeMoveIn.isNotEmpty) ...[
                      _buildPhotoList(_photosBeforeMoveIn, setModalState),
                      const SizedBox(height: 10),
                    ],
                    _buildAddPhotoRow(
                      _photoBeforeController,
                      _photosBeforeMoveIn,
                      setModalState,
                    ),
                    const SizedBox(height: 25),
                    const Text(
                      "📸 ด้านล่าง: รูปภาพสภาพห้องหลังจากผู้เช่าย้ายออก",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_photosAfterMoveOut.isNotEmpty) ...[
                      _buildPhotoList(_photosAfterMoveOut, setModalState),
                      const SizedBox(height: 10),
                    ],
                    _buildAddPhotoRow(
                      _photoAfterController,
                      _photosAfterMoveOut,
                      setModalState,
                    ),
                    const Divider(height: 40),
                    const Text(
                      "แท็กสิ่งอำนวยความสะดวก",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    _buildTagsManager(setModalState),
                    const SizedBox(height: 35),
                    SExpandingButton(
                      label: "บันทึกข้อมูลทั้งหมด",
                      color: const Color(0xFF1DB954),
                      onPressed: () => _saveAllData(docId, currentDbStatus),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('rooms')
                              .doc(docId)
                              .delete();
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text(
                          "ลบห้องพักนี้ออกจากระบบ",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // 🌟 [ปรับปรุงระบบ Grid]: รองรับฟังก์ชันค้นหา และจัดเรียงเลขห้องจากน้อยไปมาก
  Widget _buildRoomGrid() {
    if (_selectedBuilding == null)
      return const Center(child: Text("กรุณาเลือกตึก"));
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .where('buildingName', isEqualTo: _selectedBuilding)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;

        // 1. ดำเนินการคัดกรองข้อมูลตามคำค้นหา (เลขห้อง, ชื่อผู้เช่า, ชื่อผู้จอง)
        var filteredDocs = docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String roomNo = (data['roomNo'] ?? "").toString().toLowerCase();
          String tenantName = (data['tenantName'] ?? "")
              .toString()
              .toLowerCase();
          String bookingName = (data['bookingName'] ?? data['reservedBy'] ?? "")
              .toString()
              .toLowerCase();
          String query = _searchQuery.toLowerCase();

          return roomNo.contains(query) ||
              tenantName.contains(query) ||
              bookingName.contains(query);
        }).toList();

        // 2. ดำเนินการจัดเรียงหมายเลขห้องพักจาก "น้อยไปมาก" (Ascending)
        filteredDocs.sort((a, b) {
          var dataA = a.data() as Map<String, dynamic>;
          var dataB = b.data() as Map<String, dynamic>;
          String roomA = (dataA['roomNo'] ?? "").toString();
          String roomB = (dataB['roomNo'] ?? "").toString();
          return roomA.compareTo(roomB);
        });

        if (filteredDocs.isEmpty) {
          return const Center(child: Text("ไม่พบข้อมูลห้องพักกรุณาสร้างห้อง"));
        }

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 15,
            crossAxisSpacing: 15,
            childAspectRatio: 1.1,
          ),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            var room = filteredDocs[index].data() as Map<String, dynamic>;
            return InkWell(
              onTap: () => _showRoomManagementModal(
                context,
                room,
                filteredDocs[index].id,
              ),
              child: _buildRoomBox(
                room['roomNo'] ?? "",
                room['status'] ?? "ว่าง",
                room['tenantName'] ?? "",
                room['bookingName'] ?? room['reservedBy'] ?? "",
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRoomBox(String no, String status, String tenant, String booker) {
    Color bg;
    Color txt;
    switch (status) {
      case "มีผู้เช่า":
        bg = const Color(0xFFFFF1F2);
        txt = const Color(0xFFE11D48);
        break;
      case "ทำความสะอาด":
        bg = const Color(0xFFF0F9FF);
        txt = const Color(0xFF0284C7);
        break;
      case "จองแล้ว":
        bg = const Color(0xFFFFFBEB);
        txt = const Color(0xFFD97706);
        break;
      default:
        bg = const Color(0xFFE8F5E9);
        txt = const Color(0xFF2E7D32);
    }
    String subTextDisplay = tenant.isNotEmpty
        ? tenant
        : (booker.isNotEmpty ? "ผู้จอง: $booker" : "");
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            no,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: txt,
            ),
          ),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: txt,
            ),
          ),
          if (subTextDisplay.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                subTextDisplay,
                style: TextStyle(fontSize: 11, color: txt.withOpacity(0.7)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusLegend() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 25),
    child: Wrap(
      spacing: 8,
      children: [
        _legend("ว่าง", const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
        _legend("มีผู้เช่า", const Color(0xFFFFF1F2), const Color(0xFFE11D48)),
        _legend(
          "ทำความสะอาด",
          const Color(0xFFF0F9FF),
          const Color(0xFF0284C7),
        ),
        _legend("จองแล้ว", const Color(0xFFFFFBEB), const Color(0xFFD97706)),
      ],
    ),
  );

  Widget _legend(String t, Color b, Color txt) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: b, borderRadius: BorderRadius.circular(8)),
    child: Text(
      t,
      style: TextStyle(color: txt, fontSize: 11, fontWeight: FontWeight.bold),
    ),
  );

  Widget _editField(
    String l,
    TextEditingController c, {
    bool isNumber = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 15),
    child: TextField(
      controller: c,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: l,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  Widget _buildPhotoList(List<String> photos, StateSetter setModalState) =>
      SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: photos.length,
          itemBuilder: (context, index) => Stack(
            children: [
              Container(
                width: 100,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(_convertToDirectLink(photos[index])),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                  onPressed: () => setModalState(() => photos.removeAt(index)),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildAddPhotoRow(
    TextEditingController controller,
    List<String> targetList,
    StateSetter setModalState,
  ) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: "วางลิงก์รูปภาพสภาพห้องจาก Google Drive",
              prefixIcon: const Icon(Icons.link, color: Color(0xFF1DB954)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 15,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(
            Icons.add_photo_alternate,
            color: Color(0xFF1DB954),
            size: 32,
          ),
          onPressed: () {
            if (controller.text.isNotEmpty &&
                controller.text.startsWith('http')) {
              setModalState(() {
                targetList.add(controller.text.trim());
                controller.clear();
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildTagsManager(StateSetter setModalState) => Column(
    children: [
      Wrap(
        spacing: 8,
        children: _currentTags
            .map(
              (t) => Chip(
                label: Text(t),
                onDeleted: () => setModalState(() => _currentTags.remove(t)),
              ),
            )
            .toList(),
      ),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _tagController,
              decoration: const InputDecoration(
                hintText: "เพิ่มแท็กสิ่งอำนวยความสะดวก",
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: Color(0xFF1DB954)),
            onPressed: () {
              if (_tagController.text.isNotEmpty) {
                setModalState(() {
                  _currentTags.add(_tagController.text.trim());
                  _tagController.clear();
                });
              }
            },
          ),
        ],
      ),
    ],
  );
}

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

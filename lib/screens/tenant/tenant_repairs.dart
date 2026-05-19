import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // 🌟 [เพิ่มใหม่]: สำหรับเรียกเปิดลิงก์คลังไดรฟ์ภายนอกแอป
import '../../widgets/tenant_bottom_nav.dart'; //
import '../../widgets/tenant_app_bar.dart'; //

class TenantRepairs extends StatefulWidget {
  const TenantRepairs({super.key});

  @override
  State<TenantRepairs> createState() => _TenantRepairsState();
}

class _TenantRepairsState extends State<TenantRepairs> {
  int _activeTab = 0; // 0 = แจ้งปัญหาใหม่, 1 = ประวัติแจ้งซ่อม
  String _selectedCategory = "ไฟฟ้า / หลอดไฟ"; //
  final TextEditingController _detailController = TextEditingController(); //
  final TextEditingController _photoUrlController = TextEditingController(); //
  final user = FirebaseAuth.instance.currentUser; //

  @override
  void dispose() {
    _detailController.dispose(); //
    _photoUrlController.dispose(); //
    super.dispose(); //
  }

  // 🌟 [เพิ่มใหม่]: ฟังก์ชันเปิดคลัง Google Drive ส่วนกลางดึงค่าลิงก์จากเอกสารตั้งค่าหอพัก 🌟
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
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ฟังก์ชันแสดงรายละเอียดประวัติการแจ้งซ่อม (โชว์รูปและคำบรรยาย)
  void _showRepairDetail(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)), //
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
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
                  Text(
                    data['title'] ?? "รายละเอียด", //
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold, //
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close), //
                  ),
                ],
              ),
              _buildStatusBadge(data['status'] ?? "รอดำเนินการ"), //
              const Divider(height: 30), //

              const Text(
                "รายละเอียดที่แจ้ง:", //
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey, //
                ),
              ),
              const SizedBox(height: 8), //
              Text(
                data['description'] ?? "ไม่ได้ระบุรายละเอียด", //
                style: const TextStyle(fontSize: 16), //
              ),

              const SizedBox(height: 25), //
              // --- แสดงรูปภาพประกอบจาก Drive (หากมี) ---
              if (data['photoUrl'] != null &&
                  data['photoUrl'].toString().startsWith('http')) ...[
                const Text(
                  "รูปภาพประกอบ:", //
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey, //
                  ),
                ),
                const SizedBox(height: 10), //
                ClipRRect(
                  borderRadius: BorderRadius.circular(15), //
                  child: Image.network(
                    _convertToDirectLink(data['photoUrl']), //
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                        ? child
                        : const Center(child: CircularProgressIndicator()), //
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 150,
                      width: double.infinity,
                      color: Colors.grey[100], //
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            color: Colors.grey,
                          ), //
                          Text(
                            "ไม่สามารถโหลดรูปภาพได้", //
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ), //
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25), //
              ],

              const Divider(), //
              _infoRow(
                "วันที่แจ้ง:", //
                data['createdAt'] != null
                    ? DateFormat(
                        'dd MMM yyyy HH:mm',
                        'th',
                      ).format((data['createdAt'] as Timestamp).toDate())
                    : "-", //
              ),
              _infoRow(
                "ผู้รับผิดชอบ:",
                data['assignedPerson'] ?? "รอมอบหมาย",
              ), //
              const SizedBox(height: 30), //
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8), //
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)), //
          const SizedBox(width: 10), //
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)), //
        ],
      ),
    );
  }

  // แปลงลิงก์ Drive เป็น Direct Link สำหรับแสดงผล
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

  // ฟังก์ชันส่งข้อมูลแจ้งซ่อม (ระบุว่าเป็น 'งานซ่อม' เพื่อเชื่อมระบบแม่บ้าน)
  Future<void> _submitRepairRequest(String roomNo, String tenantName) async {
    if (_detailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณาระบุรายละเอียดปัญหา")), //
      );
      return; //
    }
    await FirebaseFirestore.instance.collection('repairs').add({
      'roomNo': roomNo,
      'title': _selectedCategory, //
      'description': _detailController.text, //
      'photoUrl': _photoUrlController.text, //
      'status': 'รอดำเนินการ', //
      'type': 'งานซ่อม', // สำคัญ: เพื่อให้แม่บ้านเห็นข้อมูลถูกต้อง
      'createdAt': FieldValue.serverTimestamp(), //
      'tenantUid': user?.uid, //
      'reportedBy':
          tenantName, // ฝังชื่อเล่นผู้แจ้งเพื่อให้ระบบฝั่งอื่นดักกรองแมตช์จับคู่ได้สมบูรณ์
    });
    _detailController.clear(); //
    _photoUrlController.clear(); //
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ส่งข้อมูลแจ้งซ่อมเรียบร้อยแล้ว")), //
      );
      setState(() => _activeTab = 1); //
    }
  }

  // 🌟 [จุดอัปเดตสถาปัตยกรรม]: ดึงข้อมูลสตรีมหลักผู้เช่าและห้องพักจากด้านบนสุด เพื่อส่งมอบต่อให้ Widget ลูกใช้งานร่วมกันอย่างมีเสถียรภาพ 🌟
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), //
      appBar: buildTenantAppBar(context, title: "แจ้งซ่อม / ปัญหา"), //
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData)
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );

          var userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
          String tenantName = userData['name'] ?? "ผู้เช่า";

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('rooms')
                .where('tenantName', isEqualTo: tenantName)
                .limit(1)
                .snapshots(),
            builder: (context, roomSnap) {
              String roomNo =
                  (roomSnap.hasData && roomSnap.data!.docs.isNotEmpty)
                  ? roomSnap.data!.docs.first['roomNo']
                  : "N/A"; //

              return Column(
                children: [
                  _buildTabs(), //
                  Expanded(
                    child: _activeTab == 0
                        ? _buildNewRepairForm(roomNo, tenantName)
                        : _buildRepairHistory(
                            roomNo,
                            tenantName,
                          ), // ส่งค่าตัวแปร Scope ล็อกสิทธิ์
                  ),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: buildTenantBottomNav(
        context,
        2,
      ), // index 2 สำหรับแจ้งซ่อม
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
            _tabItem(0, "แจ้งปัญหาใหม่"), //
            _tabItem(1, "ประวัติแจ้งซ่อม"), //
          ],
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

  // หน้าแจ้งปัญหาใหม่ (ดึงค่าห้องพักเข้ามาทำงานอินไลน์เรียบร้อย)
  Widget _buildNewRepairForm(String roomNo, String tenantName) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20), //
      child: Container(
        padding: const EdgeInsets.all(25), //
        decoration: BoxDecoration(
          color: Colors.white, //
          borderRadius: BorderRadius.circular(30), //
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, //
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFFFF7ED), //
                  child: Icon(
                    Icons.build_outlined, //
                    color: Colors.orange,
                    size: 20, //
                  ),
                ),
                const SizedBox(width: 15), //
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, //
                    children: [
                      Text(
                        "แจ้งซ่อมห้อง $roomNo", // แสดงหมายเลขห้องพักจริง
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ), //
                      ),
                      const Text(
                        "ระบุรายละเอียดเพื่อให้ช่างเตรียมเครื่องมือได้ถูกต้อง", //
                        style: TextStyle(color: Colors.grey, fontSize: 11), //
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25), //
            const Text(
              "ประเภทปัญหา *", //
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), //
            ),
            Container(
              margin: const EdgeInsets.only(top: 10), //
              padding: const EdgeInsets.symmetric(horizontal: 15), //
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB), //
                borderRadius: BorderRadius.circular(12), //
                border: Border.all(color: Colors.grey.shade200), //
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true, //
                  value: _selectedCategory, //
                  // 🌟 [จุดแก้ไข]: ขยายประเภทปัญหาที่พบได้บ่อยให้แม่นยำยิ่งขึ้นตามเงื่อนไขหอพัก 🌟
                  items:
                      [
                            "ไฟฟ้า / หลอดไฟ",
                            "น้ำประปา / สุขาภิบาล",
                            "แอร์ / เครื่องปรับอากาศ",
                            "ประตู / หน้าต่าง / ลูกบิดกุญแจ",
                            "เฟอร์นิเจอร์ / โครงสร้างห้อง",
                            "เครื่องใช้ไฟฟ้าอื่นๆ",
                            "อินเทอร์เน็ต / สัญญาณเน็ต",
                            "อื่นๆ",
                          ]
                          .map(
                            (val) =>
                                DropdownMenuItem(value: val, child: Text(val)),
                          )
                          .toList(), //
                  onChanged: (v) => setState(() => _selectedCategory = v!), //
                ),
              ),
            ),
            const SizedBox(height: 20), //
            const Text(
              "รายละเอียดเพิ่มเติม *", //
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), //
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _detailController, //
              maxLines: 4, //
              decoration: InputDecoration(
                hintText: "อธิบายปัญหาที่พบ...", //
                filled: true, //
                fillColor: const Color(0xFFF9FAFB), //
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), //
                  borderSide: BorderSide.none, //
                ),
              ),
            ),
            const SizedBox(height: 20), //
            const Text(
              "แนบรูปภาพจุดเสียหายความปลอดภัยระบบ", //
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), //
            ),
            const SizedBox(height: 10),

            // 🌟 [เพิ่มใหม่]: แผงปุ่มสำหรับเปิดลิงก์เปิดแอป Google Drive คลังกลางเพื่ออัปโหลดรูปภาพสลิป/บิลสากล 🌟
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
                  "เปิดคลัง Google Drive เพื่ออัปโหลดรูปภาพ",
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
            const SizedBox(height: 12),

            TextField(
              controller: _photoUrlController, //
              decoration: InputDecoration(
                hintText: "วางลิงก์รูปภาพหลักฐานจาก Drive ที่นี่", //
                prefixIcon: const Icon(Icons.link), //
                filled: true, //
                fillColor: const Color(0xFFF9FAFB), //
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), //
                  borderSide: BorderSide.none, //
                ),
              ),
            ),
            const SizedBox(height: 30), //
            SizedBox(
              width: double.infinity, //
              child: ElevatedButton(
                onPressed: () => _submitRepairRequest(roomNo, tenantName), //
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF101828), //
                  padding: const EdgeInsets.symmetric(vertical: 18), //
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15), //
                  ),
                ),
                child: const Text(
                  "ยืนยันการส่งข้อมูลแจ้งซ่อม", //
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ), //
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 🌟 [ปรับปรุงใหม่]: ดึงประวัติและทำการกรองความปลอดภัยระดับ Client-side แมตช์ตรงเป๊ะกับ tenant_home 🌟 ---
  Widget _buildRepairHistory(String roomNo, String tenantName) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('repairs')
          .where(
            'roomNo',
            isEqualTo: roomNo,
          ) // โหลดใบงานทั้งหมดประจำห้องพักมาสแกน
          .snapshots(), //
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator()); //
        var docs = snapshot.data!.docs; //

        // คัดกรองข้อมูลฝั่ง Client ดักจับจับคู่เฉพาะประวัติตนเอง และต้องไม่ใช่ประเภทบิ๊กคลีนนิ่งล้างห้องพักแม่บ้าน
        var myPersonalRepairs = docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>? ?? {};
          return (data['reportedBy'] == tenantName ||
                  data['tenantName'] == tenantName ||
                  data['tenantUid'] == user?.uid ||
                  data['uid'] == user?.uid) &&
              data['type'] != "ทำความสะอาด" &&
              data['title'] != "ทำความสะอาด"; //
        }).toList();

        if (myPersonalRepairs.isEmpty) {
          return const Center(
            child: Text("คุณยังไม่เคยส่งประวัติคำร้องแจ้งซ่อม"),
          ); //
        }

        // จัดเรียงข้อมูลประวัติโดยใช้ชุดคลาสภาษา Dart พื้นฐาน (จากวันเวลาใหม่ล่าสุดไปเก่าสุด)
        myPersonalRepairs.sort((a, b) {
          var aData = a.data() as Map<String, dynamic>? ?? {};
          var bData = b.data() as Map<String, dynamic>? ?? {};
          var aTime =
              (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000); //
          var bTime =
              (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000); //
          return bTime.compareTo(aTime); //
        });

        return ListView.builder(
          padding: const EdgeInsets.all(20), //
          itemCount: myPersonalRepairs.length, //
          itemBuilder: (context, index) {
            var data =
                myPersonalRepairs[index].data() as Map<String, dynamic>; //
            return Container(
              margin: const EdgeInsets.only(bottom: 15), //
              decoration: BoxDecoration(
                color: Colors.white, //
                borderRadius: BorderRadius.circular(20), //
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.01),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(20), //
                onTap: () => _showRepairDetail(data), //
                child: Padding(
                  padding: const EdgeInsets.all(20), //
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, //
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween, //
                        children: [
                          Text(
                            data['title'] ?? "", //
                            style: const TextStyle(
                              fontWeight: FontWeight.bold, //
                              fontSize: 16, //
                            ),
                          ),
                          _buildStatusBadge(data['status'] ?? "รอดำเนินการ"), //
                        ],
                      ),
                      const SizedBox(height: 8), //
                      Text(
                        data['description'] ?? "", //
                        maxLines: 1, //
                        overflow: TextOverflow.ellipsis, //
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ), //
                      ),
                      const Divider(height: 30), //
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey,
                          ), //
                          const SizedBox(width: 5), //
                          Text(
                            data['createdAt'] != null
                                ? DateFormat('dd MMM yyyy HH:mm', 'th').format(
                                    (data['createdAt'] as Timestamp).toDate(),
                                  )
                                : "", //
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ), //
                          ),
                          const Spacer(), //
                          const Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: Colors.grey,
                          ), //
                        ],
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

  Widget _buildStatusBadge(String status) {
    Color bg; //
    Color text; //
    if (status == "เสร็จสิ้น") {
      bg = const Color(0xFFECFDF5); //
      text = const Color(0xFF10B981); //
    } else if (status == "กำลังดำเนินการ") {
      bg = const Color(0xFFFEF3C7); //
      text = const Color(0xFFD97706); //
    } else {
      bg = const Color(0xFFF1F5F9); //
      text = Colors.grey; //
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), //
      decoration: BoxDecoration(
        color: bg, //
        borderRadius: BorderRadius.circular(8), //
      ),
      child: Text(
        status, //
        style: TextStyle(
          color: text, //
          fontSize: 10, //
          fontWeight: FontWeight.bold, //
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../widgets/owner_bottom_nav.dart'; //
import '../../widgets/owner_app_bar.dart'; // นำเข้า AppBar ส่วนกลางตัวล่าสุด

class OwnerRepairs extends StatefulWidget {
  const OwnerRepairs({super.key});

  @override
  State<OwnerRepairs> createState() => _OwnerRepairsState();
}

class _OwnerRepairsState extends State<OwnerRepairs> {
  String _selectedStatus = "ทั้งหมด"; //

  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _issueController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _techNameController = TextEditingController();
  final TextEditingController _techPhoneController = TextEditingController();

  @override
  void dispose() {
    _locationController.dispose();
    _issueController.dispose();
    _descController.dispose();
    _costController.dispose();
    _techNameController.dispose();
    _techPhoneController.dispose();
    super.dispose();
  }

  // --- 1. ฟังก์ชันแปลงลิงก์ Google Drive เป็น Direct Link เพื่อพรีวิวรูปภาพในแอป ---
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

  // --- 2. ฟังก์ชันบันทึกค่าใช้จ่ายและยืนยันปิดงานซ่อม ---
  void _showCloseJobDialog(String docId, double currentCost) {
    TextEditingController finalCostController = TextEditingController(
      text: currentCost > 0 ? currentCost.toString() : "",
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text("บันทึกค่าใช้จ่ายและปิดงาน"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "ระบุค่าใช้จ่ายรวมทั้งหมดสำหรับการซ่อมครั้งนี้",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: finalCostController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: "ค่าใช้จ่าย (บาท)",
                hintText: "0.00",
                prefixIcon: const Icon(
                  Icons.payments_outlined,
                  color: Color(0xFF1DB954),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
              double enteredCost =
                  double.tryParse(finalCostController.text) ?? 0.0;
              await FirebaseFirestore.instance
                  .collection('repairs')
                  .doc(docId)
                  .update({'status': 'เสร็จสิ้น', 'cost': enteredCost});
              if (context.mounted) Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("ปิดงานซ่อมเรียบร้อยแล้ว"),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
            ),
            child: const Text(
              "ยืนยันการปิดงาน",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. หน้าต่างแผ่นพับแสดงรายละเอียดงานซ่อมแซมเชิงลึก ---
  void _showRepairDetail(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
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
                  const Text(
                    "รายละเอียดงานซ่อม",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 30),
              if (data['photoUrl'] != null &&
                  data['photoUrl'].toString().isNotEmpty) ...[
                const Text(
                  "รูปภาพประกอบหน้างาน:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.network(
                    _convertToDirectLink(data['photoUrl']),
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 150,
                      width: double.infinity,
                      color: Colors.grey[100],
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.grey,
                        size: 40,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
              ],
              _detailRow("สถานที่ห้องพัก:", data['roomNo'] ?? "ส่วนกลาง"),
              _detailRow("หัวข้อปัญหาระบบ:", data['title'] ?? "-"),
              const Text(
                "รายละเอียดเพิ่มเติม:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                data['description'] ?? "ไม่มีข้อมูลเพิ่มเติม",
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 20),
              _detailRow("ค่าใช้จ่ายรวมคงเหลือ:", "฿${data['cost'] ?? 0.0}"),
              _detailRow(
                "ผู้รับผิดชอบดูแล:",
                data['assignedPerson'] ?? "รอมอบหมาย",
              ),
              _detailRow(
                "บันทึกแจ้งเมื่อ:",
                data['createdAt'] != null
                    ? DateFormat(
                        'dd MMM yyyy HH:mm',
                      ).format((data['createdAt'] as Timestamp).toDate())
                    : "-",
              ),
              const SizedBox(height: 30),
              if (data['status'] == "เสร็จสิ้น")
                const Center(
                  child: Text(
                    "รายการนี้ได้รับการซ่อมแซมเสร็จสิ้นแล้ว",
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l, style: const TextStyle(color: Colors.grey)),
        Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      // --- จุดที่แก้ไขหลัก: ปรับมาใช้ AppBar ส่วนกลาง เพื่อดึงข้อมูลโปรไฟล์และธนาคารของแท้มาแสดงผลทันที ---
      appBar: buildOwnerAppBar(context),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildRepairsList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddRepairModal,
        backgroundColor: const Color(0xFF101828),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: buildOwnerBottomNav(context, 3), //
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.build_circle_outlined,
                color: Color(0xFF1DB954),
                size: 28,
              ),
              SizedBox(width: 10),
              Text(
                "งานแจ้งซ่อมทั้งหมด",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStatus,
                isExpanded: true,
                items: ["ทั้งหมด", "รอดำเนินการ", "กำลังดำเนินการ", "เสร็จสิ้น"]
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedStatus = v!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepairsList() {
    Query query = FirebaseFirestore.instance
        .collection('repairs')
        .orderBy('createdAt', descending: true);
    if (_selectedStatus != "ทั้งหมด")
      query = query.where('status', isEqualTo: _selectedStatus);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text("Error: Index Required"));
        if (!snapshot.hasData)
          return const Center(
            child: CircularProgressIndicator(color: Colors.green),
          );
        var docs = snapshot.data!.docs;
        if (docs.isEmpty)
          return const Center(
            child: Text(
              "ไม่มีข้อมูลงานแจ้งซ่อมในขณะนี้",
              style: TextStyle(color: Colors.grey),
            ),
          );

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: docs.length,
          itemBuilder: (context, index) => _buildRepairCard(
            docs[index].id,
            docs[index].data() as Map<String, dynamic>,
          ),
        );
      },
    );
  }

  Widget _buildRepairCard(String docId, Map<String, dynamic> data) {
    String status = data['status'] ?? "รอดำเนินการ";
    DateTime date =
        (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _showRepairDetail(data),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        data['roomNo'] ?? "N/A",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    _buildStatusBadge(status),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  data['title'] ?? "ปัญหาทั่วไป",
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "แจ้งเมื่อ: ${DateFormat('dd พ.ค. yyyy', 'th').format(date)}",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (data['cost'] != null && data['cost'] > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      "ค่าใช้จ่ายรวม: ฿${data['cost']}",
                      style: const TextStyle(
                        color: Color(0xFF1DB954),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: status == "เสร็จสิ้น"
                ? () => _showRepairDetail(data)
                : () => _showAssignmentModal(docId, data['assignedPerson']),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    data['assignmentType'] == "maid"
                        ? Icons.cleaning_services_outlined
                        : Icons.engineering_outlined,
                    size: 18,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    data['assignmentType'] == "maid" ? "แม่บ้าน:" : "ช่างซ่อม:",
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    data['assignedPerson'] ?? "กดมอบหมายงาน",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: data['assignedPerson'] == null
                          ? Colors.orange
                          : Colors.black,
                    ),
                  ),
                  Icon(
                    status == "เสร็จสิ้น"
                        ? Icons.info_outline
                        : Icons.chevron_right,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          if (status != "เสร็จสิ้น")
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _showCloseJobDialog(
                  docId,
                  (data['cost'] ?? 0.0).toDouble(),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1DB954)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "ปิดงาน (ซ่อมเสร็จแล้ว)",
                  style: TextStyle(
                    color: Color(0xFF1DB954),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- 4. ชุดคำสั่งมอบหมายคัดแยกผู้ดูแลรับผิดชอบงานซ่อมบำรุง ---
  void _showAssignmentModal(String id, String? cur) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        expand: false,
        builder: (context, sc) => SingleChildScrollView(
          controller: sc,
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "มอบหมายงาน",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (cur != null) ...[
                const SizedBox(height: 10),
                ListTile(
                  tileColor: Colors.red[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: const Icon(
                    Icons.person_remove_outlined,
                    color: Colors.red,
                  ),
                  title: const Text(
                    "ยกเลิกผู้รับผิดชอบเดิม",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    FirebaseFirestore.instance
                        .collection('repairs')
                        .doc(id)
                        .update({
                          'assignedPerson': FieldValue.delete(),
                          'assignmentType': FieldValue.delete(),
                          'status': 'รอดำเนินการ',
                        });
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 40),
              ],
              const Text(
                "1. แม่บ้านในระบบ",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
              _buildMaidSelector(id),
              const Divider(height: 40),
              const Text(
                "2. รายชื่อช่างเดิม",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
              _buildExistingTechSelector(id),
              const Divider(height: 40),
              const Text(
                "3. เพิ่มช่างใหม่",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1DB954),
                ),
              ),
              _buildDirectAddTechForm(id),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddRepairModal() {
    _locationController.clear();
    _issueController.clear();
    _descController.clear();
    _costController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 25,
          right: 25,
          top: 25,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "เพิ่มรายการแจ้งซ่อมใหม่",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Divider(height: 30),
              _styledField(
                _locationController,
                "สถานที่ (ยิม, ห้อง A101)",
                Icons.location_on_outlined,
              ),
              _styledField(
                _issueController,
                "หัวข้อปัญหา",
                Icons.build_outlined,
              ),
              _styledField(
                _descController,
                "รายละเอียดปัญหา",
                Icons.description_outlined,
              ),
              _styledField(
                _costController,
                "ค่าใช้จ่ายเบื้องต้น (บาท)",
                Icons.payments_outlined,
                isNum: true,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_locationController.text.isNotEmpty &&
                        _issueController.text.isNotEmpty) {
                      await FirebaseFirestore.instance
                          .collection('repairs')
                          .add({
                            'roomNo': _locationController.text,
                            'title': _issueController.text,
                            'description': _descController.text,
                            'type': 'งานซ่อม',
                            'cost':
                                double.tryParse(_costController.text) ?? 0.0,
                            'status': 'รอดำเนินการ',
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                      if (context.mounted) Navigator.pop(context);
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
                    "บันทึกรายการ",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExistingTechSelector(String id) => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('technicians').snapshots(),
    builder: (context, snap) {
      if (!snap.hasData) return const LinearProgressIndicator();
      return Column(
        children: snap.data!.docs
            .map(
              (doc) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  radius: 15,
                  child: Icon(Icons.engineering, size: 16),
                ),
                title: Text(doc['name']),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.blue,
                  ),
                  onPressed: () {
                    FirebaseFirestore.instance
                        .collection('repairs')
                        .doc(id)
                        .update({
                          'assignedPerson': doc['name'],
                          'assignmentType': 'tech',
                          'status': 'กำลังดำเนินการ',
                        });
                    Navigator.pop(context);
                  },
                ),
              ),
            )
            .toList(),
      );
    },
  );

  Widget _buildMaidSelector(String id) => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'maid')
        .snapshots(),
    builder: (context, snap) {
      if (!snap.hasData) return const LinearProgressIndicator();
      return Column(
        children: snap.data!.docs
            .map(
              (doc) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  radius: 15,
                  child: Icon(Icons.person, size: 16),
                ),
                title: Text(doc['name']),
                trailing: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.blue,
                ),
                onTap: () {
                  FirebaseFirestore.instance
                      .collection('repairs')
                      .doc(id)
                      .update({
                        'assignedPerson': doc['name'],
                        'assignmentType': 'maid',
                        'status': 'กำลังดำเนินการ',
                      });
                  Navigator.pop(context);
                },
              ),
            )
            .toList(),
      );
    },
  );

  Widget _buildDirectAddTechForm(String id) => Column(
    children: [
      const SizedBox(height: 10),
      TextField(
        controller: _techNameController,
        decoration: InputDecoration(
          hintText: "ชื่อช่าง",
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _techPhoneController,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          hintText: "เบอร์โทร",
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      const SizedBox(height: 15),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            if (_techNameController.text.isNotEmpty) {
              await FirebaseFirestore.instance.collection('technicians').add({
                'name': _techNameController.text,
                'phone': _techPhoneController.text,
              });
              FirebaseFirestore.instance.collection('repairs').doc(id).update({
                'assignedPerson': _techNameController.text,
                'assignmentType': 'tech',
                'status': 'กำลังดำเนินการ',
              });
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF101828),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            "บันทึกและมอบหมาย",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    ],
  );

  Widget _styledField(
    TextEditingController c,
    String l,
    IconData i, {
    bool isNum = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: TextField(
      controller: c,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: l,
        prefixIcon: Icon(i, color: const Color(0xFF1DB954)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
  );

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;
    if (status == "เสร็จสิ้น") {
      bg = const Color(0xFFECFDF5);
      text = const Color(0xFF10B981);
    } else if (status == "กำลังดำเนินการ") {
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFFD97706);
    } else {
      bg = const Color(0xFFF1F5F9);
      text = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: text,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

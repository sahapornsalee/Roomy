import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

PreferredSizeWidget buildTenantAppBar(
  BuildContext context, {
  String title = "Roomy",
}) {
  final user = FirebaseAuth.instance.currentUser;

  // --- ฟังก์ชันแสดงการตั้งค่าและแบบฟอร์มแก้ไขรายละเอียดผู้เช่าทั้งหมด ---
  void _showTenantSettings() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController lineIdController = TextEditingController();
    final TextEditingController emergencyNameController =
        TextEditingController();
    final TextEditingController emergencyRelationController =
        TextEditingController();
    final TextEditingController emergencyPhoneController =
        TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    int residentCount = 1;
    int carCount = 0;
    int motorcycleCount = 0;

    bool isInitialized = false; // ตัวแปรล็อกสำหรับการดึงข้อมูลรอบแรกรอบเดียว
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(
              context,
            ).viewInsets.bottom, // ดันฟอร์มหนีคีย์บอร์ดมือถือ
          ),
          child: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user?.uid)
                .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(
                  child: CircularProgressIndicator(color: Colors.green),
                );

              // โหลดค่าดั้งเดิมจากฐานข้อมูลมากรอกลงในคอนโทรลเลอร์ (ทำเพียงครั้งเดียวป้องกันพิมพ์แล้วหลุด)
              if (!isInitialized) {
                var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                nameController.text = data['name'] ?? "";
                phoneController.text = data['phone'] ?? "";
                lineIdController.text = data['lineId'] ?? "";
                residentCount = data['residentCount'] ?? 1;

                var parking =
                    data['parkingRequest'] as Map<String, dynamic>? ?? {};
                carCount = parking['carCount'] ?? 0;
                motorcycleCount = parking['motorcycleCount'] ?? 0;

                var emergency =
                    data['emergencyContact'] as Map<String, dynamic>? ?? {};
                emergencyNameController.text = emergency['name'] ?? "";
                emergencyRelationController.text =
                    emergency['relationship'] ?? "";
                emergencyPhoneController.text = emergency['phone'] ?? "";

                isInitialized = true;
              }

              var currentData =
                  snapshot.data!.data() as Map<String, dynamic>? ?? {};
              String emailDisplay = currentData['email'] ?? "-";

              return SingleChildScrollView(
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
                        const Text(
                          "แก้ไขข้อมูลโปรไฟล์ผู้เช่า",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF101828),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const Divider(height: 25),

                    // --- หมวดที่ 1: ข้อมูลส่วนตัวทั่วไป ---
                    _sectionTitle("1. ข้อมูลส่วนตัวผู้เช่า"),
                    _buildInputField(
                      nameController,
                      "ชื่อ - นามสกุล",
                      Icons.person_outline,
                    ),
                    _buildInputField(
                      phoneController,
                      "เบอร์โทรศัพท์",
                      Icons.phone_android_outlined,
                      isPhone: true,
                    ),
                    _buildInputField(
                      lineIdController,
                      "Line ID",
                      Icons.chat_bubble_outline,
                    ),

                    // แสดงอีเมลแบบปิดกั้นการแก้ไข (Read-only) เพื่อป้องกันสิทธิ์ความปลอดภัย Auth พัง
                    TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        labelText:
                            "อีเมลล็อกอินระบบ (แก้ไขไม่ได้): $emailDisplay",
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: Colors.grey,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // เลือกจำนวนผู้เข้าพักอาศัย
                    DropdownButtonFormField<int>(
                      value: residentCount,
                      decoration: InputDecoration(
                        labelText: 'จำนวนผู้พักอาศัยภายในห้อง',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        prefixIcon: const Icon(Icons.group_outlined),
                      ),
                      items: [1, 2, 3, 4, 5]
                          .map(
                            (num) => DropdownMenuItem(
                              value: num,
                              child: Text(num == 5 ? "5 คนขึ้นไป" : "$num คน"),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setModalState(() => residentCount = v!),
                    ),

                    const SizedBox(height: 25),
                    // --- หมวดที่ 2: ข้อมูลสิทธิ์จอดรถหลายคันควบคู่กันได้ ---
                    _sectionTitle("2. สิ่งอำนวยความสะดวกและยานพาหนะ"),
                    DropdownButtonFormField<int>(
                      value: carCount,
                      decoration: InputDecoration(
                        labelText: 'จำนวนรถยนต์ที่นำมาจอด',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        prefixIcon: const Icon(
                          Icons.directions_car_filled_outlined,
                        ),
                      ),
                      items: [0, 1, 2, 3]
                          .map(
                            (num) => DropdownMenuItem(
                              value: num,
                              child: Text(
                                num == 0 ? "ไม่มีรถยนต์" : "$num คัน",
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setModalState(() => carCount = v!),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<int>(
                      value: motorcycleCount,
                      decoration: InputDecoration(
                        labelText: 'จำนวนรถจักรยานยนต์ที่นำมาจอด',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        prefixIcon: const Icon(Icons.two_wheeler_outlined),
                      ),
                      items: [0, 1, 2, 3]
                          .map(
                            (num) => DropdownMenuItem(
                              value: num,
                              child: Text(
                                num == 0 ? "ไม่มีรถจักรยานยนต์" : "$num คัน",
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setModalState(() => motorcycleCount = v!),
                    ),

                    const SizedBox(height: 25),
                    // --- หมวดที่ 3: ข้อมูลผู้ติดต่อฉุกเฉิน ---
                    _sectionTitle("3. ข้อมูลผู้ติดต่อฉุกเฉิน"),
                    _buildInputField(
                      emergencyNameController,
                      "ชื่อ-นามสกุล ผู้ติดต่อฉุกเฉิน",
                      Icons.contact_phone_outlined,
                    ),
                    _buildInputField(
                      emergencyRelationController,
                      "ความสัมพันธ์กับผู้เช่า",
                      Icons.people_outline,
                    ),
                    _buildInputField(
                      emergencyPhoneController,
                      "เบอร์โทรศัพท์ฉุกเฉิน",
                      Icons.phone_callback_outlined,
                      isPhone: true,
                    ),

                    const SizedBox(height: 10),
                    _sectionTitle(
                      "4. รหัสผ่านความปลอดภัย (ระบุเมื่อต้องการเปลี่ยนเท่านั้น)",
                    ),
                    _buildInputField(
                      passwordController,
                      "รหัสผ่านใหม่เข้าแอป (6 ตัวขึ้นไป)",
                      Icons.lock_outline,
                      isPassword: true,
                    ),

                    const SizedBox(height: 20),
                    // --- ปุ่มบันทึกการแก้ไขข้อมูลทั้งหมด ---
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (nameController.text.trim().isEmpty ||
                                    phoneController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "กรุณากรอกชื่อและเบอร์โทรศัพท์ห้ามเป็นค่าว่าง",
                                      ),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  return;
                                }
                                setModalState(() => isSaving = true);
                                try {
                                  String oldName = currentData['name'] ?? "";
                                  String newName = nameController.text.trim();

                                  // 1. อัปเดตข้อมูลผู้ใช้งานหลักในคอลเลกชัน users
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user?.uid)
                                      .update({
                                        'name': newName,
                                        'phone': phoneController.text.trim(),
                                        'lineId': lineIdController.text.trim(),
                                        'residentCount': residentCount,
                                        'parkingRequest': {
                                          'carCount': carCount,
                                          'motorcycleCount': motorcycleCount,
                                          'hasVehicle':
                                              carCount > 0 ||
                                              motorcycleCount > 0,
                                        },
                                        'emergencyContact': {
                                          'name': emergencyNameController.text
                                              .trim(),
                                          'relationship':
                                              emergencyRelationController.text
                                                  .trim(),
                                          'phone': emergencyPhoneController.text
                                              .trim(),
                                        },
                                      });

                                  // 2. Logic สำคัญ: ตรวจสอบและอัปเดตข้อมูลในคอลเลกชัน rooms ป้องกันบิลเสียหาย
                                  if (oldName != newName &&
                                      oldName.isNotEmpty) {
                                    var roomQuery = await FirebaseFirestore
                                        .instance
                                        .collection('rooms')
                                        .where('tenantName', isEqualTo: oldName)
                                        .get();
                                    for (var doc in roomQuery.docs) {
                                      await doc.reference.update({
                                        'tenantName': newName,
                                        'tenantPhone': phoneController.text
                                            .trim(),
                                      });
                                    }
                                  }

                                  // 3. จัดการกรณีต้องการเปลี่ยนรหัสผ่านใหม่
                                  if (passwordController.text
                                      .trim()
                                      .isNotEmpty) {
                                    if (passwordController.text.trim().length <
                                        6) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "รหัสผ่านใหม่ต้องมี 6 ตัวขึ้นไป",
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      setModalState(() => isSaving = false);
                                      return;
                                    }
                                    await FirebaseAuth.instance.currentUser
                                        ?.updatePassword(
                                          passwordController.text.trim(),
                                        );
                                  }

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "บันทึกการแก้ไขข้อมูลผู้เช่าสำเร็จแล้ว",
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("บันทึกไม่สำเร็จ: $e"),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                } finally {
                                  setModalState(() => isSaving = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1DB954),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        icon: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check, color: Colors.white),
                        label: const Text(
                          "บันทึกการแก้ไขทั้งหมด",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  return AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    automaticallyImplyLeading: false,
    title: Row(
      children: [
        const Icon(Icons.business_outlined, color: Color(0xFF1DB954)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF101828),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
    actions: [
      IconButton(
        onPressed: _showTenantSettings,
        icon: const Icon(Icons.settings_outlined, color: Color(0xFF101828)),
      ),
      IconButton(
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
          if (context.mounted) Navigator.pushReplacementNamed(context, '/');
        },
        icon: const Icon(Icons.logout, color: Colors.grey),
      ),
    ],
  );
}

Widget _sectionTitle(String t) => Padding(
  padding: const EdgeInsets.only(bottom: 15, top: 10),
  child: Text(
    t,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: Color(0xFF101828),
    ),
  ),
);

Widget _buildInputField(
  TextEditingController controller,
  String label,
  IconData icon, {
  bool isPassword = false,
  bool isPhone = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

PreferredSizeWidget buildOwnerAppBar(
  BuildContext context, {
  String title = "Roomy",
  VoidCallback? onSettingsPressed,
}) {
  final user = FirebaseAuth.instance.currentUser;

  // --- [ฟังก์ชันใหม่] หน้าต่างแผ่นพับตั้งค่าข้อมูลเจ้าของหอพัก & บัญชีธนาคารระบบทั้งหมด ---
  void _showCentralOwnerSettingsModal() {
    // คอนโทรลเลอร์ข้อมูลส่วนตัวเจ้าของหอพัก
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final lineController = TextEditingController();
    final facebookController =
        TextEditingController(); // 🛠️ เพิ่ม Controller สำหรับ Facebook

    // คอนโทรลเลอร์บัญชีธนาคารส่วนกลางของระบบ
    final bankNameController = TextEditingController();
    final bankAccountNoController = TextEditingController();
    final bankAccountNameController = TextEditingController();
    final promptPayIdController = TextEditingController();

    // คอนโทรลเลอร์ความปลอดภัย & ลิงก์ไดรฟ์
    final passwordController = TextEditingController();
    final driveLinkController = TextEditingController();

    bool isInitialized = false; // ล็อกอินพุตป้องกันโฟกัสหลุดตอนพิมพ์
    bool isSavingData = false;

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
            ).viewInsets.bottom, // ดันหลบแป้นพิมพ์โทรศัพท์อัตโนมัติ
          ),
          child: FutureBuilder<List<DocumentSnapshot>>(
            // ดึงข้อมูลโปรไฟล์ผู้ใช้ และข้อมูลธนาคาร/ไดรฟ์ ส่วนกลางพร้อมกัน
            future: Future.wait([
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .get(),
              FirebaseFirestore.instance
                  .collection('settings')
                  .doc('config')
                  .get(),
            ]),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1DB954)),
                );
              }

              // โหลดค่าเริ่มต้นกรอกลงใน TextFields รอบแรก
              if (!isInitialized) {
                var userDoc = snapshot.data![0];
                var configDoc = snapshot.data![1];

                if (userDoc.exists) {
                  var userData = userDoc.data() as Map<String, dynamic>;
                  nameController.text = userData['name'] ?? "";
                  phoneController.text = userData['phone'] ?? "";
                  lineController.text = userData['lineId'] ?? "";
                  facebookController.text =
                      userData['facebook'] ??
                      ""; // 🛠️ ดึงข้อมูล Facebook เริ่มต้นจาก Firestore
                }

                if (configDoc.exists) {
                  var configData = configDoc.data() as Map<String, dynamic>;
                  bankNameController.text = configData['bankName'] ?? "";
                  bankAccountNoController.text =
                      configData['bankAccountNo'] ?? "";
                  bankAccountNameController.text =
                      configData['bankAccountName'] ?? "";
                  promptPayIdController.text = configData['promptPayId'] ?? "";
                  driveLinkController.text = configData['driveUrl'] ?? "";
                }
                isInitialized = true;
              }

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
                          "ตั้งค่าระบบและบัญชีผู้ดูแล",
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

                    // --- ส่วนที่ 1: แก้ไขข้อมูลส่วนตัวเจ้าของหอพัก ---
                    _buildSubTitle("1. ข้อมูลส่วนตัวเจ้าของหอพัก"),
                    _buildField(
                      nameController,
                      "ชื่อ-นามสกุล เจ้าของหอพัก",
                      Icons.person_outline,
                    ),
                    _buildField(
                      phoneController,
                      "เบอร์โทรศัพท์ติดต่อ",
                      Icons.phone_android_outlined,
                      isNum: true,
                    ),
                    _buildField(
                      lineController,
                      "Line ID ผู้ดูแล",
                      Icons.chat_bubble_outline,
                    ),
                    _buildField(
                      facebookController,
                      "Facebook ผู้ดูแล",
                      Icons
                          .facebook_outlined, // 🛠️ เพิ่มช่องกรอก Facebook ใน UI
                    ),

                    const SizedBox(height: 15),
                    // --- ส่วนที่ 2: แก้ไขข้อมูลบัญชีธนาคารส่วนกลางของระบบ ---
                    _buildSubTitle(
                      "2. ข้อมูลบัญชีธนาคาร & พร้อมเพย์ระบบ (สำหรับรับเงินค่าเช่า)",
                    ),
                    _buildField(
                      bankNameController,
                      "ชื่อธนาคาร (เช่น กสิกรไทย, ไทยพาณิชย์)",
                      Icons.account_balance_outlined,
                    ),
                    _buildField(
                      bankAccountNoController,
                      "เลขที่บัญชีธนาคาร",
                      Icons.badge_outlined,
                      isNum: true,
                    ),
                    _buildField(
                      bankAccountNameController,
                      "ชื่อบัญชีผู้รับเงิน",
                      Icons.subtitles_outlined,
                    ),
                    _buildField(
                      promptPayIdController,
                      "หมายเลขพร้อมเพย์หอพัก (เบอร์มือถือ/เลขบัตรประชาชน)",
                      Icons.qr_code_scanner_outlined,
                      isNum: true,
                    ),

                    const SizedBox(height: 15),
                    // --- ส่วนที่ 3: แก้ไขลิงก์ Google Drive คลังระบบกลาง ---
                    _buildSubTitle(
                      "3. คลังไดรฟ์แอปส่วนกลาง (Google Drive System)",
                    ),
                    _buildField(
                      driveLinkController,
                      "ลิงก์ URL โฟลเดอร์ Google Drive",
                      Icons.cloud_queue_outlined,
                    ),

                    const Divider(height: 25),

                    // --- ส่วนที่ 4: เปลี่ยนรหัสผ่านความปลอดภัยเข้าสู่ระบบ ---
                    _buildSubTitle(
                      "4. รหัสผ่านความปลอดภัยเข้าสู่ระบบ (เว้นว่างไว้หากไม่ต้องการเปลี่ยน)",
                    ),
                    _buildField(
                      passwordController,
                      "รหัสผ่านใหม่ (6 ตัวขึ้นไป)",
                      Icons.lock_outline,
                      isObscure: true,
                    ),

                    const SizedBox(height: 20),

                    // ปุ่มบันทึกข้อมูลฟอร์มทั้งหมด (มัดรวมระบบ Firestore + Auth)
                    SExpandingButton(
                      label: "บันทึกการตั้งค่าทั้งหมด",
                      isLoading: isSavingData,
                      color: const Color(0xFF1DB954),
                      onPressed: () async {
                        final newPassword = passwordController.text.trim();

                        // ตรวจสอบความถูกต้องของรหัสผ่านก่อน (ถ้ากรอกมา)
                        if (newPassword.isNotEmpty && newPassword.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "กรุณาระบุรหัสผ่านใหม่อย่างน้อย 6 ตัวอักษรขึ้นไป",
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        setModalState(() => isSavingData = true);
                        try {
                          // 1. บันทึกข้อมูลส่วนตัวเข้าคอลเลกชัน users
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user?.uid)
                              .update({
                                'name': nameController.text.trim(),
                                'phone': phoneController.text.trim(),
                                'lineId': lineController.text.trim(),
                                'facebook': facebookController.text
                                    .trim(), // 🛠️ บันทึกค่า Facebook ลง Firestore
                              });

                          // 2. บันทึกข้อมูลธนาคารและลิงก์ไดรฟ์เข้า settings/config
                          await FirebaseFirestore.instance
                              .collection('settings')
                              .doc('config')
                              .set({
                                'bankName': bankNameController.text.trim(),
                                'bankAccountNo': bankAccountNoController.text
                                    .trim(),
                                'bankAccountName': bankAccountNameController
                                    .text
                                    .trim(),
                                'promptPayId': promptPayIdController.text
                                    .trim(),
                                'driveUrl': driveLinkController.text.trim(),
                                'lastUpdatedBy': user?.uid,
                                'updatedAt': FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));

                          // 3. จัดการเปลี่ยนรหัสผ่าน Firebase Auth (เฉพาะเมื่อมีการกรอกค่ามา)
                          bool isPasswordUpdated = false;
                          if (newPassword.isNotEmpty) {
                            await FirebaseAuth.instance.currentUser
                                ?.updatePassword(newPassword);
                            passwordController.clear();
                            isPasswordUpdated = true;
                          }

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isPasswordUpdated
                                      ? "อัปเดตข้อมูลระบบ บัญชีธนาคาร และเปลี่ยนรหัสผ่านสำเร็จแล้ว"
                                      : "อัปเดตข้อมูลโปรไฟล์และบัญชีธนาคารระบบสำเร็จแล้ว",
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            String errorMessage = "เกิดข้อผิดพลาด: $e";
                            // แจ้งเตือนกรณี Firebase บังคับ Re-authenticate (เมื่อไม่ได้ล็อกอินนานแล้วมาเปลี่ยนรหัสผ่าน)
                            if (e.toString().contains(
                              "requires-recent-login",
                            )) {
                              errorMessage =
                                  "ความปลอดภัยปฏิเสธ: กรุณาออกจากระบบแล้วเข้าสู่ระบบใหม่อีกครั้งเพื่อเปลี่ยนรหัสผ่าน";
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(errorMessage),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        } finally {
                          setModalState(() => isSavingData = false);
                        }
                      },
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
      // ปุ่มตั้งค่าอัจฉริยะ: เรียกฟังก์ชันตั้งค่าบัญชีและธนาคารกลางทันที
      IconButton(
        onPressed: onSettingsPressed ?? _showCentralOwnerSettingsModal,
        icon: const Icon(Icons.settings_outlined, color: Color(0xFF101828)),
      ),
      IconButton(
        onPressed: () async {
          await FirebaseAuth.instance.signOut(); // เคลียร์เซสชันล็อกอิน
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, '/');
          }
        },
        icon: const Icon(Icons.logout, color: Colors.grey),
      ),
    ],
  );
}

// --- ชุดวิจเจ็ตประกอบโครงสร้างหน้าฟอร์มตกแต่งสวยงาม ---
Widget _buildSubTitle(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 12, top: 10),
  child: Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.bold,
      color: Colors.blueGrey,
    ),
  ),
);

Widget _buildField(
  TextEditingController controller,
  String label,
  IconData icon, {
  bool isNum = false,
  bool isObscure = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 12,
        ),
      ),
    ),
  );
}

class SExpandingButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final Color color;
  final VoidCallback onPressed;

  const SExpandingButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }
}

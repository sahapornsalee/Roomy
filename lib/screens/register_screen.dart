import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _lineIdController = TextEditingController();

  // คอนโทรลเลอร์สำหรับข้อมูลผู้เช่าเพิ่มเติม
  final _tenantNoteController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyRelationController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  String _selectedRole = 'tenant'; // ค่าเริ่มต้นเป็นผู้เช่า
  int _extraKeycards = 1; // เริ่มต้นคีย์การ์ด 1 ใบ
  bool _agreedToRules = false; // Status ยอมรับกฎระเบียบ

  // ตัวแปรสำหรับคัดแยกจำนวนยานพาหนะแต่ละประเภท
  int _carCount = 0;
  int _motorcycleCount = 0;

  // ตัวแปรสเตตสำหรับเก็บจำนวนผู้พักอาศัยภายในห้อง
  int _residentCount = 1;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    _lineIdController.dispose();
    _tenantNoteController.dispose();
    _emergencyNameController.dispose();
    _emergencyRelationController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _register(String? passedRoomNo) async {
    if (_selectedRole == 'tenant' && !_agreedToRules) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากดยอมรับกฎระเบียบของหอพักก่อนลงทะเบียน'),
          backgroundColor: Colors.orange, //
        ),
      );
      return;
    }

    try {
      // 1. สร้างบัญชีผู้ใช้ใน Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      // 2. จัดเตรียมชุดข้อมูลพื้นฐาน
      Map<String, dynamic> userData = {
        'uid': userCredential.user!.uid,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'lineId': _lineIdController.text.trim(),
        'role': _selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // บันทึกฟิลด์เพิ่มเติมในกรณีที่เป็นผู้เช่า
      if (_selectedRole == 'tenant') {
        userData['residentCount'] = _residentCount; //
        userData['additionalDetails'] = _tenantNoteController.text.trim(); //
        userData['extraKeycards'] = _extraKeycards; //

        if (passedRoomNo != null) {
          userData['roomNo'] = passedRoomNo;
        } else {
          userData['roomNo'] = ""; //
        }

        userData['parkingRequest'] = {
          'carCount': _carCount,
          'motorcycleCount': _motorcycleCount,
          'hasVehicle': _carCount > 0 || _motorcycleCount > 0,
        };

        userData['emergencyContact'] = {
          'name': _emergencyNameController.text.trim(),
          'relationship': _emergencyRelationController.text.trim(),
          'phone': _emergencyPhoneController.text.trim(),
        };
        userData['agreedToRules'] = _agreedToRules; //
      }

      // 3. บันทึกข้อมูลเสริมทั้งหมดลง Cloud Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(userData);

      // 4. ผูกชื่อผู้จองเข้าคอลเลกชัน rooms
      if (_selectedRole == 'tenant' && passedRoomNo != null) {
        var roomQuery = await FirebaseFirestore.instance
            .collection('rooms')
            .where('roomNo', isEqualTo: passedRoomNo)
            .limit(1)
            .get();

        if (roomQuery.docs.isNotEmpty) {
          await roomQuery.docs.first.reference.update({
            'bookingName': _nameController.text.trim(),
            'reservedBy': _nameController.text.trim(),
            'tenantUid': userCredential.user!.uid,
            'status': 'จองแล้ว',
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ลงทะเบียนสมาชิกสำเร็จแล้ว!'),
            backgroundColor: Colors.green, //
          ),
        );
        Navigator.pop(context); //
      }
    } on FirebaseAuthException catch (e) {
      // 🌟 [จุดแก้ไข]: ดักจับรหัส Error จากระบบคลาวด์แปลงความหมายเป็นไทยเพื่อความลื่นไหลของ UX 🌟
      String thaiErrorMessage =
          'เกิดข้อผิดพลาดในการเชื่อมต่อระบบลงทะเบียนสมาชิก';

      if (e.code == 'email-already-in-use') {
        thaiErrorMessage =
            '⚠️ ขออภัย: อีเมลนี้ถูกใช้งานไปแล้วในระบบ กรุณาเปลี่ยนใช้อีเมลอื่น หรือกดไปที่หน้าเข้าสู่ระบบ';
      } else if (e.code == 'weak-password') {
        thaiErrorMessage =
            '⚠️ รหัสผ่านคาดเดาได้ง่ายเกินไป ระบบบังคับความยาวอย่างน้อย 6 ตัวอักษรขึ้นไป';
      } else if (e.code == 'invalid-email') {
        thaiErrorMessage =
            '⚠️ รูปแบบที่กรอกไม่ถูกต้องตามมาตรฐานของที่อยู่อีเมลสากล';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(thaiErrorMessage),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration Failed: $e'),
          backgroundColor: Colors.redAccent, //
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    String? passedRoomNo;
    if (args is Map && args.containsKey('roomNo')) {
      passedRoomNo = args['roomNo']?.toString();
    } else if (args is String) {
      passedRoomNo = args;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), //
      appBar: AppBar(
        title: const Text(
          "สมัครสมาชิก",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold), //
        ),
        backgroundColor: Colors.white, //
        elevation: 0, //
        iconTheme: const IconThemeData(color: Colors.black), //
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0), //
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, //
          children: [
            if (_selectedRole == 'tenant' && passedRoomNo != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xFFD97706).withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bookmark_added_outlined,
                      color: Color(0xFFD97706),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "คุณกำลังลงทะเบียนเพื่อยืนยันสิทธิ์ในสถานะผู้จอง ห้องพักหมายเลข: $passedRoomNo",
                        style: const TextStyle(
                          color: Color(0xFFD97706),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            DropdownButtonFormField<String>(
              value: _selectedRole,
              items: const [
                DropdownMenuItem(
                  value: 'tenant',
                  child: Text("ผู้เช่า (Tenant)"), //
                ),
                DropdownMenuItem(
                  value: 'maid',
                  child: Text("แม่บ้าน (Maid)"),
                ), //
              ],
              onChanged: (val) => setState(() {
                _selectedRole = val as String; //
              }),
              decoration: InputDecoration(
                labelText: 'ประเภทผู้ใช้งาน',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15), //
                ),
              ),
            ),
            const SizedBox(height: 25), //

            if (_selectedRole == 'tenant') ...[
              _buildSectionTitle("1. ข้อมูลส่วนตัวผู้เช่า"), //
              _buildTextField(
                _nameController,
                'ชื่อ-นามสกุล',
                Icons.person_outline,
              ), //
              _buildTextField(
                _phoneController,
                'เบอร์โทรศัพท์ผู้เช่า',
                Icons.phone_android_outlined,
                isPhone: true,
              ), //
              _buildTextField(
                _emailController,
                'Email',
                Icons.email_outlined,
              ), //
              _buildTextField(
                _lineIdController,
                'Line ID',
                Icons.chat_bubble_outline,
              ), //
              _buildTextField(
                _passwordController,
                'Password (6 ตัวขึ้นไป)',
                Icons.lock_outline,
                isPassword: true,
              ), //

              DropdownButtonFormField<int>(
                value: _residentCount,
                decoration: InputDecoration(
                  labelText: 'จำนวนผู้พักอาศัยภายในห้อง *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ), //
                  prefixIcon: const Icon(Icons.group_outlined), //
                ),
                items: [1, 2, 3, 4, 5]
                    .map(
                      (num) => DropdownMenuItem(
                        value: num,
                        child: Text(num == 5 ? "5 คนขึ้นไป" : "$num คน"),
                      ),
                    ) //
                    .toList(),
                onChanged: (v) => setState(() => _residentCount = v!), //
              ),
              const SizedBox(height: 20), //

              _buildSectionTitle(
                "2. สิ่งอำนวยความสะดวกและค่าใช้จ่ายเพิ่มเติม",
              ), //
              DropdownButtonFormField<int>(
                value: _carCount,
                decoration: InputDecoration(
                  labelText: 'จำนวนรถยนต์ที่นำมาจอด (Parking Request)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ), //
                  prefixIcon: const Icon(
                    Icons.directions_car_filled_outlined,
                  ), //
                ),
                items: [0, 1, 2, 3]
                    .map(
                      (num) => DropdownMenuItem(
                        value: num,
                        child: Text(num == 0 ? "ไม่มีรถยนต์ (฿0)" : "$num คัน"),
                      ),
                    ) //
                    .toList(),
                onChanged: (v) => setState(() => _carCount = v!), //
              ),
              const SizedBox(height: 20), //

              DropdownButtonFormField<int>(
                value: _motorcycleCount,
                decoration: InputDecoration(
                  labelText: 'จำนวนรถจักรยานยนต์ที่นำมาจอด',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ), //
                  prefixIcon: const Icon(Icons.two_wheeler_outlined), //
                ),
                items: [0, 1, 2, 3]
                    .map(
                      (num) => DropdownMenuItem(
                        value: num,
                        child: Text(
                          num == 0 ? "ไม่มีรถจักรยานยนต์ (฿0)" : "$num คัน",
                        ),
                      ),
                    ) //
                    .toList(),
                onChanged: (v) => setState(() => _motorcycleCount = v!), //
              ),
              const SizedBox(height: 20), //

              DropdownButtonFormField<int>(
                value: _extraKeycards,
                decoration: InputDecoration(
                  labelText: 'จำนวนคีย์การ์ด/กุญแจที่ต้องการ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ), //
                  prefixIcon: const Icon(Icons.vpn_key_outlined), //
                ),
                items: [1, 2, 3]
                    .map(
                      (num) =>
                          DropdownMenuItem(value: num, child: Text("$num ใบ")),
                    ) //
                    .toList(),
                onChanged: (v) => setState(() => _extraKeycards = v!), //
              ),
              const SizedBox(height: 25), //

              _buildSectionTitle(
                "3. หมวดการจัดการและกฎระเบียบ (Preferences & Rules)",
              ), //
              _buildTextField(
                _emergencyNameController,
                'ชื่อ-นามสกุล ผู้ติดต่อฉุกเฉิน',
                Icons.contact_phone_outlined,
              ), //
              _buildTextField(
                _emergencyRelationController,
                'ความสัมพันธ์กับผู้เช่า',
                Icons.people_outline,
              ), //
              _buildTextField(
                _emergencyPhoneController,
                'เบอร์โทรศัพท์ผู้ติดต่อฉุกเฉิน',
                Icons.phone_callback_outlined,
                isPhone: true,
              ), //

              CheckboxListTile(
                title: const Text(
                  "ยอมรับว่าหอพักนี้เป็นเขตปลอดบุหรี่และไม่อนุญาตให้เลี้ยงสัตว์ภายในอาคาร",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ), //
                ),
                value: _agreedToRules,
                controlAffinity: ListTileControlAffinity.leading, //
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF1DB954),
                onChanged: (v) => setState(() => _agreedToRules = v!), //
              ),
            ] else ...[
              _buildSectionTitle("ข้อมูลส่วนตัวแม่บ้าน"), //
              _buildTextField(
                _nameController,
                'ชื่อ-นามสกุล',
                Icons.person_outline,
              ), //
              _buildTextField(
                _phoneController,
                'เบอร์โทรศัพท์แม่บ้าน',
                Icons.phone_android_outlined,
                isPhone: true,
              ), //
              _buildTextField(
                _emailController,
                'Email',
                Icons.email_outlined,
              ), //
              _buildTextField(
                _lineIdController,
                'Line ID',
                Icons.chat_bubble_outline,
              ), //
              _buildTextField(
                _passwordController,
                'Password (6 ตัวขึ้นไป)',
                Icons.lock_outline,
                isPassword: true,
              ), //
            ],

            const SizedBox(height: 25), //

            SizedBox(
              width: double.infinity, //
              height: 55, //
              child: ElevatedButton(
                onPressed: () => _register(passedRoomNo), //
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954), //
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ), //
                  elevation: 2, //
                ),
                child: const Text(
                  "ลงทะเบียนสมาชิก",
                  style: TextStyle(
                    fontSize: 18,
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, top: 10), //
      child: Text(
        title, //
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF101828),
        ), //
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData prefixIcon, {
    bool isPassword = false,
    bool isPhone = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20), //
      child: TextField(
        controller: controller,
        obscureText: isPassword, //
        maxLines: maxLines, //
        keyboardType: isPhone
            ? TextInputType.phone
            : (maxLines > 1 ? TextInputType.multiline : TextInputType.text), //
        decoration: InputDecoration(
          labelText: label, //
          prefixIcon: Icon(prefixIcon), //
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
          ), //
        ),
      ),
    );
  }
}

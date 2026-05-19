import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../widgets/tenant_bottom_nav.dart';
import '../../widgets/tenant_app_bar.dart';

class TenantBooking extends StatefulWidget {
  const TenantBooking({super.key});

  @override
  State<TenantBooking> createState() => _TenantBookingState();
}

class _OriginalFacilityItem {
  final String name;
  final String emoji;
  _OriginalFacilityItem(this.name, this.emoji);
}

class _TenantBookingState extends State<TenantBooking> {
  int _activeTab = 0; // 0 = จองส่วนกลาง, 1 = ประวัติการจอง
  String? _selectedFacility; // โหลดค่าแบบไดนามิกตามฐานข้อมูลจริงของเจ้าของหอพัก
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final user = FirebaseAuth.instance.currentUser;

  int _toMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  bool _isValidDuration() {
    if (_startTime == null || _endTime == null) return false;
    int diff = _toMinutes(_endTime!) - _toMinutes(_startTime!);
    return diff >= 60;
  }

  // จัดรูปแบบเวลาให้เป็นระบบไทยมาตรฐานสากลต่อท้ายด้วย "น." เสมอ
  String _formatTimeThai(TimeOfDay? time) {
    if (time == null) return "--:--";
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute น.";
  }

  // แปลงข้อความจากฐานข้อมูลให้เป็นระบบไทยเวลา 24 ชม.
  String _formatTimeStringThai(String timeStr) {
    if (timeStr.isEmpty || timeStr == "--:--") return "--:--";
    String cleanTime = timeStr.replaceAll(RegExp(r'[^0-9:]'), '').trim();
    return "$cleanTime น.";
  }

  // 🌟 บังคับให้หน้าต่าง TimePicker แสดงผลเป็นแบบ 24 ชั่วโมง (ไทยสไตล์) เสมอ
  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? TimeOfDay.now())
          : (_endTime ?? TimeOfDay.now()),
      helpText: isStart ? "เลือกเวลาเริ่มใช้งาน" : "เลือกเวลาสิ้นสุด",
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          // บังคับแปลงค่า Environment ให้ข้ามระบบ AM/PM ดรอปดาวน์
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          _endTime = null;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _confirmBooking(
    String tenantName,
    String roomNo,
    List<QueryDocumentSnapshot> existing,
  ) async {
    if (_selectedFacility == null || _startTime == null || _endTime == null)
      return;

    int newS = _toMinutes(_startTime!);
    int newE = _toMinutes(_endTime!);

    // 🛠️ ปรับปรุงความปลอดภัย: ป้องกันอาการแครชหากฟิลด์นาทีในฐานข้อมูลเป็น Null
    bool isOverlap = existing.any((doc) {
      var data = doc.data() as Map<String, dynamic>? ?? {};
      int startMinutes = data['startMinutes'] ?? 0;
      int endMinutes = data['endMinutes'] ?? 0;
      return (newS < endMinutes && newE > startMinutes);
    });

    if (isOverlap) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("ช่วงเวลาที่เลือกมีการจองไว้แล้ว กรุณาเลือกเวลาอื่น"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // แปลงค่าเวลาให้อยู่ในระบบ String 24 ชม. ที่สะอาดสะอ้านก่อนเซฟลงฐานข้อมูล
    String start24hStr =
        "${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}";
    String end24hStr =
        "${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}";

    await FirebaseFirestore.instance.collection('bookings').add({
      'facilityName': _selectedFacility,
      'startTime': start24hStr, // บันทึกเป็น 24 ชม. ตายตัว
      'endTime': end24hStr, // บันทึกเป็น 24 ชม. ตายตัว
      'startMinutes': newS,
      'endMinutes': newE,
      'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      'tenantName': tenantName,
      'roomNo': roomNo,
      'tenantUid': user?.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ส่งคำขอจองพื้นที่ส่วนกลางสำเร็จ!")),
      );
      setState(() {
        _startTime = null;
        _endTime = null;
        _activeTab = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: buildTenantAppBar(context, title: "จองส่วนกลาง"),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData)
            return const Center(child: CircularProgressIndicator());

          var userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
          String tenantName = userData['name'] ?? "ผู้เช่า";

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('rooms')
                .where('tenantName', isEqualTo: tenantName)
                .limit(1)
                .snapshots(),
            builder: (context, roomSnap) {
              // 🛠️ ปรับปรุงความปลอดภัย: ป้องกันการดึงค่าจากด็อคคิวเมนต์สแนปช็อตตรงๆ
              String roomNo = "N/A";
              if (roomSnap.hasData && roomSnap.data!.docs.isNotEmpty) {
                var roomData =
                    roomSnap.data!.docs.first.data() as Map<String, dynamic>?;
                roomNo = roomData?['roomNo'] ?? "N/A";
              }

              return Column(
                children: [
                  _buildTabs(),
                  Expanded(
                    child: _activeTab == 0
                        ? _buildBookingView(tenantName, roomNo)
                        : _buildHistoryView(),
                  ),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: buildTenantBottomNav(context, 3),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [_tabItem(0, "จองส่วนกลาง"), _tabItem(1, "ประวัติการจอง")],
        ),
      ),
    );
  }

  Widget _tabItem(int index, String title) {
    bool isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _activeTab = index;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF1F5F9) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF101828) : Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingView(String tenantName, String roomNo) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('facilities').snapshots(),
      builder: (context, facilitySnap) {
        List<_OriginalFacilityItem> dynamicFacilities = [];

        if (facilitySnap.hasData && facilitySnap.data!.docs.isNotEmpty) {
          dynamicFacilities = facilitySnap.data!.docs.map((doc) {
            var fData = doc.data() as Map<String, dynamic>;
            return _OriginalFacilityItem(
              fData['name'] ?? "ส่วนกลาง",
              fData['emoji'] ?? "🏢",
            );
          }).toList();
        } else {
          dynamicFacilities = [
            _OriginalFacilityItem("ยิม (ฟิตเนส)", "💪"),
            _OriginalFacilityItem("ห้องสมุด", "📚"),
            _OriginalFacilityItem("เลานจ์ส่วนกลาง", "🛋️"),
          ];
        }

        if (dynamicFacilities.isNotEmpty) {
          bool stillExists = dynamicFacilities.any(
            (f) => f.name == _selectedFacility,
          );
          if (!stillExists) {
            _selectedFacility = dynamicFacilities.first.name;
          }
        } else {
          _selectedFacility = null;
        }

        return SingleChildScrollView(
          child: Column(
            children: [
              if (dynamicFacilities.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 20,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: dynamicFacilities
                        .map((f) => _facilityCard(f.name, f.emoji))
                        .toList(),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Text(
                    "ขณะนี้เจ้าของหอพักยังไม่ได้เปิดระบบสิ่งอำนวยความสะดวกส่วนกลาง",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),

              if (_selectedFacility != null) ...[
                _buildHorizontalCalendar(),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .where('facilityName', isEqualTo: _selectedFacility)
                      .where(
                        'date',
                        isEqualTo: DateFormat(
                          'yyyy-MM-dd',
                        ).format(_selectedDate),
                      )
                      .snapshots(),
                  builder: (context, bookingSnap) {
                    List<QueryDocumentSnapshot> bookings = bookingSnap.hasData
                        ? bookingSnap.data!.docs
                        : [];

                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildTimePickerSection(),
                          const SizedBox(height: 20),
                          _buildExistingBookingsList(bookings),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed:
                                  (_startTime != null &&
                                      _endTime != null &&
                                      _isValidDuration())
                                  ? () => _confirmBooking(
                                      tenantName,
                                      roomNo,
                                      bookings,
                                    )
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF101828),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text(
                                "ยืนยันการจองส่วนกลาง",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // --- 🌟 หน้าประวัติการจองส่วนตัวของผู้เช่าย้อนหลัง ปรับระบบไทยสมบูรณ์แบบ 🌟 ---
  Widget _buildHistoryView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('tenantUid', isEqualTo: user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              "คุณยังไม่มีประวัติการจองพื้นที่ส่วนกลางในระบบ",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        // 🛠️ [จุดที่แก้ไขข้อผิดพลาด]: ดึงค่าผ่าน Map แทนการเจาะข้อมูล snapshot ตรงๆ ป้องกัน StateError บาดลึกระบบ
        var mySortedBookings = docs.toList()
          ..sort((a, b) {
            var dataA = a.data() as Map<String, dynamic>? ?? {};
            var dataB = b.data() as Map<String, dynamic>? ?? {};

            String dateA = dataA['date'] ?? "";
            String dateB = dataB['date'] ?? "";
            int startA = dataA['startMinutes'] ?? 0;
            int startB = dataB['startMinutes'] ?? 0;

            int comp = dateB.compareTo(dateA);
            if (comp == 0) return startB.compareTo(startA);
            return comp;
          });

        String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        int currentMinutesNow =
            TimeOfDay.now().hour * 60 + TimeOfDay.now().minute;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: mySortedBookings.length,
          itemBuilder: (context, idx) {
            var data = mySortedBookings[idx].data() as Map<String, dynamic>;
            String fName = data['facilityName'] ?? "พื้นที่ส่วนกลาง";
            String bDate = data['date'] ?? "";
            String sTime = data['startTime'] ?? "--:--";
            String eTime = data['endTime'] ?? "--:--";

            DateTime parsedDate = DateTime.tryParse(bDate) ?? DateTime.now();
            String formattedDateThai = DateFormat(
              'EE dd MMM yyyy',
              'th',
            ).format(parsedDate);

            bool isPast =
                bDate.compareTo(todayStr) < 0 ||
                (bDate == todayStr &&
                    (data['endMinutes'] ?? 0) < currentMinutesNow);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.01),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        fName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isPast
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isPast ? "ผ่านไปแล้ว" : "กำลังจะมาถึง",
                          style: TextStyle(
                            color: isPast
                                ? Colors.grey
                                : const Color(0xFF10B981),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 25),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_outlined,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formattedDateThai,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "${_formatTimeStringThai(sTime)} - ${_formatTimeStringThai(eTime)}",
                        style: const TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHorizontalCalendar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 25),
          child: Text(
            "เลือกวันที่ต้องการจอง",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 14,
            itemBuilder: (context, index) {
              DateTime date = DateTime.now().add(Duration(days: index));
              bool isSelected =
                  DateFormat('yyyy-MM-dd').format(date) ==
                  DateFormat('yyyy-MM-dd').format(_selectedDate);
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedDate = date;
                  _startTime = null;
                  _endTime = null;
                }),
                child: Container(
                  width: 65,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1DB954) : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('E', 'th').format(date),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        DateFormat('dd').format(date),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF101828),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimePickerSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.access_time, color: Color(0xFF1DB954), size: 20),
              SizedBox(width: 10),
              Text(
                "ระบุเวลาใช้งาน (ขั้นต่ำ 1 ชม.)",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _timeBox(
                "เวลาเริ่ม",
                _startTime,
                () => _selectTime(context, true),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.arrow_forward, color: Colors.grey, size: 16),
              ),
              _timeBox(
                "เวลาสิ้นสุด",
                _endTime,
                () => _selectTime(context, false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeBox(String label, TimeOfDay? time, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              Text(
                _formatTimeThai(time),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExistingBookingsList(List<QueryDocumentSnapshot> bookings) {
    if (bookings.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 40),
        const Text(
          "ช่วงเวลาที่มีคนจองแล้วของวันนี้",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.redAccent,
          ),
        ),
        const SizedBox(height: 10),
        ...bookings.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String startText = data['startTime'] ?? "";
          String endText = data['endTime'] ?? "";
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.block, size: 14, color: Colors.red),
                const SizedBox(width: 10),
                Text(
                  "${_formatTimeStringThai(startText)} - ${_formatTimeStringThai(endText)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  "ห้อง ${data['roomNo']}",
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _facilityCard(String name, String emoji) {
    bool isSelected = _selectedFacility == name;
    return Container(
      width: 105,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedFacility = name;
          _startTime = null;
          _endTime = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF101828) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? Colors.transparent : Colors.grey.shade100,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 8),
              Text(
                name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

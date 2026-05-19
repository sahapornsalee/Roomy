import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RoomDetails extends StatelessWidget {
  final Map<String, dynamic> room;

  const RoomDetails({super.key, required this.room});

  // ฟังก์ชันแปลงลิงก์ Google Drive ให้แสดงผลรูปภาพบนแอปสำเร็จ
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

  // 🌟 [ปรับปรุงใหม่]: ระบบจองห้องพักผ่านระบบ Transaction ป้องกันการจองซ้อนพ่วงระบบคำนวณวันหมดอายุ 🌟
  Future<void> _bookRoom(BuildContext context, String roomDocId) async {
    try {
      // 1. ดึงข้อมูลจำนวนวันที่โฮลด์สเตตการจองจาก config ของเจ้าของหอพัก (ค่าเริ่มต้นเป็น 2 วัน)
      var configSnap = await FirebaseFirestore.instance
          .collection('settings')
          .doc('config')
          .get();
      int durationDays = 2;
      if (configSnap.exists &&
          configSnap.data()?['bookingDurationDays'] != null) {
        durationDays = (configSnap.data()?['bookingDurationDays'] as num)
            .toInt(); //
      }

      // 2. รันระบบ Transaction เพื่อล็อกคลาวด์ให้จองได้เพียงคนเดียวในเวลาเดียวกัน
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference roomRef = FirebaseFirestore.instance
            .collection('rooms')
            .doc(roomDocId);
        DocumentSnapshot roomSnapshot = await transaction.get(roomRef);

        if (!roomSnapshot.exists) throw "ไม่พบข้อมูลห้องพักในระบบ";

        var currentRoomData = roomSnapshot.data() as Map<String, dynamic>;
        String currentStatus = currentRoomData['status'] ?? 'ว่าง';

        // ดักตรวจสอบเช็กหมดอายุภายในตัว Transaction
        Timestamp? expiryTime =
            currentRoomData['bookingExpiresAt'] as Timestamp?;
        if (currentStatus == 'จองแล้ว' &&
            expiryTime != null &&
            DateTime.now().isAfter(expiryTime.toDate())) {
          currentStatus = 'ว่าง'; // หมดอายุแล้ว ถือว่าเป็นห้องว่าง
        }

        if (currentStatus != 'ว่าง') {
          throw "ห้องนี้ไม่ว่างสำหรับการจองแล้ว (มีคนจองตัดหน้าหรือมีผู้เช่าแล้วครับ)";
        }

        // คำนวณวันหมดอายุตามเวลาไทยสากล
        DateTime expirationDate = DateTime.now().add(
          Duration(days: durationDays),
        );

        // อัปเดตข้อมูลล็อกใบงานการจองชุดนี้ทันที
        transaction.update(roomRef, {
          'status': 'จองแล้ว',
          'bookedAt': FieldValue.serverTimestamp(),
          'bookingExpiresAt': Timestamp.fromDate(
            expirationDate,
          ), // ฝังวันหมดอายุ
        });
      });

      if (context.mounted) {
        _showRegisterTenantDialog(context); //
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("⚠️ จองไม่สำเร็จ: $e"),
            backgroundColor: Colors.redAccent, //
          ),
        );
      }
    }
  }

  void _showRegisterTenantDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, //
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ), //
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF1DB954), size: 28), //
            SizedBox(width: 10), //
            Text(
              "จองห้องพักสำเร็จ!",
              style: TextStyle(fontWeight: FontWeight.bold), //
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min, //
          crossAxisAlignment: CrossAxisAlignment.start, //
          children: [
            Text(
              "ห้อง ${room['roomNo'] ?? ''} ได้เปลี่ยนสถานะเป็นจองแล้วเรียบร้อย", //
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ), //
            ),
            const SizedBox(height: 10), //
            const Text(
              "ขั้นตอนถัดไป: ระบบบังคับให้คุณต้องลงทะเบียนสมัครสมาชิกเป็นผู้เช่าของหอพัก เพื่อใช้จัดเก็บข้อมูลสัญญา บัญชีค่าเช่า และแจ้งซ่อมส่วนตัวภายในแอปพลิเคชัน",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
                height: 1.4,
              ), //
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity, //
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); //
                Navigator.pushNamed(
                  context,
                  '/register',
                  arguments: {'roomNo': room['roomNo']},
                ); //
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF101828), //
                padding: const EdgeInsets.symmetric(vertical: 15), //
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ), //
              ),
              child: const Text(
                "ไปหน้าสมัครสมาชิกผู้เช่า",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ), //
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List internalPhotos = room['internalPhotos'] as List? ?? []; //
    if (internalPhotos.isEmpty && room['imageUrl'] != null) {
      internalPhotos = [room['imageUrl']]; //
    }

    // 🌟 เปิดระบบสตรีมซิงก์ข้อมูลห้องพักเรียลไทม์ เพื่อตรวจสอบและเคลียร์สเตตัสหมดอายุแบบเรียลไทม์ 🌟
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .where('roomNo', isEqualTo: room['roomNo'])
          .limit(1)
          .snapshots(),
      builder: (context, roomSnap) {
        Map<String, dynamic> liveRoomData = room;
        String roomDocId = "";
        String currentStatus = room['status'] ?? "ว่าง";

        if (roomSnap.hasData && roomSnap.data!.docs.isNotEmpty) {
          var doc = roomSnap.data!.docs.first;
          roomDocId = doc.id;
          liveRoomData = doc.data() as Map<String, dynamic>;
          currentStatus = liveRoomData['status'] ?? "ว่าง";

          // ⚙️ [ระบบทำลายตัวเอง]: ตรวจสอบหากหมดเวลาโฮลด์แล้วผู้เช่ายังไม่มาทำสัญญา ปรับคืนเป็น "ว่าง" ทันที ⚙️
          Timestamp? expiresAt = liveRoomData['bookingExpiresAt'] as Timestamp?;
          if (currentStatus == "จองแล้ว" && expiresAt != null) {
            if (DateTime.now().isAfter(expiresAt.toDate())) {
              FirebaseFirestore.instance
                  .collection('rooms')
                  .doc(roomDocId)
                  .update({
                    'status': 'ว่าง',
                    'bookedAt': FieldValue.delete(),
                    'bookingExpiresAt': FieldValue.delete(),
                  });
              currentStatus =
                  "ว่าง"; // สลับตัวแปรอินไลน์เพื่อให้ UI อัปเดตทันที
            }
          }
        }

        // ตัวแปรควบคุมพฤติกรรมความปลอดภัยของปุ่มจองห้องพัก
        bool isButtonEnabled = currentStatus == "ว่าง";
        String buttonText = "จองห้องพักตอนนี้";
        Color buttonColor = const Color(0xFF101828);

        if (currentStatus == "มีผู้เช่า") {
          buttonText = "ห้องนี้มีผู้เช่าพักอาศัยอยู่แล้ว 🛑";
          buttonColor = Colors.grey;
        } else if (currentStatus == "จองแล้ว") {
          Timestamp? expiresAt = liveRoomData['bookingExpiresAt'] as Timestamp?;
          String dateText = "";
          if (expiresAt != null) {
            dateText =
                " (หมดอายุ ${DateFormat('dd/MM HH:mm น.').format(expiresAt.toDate())})"; //
          }
          buttonText = "ห้องนี้ติดสถานะถูกจองแล้ว$dateText"; //
          buttonColor = Colors.grey;
        } else if (currentStatus == "ทำความสะอาด") {
          buttonText = "ห้องพักกำลังทำความสะอาด 🧹";
          buttonColor = Colors.grey;
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB), //
          appBar: AppBar(
            title: const Text(
              "รายละเอียดห้องพัก",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ), //
            ),
            backgroundColor: Colors.white, //
            elevation: 0, //
            iconTheme: const IconThemeData(color: Colors.black), //
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, //
              children: [
                _buildImageCarousel(context, internalPhotos), //

                Padding(
                  padding: const EdgeInsets.all(20), //
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, //
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween, //
                        children: [
                          Text(
                            liveRoomData['title'] ??
                                (liveRoomData['roomNo'] != null
                                    ? "ห้อง ${liveRoomData['roomNo']}"
                                    : "ไม่มีชื่อห้อง"), //
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ), //
                          ),
                          Text(
                            "฿${liveRoomData['price']} / เดือน", //
                            style: const TextStyle(
                              fontSize: 20,
                              color: Color(0xFF1DB954),
                              fontWeight: FontWeight.bold,
                            ), //
                          ),
                        ],
                      ),
                      const SizedBox(height: 15), //

                      const Text(
                        "สิ่งอำนวยความสะดวก",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ), //
                      ),
                      const SizedBox(height: 10), //
                      Wrap(
                        spacing: 8, //
                        runSpacing: 8, //
                        children: (liveRoomData['tags'] as List? ?? [])
                            .map(
                              (tag) => Chip(
                                label: Text(
                                  tag,
                                  style: const TextStyle(fontSize: 12),
                                ), //
                                backgroundColor: Colors.grey[100], //
                                side: BorderSide.none, //
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ), //
                              ),
                            )
                            .toList(), //
                      ),

                      const Divider(height: 40), //

                      const Text(
                        "ข้อมูลติดต่อเจ้าของหอพัก",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ), //
                      ),
                      const SizedBox(height: 15), //
                      // 🛠️ แก้ไขส่วนดึงข้อมูลติดต่อ: ดึงจากคอลเลกชัน users ที่มี role เป็น owner
                      FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .where('role', isEqualTo: 'owner')
                            .limit(1)
                            .get(),
                        builder: (context, ownerSnap) {
                          String ownerName = "ไม่ระบุ";
                          String phone = "ไม่ระบุ";
                          String lineId = "ไม่ระบุ";
                          String facebook = "ไม่ระบุ";

                          if (ownerSnap.hasData &&
                              ownerSnap.data!.docs.isNotEmpty) {
                            var ownerData =
                                ownerSnap.data!.docs.first.data()
                                    as Map<String, dynamic>;
                            ownerName = ownerData['name'] ?? "ไม่ระบุ";
                            phone = ownerData['phone'] ?? "ไม่ระบุ";
                            lineId = ownerData['lineId'] ?? "ไม่ระบุ";
                            facebook = ownerData['facebook'] ?? "ไม่ระบุ";
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _contactItem(
                                Icons.person,
                                "ชื่อผู้ดูแล: $ownerName",
                              ),
                              _contactItem(
                                Icons.phone,
                                "เบอร์โทรศัพท์: $phone",
                              ),
                              _contactItem(
                                Icons.chat_bubble,
                                "Line ID: $lineId",
                              ),
                              _contactItem(
                                Icons.facebook,
                                "Facebook: $facebook",
                              ), //
                            ],
                          );
                        },
                      ),

                      const Divider(height: 40), //

                      const Text(
                        "รายละเอียดเพิ่มเติม",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ), //
                      ),
                      const SizedBox(height: 10), //
                      Text(
                        liveRoomData['description'] ??
                            "ไม่มีรายละเอียดเพิ่มเติมเกี่ยวกับห้องนี้", //
                        style: TextStyle(
                          color: Colors.grey[700],
                          height: 1.5,
                          fontSize: 15,
                        ), //
                      ),
                      const SizedBox(height: 100), //
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(20.0), //
            decoration: BoxDecoration(
              color: Colors.white, //
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05), //
                  blurRadius: 10, //
                  offset: const Offset(0, -5), //
                ),
              ],
            ),
            child: ElevatedButton(
              // ควบคุมสิทธิ์การคลิกและการเปลี่ยนปุ่มแสดงผลไดนามิก
              onPressed: isButtonEnabled && roomDocId.isNotEmpty
                  ? () => _bookRoom(context, roomDocId)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor, //
                padding: const EdgeInsets.symmetric(vertical: 18), //
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ), //
                disabledBackgroundColor: Colors.grey.shade400,
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ), //
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageCarousel(BuildContext context, List photos) {
    return SizedBox(
      height: 300, //
      child: photos.isEmpty
          ? Container(
              color: Colors.grey[200], //
              child: const Icon(Icons.image, size: 100, color: Colors.grey), //
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal, //
              itemCount: photos.length, //
              itemBuilder: (context, index) {
                return Container(
                  width: MediaQuery.of(context).size.width * 0.9, //
                  margin: const EdgeInsets.all(10), //
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20), //
                    child: Image.network(
                      _convertToDirectLink(photos[index].toString()), //
                      fit: BoxFit.cover, //
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[200], //
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                          size: 50,
                        ), //
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _contactItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0), //
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1DB954), size: 22), //
          const SizedBox(width: 12), //
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))), //
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'room_details.dart'; //

class GuestHome extends StatefulWidget {
  const GuestHome({super.key});

  @override
  State<GuestHome> createState() => _GuestHomeState();
}

class _GuestHomeState extends State<GuestHome> {
  String _searchQuery = ""; //
  final TextEditingController _searchController = TextEditingController(); //

  // ปรับปรุงตัวดักจับสีสถานะให้รองรับสถานะแบบผสม (Composite Status) ได้ถูกต้องแม่นยำ
  Color _getStatusColor(String status) {
    if (status.contains("ทำความสะอาด")) {
      return const Color(
        0xFF0284C7,
      ); // สีฟ้า (สำหรับสถานะ ทำความสะอาด, ทำความสะอาด + มีผู้เช่า, ทำความสะอาด + จองแล้ว)
    } else if (status.contains("ว่าง")) {
      return const Color(0xFF1DB954); // สีเขียว
    } else if (status.contains("มีผู้เช่า")) {
      return const Color(0xFFE11D48); // สีแดง
    } else if (status.contains("จองแล้ว")) {
      return const Color(0xFFD97706); // สีส้ม
    }
    return Colors.grey; // สีเทาสำรองระบบความปลอดภัย
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), //
      body: Column(
        children: [
          _buildHeader(context), //
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rooms')
                  .snapshots(), //
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator()); //
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("ยังไม่มีข้อมูลห้องพัก")); //
                }

                // กรองข้อมูลตามหมายเลขห้องหรือชื่อหัวข้อ
                var filteredDocs = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>; //
                  var searchTarget =
                      (data['roomNo'] ?? data['title'] ?? "") //
                          .toString()
                          .toLowerCase(); //
                  return searchTarget.contains(_searchQuery.toLowerCase()); //
                }).toList(); //

                // 🌟 [เพิ่มฟิลเตอร์ระบบจัดเรียง]: เรียงลำดับหมายเลขห้องพักจาก "น้อยไปมาก"
                filteredDocs.sort((a, b) {
                  var dataA = a.data() as Map<String, dynamic>;
                  var dataB = b.data() as Map<String, dynamic>;
                  String roomA = (dataA['roomNo'] ?? "").toString();
                  String roomB = (dataB['roomNo'] ?? "").toString();
                  return roomA.compareTo(
                    roomB,
                  ); // จัดเรียงแบบ Ascending (จากน้อยไปมาก)
                });

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 20), //
                  itemCount: filteredDocs.length, //
                  itemBuilder: (context, index) {
                    var room =
                        filteredDocs[index].data() as Map<String, dynamic>; //
                    return _buildRoomCard(context, room: room); //
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
        top: 50,
        left: 20,
        right: 20,
        bottom: 30,
      ), //
      decoration: const BoxDecoration(
        color: Color(0xFF101828), //
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40), //
          bottomRight: Radius.circular(40), //
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, //
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.business_outlined,
                    color: Color(0xFF1DB954), //
                    size: 24, //
                  ),
                  SizedBox(width: 8), //
                  Text(
                    "Roomy", //
                    style: TextStyle(
                      color: Colors.white, //
                      fontSize: 20, //
                      fontWeight: FontWeight.bold, //
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/login'), //
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.05), //
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), //
                    side: const BorderSide(color: Colors.white12), //
                  ),
                ),
                child: const Text(
                  "เข้าสู่ระบบ", //
                  style: TextStyle(
                    color: Colors.white, //
                    fontWeight: FontWeight.bold, //
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30), //
          const Text(
            "ชีวิตลงตัว ที่พักที่คุณถูกใจ", //
            style: TextStyle(
              color: Colors.white, //
              fontSize: 26, //
              fontWeight: FontWeight.bold, //
            ),
          ),
          const Text(
            "ที่ Roomy", //
            style: TextStyle(
              color: Color(0xFF1DB954), //
              fontSize: 34, //
              fontWeight: FontWeight.bold, //
            ),
          ),
          const SizedBox(height: 30), //
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5), //
            decoration: BoxDecoration(
              color: Colors.white, //
              borderRadius: BorderRadius.circular(15), //
            ),
            child: TextField(
              controller: _searchController, //
              onChanged: (value) => setState(() => _searchQuery = value), //
              decoration: const InputDecoration(
                icon: Icon(Icons.search, color: Color(0xFF1DB954)), //
                hintText: "ค้นหาหมายเลขห้อง...", //
                border: InputBorder.none, //
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(
    BuildContext context, {
    required Map<String, dynamic> room,
  }) {
    String status = room['status'] ?? "ไม่ระบุ"; //

    List photos = room['internalPhotos'] as List? ?? []; //
    String displayImageUrl = ""; //

    if (photos.isNotEmpty && photos[0].toString().startsWith('http')) {
      displayImageUrl = photos[0]; //
    } else {
      displayImageUrl = room['imageUrl'] ?? ""; //
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => RoomDetails(room: room)), //
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), //
        decoration: BoxDecoration(
          color: Colors.white, //
          borderRadius: BorderRadius.circular(30), //
          boxShadow: const [
            BoxShadow(
              color: Colors.black12, //
              blurRadius: 15, //
              offset: Offset(0, 8), //
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, //
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30), //
                  ),
                  child: displayImageUrl.startsWith('http')
                      ? Image.network(
                          _convertToDirectLink(displayImageUrl), //
                          height: 220, //
                          width: double.infinity, //
                          fit: BoxFit.cover, //
                          errorBuilder: (context, error, stackTrace) =>
                              _buildImageError(), //
                        )
                      : _buildImageError(), //
                ),
                Positioned(
                  top: 15, //
                  right: 15, //
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14, //
                      vertical: 8, //
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        status,
                      ), // เรียกใช้งานชุดคำสั่งดักจับสี Regex ใหม่
                      borderRadius: BorderRadius.circular(15), //
                    ),
                    child: Text(
                      status, //
                      style: const TextStyle(
                        color: Colors.white, //
                        fontSize: 11, //
                        fontWeight: FontWeight.bold, //
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20), //
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, //
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, //
                    children: [
                      Text(
                        room['roomNo'] ?? "ห้องพัก", //
                        style: const TextStyle(
                          fontSize: 22, //
                          fontWeight: FontWeight.bold, //
                        ),
                      ),
                      Text(
                        "฿${room['price']}", //
                        style: const TextStyle(
                          fontSize: 22, //
                          fontWeight: FontWeight.bold, //
                          color: Color(0xFF1DB954), //
                        ),
                      ),
                    ],
                  ),
                  Text(
                    room['buildingName'] ?? "", //
                    style: const TextStyle(color: Colors.grey), //
                  ),
                  const SizedBox(height: 15), //
                  Wrap(
                    spacing: 10, //
                    children: (room['tags'] as List? ?? [])
                        .map(
                          (tag) => Chip(
                            label: Text(
                              tag, //
                              style: const TextStyle(fontSize: 10), //
                            ),
                            backgroundColor: Colors.grey[100], //
                            side: BorderSide.none, //
                          ),
                        )
                        .toList(), //
                  ),
                  const SizedBox(height: 20), //
                  SizedBox(
                    width: double.infinity, //
                    height: 50, //
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RoomDetails(room: room), //
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF101828), //
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15), //
                        ),
                      ),
                      child: const Text(
                        "ดูรายละเอียด", //
                        style: TextStyle(
                          color: Colors.white, //
                          fontWeight: FontWeight.bold, //
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageError() {
    return Container(
      height: 220, //
      width: double.infinity, //
      color: Colors.grey[200], //
      child: const Icon(Icons.broken_image, color: Colors.grey, size: 50), //
    );
  }
}

import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class GoogleDriveService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  Future<String?> uploadToDrive(File imageFile) async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) return null;

      final authHeaders = await account.authHeaders;
      final authenticateClient = GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(authenticateClient);

      String folderId =
          "15yUWBR9hxS37FHeGmP9SU8t9IidY8f08"; // ID โฟลเดอร์ที่คุณกำหนด

      var driveFile = drive.File();
      driveFile.name = "room_${DateTime.now().millisecondsSinceEpoch}.jpg";
      driveFile.parents = [folderId];

      var response = await driveApi.files.create(
        driveFile,
        uploadMedia: drive.Media(imageFile.openRead(), imageFile.lengthSync()),
      );

      return "https://drive.google.com/uc?export=view&id=${response.id}"; // คืนค่าลิงก์ตรง
    } catch (e) {
      print("Upload Error: $e");
      return null;
    }
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  GoogleAuthClient(this._headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

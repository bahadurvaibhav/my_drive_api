import 'package:http_server/http_server.dart';
import 'package:mime/mime.dart';

import 'my_drive_api.dart';

class MyDriveApiChannel extends ApplicationChannel {
  @override
  Future prepare() async {
    logger.onRecord.listen(
        (rec) => print("$rec ${rec.error ?? ""} ${rec.stackTrace ?? ""}"));
  }

  @override
  Controller get entryPoint {
    final router = Router();

    router.route("/uploadDocument").link(() => MediaUploadController());

    router.route("/files/*").link(() => FileController(
          "files/",
          onFileNotFound: (FileController controller, Request req) {
            print('File not found');
          },
        ));

    return router;
  }
}

class MediaUploadController extends ResourceController {
  MediaUploadController() {
    acceptedContentTypes = [ContentType("multipart", "form-data")];
  }

  @Operation.post()
  Future<Response> postMultipartForm() async {
    return MultiPartFormDataParser.multiPartData(
      request: request,
      folder: 'files/',
      onFileData: (multipart, path) async {},
    ).then(
      (object) async {
        return Response.ok({"msg": "Document uploaded"});
      },
    );
  }
}

class MultiPartFormDataParser {
  static Future<void> multiPartData(
      {Request request, String folder, Function onFileData}) async {
    final transformer = MimeMultipartTransformer(
        request.raw.headers.contentType.parameters["boundary"]);
    final parts = await transformer
        .bind(Stream.fromIterable([await request.body.decode<List<int>>()]))
        .toList();
    for (var part in parts) {
      final multipart = HttpMultipartFormData.parse(part);
      try {
        final content = multipart.cast<List<int>>();
        final String fileName =
            multipart.contentDisposition.parameters.values.first;
        onFileData(await multipart, '$folder/$fileName');

        final IOSink sink = File('$folder/$fileName').openWrite();
        await for (List<int> item in content) {
          sink.add(item);
        }
        await sink.flush();
        await sink.close();
      } catch (e) {
        print("MultipartFormData Exception : \n ${e}");
      }
    }
  }
}

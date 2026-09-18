import 'package:flutter_test/flutter_test.dart';
import 'package:takamaka_sdk_wrap/models/chat/upload_status_bean.dart';

void main() {
  group('UploadStatusBean', () {
    test('COMPLETE is treated as complete (rsclient tests)', () {
      final bean = UploadStatusBean.fromJson({
        'upload_content_id_hash': 'abc',
        'status': 'COMPLETE',
        'uploaded_chunk': 10,
      });
      expect(bean.isComplete, isTrue);
      expect(bean.isError, isFalse);
    });

    test('READY_FOR_DOWNLOAD is complete', () {
      final bean = UploadStatusBean.fromJson({
        'status': 'READY_FOR_DOWNLOAD',
        'uploaded_chunk': 3,
      });
      expect(bean.isComplete, isTrue);
    });

    test('Java verified=true is complete', () {
      final bean = UploadStatusBean.fromJson({
        'signature': 'hash',
        'verified': true,
        'size': 4096,
      });
      expect(bean.isComplete, isTrue);
      expect(bean.uploadContentIdentifyingHash, 'hash');
    });

    test('UPLOADING is not complete', () {
      final bean = UploadStatusBean.fromJson({
        'status': 'UPLOADING',
        'uploaded_chunk': 2,
      });
      expect(bean.isComplete, isFalse);
    });
  });
}

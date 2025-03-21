part of aliyun_oss_flutter;

class OSSClient {
  factory OSSClient() {
    return _instance!;
  }

  OSSClient._({
    required this.endpoint,
    required this.bucket,
  });

  /// * 初始化设置 `endpoint` `bucket` `credentials`
  /// * [credentials] 需要静态存储，避免每次获取
  /// * 一旦初始化，则 `signer` 清空，上传前会重新拉取 OSS 信息
  static OSSClient init({
    required String endpoint,
    required String bucket,
    required Credentials credentials, // Now a static variable
    Dio? dio,
  }) {
    _instance = OSSClient._(
      endpoint: endpoint,
      bucket: bucket,
    );
    _credentials = credentials;
    _signer = Signer(_credentials!); // Initialize signer with credentials

    if (dio != null) {
      _http = dio;
    }
    return _instance!;
  }

  static OSSClient? _instance;
  static Credentials? _credentials;
  static Signer? _signer;
  static late Dio _http; // Ensure it's properly initialized

  final String endpoint;
  final String bucket;

  /// * 上传对象
  /// * [bucket] [endpoint] 一次性生效
  /// * [path] 上传路径，如不写则自动生成
  Future<OSSObject> putObject({
    required OSSObject object,
    String? bucket,
    String? endpoint,
    String? path,
  }) async {
    await verify(); // Ensure credentials are valid

    final String objectPath = object.resourcePath(path);
    final Map<String, dynamic> safeHeaders = _signer!.sign(
      httpMethod: 'PUT',
      resourcePath: '/${bucket ?? this.bucket}/$objectPath',
      headers: {
        'content-type': object.mediaType.mimeType,
      },
    ).toHeaders();

    try {
      final String url =
          'https://${bucket ?? this.bucket}.${endpoint ?? this.endpoint}/$objectPath';
      final Uint8List bytes = object.bytes;

      await _http.put<void>(
        url,
        data: Stream.fromIterable(bytes.map((e) => [e])),
        options: Options(
          headers: {
            ...safeHeaders,
            'content-length': object.length,
          },
          contentType: object._mediaType.mimeType,
        ),
      );

      return object..uploadSuccessful(url);
    } catch (e) {
      rethrow;
    }
  }

  /// 验证检查
  Future<void> verify() async {
    if (_credentials == null) {
      throw Exception("OSS credentials have not been initialized.");
    }

    // Check if the security token has expired
    if (_credentials!.useSecurityToken &&
        _credentials!.expiration!.isBefore(DateTime.now().toUtc())) {
      throw Exception("OSS credentials have expired. Please reinitialize.");
    }

    // Ensure the Signer uses the latest credentials
    if (_signer == null) {
      _signer = Signer(_credentials!);
    }
  }
}
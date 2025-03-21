part of aliyun_oss_flutter;

class OSSClient {
  factory OSSClient() {
    return _instance!;
  }

  OSSClient._({
    required this.endpoint,
    required this.bucket,
  }) {
    _signer = null;
  }

  /// * 初始化设置`endpoint` `bucket` `credentials`
  /// * [credentials] 需要静态存储，避免每次获取
  /// * 一旦初始化，则`signer`清空，上传前会重新拉取oss信息
  static OSSClient init({
    required String endpoint,
    required String bucket,
    required Credentials credentials, // Changed to a static variable
    Dio? dio,
  }) {
    _instance = OSSClient._(
      endpoint: endpoint,
      bucket: bucket,
    );
    _credentials = credentials;
    _signer = Signer(_credentials!);
    if (dio != null) {
      _http = dio;
    }
    return _instance!;
  }

  static OSSClient? _instance;
  static Credentials? _credentials;
  static Signer? _signer;

  final String endpoint;
  final String bucket;

  /// * [bucket] [endpoint] 一次性生效
  /// * [path] 上传路径 如不写则自动以 Object[type] [time] 生成path
  Future<OSSObject> putObject({
    required OSSObject object,
    String? bucket,
    String? endpoint,
    String? path,
  }) async {
    await verify(); // Ensure credentials are still valid

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
          headers: <String, dynamic>{
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

    // 使用 securityToken 进行鉴权，则判断 securityToken 是否过期
    if (_credentials!.useSecurityToken &&
        _credentials!.expiration!.isBefore(DateTime.now().toUtc())) {
      throw Exception("OSS credentials have expired. Please reinitialize.");
    }

    // 确保 Signer 也使用最新的凭据
    if (_signer == null) {
      _signer = Signer(_credentials!);
    }
  }
}
class ScanResult {
  final String imagePath;
  final String response;
  final String location;
  final String storeName;
  final DateTime timestamp;
  final String imageUrl;

  ScanResult({
    required this.imagePath,
    required this.response,
    required this.location,
    required this.storeName,
    required this.timestamp,
    required this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'imagePath': imagePath,
      'response': response,
      'location': location,
      'storeName': storeName,
      'timestamp': timestamp.toIso8601String(),
      'imageUrl': imageUrl,
    };
  }

  factory ScanResult.fromMap(Map<String, dynamic> map) {
    return ScanResult(
      imagePath: map['imagePath'],
      response: map['response'],
      location: map['location'],
      storeName: map['storeName'],
      timestamp: DateTime.parse(map['timestamp']),
      imageUrl: map['imageUrl'],
    );
  }
}

class Song {
  final String videoId;
  final String title;
  final String artist;
  final String thumbnailUrl;
  final int durationSeconds;

  /// Kolom 'id' dari tabel playlist_songs. Dipakai untuk MENGHAPUS lagu:
  /// rute hapus backend berbunyi
  ///     DELETE /api/playlist/:playlistId/songs/:songId
  /// dan menghapus dengan
  ///     WHERE id = ? AND playlist_id = ?
  /// Jadi yang harus dikirim adalah KOLOM id (angka), BUKAN videoId.
  /// Sebelumnya aplikasi mengirim videoId sehingga tidak ada baris yang
  /// cocok dan lagu tidak pernah terhapus.
  final String id;

  Song({
    required this.videoId,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    required this.durationSeconds,
    this.id = '',
  });

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        id: (j['id'] ?? j['songId'] ?? j['song_id'] ?? '').toString(),
        videoId: (j['videoId'] ?? j['video_id'] ?? '').toString(),
        title: j['title'] ?? '',
        artist: j['artist'] ?? '',
        thumbnailUrl: (j['thumbnailUrl'] ?? (j['thumb'] ?? j['thumbnailUrl'] ?? j['thumbnail']) ?? j['thumbnail']) ?? '',
        durationSeconds: (j['durationSeconds'] ?? j['duration'] ?? j['durasi']) is int
            ? (j['durationSeconds'] ?? j['duration'] ?? j['durasi'])
            : int.tryParse('${(j['durationSeconds'] ?? j['duration'] ?? j['durasi'])}') ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'title': title,
        'artist': artist,
        'thumbnailUrl': thumbnailUrl,
        'durationSeconds': durationSeconds,
      };
}

class IsanUser {
  final String id;
  final String username;
  final String email;
  final int createdAt;

  IsanUser({required this.id, required this.username, required this.email, required this.createdAt});

  factory IsanUser.fromJson(Map<String, dynamic> j) => IsanUser(
        id: j['id']?.toString() ?? '',
        username: j['username'] ?? '',
        email: j['email'] ?? '',
        createdAt: j['createdAt'] is int ? j['createdAt'] : int.tryParse('${j['createdAt']}') ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'createdAt': createdAt,
      };
}

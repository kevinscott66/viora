import 'dart:convert';
import '../services/moment_link.dart';

class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.date,
    required this.moment,
    this.note = '',
    this.photo,
  });
  final String id, note;
  final DateTime date;
  final ReceivedMoment moment;
  final String? photo;
  Map<String, dynamic> toJson() => {
    'version': 1,
    'id': id,
    'date': date.toIso8601String(),
    'moment': {...moment.summary, 'note': moment.note},
    'note': note,
    if (photo != null) 'photo': photo,
  };
  factory DiaryEntry.fromJson(Map<String, dynamic> data) {
    final moment = ReceivedMoment.parse(
      Uri(
        scheme: 'viora',
        host: 'moment',
        fragment: jsonEncode(data['moment']),
      ),
    );
    if (data['version'] != 1 ||
        moment == null ||
        !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(data['id'] as String)) {
      throw const FormatException('Invalid diary entry');
    }
    return DiaryEntry(
      id: data['id'],
      date: DateTime.parse(data['date']),
      moment: moment,
      note: data['note'] as String? ?? '',
      photo: data['photo'] as String?,
    );
  }
  bool matches(String query, DateTime? day) =>
      (day == null ||
          (date.year == day.year &&
              date.month == day.month &&
              date.day == day.day)) &&
      '${moment.title} ${moment.artists.join(' ')} ${moment.lyric} $note'
          .toLowerCase()
          .replaceAll('ё', 'е')
          .contains(query.trim().toLowerCase().replaceAll('ё', 'е'));
}

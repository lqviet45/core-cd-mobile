import 'package:decimal/decimal.dart';
import 'package:json_annotation/json_annotation.dart';

/// Chuyển số JSON sang [Decimal] — **tiền và lãi suất không bao giờ đi qua `double` trong logic**.
///
/// `jsonDecode` đã trả `int`/`double`; với `double` ta in ra tối đa 8 chữ số thập phân (đủ cho lãi suất 6 chữ số
/// và tiền VND) rồi mới parse, để tránh dạng khoa học (`1e-7`) mà `Decimal.parse` không nhận.
Decimal decimalFromJson(Object? value) => switch (value) {
  null => throw const FormatException('Thiếu giá trị số.'),
  final int v => Decimal.fromInt(v),
  final double v => Decimal.parse(v.toStringAsFixed(8)),
  final String v => Decimal.parse(v),
  _ => throw FormatException('Không phải số: $value'),
};

class DecimalConverter implements JsonConverter<Decimal, Object?> {
  const DecimalConverter();

  @override
  Decimal fromJson(Object? json) => decimalFromJson(json);

  @override
  Object? toJson(Decimal object) => object.toString();
}

class NullableDecimalConverter implements JsonConverter<Decimal?, Object?> {
  const NullableDecimalConverter();

  @override
  Decimal? fromJson(Object? json) =>
      json == null ? null : decimalFromJson(json);

  @override
  Object? toJson(Decimal? object) => object?.toString();
}

/// Ngày/giờ từ backend. Một số trường không có hậu tố múi giờ (`2026-07-15T00:00:00`) – luôn hiểu là **UTC**
/// (ngày nghiệp vụ), nếu không `DateTime.parse` sẽ coi là giờ máy và hiển thị lệch ngày.
DateTime parseUtc(String s) {
  final hasZone = s.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s);
  return DateTime.parse(hasZone ? s : '${s}Z').toUtc();
}

class UtcDateConverter implements JsonConverter<DateTime, String> {
  const UtcDateConverter();

  @override
  DateTime fromJson(String json) => parseUtc(json);

  @override
  String toJson(DateTime object) => object.toUtc().toIso8601String();
}

class NullableUtcDateConverter implements JsonConverter<DateTime?, String?> {
  const NullableUtcDateConverter();

  @override
  DateTime? fromJson(String? json) => json == null ? null : parseUtc(json);

  @override
  String? toJson(DateTime? object) => object?.toUtc().toIso8601String();
}

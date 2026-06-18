import 'package:freezed_annotation/freezed_annotation.dart';

part 'category.freezed.dart';
part 'category.g.dart';

enum CategoryType {
  @JsonValue('EXPENSE') expense,
  @JsonValue('INCOME') income,
}

@freezed
class Category with _$Category {
  const factory Category({
    required String id,
    required String workspaceId,
    required String name,
    required String icon,
    required String color,
    required CategoryType type,
  }) = _Category;

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
}

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fixmate/core/utils/validators.dart';

class BangladeshDivision {
  const BangladeshDivision({
    required this.code,
    required this.name,
    required this.districts,
  });

  factory BangladeshDivision.fromJson(Map<String, dynamic> json) =>
      BangladeshDivision(
        code: json['code'] as String,
        name: json['name'] as String,
        districts: List<String>.from(json['districts'] as List<dynamic>),
      );

  final String code;
  final String name;
  final List<String> districts;
}

final bangladeshLocationsProvider = FutureProvider<List<BangladeshDivision>>((
  ref,
) async {
  final raw = await rootBundle.loadString(
    'assets/data/bangladesh_locations.json',
  );
  final list = jsonDecode(raw) as List<dynamic>;
  return list
      .map(
        (dynamic value) =>
            BangladeshDivision.fromJson(value as Map<String, dynamic>),
      )
      .toList(growable: false);
});

String districtCode(String district) => Validators.normalizeKey(district);

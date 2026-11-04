import 'dart:io';

import 'package:latin_practice/models/course.dart';
import 'package:yaml/yaml.dart';

/// The one course of [coursesAsset], read from the repo without the asset
/// bundle.
final Course latinCourse = () {
  final path =
      (loadYaml(File(coursesAsset).readAsStringSync()) as YamlList).single
          as String;
  return Course.parse(path, File(path).readAsStringSync());
}();

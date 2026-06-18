// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dotenv.dart';

// **************************************************************************
// EnviedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// generated_from: .env
final class _DotEnv {
  static const String apiHost = '';

  static const List<int> _enviedkeyjwtSecret = <int>[];

  static const List<int> _envieddatajwtSecret = <int>[];

  static final String jwtSecret = String.fromCharCodes(
    List<int>.generate(
      _envieddatajwtSecret.length,
      (int i) => i,
      growable: false,
    ).map((int i) => _envieddatajwtSecret[i] ^ _enviedkeyjwtSecret[i]),
  );

  static const List<int> _enviedkeysecureKey = <int>[];

  static const List<int> _envieddatasecureKey = <int>[];

  static final String secureKey = String.fromCharCodes(
    List<int>.generate(
      _envieddatasecureKey.length,
      (int i) => i,
      growable: false,
    ).map((int i) => _envieddatasecureKey[i] ^ _enviedkeysecureKey[i]),
  );
}

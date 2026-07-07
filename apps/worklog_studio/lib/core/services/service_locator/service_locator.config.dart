// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:worklog_studio/data/settings_repository.dart' as _i800;
import 'package:worklog_studio/data/sqlite/sqlite_settings_repository.dart'
    as _i801;
import 'package:worklog_studio/entity/session/data/repository/session_storage_repository.dart'
    as _i429;
import 'package:worklog_studio/feature/work_log/data/usecases/work_log_raw_data_usecase.dart'
    as _i570;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    gh.lazySingleton<_i800.SettingsRepository>(
      () => _i801.SqliteSettingsRepository(),
    );
    gh.factory<_i570.IWorkLogRawDataUsecase>(
      () => _i570.WorkLogRawDataUsecase(gh<_i429.SessionStorageRepository>()),
    );
    return this;
  }
}

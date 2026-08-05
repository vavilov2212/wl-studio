// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reports_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReportsState {

 DashboardPeriod get period; DateTime get anchorDate; DashboardChartView get view; DateTime? get customRangeStart; DateTime? get customRangeEnd;
/// Create a copy of ReportsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReportsStateCopyWith<ReportsState> get copyWith => _$ReportsStateCopyWithImpl<ReportsState>(this as ReportsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReportsState&&(identical(other.period, period) || other.period == period)&&(identical(other.anchorDate, anchorDate) || other.anchorDate == anchorDate)&&(identical(other.view, view) || other.view == view)&&(identical(other.customRangeStart, customRangeStart) || other.customRangeStart == customRangeStart)&&(identical(other.customRangeEnd, customRangeEnd) || other.customRangeEnd == customRangeEnd));
}


@override
int get hashCode => Object.hash(runtimeType,period,anchorDate,view,customRangeStart,customRangeEnd);

@override
String toString() {
  return 'ReportsState(period: $period, anchorDate: $anchorDate, view: $view, customRangeStart: $customRangeStart, customRangeEnd: $customRangeEnd)';
}


}

/// @nodoc
abstract mixin class $ReportsStateCopyWith<$Res>  {
  factory $ReportsStateCopyWith(ReportsState value, $Res Function(ReportsState) _then) = _$ReportsStateCopyWithImpl;
@useResult
$Res call({
 DashboardPeriod period, DateTime anchorDate, DashboardChartView view, DateTime? customRangeStart, DateTime? customRangeEnd
});




}
/// @nodoc
class _$ReportsStateCopyWithImpl<$Res>
    implements $ReportsStateCopyWith<$Res> {
  _$ReportsStateCopyWithImpl(this._self, this._then);

  final ReportsState _self;
  final $Res Function(ReportsState) _then;

/// Create a copy of ReportsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? period = null,Object? anchorDate = null,Object? view = null,Object? customRangeStart = freezed,Object? customRangeEnd = freezed,}) {
  return _then(_self.copyWith(
period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as DashboardPeriod,anchorDate: null == anchorDate ? _self.anchorDate : anchorDate // ignore: cast_nullable_to_non_nullable
as DateTime,view: null == view ? _self.view : view // ignore: cast_nullable_to_non_nullable
as DashboardChartView,customRangeStart: freezed == customRangeStart ? _self.customRangeStart : customRangeStart // ignore: cast_nullable_to_non_nullable
as DateTime?,customRangeEnd: freezed == customRangeEnd ? _self.customRangeEnd : customRangeEnd // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ReportsState].
extension ReportsStatePatterns on ReportsState {
@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReportsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReportsState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReportsState value)  $default,){
final _that = this;
switch (_that) {
case _ReportsState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReportsState value)?  $default,){
final _that = this;
switch (_that) {
case _ReportsState() when $default != null:
return $default(_that);case _:
  return null;

}
}

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DashboardPeriod period,  DateTime anchorDate,  DashboardChartView view,  DateTime? customRangeStart,  DateTime? customRangeEnd)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReportsState() when $default != null:
return $default(_that.period,_that.anchorDate,_that.view,_that.customRangeStart,_that.customRangeEnd);case _:
  return orElse();

}
}

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DashboardPeriod period,  DateTime anchorDate,  DashboardChartView view,  DateTime? customRangeStart,  DateTime? customRangeEnd)  $default,) {final _that = this;
switch (_that) {
case _ReportsState():
return $default(_that.period,_that.anchorDate,_that.view,_that.customRangeStart,_that.customRangeEnd);case _:
  throw StateError('Unexpected subclass');

}
}

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DashboardPeriod period,  DateTime anchorDate,  DashboardChartView view,  DateTime? customRangeStart,  DateTime? customRangeEnd)?  $default,) {final _that = this;
switch (_that) {
case _ReportsState() when $default != null:
return $default(_that.period,_that.anchorDate,_that.view,_that.customRangeStart,_that.customRangeEnd);case _:
  return null;

}
}

}

/// @nodoc


class _ReportsState extends ReportsState {
  const _ReportsState({required this.period, required this.anchorDate, this.view = DashboardChartView.donut, this.customRangeStart, this.customRangeEnd}): super._();


@override final  DashboardPeriod period;
@override final  DateTime anchorDate;
@override@JsonKey() final  DashboardChartView view;
@override final  DateTime? customRangeStart;
@override final  DateTime? customRangeEnd;

/// Create a copy of ReportsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReportsStateCopyWith<_ReportsState> get copyWith => __$ReportsStateCopyWithImpl<_ReportsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReportsState&&(identical(other.period, period) || other.period == period)&&(identical(other.anchorDate, anchorDate) || other.anchorDate == anchorDate)&&(identical(other.view, view) || other.view == view)&&(identical(other.customRangeStart, customRangeStart) || other.customRangeStart == customRangeStart)&&(identical(other.customRangeEnd, customRangeEnd) || other.customRangeEnd == customRangeEnd));
}


@override
int get hashCode => Object.hash(runtimeType,period,anchorDate,view,customRangeStart,customRangeEnd);

@override
String toString() {
  return 'ReportsState(period: $period, anchorDate: $anchorDate, view: $view, customRangeStart: $customRangeStart, customRangeEnd: $customRangeEnd)';
}


}

/// @nodoc
abstract mixin class _$ReportsStateCopyWith<$Res> implements $ReportsStateCopyWith<$Res> {
  factory _$ReportsStateCopyWith(_ReportsState value, $Res Function(_ReportsState) _then) = __$ReportsStateCopyWithImpl;
@override @useResult
$Res call({
 DashboardPeriod period, DateTime anchorDate, DashboardChartView view, DateTime? customRangeStart, DateTime? customRangeEnd
});




}
/// @nodoc
class __$ReportsStateCopyWithImpl<$Res>
    implements _$ReportsStateCopyWith<$Res> {
  __$ReportsStateCopyWithImpl(this._self, this._then);

  final _ReportsState _self;
  final $Res Function(_ReportsState) _then;

/// Create a copy of ReportsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? period = null,Object? anchorDate = null,Object? view = null,Object? customRangeStart = freezed,Object? customRangeEnd = freezed,}) {
  return _then(_ReportsState(
period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as DashboardPeriod,anchorDate: null == anchorDate ? _self.anchorDate : anchorDate // ignore: cast_nullable_to_non_nullable
as DateTime,view: null == view ? _self.view : view // ignore: cast_nullable_to_non_nullable
as DashboardChartView,customRangeStart: freezed == customRangeStart ? _self.customRangeStart : customRangeStart // ignore: cast_nullable_to_non_nullable
as DateTime?,customRangeEnd: freezed == customRangeEnd ? _self.customRangeEnd : customRangeEnd // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on

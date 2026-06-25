// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dashboard_charts_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DashboardChartsEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DashboardChartsEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DashboardChartsEvent()';
}


}

/// @nodoc
class $DashboardChartsEventCopyWith<$Res>  {
$DashboardChartsEventCopyWith(DashboardChartsEvent _, $Res Function(DashboardChartsEvent) __);
}


/// Adds pattern-matching-related methods to [DashboardChartsEvent].
extension DashboardChartsEventPatterns on DashboardChartsEvent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( DashboardPeriodChanged value)?  periodChanged,TResult Function( DashboardViewChanged value)?  viewChanged,TResult Function( DashboardPeriodStepped value)?  periodStepped,required TResult orElse(),}){
final _that = this;
switch (_that) {
case DashboardPeriodChanged() when periodChanged != null:
return periodChanged(_that);case DashboardViewChanged() when viewChanged != null:
return viewChanged(_that);case DashboardPeriodStepped() when periodStepped != null:
return periodStepped(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( DashboardPeriodChanged value)  periodChanged,required TResult Function( DashboardViewChanged value)  viewChanged,required TResult Function( DashboardPeriodStepped value)  periodStepped,}){
final _that = this;
switch (_that) {
case DashboardPeriodChanged():
return periodChanged(_that);case DashboardViewChanged():
return viewChanged(_that);case DashboardPeriodStepped():
return periodStepped(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( DashboardPeriodChanged value)?  periodChanged,TResult? Function( DashboardViewChanged value)?  viewChanged,TResult? Function( DashboardPeriodStepped value)?  periodStepped,}){
final _that = this;
switch (_that) {
case DashboardPeriodChanged() when periodChanged != null:
return periodChanged(_that);case DashboardViewChanged() when viewChanged != null:
return viewChanged(_that);case DashboardPeriodStepped() when periodStepped != null:
return periodStepped(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( DashboardPeriod period)?  periodChanged,TResult Function( DashboardChartView view)?  viewChanged,TResult Function( int direction)?  periodStepped,required TResult orElse(),}) {final _that = this;
switch (_that) {
case DashboardPeriodChanged() when periodChanged != null:
return periodChanged(_that.period);case DashboardViewChanged() when viewChanged != null:
return viewChanged(_that.view);case DashboardPeriodStepped() when periodStepped != null:
return periodStepped(_that.direction);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( DashboardPeriod period)  periodChanged,required TResult Function( DashboardChartView view)  viewChanged,required TResult Function( int direction)  periodStepped,}) {final _that = this;
switch (_that) {
case DashboardPeriodChanged():
return periodChanged(_that.period);case DashboardViewChanged():
return viewChanged(_that.view);case DashboardPeriodStepped():
return periodStepped(_that.direction);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( DashboardPeriod period)?  periodChanged,TResult? Function( DashboardChartView view)?  viewChanged,TResult? Function( int direction)?  periodStepped,}) {final _that = this;
switch (_that) {
case DashboardPeriodChanged() when periodChanged != null:
return periodChanged(_that.period);case DashboardViewChanged() when viewChanged != null:
return viewChanged(_that.view);case DashboardPeriodStepped() when periodStepped != null:
return periodStepped(_that.direction);case _:
  return null;

}
}

}

/// @nodoc


class DashboardPeriodChanged implements DashboardChartsEvent {
  const DashboardPeriodChanged(this.period);
  

 final  DashboardPeriod period;

/// Create a copy of DashboardChartsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DashboardPeriodChangedCopyWith<DashboardPeriodChanged> get copyWith => _$DashboardPeriodChangedCopyWithImpl<DashboardPeriodChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DashboardPeriodChanged&&(identical(other.period, period) || other.period == period));
}


@override
int get hashCode => Object.hash(runtimeType,period);

@override
String toString() {
  return 'DashboardChartsEvent.periodChanged(period: $period)';
}


}

/// @nodoc
abstract mixin class $DashboardPeriodChangedCopyWith<$Res> implements $DashboardChartsEventCopyWith<$Res> {
  factory $DashboardPeriodChangedCopyWith(DashboardPeriodChanged value, $Res Function(DashboardPeriodChanged) _then) = _$DashboardPeriodChangedCopyWithImpl;
@useResult
$Res call({
 DashboardPeriod period
});




}
/// @nodoc
class _$DashboardPeriodChangedCopyWithImpl<$Res>
    implements $DashboardPeriodChangedCopyWith<$Res> {
  _$DashboardPeriodChangedCopyWithImpl(this._self, this._then);

  final DashboardPeriodChanged _self;
  final $Res Function(DashboardPeriodChanged) _then;

/// Create a copy of DashboardChartsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? period = null,}) {
  return _then(DashboardPeriodChanged(
null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as DashboardPeriod,
  ));
}


}

/// @nodoc


class DashboardViewChanged implements DashboardChartsEvent {
  const DashboardViewChanged(this.view);
  

 final  DashboardChartView view;

/// Create a copy of DashboardChartsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DashboardViewChangedCopyWith<DashboardViewChanged> get copyWith => _$DashboardViewChangedCopyWithImpl<DashboardViewChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DashboardViewChanged&&(identical(other.view, view) || other.view == view));
}


@override
int get hashCode => Object.hash(runtimeType,view);

@override
String toString() {
  return 'DashboardChartsEvent.viewChanged(view: $view)';
}


}

/// @nodoc
abstract mixin class $DashboardViewChangedCopyWith<$Res> implements $DashboardChartsEventCopyWith<$Res> {
  factory $DashboardViewChangedCopyWith(DashboardViewChanged value, $Res Function(DashboardViewChanged) _then) = _$DashboardViewChangedCopyWithImpl;
@useResult
$Res call({
 DashboardChartView view
});




}
/// @nodoc
class _$DashboardViewChangedCopyWithImpl<$Res>
    implements $DashboardViewChangedCopyWith<$Res> {
  _$DashboardViewChangedCopyWithImpl(this._self, this._then);

  final DashboardViewChanged _self;
  final $Res Function(DashboardViewChanged) _then;

/// Create a copy of DashboardChartsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? view = null,}) {
  return _then(DashboardViewChanged(
null == view ? _self.view : view // ignore: cast_nullable_to_non_nullable
as DashboardChartView,
  ));
}


}

/// @nodoc


class DashboardPeriodStepped implements DashboardChartsEvent {
  const DashboardPeriodStepped(this.direction);
  

 final  int direction;

/// Create a copy of DashboardChartsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DashboardPeriodSteppedCopyWith<DashboardPeriodStepped> get copyWith => _$DashboardPeriodSteppedCopyWithImpl<DashboardPeriodStepped>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DashboardPeriodStepped&&(identical(other.direction, direction) || other.direction == direction));
}


@override
int get hashCode => Object.hash(runtimeType,direction);

@override
String toString() {
  return 'DashboardChartsEvent.periodStepped(direction: $direction)';
}


}

/// @nodoc
abstract mixin class $DashboardPeriodSteppedCopyWith<$Res> implements $DashboardChartsEventCopyWith<$Res> {
  factory $DashboardPeriodSteppedCopyWith(DashboardPeriodStepped value, $Res Function(DashboardPeriodStepped) _then) = _$DashboardPeriodSteppedCopyWithImpl;
@useResult
$Res call({
 int direction
});




}
/// @nodoc
class _$DashboardPeriodSteppedCopyWithImpl<$Res>
    implements $DashboardPeriodSteppedCopyWith<$Res> {
  _$DashboardPeriodSteppedCopyWithImpl(this._self, this._then);

  final DashboardPeriodStepped _self;
  final $Res Function(DashboardPeriodStepped) _then;

/// Create a copy of DashboardChartsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? direction = null,}) {
  return _then(DashboardPeriodStepped(
null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$DashboardChartsState {

 DashboardPeriod get period; DateTime get anchorDate; DashboardChartView get view;
/// Create a copy of DashboardChartsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DashboardChartsStateCopyWith<DashboardChartsState> get copyWith => _$DashboardChartsStateCopyWithImpl<DashboardChartsState>(this as DashboardChartsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DashboardChartsState&&(identical(other.period, period) || other.period == period)&&(identical(other.anchorDate, anchorDate) || other.anchorDate == anchorDate)&&(identical(other.view, view) || other.view == view));
}


@override
int get hashCode => Object.hash(runtimeType,period,anchorDate,view);

@override
String toString() {
  return 'DashboardChartsState(period: $period, anchorDate: $anchorDate, view: $view)';
}


}

/// @nodoc
abstract mixin class $DashboardChartsStateCopyWith<$Res>  {
  factory $DashboardChartsStateCopyWith(DashboardChartsState value, $Res Function(DashboardChartsState) _then) = _$DashboardChartsStateCopyWithImpl;
@useResult
$Res call({
 DashboardPeriod period, DateTime anchorDate, DashboardChartView view
});




}
/// @nodoc
class _$DashboardChartsStateCopyWithImpl<$Res>
    implements $DashboardChartsStateCopyWith<$Res> {
  _$DashboardChartsStateCopyWithImpl(this._self, this._then);

  final DashboardChartsState _self;
  final $Res Function(DashboardChartsState) _then;

/// Create a copy of DashboardChartsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? period = null,Object? anchorDate = null,Object? view = null,}) {
  return _then(_self.copyWith(
period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as DashboardPeriod,anchorDate: null == anchorDate ? _self.anchorDate : anchorDate // ignore: cast_nullable_to_non_nullable
as DateTime,view: null == view ? _self.view : view // ignore: cast_nullable_to_non_nullable
as DashboardChartView,
  ));
}

}


/// Adds pattern-matching-related methods to [DashboardChartsState].
extension DashboardChartsStatePatterns on DashboardChartsState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DashboardChartsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DashboardChartsState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DashboardChartsState value)  $default,){
final _that = this;
switch (_that) {
case _DashboardChartsState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DashboardChartsState value)?  $default,){
final _that = this;
switch (_that) {
case _DashboardChartsState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DashboardPeriod period,  DateTime anchorDate,  DashboardChartView view)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DashboardChartsState() when $default != null:
return $default(_that.period,_that.anchorDate,_that.view);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DashboardPeriod period,  DateTime anchorDate,  DashboardChartView view)  $default,) {final _that = this;
switch (_that) {
case _DashboardChartsState():
return $default(_that.period,_that.anchorDate,_that.view);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DashboardPeriod period,  DateTime anchorDate,  DashboardChartView view)?  $default,) {final _that = this;
switch (_that) {
case _DashboardChartsState() when $default != null:
return $default(_that.period,_that.anchorDate,_that.view);case _:
  return null;

}
}

}

/// @nodoc


class _DashboardChartsState extends DashboardChartsState {
  const _DashboardChartsState({required this.period, required this.anchorDate, this.view = DashboardChartView.donut}): super._();
  

@override final  DashboardPeriod period;
@override final  DateTime anchorDate;
@override@JsonKey() final  DashboardChartView view;

/// Create a copy of DashboardChartsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DashboardChartsStateCopyWith<_DashboardChartsState> get copyWith => __$DashboardChartsStateCopyWithImpl<_DashboardChartsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DashboardChartsState&&(identical(other.period, period) || other.period == period)&&(identical(other.anchorDate, anchorDate) || other.anchorDate == anchorDate)&&(identical(other.view, view) || other.view == view));
}


@override
int get hashCode => Object.hash(runtimeType,period,anchorDate,view);

@override
String toString() {
  return 'DashboardChartsState(period: $period, anchorDate: $anchorDate, view: $view)';
}


}

/// @nodoc
abstract mixin class _$DashboardChartsStateCopyWith<$Res> implements $DashboardChartsStateCopyWith<$Res> {
  factory _$DashboardChartsStateCopyWith(_DashboardChartsState value, $Res Function(_DashboardChartsState) _then) = __$DashboardChartsStateCopyWithImpl;
@override @useResult
$Res call({
 DashboardPeriod period, DateTime anchorDate, DashboardChartView view
});




}
/// @nodoc
class __$DashboardChartsStateCopyWithImpl<$Res>
    implements _$DashboardChartsStateCopyWith<$Res> {
  __$DashboardChartsStateCopyWithImpl(this._self, this._then);

  final _DashboardChartsState _self;
  final $Res Function(_DashboardChartsState) _then;

/// Create a copy of DashboardChartsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? period = null,Object? anchorDate = null,Object? view = null,}) {
  return _then(_DashboardChartsState(
period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as DashboardPeriod,anchorDate: null == anchorDate ? _self.anchorDate : anchorDate // ignore: cast_nullable_to_non_nullable
as DateTime,view: null == view ? _self.view : view // ignore: cast_nullable_to_non_nullable
as DashboardChartView,
  ));
}


}

// dart format on

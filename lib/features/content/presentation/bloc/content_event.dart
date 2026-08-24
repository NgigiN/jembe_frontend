import 'package:equatable/equatable.dart';

abstract class ContentEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class GetAllContentEvent extends ContentEvent {}

import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/content/domain/entities/content_item.dart';

abstract class ContentState extends Equatable {
  const ContentState({this.items = const []});
  final List<ContentItem> items;

  @override
  List<Object?> get props => [items];
}

class ContentInitial extends ContentState {}

class ContentLoading extends ContentState {
  const ContentLoading({super.items});
}

class ContentLoaded extends ContentState {
  const ContentLoaded({required super.items});
}

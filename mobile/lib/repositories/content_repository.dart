import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
import '../models/content.dart';

/// Reads lesson content. All of it is read-only - content is authored in the
/// Django admin, never by the app.
class ContentRepository {
  const ContentRepository(this._dio);

  final Dio _dio;

  Future<List<LanguageInfo>> fetchLanguages() async {
    return _getList('/languages/', LanguageInfo.fromJson);
  }

  Future<List<Category>> fetchCategories({String? languageCode}) async {
    return _getList(
      '/categories/',
      Category.fromJson,
      query: {if (languageCode != null) 'language': languageCode},
    );
  }

  Future<List<Lesson>> fetchLessons({
    String? languageCode,
    int? categoryId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/lessons/',
        queryParameters: {
          if (languageCode != null) 'language': languageCode,
          if (categoryId != null) 'category': categoryId,
        },
      );

      // Lessons are paginated; categories and languages are not.
      final results = response.data?['results'] as List? ?? const [];
      return results
          .map((item) => Lesson.fromJson((item as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Lesson> fetchLesson(int id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/lessons/$id/');
      return Lesson.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Builds one multiple-choice round. The options are shuffled server-side,
  /// so their order carries no hint about which is correct.
  Future<QuizRound> fetchQuizRound(int wordId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/words/$wordId/quiz-round/',
      );
      return QuizRound.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<T>> _getList<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        path,
        queryParameters: query,
      );
      return (response.data ?? const [])
          .map((item) => parse((item as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return ContentRepository(ref.watch(dioProvider));
});

/// The languages on offer, with their Azure capability blocks.
final languagesProvider = FutureProvider<List<LanguageInfo>>((ref) {
  return ref.watch(contentRepositoryProvider).fetchLanguages();
});

/// Categories for a given practice language.
final categoriesProvider = FutureProvider.family<List<Category>, String>((
  ref,
  languageCode,
) {
  return ref
      .watch(contentRepositoryProvider)
      .fetchCategories(languageCode: languageCode);
});

final lessonProvider = FutureProvider.family<Lesson, int>((ref, id) {
  return ref.watch(contentRepositoryProvider).fetchLesson(id);
});

/// Lessons available in a given practice language.
final lessonsForLanguageProvider = FutureProvider.family<List<Lesson>, String>((
  ref,
  languageCode,
) {
  return ref
      .watch(contentRepositoryProvider)
      .fetchLessons(languageCode: languageCode);
});

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

  /// The one endpoint that links a lesson back to its category - the plain
  /// lesson list/detail never includes it, so the Lesson Intro screen's
  /// category chip is built by fetching every category's detail once and
  /// indexing by lesson id (see [lessonCategoryNamesProvider]).
  Future<Category> fetchCategoryDetail(int id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/categories/$id/');
      return Category.fromJson(response.data!);
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

/// The languages on offer.
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

/// Lesson id -> category name, for a given practice language. Built by
/// fetching every category's detail once, since no lesson endpoint exposes
/// its own category. The category list is short (a handful per language),
/// so this stays cheap.
final lessonCategoryNamesProvider =
    FutureProvider.family<Map<int, String>, String>((ref, languageCode) async {
      final repository = ref.watch(contentRepositoryProvider);
      final categories = await repository.fetchCategories(
        languageCode: languageCode,
      );
      final details = await Future.wait(
        categories.map(
          (category) => repository.fetchCategoryDetail(category.id),
        ),
      );

      return {
        for (final detail in details)
          for (final lessonId in detail.lessonIds) lessonId: detail.name,
      };
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

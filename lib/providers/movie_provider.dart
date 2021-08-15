import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:peliculas/helpers/debouncer.dart';
import 'package:peliculas/models/movie.dart';
import 'dart:convert';
import 'package:peliculas/models/now_playing_response.dart';
import 'package:peliculas/models/popular_response.dart';
import 'package:peliculas/models/credits_response.dart';
import 'package:peliculas/models/search_response.dart';

class MovieProvider extends ChangeNotifier {

  String _apiKey = '231c41c24009854f5b79fdd231ed3e75';
  String _base_endpoint = 'api.themoviedb.org';
  String _language = 'es-ES';

  List<Movie> onDisplayMovies = [];
  List<Movie> popularMovies = [];
  List<Movie> moviesSearch = [];
  Map<int, List<Cast>> movieCast = {};
  int _popularPage = 0;
  final debouncer = Debouncer(
    duration: Duration(milliseconds: 500),
  );
  final StreamController<List<Movie>> _suggestionStreamController = new StreamController.broadcast(); 
  Stream<List<Movie>> get suggestionStream => this._suggestionStreamController.stream;
  
  MovieProvider() {
    print('MoviesProvider inicializado!');
    this.getOnDisplayMovies();
    this.getPopularMovies();
  }

  Future<String> _getJsonData(String endpoint, [int page = 1]) async {
    var url = Uri.https(_base_endpoint, endpoint, {
      'api_key': _apiKey,
      'language': _language,
      'page': '$page' 
    });

    var response = await http.get(url);
    return response.body;
  }

  getOnDisplayMovies() async {
    var response = await this._getJsonData('3/movie/now_playing');
    final  nowPlayingResponse = NowPlayingResponse.fromJson(response);
    this.onDisplayMovies = [...nowPlayingResponse.results];
    notifyListeners();  // Sirve para redibujar los widgets cuando hay cambios en la data
  }

  getPopularMovies() async {
    this._popularPage++;
    var response = await this._getJsonData('3/movie/popular', this._popularPage);
    final  popularResponse = PopularResponse.fromJson(response);
    this.popularMovies = [...popularMovies, ...popularResponse.results];
    notifyListeners();  // Sirve para redibujar los widgets cuando hay cambios en la data
  }

  Future<List<Cast>> getMovieCast(int idMovie) async {
    if ((movieCast.containsKey(idMovie))) {
      return movieCast[idMovie]!;
    }

    print('Obteniendo los actores del servidor');
    var response = await this._getJsonData('3/movie/${idMovie}/credits');
    final creditsReponse = CreditsResponse.fromJson(response);
    // Guardo en memoria la respuesta
    movieCast[idMovie] = creditsReponse.cast;
    return creditsReponse.cast;
  }

  Future<List<Movie>> searchMovies( String query ) async {

    final url = Uri.https( _base_endpoint, '3/search/movie', {
      'api_key': _apiKey,
      'language': _language,
      'query': query
    });

    final response = await http.get(url);
    final searchResponse = SearchResponse.fromJson( response.body );
    return searchResponse.results;
  }

  void getSuggestionsByQuery(String query) {
    debouncer.value = '';
    debouncer.onValue = (value) async {
      final results = await this.searchMovies(value);
      this._suggestionStreamController.add(results);
    };

    final timer = Timer.periodic(Duration(milliseconds: 300), (_) { 
      debouncer.value = query;
    });

    Future.delayed(Duration(milliseconds: 301)).then((_) => timer.cancel());
  }

}
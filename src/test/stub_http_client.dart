import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A canned HTTP reply.
class StubReply {
  const StubReply(this.body, {this.statusCode = 200});

  final String body;
  final int statusCode;

  factory StubReply.json(Object value) => StubReply(jsonEncode(value));
}

/// HTTP client that answers from a table of routes instead of the network.
///
/// Routes are matched by path prefix and the longest match wins. Several
/// replies for one path are returned in order and the last one repeats, which
/// covers calls made more than once (a balance check happens per trade).
class StubClient extends http.BaseClient {
  StubClient(this._routes);

  final Map<String, List<StubReply>> _routes;
  final Map<String, int> _cursor = {};

  /// Every request the client was asked to send, in order.
  final List<http.BaseRequest> requests = [];

  Uri urlAt(int index) => requests[index].url;

  Uri get lastUrl => requests.last.url;

  /// Body of the request at [index], for asserting what was sent.
  String bodyAt(int index) => (requests[index] as http.Request).body;

  StubReply _replyFor(Uri uri) {
    String? route;
    for (final candidate in _routes.keys) {
      if (!uri.path.startsWith(candidate)) continue;
      if (route == null || candidate.length > route.length) route = candidate;
    }

    if (route == null) throw StubError(uri);

    final replies = _routes[route]!;
    final index = (_cursor[route] ?? 0).clamp(0, replies.length - 1);
    _cursor[route] = index + 1;
    return replies[index];
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final reply = _replyFor(request.url);
    final bytes = utf8.encode(reply.body);

    return http.StreamedResponse(
      Stream.fromIterable([bytes]),
      reply.statusCode,
      headers: request.headers,
    );
  }
}

class StubError implements Exception {
  const StubError(this.uri);

  final Uri uri;

  @override
  String toString() => 'No stubbed response for ${uri.path}';
}

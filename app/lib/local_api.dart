import 'api.dart';
import 'school_book.dart';

class LocalSchoolApi extends SchoolApi {
  LocalSchoolApi() : super('local');

  @override
  Future<dynamic> get(String path) => SchoolBook.instance.call('GET', path, null);

  @override
  Future<dynamic> post(String path, Object body) => SchoolBook.instance.call('POST', path, body);

  @override
  Future<dynamic> put(String path, Object body) => SchoolBook.instance.call('PUT', path, body);

  @override
  Future<dynamic> delete(String path) => SchoolBook.instance.call('DELETE', path, null);

  @override
  Future<List<int>> bytes(String path) async => _asBytes(await get(path));

  @override
  Future<List<int>> postBytes(String path, Object body) async => _asBytes(await post(path, body));

  List<int> _asBytes(dynamic data) {
    if (data is List<int>) return data;
    if (data is List) return data.cast<int>();
    throw ApiException('Could not open the file');
  }
}

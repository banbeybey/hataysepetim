import 'package:flutter/foundation.dart';
import '../services/kurumsal_api_service.dart';

class KurumsalProvider extends ChangeNotifier {
  int?    _storeId;
  int?    _userId;
  String? _username;
  String? _role;
  String? _storeCategory;
  String? _logoUrl;
  bool    _yuklendi = false;

  int?    get storeId       => _storeId;
  int?    get userId        => _userId;
  String? get username      => _username;
  String? get role          => _role;
  String? get storeCategory => _storeCategory;
  String? get logoUrl        => _logoUrl;
  bool    get girisYapildi  => _storeId != null && _storeId! > 0;
  bool    get yuklendi      => _yuklendi;

  KurumsalProvider() { _yukle(); }

  Future<void> _yukle() async {
    _storeId = await KurumsalApiService.getStoreId();
    _userId  = await KurumsalApiService.getUserId();
    final info = await KurumsalApiService.getKurumsalBilgi();
    _username      = info['username'];
    _role          = info['role'];
    _storeCategory = info['store_category'];
    if (_storeId != null && _storeId! > 0) {
      _logoUrl = await KurumsalApiService.getStoreLogo(_storeId!);
    }
    _yuklendi      = true;
    notifyListeners();
  }

  Future<Map<String, dynamic>> girisYap(String username, String password) async {
    final sonuc = await KurumsalApiService.girisYap(
        username: username, password: password);
    if (sonuc['status'] == 'success') {
      _storeId       = sonuc['store_id'] as int;
      _userId        = sonuc['user_id']  as int? ?? _storeId;
      _username      = sonuc['username']?.toString() ?? username;
      _role          = sonuc['role']?.toString() ?? 'store';
      _storeCategory = sonuc['store_category']?.toString() ?? '';
      _logoUrl = await KurumsalApiService.getStoreLogo(_storeId!);
      notifyListeners();
    }
    return sonuc;
  }

  Future<void> cikisYap() async {
    await KurumsalApiService.temizle();
    _storeId = _userId = _username = _role = _storeCategory = _logoUrl = null;
    notifyListeners();
  }
}


import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'app_constants.dart';
import 'models.dart';

class SupabaseService {
  SupabaseClient get client => Supabase.instance.client;
  String? get userId => client.auth.currentUser?.id;

  Future<void> signIn(String email, String password) => client.auth.signInWithPassword(email: email, password: password).then((_){ });
  Future<void> signOut() => client.auth.signOut();

  Future<ProfileModel?> currentProfile() async {
    final uid = userId; if (uid == null) return null;
    final data = await client.from(AppConstants.tableProfiles).select().eq('id', uid).maybeSingle();
    if (data == null) return null;
    final p = ProfileModel.fromJson(data);
    return p.isActive ? p : null;
  }

  Future<List<ProfileModel>> agents() async {
    final rows = await client.from(AppConstants.tableProfiles).select().eq('role', AppConstants.roleAgent).order('created_at', ascending: false);
    return (rows as List).map((e)=>ProfileModel.fromJson(e)).toList();
  }

  Future<void> createAgent({required String email, required String password, required String name, String? phone}) async {
    final auth = await client.auth.signUp(email: email, password: password);
    final uid = auth.user?.id;
    if (uid == null) throw Exception('لم يتم إنشاء المستخدم');
    await client.from(AppConstants.tableProfiles).insert({'id':uid,'full_name':name,'phone':phone,'role':'agent','is_active':true});
  }

  Future<String> nextCode() async => 'CL-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

  Future<String?> uploadImageBytes(Uint8List bytes, String code) async {
    final uid = userId ?? 'unknown';
    final path = '$uid/$code-${const Uuid().v4()}.jpg';
    await client.storage.from(AppConstants.storageBucket).uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));
    return client.storage.from(AppConstants.storageBucket).getPublicUrl(path);
  }

  Future<void> insertClinic(ClinicModel clinic) async => client.from(AppConstants.tableClinics).insert(clinic.toInsert());

  Future<List<ClinicModel>> clinics({bool mineOnly=false}) async {
    final p = await currentProfile();
    dynamic q = client.from(AppConstants.tableClinics).select();
    if (mineOnly && p != null) q = q.eq('created_by', p.id);
    final rows = await q.order('created_at', ascending: false).limit(1000);
    return (rows as List).map((e)=>ClinicModel.fromJson(e)).toList();
  }

  Future<ClinicModel?> findDuplicate({String? mobile, String? phone, double? lat, double? lng}) async {
    final all = await clinics();
    final phones = {_normalizePhone(mobile), _normalizePhone(phone)}..removeWhere((e)=>e.isEmpty || e.length < 7);
    for (final c in all) {
      final cPhones = {_normalizePhone(c.mobile), _normalizePhone(c.phone)}..removeWhere((e)=>e.isEmpty || e.length < 7);
      if (phones.intersection(cPhones).isNotEmpty) return c;
      if (lat != null && lng != null && c.lat != null && c.lng != null) {
        final meters = _distanceMeters(lat, lng, c.lat!, c.lng!);
        if (meters < 35 && ((c.clinicName ?? '').trim().isNotEmpty)) return c;
      }
    }
    return null;
  }

  Future<Map<String,int>> stats() async {
    final all = await clinics();
    final today = DateTime.now();
    return {
      'total': all.length,
      'today': all.where((c)=>c.createdAt.year==today.year && c.createdAt.month==today.month && c.createdAt.day==today.day).length,
      'incomplete': all.where((c)=>(c.phone??c.mobile??'').isEmpty || (c.clinicName??'').isEmpty).length,
      'duplicate': all.where((c)=>c.status == 'Duplicate').length,
      'reviewed': all.where((c)=>c.status == 'Reviewed').length,
    };
  }

  Future<List<Map<String,dynamic>>> agentStats() async {
    final agentsList = await agents();
    final all = await clinics();
    return agentsList.map((a){
      final count = all.where((c)=>c.createdBy == a.id).length;
      return {'name': a.fullName, 'phone': a.phone ?? '', 'count': count, 'active': a.isActive};
    }).toList()..sort((a,b)=>(b['count'] as int).compareTo(a['count'] as int));
  }

  String _normalizePhone(String? value) => (value ?? '').replaceAll(RegExp(r'[^0-9+]'), '').replaceFirst(RegExp(r'^00963'), '+963').replaceFirst(RegExp(r'^0(?=9)'), '+963');
  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _rad(lat2-lat1), dLon = _rad(lon2-lon1);
    final a = math.sin(dLat/2)*math.sin(dLat/2)+math.cos(_rad(lat1))*math.cos(_rad(lat2))*math.sin(dLon/2)*math.sin(dLon/2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));
  }
  double _rad(double x) => x * math.pi / 180.0;
}
final supabaseService = SupabaseService();

class OcrService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<OcrResult> scanBytes(Uint8List bytes) async {
    if (AppConstants.useRealOcr) {
      try {
        final response = await _client.functions.invoke(
          AppConstants.ocrFunctionName,
          body: {'image_base64': base64Encode(bytes), 'mime_type': 'image/jpeg'},
        );
        final data = response.data;
        if (data is Map && data['error'] == null) return OcrResult.fromJson(Map<String, dynamic>.from(data));
        if (data is Map && data['error'] != null) throw Exception(data['error']);
      } catch (e) {
        throw Exception('فشل تحليل Gemini: $e');
      }
    }
    return _mockResult();
  }

  OcrResult _mockResult() => OcrResult(clinicName: 'مركز الشفاء الطبي', doctorName: 'د. أحمد خالد', phone: '0111234567', mobile: '0991234567', specialty: 'طب أسنان', city: '', area: '', addressText: '', rawText: 'Mock OCR: مركز الشفاء الطبي\nد. أحمد خالد\n0991234567', confidence: .82);
}
final ocrService = OcrService();

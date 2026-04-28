
class ProfileModel {
  final String id, authUserId, fullName, role;
  final String? phone;
  final bool isActive;
  ProfileModel({required this.id, required this.authUserId, required this.fullName, required this.role, this.phone, required this.isActive});
  bool get isAdmin => role == 'admin';
  factory ProfileModel.fromJson(Map<String,dynamic> j)=>ProfileModel(
    id: '${j['id']}', authUserId: '${j['id'] ?? j['auth_user_id'] ?? ''}', fullName: '${j['full_name'] ?? ''}', role: '${j['role'] ?? 'agent'}', phone: j['phone']?.toString(), isActive: j['is_active'] != false);
  Map<String,dynamic> toJson()=>{'id':id,'full_name':fullName,'phone':phone,'role':role,'is_active':isActive};
}

class ClinicModel {
  final String id, code, status;
  final String? clinicName, doctorName, phone, mobile, specialty, city, area, addressText, imageUrl, rawText, createdBy;
  final double? lat, lng, confidence;
  final DateTime createdAt;
  ClinicModel({required this.id,required this.code,this.clinicName,this.doctorName,this.phone,this.mobile,this.specialty,this.city,this.area,this.addressText,this.lat,this.lng,this.imageUrl,this.rawText,this.confidence,this.createdBy,this.status='New',DateTime? createdAt}):createdAt=createdAt??DateTime.now();
  factory ClinicModel.fromJson(Map<String,dynamic> j)=>ClinicModel(
    id:'${j['id']}', code:'${j['code'] ?? ''}', clinicName:j['clinic_name']?.toString() ?? j['name']?.toString(), doctorName:j['doctor_name']?.toString(), phone:j['phone']?.toString(), mobile:j['mobile']?.toString(), specialty:j['specialty']?.toString(), city:j['city']?.toString(), area:j['area']?.toString(), addressText:j['address_text']?.toString(), lat:(j['lat'] as num?)?.toDouble(), lng:(j['lng'] as num?)?.toDouble(), imageUrl:j['image_url']?.toString(), rawText:j['raw_text']?.toString(), confidence:(j['confidence'] as num?)?.toDouble(), createdBy:j['created_by']?.toString(), status:j['status']?.toString() ?? 'New', createdAt:DateTime.tryParse('${j['created_at']}'));
  Map<String,dynamic> toInsert()=>{'code':code,'clinic_name':clinicName,'name':clinicName,'doctor_name':doctorName,'phone':phone,'mobile':mobile,'specialty':specialty,'city':city,'area':area,'address_text':addressText,'lat':lat,'lng':lng,'image_url':imageUrl,'raw_text':rawText,'confidence':confidence,'created_by':createdBy,'status':status};
}

class OcrResult {
  final String? clinicName, doctorName, phone, mobile, specialty, city, area, addressText, rawText;
  final double confidence;
  OcrResult({this.clinicName,this.doctorName,this.phone,this.mobile,this.specialty,this.city,this.area,this.addressText,this.rawText,this.confidence = .8});
  factory OcrResult.fromJson(Map<String, dynamic> j) => OcrResult(
    clinicName: j['clinic_name']?.toString(), doctorName: j['doctor_name']?.toString(), phone: j['phone']?.toString(), mobile: j['mobile']?.toString(), specialty: (j['specialty'] ?? j['category'])?.toString(), city: j['city']?.toString(), area: j['area']?.toString(), addressText: j['address_text']?.toString(), rawText: j['raw_text']?.toString(), confidence: (j['confidence'] is num) ? (j['confidence'] as num).toDouble() : .8,
  );
}

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'app_router.dart';
import 'app_theme.dart';
import 'models.dart';
import 'providers.dart';
import 'services.dart';
import 'export_service.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext c, WidgetRef r) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool loading = false;
  @override
  Widget build(BuildContext context) => Scaffold(
      body: Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(children: [
                    const Icon(Icons.local_hospital_rounded,
                        size: 72, color: AppColors.primary),
                    const SizedBox(height: 12),
                    Text('Clinic Data Collector',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 28),
                    TextField(
                        controller: email,
                        decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني'),
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    TextField(
                        controller: pass,
                        decoration:
                            const InputDecoration(labelText: 'كلمة المرور'),
                        obscureText: true),
                    const SizedBox(height: 20),
                    ElevatedButton(
                        onPressed: loading
                            ? null
                            : () async {
                                setState(() => loading = true);
                                try {
                                  await supabaseService.signIn(
                                      email.text.trim(), pass.text);
                                  ref.invalidate(currentProfileProvider);
                                } catch (e) {
                                  if (mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('خطأ تسجيل الدخول: $e'),
                                            backgroundColor: AppColors.error));
                                } finally {
                                  if (mounted) setState(() => loading = false);
                                }
                              },
                        child: loading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('تسجيل الدخول')),
                  ])))));
}

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final agentStats = ref.watch(agentStatsProvider);
    return Scaffold(
        appBar: AppBar(title: const Text('لوحة الأدمن'), actions: [
          IconButton(
              onPressed: () async {
                await supabaseService.signOut();
                ref.invalidate(currentProfileProvider);
              },
              icon: const Icon(Icons.logout))
        ]),
        body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(statsProvider);
              ref.invalidate(clinicsProvider);
              ref.invalidate(agentStatsProvider);
            },
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Text('مرحباً ${profile?.fullName ?? ''}',
                  style: Theme.of(c).textTheme.headlineSmall),
              const SizedBox(height: 16),
              stats.when(
                  data: (s) => GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1.65,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          children: [
                            _Stat('كل العيادات', '${s['total']}',
                                Icons.local_hospital),
                            _Stat('اليوم', '${s['today']}', Icons.today),
                            _Stat('ناقصة', '${s['incomplete']}', Icons.warning),
                            _Stat('مكررة', '${s['duplicate']}', Icons.copy)
                          ]),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('$e')),
              const SizedBox(height: 18),
              _Action('جمع عيادة جديدة', Icons.camera_alt,
                  () => c.push(AppRoutes.capture)),
              _Action('كل العيادات + تصدير Excel', Icons.list_alt,
                  () => c.push(AppRoutes.clinics)),
              _Action('إدارة المستخدمين', Icons.people,
                  () => c.push(AppRoutes.users)),
              const SizedBox(height: 18),
              Text('أداء الفريق', style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 8),
              agentStats.when(
                  data: (list) => list.isEmpty
                      ? const Text('لا يوجد موظفون بعد')
                      : Column(
                          children: list
                              .take(8)
                              .map((a) => Card(
                                  child: ListTile(
                                      leading: const Icon(Icons.person),
                                      title: Text('${a['name']}'),
                                      subtitle: Text(
                                          '${a['active'] == true ? 'نشط' : 'معطل'} • ${a['phone']}'),
                                      trailing:
                                          Chip(label: Text('${a['count']}')))))
                              .toList()),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('$e')),
            ])));
  }
}

class _Stat extends StatelessWidget {
  final String t, v;
  final IconData i;
  const _Stat(this.t, this.v, this.i);
  @override
  Widget build(BuildContext c) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(i, color: AppColors.gold),
            const Spacer(),
            Text(v, style: Theme.of(c).textTheme.headlineSmall),
            Text(t)
          ])));
}

class _Action extends StatelessWidget {
  final String t;
  final IconData i;
  final VoidCallback on;
  const _Action(this.t, this.i, this.on);
  @override
  Widget build(BuildContext c) => Card(
      child: ListTile(
          leading: Icon(i, color: AppColors.primary),
          title: Text(t),
          trailing: const Icon(Icons.chevron_left),
          onTap: on));
}

class UsersManagementScreen extends ConsumerWidget {
  const UsersManagementScreen({super.key});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final agents = ref.watch(agentsProvider);
    return Scaffold(
        appBar: AppBar(title: const Text('إدارة المستخدمين')),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => c.push(AppRoutes.createUser),
            label: const Text('إضافة'),
            icon: const Icon(Icons.person_add)),
        body: agents.when(
            data: (list) => ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => Card(
                    child: ListTile(
                        leading: CircleAvatar(
                            child: Text(list[i].fullName.isNotEmpty
                                ? list[i].fullName[0]
                                : '?')),
                        title: Text(list[i].fullName),
                        subtitle: Text(
                            '${list[i].phone ?? ''} • ${list[i].isActive ? 'نشط' : 'معطل'}')))),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e'))));
  }
}

class CreateUserScreen extends ConsumerStatefulWidget {
  const CreateUserScreen({super.key});
  @override
  ConsumerState<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends ConsumerState<CreateUserScreen> {
  final name = TextEditingController(),
      email = TextEditingController(),
      phone = TextEditingController(),
      pass = TextEditingController();
  bool loading = false;
  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('إضافة موظف')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'الاسم')),
        const SizedBox(height: 10),
        TextField(
            controller: email,
            decoration: const InputDecoration(labelText: 'الإيميل')),
        const SizedBox(height: 10),
        TextField(
            controller: phone,
            decoration: const InputDecoration(labelText: 'الهاتف')),
        const SizedBox(height: 10),
        TextField(
            controller: pass,
            decoration: const InputDecoration(labelText: 'كلمة المرور'),
            obscureText: true),
        const SizedBox(height: 20),
        ElevatedButton(
            onPressed: loading
                ? null
                : () async {
                    setState(() => loading = true);
                    try {
                      await supabaseService.createAgent(
                          email: email.text.trim(),
                          password: pass.text,
                          name: name.text,
                          phone: phone.text);
                      ref.invalidate(agentsProvider);
                      ref.invalidate(agentStatsProvider);
                      if (c.mounted) c.pop();
                    } catch (e) {
                      if (c.mounted)
                        ScaffoldMessenger.of(c)
                            .showSnackBar(SnackBar(content: Text('$e')));
                    } finally {
                      if (mounted) setState(() => loading = false);
                    }
                  },
            child: const Text('إنشاء الحساب'))
      ]));
}

class ClinicsListScreen extends ConsumerStatefulWidget {
  final bool mineOnly;

  const ClinicsListScreen({
    super.key,
    required this.mineOnly,
  });

  @override
  ConsumerState<ClinicsListScreen> createState() => _ClinicsListScreenState();
}

class _ClinicsListScreenState extends ConsumerState<ClinicsListScreen> {
  String filter = 'الكل';

  @override
  Widget build(BuildContext c) {
    final data = ref.watch(
      widget.mineOnly ? myClinicsProvider : clinicsProvider,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (c.canPop()) {
              c.pop();
            } else {
              c.go('/');
            }
          },
        ),
        title: Text(widget.mineOnly ? 'سجلاتي' : 'العيادات'),
        actions: [
          IconButton(
            tooltip: 'تصدير Excel',
            onPressed: data.hasValue
                ? () async {
                    try {
                      await exportClinicsToCsv(
                        _filtered(data.value ?? []),
                      );
                    } catch (e) {
                      if (c.mounted) {
                        ScaffoldMessenger.of(c).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    }
                  }
                : null,
            icon: const Icon(Icons.download),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => c.push(AppRoutes.capture),
        child: const Icon(Icons.add_a_photo),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              value: filter,
              decoration: const InputDecoration(labelText: 'فلترة الحالة'),
              items: ['الكل', 'New', 'Reviewed', 'Duplicate', 'Invalid']
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => filter = v ?? 'الكل'),
            ),
          ),
          Expanded(
            child: data.when(
              data: (list) {
                final shown = _filtered(list);

                if (shown.isEmpty) {
                  return const Center(child: Text('لا توجد بيانات'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: shown.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final x = shown[i];

                    return Card(
                      child: ListTile(
                        title: Text(x.clinicName ?? 'بدون اسم'),
                        subtitle: Text(
                          '${x.code} • ${x.status}\n'
                          '${x.specialty ?? ''} • ${x.mobile ?? x.phone ?? 'لا يوجد رقم'}',
                        ),
                        isThreeLine: true,
                        leading: Icon(
                          x.status == 'Duplicate'
                              ? Icons.copy
                              : Icons.local_hospital,
                          color: x.status == 'Duplicate'
                              ? Colors.orange
                              : AppColors.primary,
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
            ),
          ),
        ],
      ),
    );
  }

  List<ClinicModel> _filtered(List<ClinicModel> list) {
    return filter == 'الكل'
        ? list
        : list.where((e) => e.status == filter).toList();
  }
}

class CapturePayload {
  final Uint8List imageBytes;
  final OcrResult ocr;
  final double? lat, lng;
  final String? imageUrl, code, profileId;
  CapturePayload(
      {required this.imageBytes,
      required this.ocr,
      this.lat,
      this.lng,
      this.imageUrl,
      this.code,
      this.profileId});
}

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});
  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  bool loading = false;
  bool scanMode = false;
  String progress = '';
  Future<void> start(ImageSource source) async {
    setState(() {
      loading = true;
      progress = 'جاري اختيار الصورة...';
    });
    try {
      final pick =
          await ImagePicker().pickImage(source: source, imageQuality: 78);
      if (pick == null) return;
      final bytes = await pick.readAsBytes();
      setState(() => progress = 'جاري تحديد الموقع...');
      Position? pos;
      try {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied)
          perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.always ||
            perm == LocationPermission.whileInUse)
          pos = await Geolocator.getCurrentPosition();
      } catch (_) {}
      final code = await supabaseService.nextCode();
      setState(() => progress = 'جاري رفع الصورة...');
      String? url;
      try {
        url = await supabaseService.uploadImageBytes(bytes, code);
      } catch (_) {}
      setState(() => progress = 'جاري تحليل اللوحة بالذكاء الاصطناعي...');
      final ocr = await ocrService.scanBytes(bytes);
      final p = ref.read(currentProfileProvider).valueOrNull;
      final payload = CapturePayload(
          imageBytes: bytes,
          ocr: ocr,
          lat: pos?.latitude,
          lng: pos?.longitude,
          imageUrl: url,
          code: code,
          profileId: p?.id);
      if (scanMode) {
        await _autoSave(payload);
        return;
      }
      if (mounted) context.push(AppRoutes.review, extra: payload);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted)
        setState(() {
          loading = false;
          progress = '';
        });
    }
  }

  Future<void> _autoSave(CapturePayload payload) async {
    final d = await supabaseService.findDuplicate(
        mobile: payload.ocr.mobile,
        phone: payload.ocr.phone,
        lat: payload.lat,
        lng: payload.lng);
    if (d != null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('مكرر: ${d.clinicName ?? d.code} - لم يتم الحفظ')));
      return;
    }
    await supabaseService.insertClinic(ClinicModel(
        id: '',
        code: payload.code ?? await supabaseService.nextCode(),
        clinicName: payload.ocr.clinicName,
        doctorName: payload.ocr.doctorName,
        phone: payload.ocr.phone,
        mobile: payload.ocr.mobile,
        specialty: payload.ocr.specialty,
        city: payload.ocr.city,
        area: payload.ocr.area,
        addressText: payload.ocr.addressText,
        lat: payload.lat,
        lng: payload.lng,
        imageUrl: payload.imageUrl,
        rawText: payload.ocr.rawText,
        confidence: payload.ocr.confidence,
        createdBy: payload.profileId));
    ref.invalidate(clinicsProvider);
    ref.invalidate(myClinicsProvider);
    ref.invalidate(statsProvider);
    ref.invalidate(agentStatsProvider);
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم الحفظ بنجاح - جاهز للصورة التالية')));
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('التقاط لوحة')),
      body: Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_a_photo,
                        size: 86, color: AppColors.primary),
                    const SizedBox(height: 20),
                    const Text(
                        'صوّر لوحة العيادة وسيتم استخراج البيانات تلقائياً'),
                    const SizedBox(height: 12),
                    SwitchListTile(
                        value: scanMode,
                        onChanged: loading
                            ? null
                            : (v) => setState(() => scanMode = v),
                        title: const Text('Scan Mode - حفظ سريع متتالي'),
                        subtitle: const Text(
                            'يحلل ويحفظ مباشرة بدون شاشة مراجعة، مع منع التكرار')),
                    const SizedBox(height: 12),
                    if (loading)
                      Column(children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(progress)
                      ])
                    else ...[
                      ElevatedButton.icon(
                          onPressed: () => start(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('فتح الكاميرا')),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                          onPressed: () => start(ImageSource.gallery),
                          icon: const Icon(Icons.photo),
                          label: const Text('اختيار صورة'))
                    ]
                  ]))));
}

class OcrReviewScreen extends ConsumerStatefulWidget {
  final CapturePayload extra;
  const OcrReviewScreen({super.key, required this.extra});
  @override
  ConsumerState<OcrReviewScreen> createState() => _OcrReviewScreenState();
}

class _OcrReviewScreenState extends ConsumerState<OcrReviewScreen> {
  late final clinic = TextEditingController(text: widget.extra.ocr.clinicName);
  late final doc = TextEditingController(text: widget.extra.ocr.doctorName);
  late final phone = TextEditingController(text: widget.extra.ocr.phone);
  late final mobile = TextEditingController(text: widget.extra.ocr.mobile);
  late final spec = TextEditingController(text: widget.extra.ocr.specialty);
  late final city = TextEditingController(text: widget.extra.ocr.city);
  late final area = TextEditingController(text: widget.extra.ocr.area);
  late final addr = TextEditingController(text: widget.extra.ocr.addressText);
  bool saving = false;
  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('مراجعة البيانات')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(widget.extra.imageBytes,
                height: 180, fit: BoxFit.cover)),
        const SizedBox(height: 14),
        Text('الثقة: ${(widget.extra.ocr.confidence * 100).round()}%'),
        const SizedBox(height: 10),
        _f(clinic, 'اسم العيادة/المركز'),
        _f(doc, 'اسم الطبيب'),
        _f(mobile, 'الموبايل'),
        _f(phone, 'الهاتف'),
        _f(spec, 'التصنيف/الاختصاص'),
        _f(city, 'المدينة'),
        _f(area, 'المنطقة'),
        _f(addr, 'العنوان'),
        Text('GPS: ${widget.extra.lat ?? '-'}, ${widget.extra.lng ?? '-'}'),
        const SizedBox(height: 18),
        ElevatedButton(
            onPressed: saving
                ? null
                : () async {
                    setState(() => saving = true);
                    try {
                      final duplicate = await supabaseService.findDuplicate(
                          mobile: mobile.text,
                          phone: phone.text,
                          lat: widget.extra.lat,
                          lng: widget.extra.lng);
                      if (duplicate != null) {
                        final ok = await showDialog<bool>(
                            context: c,
                            builder: (d) => AlertDialog(
                                    title: const Text('تنبيه: سجل مكرر محتمل'),
                                    content: Text(
                                        'يوجد سجل مشابه: ${duplicate.clinicName ?? duplicate.code}\nهل تريد الحفظ كـ Duplicate؟'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(d, false),
                                          child: const Text('إلغاء')),
                                      ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(d, true),
                                          child: const Text('حفظ كمكرر'))
                                    ]));
                        if (ok != true) {
                          setState(() => saving = false);
                          return;
                        }
                      }
                      await supabaseService.insertClinic(ClinicModel(
                          id: '',
                          code: widget.extra.code ??
                              await supabaseService.nextCode(),
                          clinicName: clinic.text,
                          doctorName: doc.text,
                          phone: phone.text,
                          mobile: mobile.text,
                          specialty: spec.text,
                          city: city.text,
                          area: area.text,
                          addressText: addr.text,
                          lat: widget.extra.lat,
                          lng: widget.extra.lng,
                          imageUrl: widget.extra.imageUrl,
                          rawText: widget.extra.ocr.rawText,
                          confidence: widget.extra.ocr.confidence,
                          createdBy: widget.extra.profileId,
                          status: duplicate != null ? 'Duplicate' : 'New'));
                      ref.invalidate(clinicsProvider);
                      ref.invalidate(myClinicsProvider);
                      ref.invalidate(statsProvider);
                      ref.invalidate(agentStatsProvider);
                      if (c.mounted) c.go(AppRoutes.mine);
                    } catch (e) {
                      if (c.mounted)
                        ScaffoldMessenger.of(c)
                            .showSnackBar(SnackBar(content: Text('$e')));
                    } finally {
                      if (mounted) setState(() => saving = false);
                    }
                  },
            child: Text(saving ? 'جاري الحفظ...' : 'حفظ البيانات'))
      ]));
  Widget _f(TextEditingController c, String l) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child:
          TextField(controller: c, decoration: InputDecoration(labelText: l)));
}

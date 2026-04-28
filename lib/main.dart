import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_constants.dart';
import 'app_router.dart';
import 'app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: AppConstants.supabaseUrl, anonKey: AppConstants.supabaseAnonKey);
  runApp(const ProviderScope(child: ClinicCollectorApp()));
}
class ClinicCollectorApp extends ConsumerWidget { const ClinicCollectorApp({super.key});
  @override Widget build(BuildContext context, WidgetRef ref)=>MaterialApp.router(
    debugShowCheckedModeBanner:false, title:'Clinic Data Collector', theme:AppTheme.light,
    locale: const Locale('ar'), supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    routerConfig: ref.watch(routerProvider), builder:(context,child)=>Directionality(textDirection:TextDirection.rtl, child:child!),);
}

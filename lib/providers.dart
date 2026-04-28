
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';
import 'services.dart';

final authChangesProvider = StreamProvider<AuthState>((ref)=>Supabase.instance.client.auth.onAuthStateChange);
final currentProfileProvider = FutureProvider<ProfileModel?>((ref) async { ref.watch(authChangesProvider); return supabaseService.currentProfile(); });
final clinicsProvider = FutureProvider<List<ClinicModel>>((ref)=>supabaseService.clinics());
final myClinicsProvider = FutureProvider<List<ClinicModel>>((ref)=>supabaseService.clinics(mineOnly:true));
final statsProvider = FutureProvider<Map<String,int>>((ref)=>supabaseService.stats());
final agentsProvider = FutureProvider<List<ProfileModel>>((ref)=>supabaseService.agents());
final agentStatsProvider = FutureProvider<List<Map<String,dynamic>>>((ref)=>supabaseService.agentStats());

class AppConstants {
  AppConstants._();
  static const supabaseUrl = 'https://ockralcvowydnrcsytbm.supabase.co';
  static const supabaseAnonKey =
      'sb_publishable_FZUOEH3jPOMAMI5Zjy1gxw_zWhAnDpb';
  static const storageBucket = 'clinic-signs';
  static const tableProfiles = 'profiles';
  static const tableClinics = 'clinics';
  static const roleAdmin = 'admin';
  static const roleAgent = 'agent';

  // Real OCR is attempted through Supabase Edge Function.
  // If the function is missing/fails, the app falls back to mock data.
  static const useRealOcr = true;
  static const ocrFunctionName = 'analyze-clinic-sign';
}

class AppConstants {
  // Supabase Configuration
  // TODO: Add your Supabase URL and Anon Key here
  static const String supabaseUrl = 'https://bgebxxxqeenjkgxhlhej.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJnZWJ4eHhxZWVuamtneGhsaGVqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkwNzQ4OTksImV4cCI6MjA4NDY1MDg5OX0.He5JQIwh5SeJfDtQdbTC3UvwmOORar8Ib-L6E_TzpYY';
  
  // App Info
  static const String appName = 'Hest Yapı Pen';
  static const String appVersion = '1.0.0';
  
  // Routes
  static const String loginRoute = '/login';
  static const String adminDashboardRoute = '/admin-dashboard';
  static const String userDashboardRoute = '/user-dashboard';
  static const String kasaDefteriRoute = '/kasa-defteri';
  static const String staffListRoute = '/staff-list';
  static const String cariHomeRoute = '/cari-alacaklar';
  static const String cariAccountDetailRoute = '/cari-hesap-detay';
  static const String mtulCalcRoute = '/metretul-hesapla';
  static const String mtulPricesRoute = '/metretul-fiyatlar';
  static const String mtulHistoryRoute = '/metretul-gecmis';
  static const String glassCalcRoute = '/cam-hesapla';
  static const String glassHistoryRoute = '/cam-gecmis';
  static const String transactionHistoryRoute = '/islem-gecmisi';
  
  // User Roles
  static const String adminRole = 'admin';
  static const String userRole = 'user';
}

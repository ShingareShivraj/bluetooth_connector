class ApiEndpoints {
  // Change the server here only. Stored sessions from another site are rejected.
  static const baseUrl = 'https://erp.erpkey.in';
  static const loginMethod = 'login';
  // static const loginMethod = 'mobile.mobile_env.app.login';
  static const currentUserMethod = 'frappe.auth.get_logged_user';

  static Uri method(String name) => Uri.parse(
    '${baseUrl.replaceFirst(RegExp(r"/+$"), "")}/api/method/$name',
  );
}

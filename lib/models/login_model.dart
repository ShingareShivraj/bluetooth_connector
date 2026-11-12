class LoginModel {
  final String site;
  final String user;
  final String sid;

  const LoginModel({
    required this.site,
    required this.user,
    required this.sid,
  });

  factory LoginModel.fromJson(Map<String, dynamic> json) => LoginModel(
    site: json['site']?.toString() ?? '',
    user: json['user']?.toString() ?? '',
    sid: json['sid']?.toString() ?? '',
  );

  bool get isValid =>
      site.isNotEmpty &&
          user.isNotEmpty &&
          user != 'Guest' &&
          sid.isNotEmpty &&
          sid != 'Guest';

  Map<String, dynamic> toJson() => {
    'site': site,
    'user': user,
    'sid': sid,
  };
}
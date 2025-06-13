class SOSUserData {
  final String firstName;
  final String middleName;
  final String lastName;
  final int age;
  final List<String> emergencyContacts;

  SOSUserData({
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.age,
    required this.emergencyContacts,
  });

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'age': age,
      'emergencyContacts': emergencyContacts,
    };
  }

  factory SOSUserData.fromJson(Map<String, dynamic> json) {
    try {
      // Validate required fields
      if (!json.containsKey('firstName') ||
          !json.containsKey('middleName') ||
          !json.containsKey('lastName') ||
          !json.containsKey('age') ||
          !json.containsKey('emergencyContacts')) {
        throw const FormatException('Missing required fields in JSON');
      }

      // Validate types and convert data
      final firstName = json['firstName'];
      final middleName = json['middleName'];
      final lastName = json['lastName'];
      final age = json['age'];
      final contacts = json['emergencyContacts'];

      if (firstName is! String ||
          middleName is! String ||
          lastName is! String ||
          age is! int ||
          contacts is! List) {
        throw const FormatException('Invalid data types in JSON');
      }

      // Convert emergency contacts to List<String>
      final emergencyContacts = contacts.map((e) {
        if (e is! String) {
          throw const FormatException('Emergency contact must be a string');
        }
        return e;
      }).toList();

      return SOSUserData(
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        age: age,
        emergencyContacts: emergencyContacts,
      );
    } catch (e) {
      throw FormatException('Failed to parse SOSUserData: ${e.toString()}');
    }
  }
}

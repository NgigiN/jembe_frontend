/// Field length and numeric bounds aligned with backend DB column sizes.
abstract final class FieldLimits {
  static const int nameMax = 100;
  static const int shortLabelMax = 100;
  static const int locationMax = 255;
  static const int notesMax = 1000;
  static const int soilTypeMax = 100;
  static const int varietyMax = 255;

  static const double moneyMax = 9999999.99;
  static const int intMax = 999999;
  static const int decimalPlaces = 2;
}
class EntityDetailRow {
  const EntityDetailRow(
    this.label,
    this.value, {
    this.isPrimary = false,
  });

  final String label;
  final String value;
  final bool isPrimary;
}
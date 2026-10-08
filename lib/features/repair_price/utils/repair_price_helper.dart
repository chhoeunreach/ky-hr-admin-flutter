class RepairPriceHelper {
  static String currency(num? value) {
    if (value == null) return '-';
    return '\$${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)}';
  }

  static String repairTime(int? minutes) {
    if (minutes == null || minutes <= 0) return '-';
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remain = minutes % 60;
    return remain == 0 ? '$hours hr' : '$hours hr $remain min';
  }

  static String warranty(int? days) {
    if (days == null || days <= 0) return 'No warranty';
    if (days >= 30 && days % 30 == 0)
      return '${days ~/ 30} Month${days == 30 ? '' : 's'}';
    return '$days Day${days == 1 ? '' : 's'}';
  }
}

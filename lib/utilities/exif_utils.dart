Duration getTimeRangeDuration(String? timeRange) {
  switch (timeRange) {
    case '1 hour':
      return const Duration(hours: 1);
    case '4 hours':
      return const Duration(hours: 4);
    case '12 hours':
      return const Duration(hours: 12);
    default:
      return const Duration(hours: 1);
  }
}

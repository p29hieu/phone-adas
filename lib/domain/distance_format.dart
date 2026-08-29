/// HUD distance formatting: above 5 m whole meters are enough; at close
/// range (parking, creeping in a queue) tenths matter.
String formatDistanceM(double meters) =>
    meters > 5 ? meters.round().toString() : meters.toStringAsFixed(1);

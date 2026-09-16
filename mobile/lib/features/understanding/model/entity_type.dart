/// Kinds of meaning TINDAK can find in text.
enum EntityType {
  phone,
  url,
  money,
  date;

  /// Tie-break order when two entities cover exactly the same span with the
  /// same confidence. Lower wins. Fixed and explicit so overlap resolution is
  /// deterministic (docs/10_ARCHITECTURE.md section 5).
  int get priority => switch (this) {
    EntityType.url => 0,
    EntityType.phone => 1,
    EntityType.date => 2,
    EntityType.money => 3,
  };
}

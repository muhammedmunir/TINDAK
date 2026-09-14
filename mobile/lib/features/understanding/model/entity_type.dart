/// Kinds of meaning TINDAK can find in text.
///
/// M3 ships phone and URL only. Money and date arrive at M6 and are added here
/// then, not before — an enum value with no detector behind it would be a
/// promise the engine does not keep.
enum EntityType {
  phone,
  url;

  /// Tie-break order when two entities cover exactly the same span with the
  /// same confidence. Lower wins. Fixed and explicit so overlap resolution is
  /// deterministic (docs/10_ARCHITECTURE.md section 5).
  int get priority => switch (this) {
    EntityType.url => 0,
    EntityType.phone => 1,
  };
}

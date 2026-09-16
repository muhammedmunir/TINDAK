import 'package:tindak/features/actions/model/action_descriptor.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';

/// Decides which actions an entity offers.
///
/// Pure Dart, independent of UI (master plan section 11). It only decides what
/// is *available*. It never runs anything — that is `ActionRunner`, and only
/// ever in response to a tap.
///
/// | Entity | M4 actions |
/// |---|---|
/// | phone | Call; WhatsApp when the number is a mobile |
/// | url | Open |
final class ActionResolver {
  const ActionResolver();

  List<ActionDescriptor> resolve(DetectedEntity entity) => switch (entity.type) {
    EntityType.phone => <ActionDescriptor>[
      ActionDescriptor(kind: ActionKind.call, entity: entity),
      // PRD section 5 says WhatsApp "where applicable". A Malaysian landline
      // has no WhatsApp account behind it, so offering the button would be a
      // control that reliably leads nowhere.
      if (_isMobile(entity))
        ActionDescriptor(kind: ActionKind.whatsapp, entity: entity),
    ],
    EntityType.url => <ActionDescriptor>[
      ActionDescriptor(kind: ActionKind.openUrl, entity: entity),
    ],
    // M6a understands money and dates; their actions — Salin and Ingatkan —
    // arrive with M6b. Until then they carry no action rather than a button
    // that does nothing.
    EntityType.money || EntityType.date => const <ActionDescriptor>[],
  };

  static bool _isMobile(DetectedEntity phone) =>
      phone.normalizedValue.startsWith('+601');
}

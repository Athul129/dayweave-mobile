/// Phase 2 records the contracts observable from the existing web client.
///
/// The supplied archive did not contain SQL migrations or policy definitions,
/// and the Supabase connector is not enabled in this session. Therefore this
/// foundation intentionally does not assert primary keys, foreign keys,
/// indexes, column nullability, or RLS policy text. The live Supabase project
/// must be verified before production migrations or policy changes.
abstract final class SchemaVerification {
  static const knownTables = <String>[
    'tasks',
    'notes',
    'daily_intentions',
    'daily_reflections',
    'focus_sessions',
  ];
}

import 'package:flutter/material.dart';

import '../../../core/theme/dayweave_theme.dart';

class LooseNotesScreen extends StatefulWidget {
  const LooseNotesScreen({super.key});

  @override
  State<LooseNotesScreen> createState() => _LooseNotesScreenState();
}

class _LooseNotesScreenState extends State<LooseNotesScreen> {
  static const notes = [
    _MockNote(
        'OCT 7, 2026',
        'API integration notes',
        'Need to check the auth flow before moving to the next step...',
        'Need to check the authentication flow before moving to the next part. Also review the API response structure and handle error states properly.\n\nAdd logging for debugging and test the integration with real data.\n\nMaybe create a small checklist to track the remaining tasks.',
        'OCT 7, 2026',
        'October 5, 2026'),
    _MockNote(
        'OCT 6, 2026',
        'Weekend ideas',
        "Places I'd like to visit sometime...",
        "Places I'd like to visit sometime. Look for somewhere quiet with good walking routes.",
        'OCT 6, 2026',
        'October 6, 2026'),
    _MockNote(
        'OCT 4, 2026',
        'Project thoughts',
        'Some ideas for the new feature...',
        'Some ideas for the new feature and a few questions to bring into the next planning session.',
        'OCT 4, 2026',
        'October 4, 2026'),
    _MockNote(
        'OCT 2, 2026',
        'Reading list',
        'Books to check this month...',
        'Books to check this month and a few essays to return to when there is more room.',
        'OCT 2, 2026',
        'October 2, 2026'),
  ];

  int selectedIndex = 0;
  _NotesPage page = _NotesPage.list;
  bool emptyPreview = false;
  bool deletePreview = false;

  _MockNote get selected => notes[selectedIndex];

  @override
  Widget build(BuildContext context) {
    if (deletePreview) return _deleteSheetPreview(context);
    if (page == _NotesPage.reader) return _reader(context);
    if (page == _NotesPage.editor) return _editor(context);
    return _list(context);
  }

  Widget _list(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              DayweaveSpacing.lg, 8, DayweaveSpacing.lg, 24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _hero(context),
            const SizedBox(height: 20),
            _notebook(context),
          ]),
        ),
      );

  Widget _hero(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
        decoration: const BoxDecoration(
            color: DayweaveColors.bluePaper, borderRadius: DayweaveRadii.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _eyebrow(context, '♧  LOOSE NOTES', accent: true),
          const SizedBox(height: 12),
          Text('Keep a thought\nbefore it drifts.',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontFamily: 'Fraunces',
                  fontWeight: FontWeight.w600,
                  fontSize: 34,
                  height: .98)),
          const SizedBox(height: 12),
          Text(
              'A quiet shelf for questions, fragments, and the things that are not tasks yet.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.45)),
          const SizedBox(height: 18),
          FilledButton.icon(
              onPressed: () => setState(() => page = _NotesPage.editor),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New note'),
              style: FilledButton.styleFrom(
                  backgroundColor: DayweaveColors.ink,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 46))),
        ]),
      );

  Widget _notebook(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
        decoration: BoxDecoration(
            color: DayweaveColors.card,
            border: Border.all(color: DayweaveColors.line),
            borderRadius: DayweaveRadii.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _eyebrow(context, 'YOUR NOTEBOOK'),
                  const SizedBox(height: 5),
                  Text(emptyPreview ? '0 notes' : '4 notes',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontSize: 26)),
                ])),
            IconButton(
                onPressed: () => setState(() => page = _NotesPage.editor),
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'New note'),
          ]),
          const Divider(height: 18),
          TextField(
              enabled: false,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.inbox_outlined, size: 18),
                  hintText: 'Search your notes')),
          if (emptyPreview)
            _emptyList(context)
          else ...[
            const SizedBox(height: 10),
            ...notes
                .asMap()
                .entries
                .map((entry) => _noteRow(context, entry.key, entry.value)),
          ],
        ]),
      );

  Widget _noteRow(BuildContext context, int index, _MockNote note) => InkWell(
        onTap: () => setState(() {
          selectedIndex = index;
          page = _NotesPage.reader;
        }),
        borderRadius: DayweaveRadii.sm,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.fromLTRB(12, 11, 8, 10),
          decoration: BoxDecoration(
              color: index == selectedIndex
                  ? const Color(0xFFFFF3D9)
                  : DayweaveColors.card,
              border: Border(
                  left: BorderSide(
                      color: index == selectedIndex
                          ? DayweaveColors.marigold
                          : DayweaveColors.sage,
                      width: 2)),
              borderRadius: DayweaveRadii.sm),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(note.date,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(fontSize: 10, letterSpacing: 1.2))),
              const Icon(Icons.chevron_right,
                  size: 18, color: DayweaveColors.inkSoft)
            ]),
            const SizedBox(height: 5),
            Text(note.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontFamily: 'Fraunces', fontSize: 18)),
            const SizedBox(height: 4),
            Text(note.preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: DayweaveColors.inkSoft)),
          ]),
        ),
      );

  Widget _emptyList(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.edit_note, size: 30, color: DayweaveColors.sage),
          const SizedBox(height: 18),
          Text('Nothing loose yet.',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontSize: 24)),
          const SizedBox(height: 7),
          Text('Give the first thought somewhere to land.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          TextButton.icon(
              onPressed: () => setState(() => page = _NotesPage.editor),
              icon: const Icon(Icons.arrow_outward, size: 16),
              label: const Text('Write a note')),
        ]),
      );

  Widget _reader(BuildContext context) =>
      _scaffoldPage(context, 'LOOSE NOTES', [
        _eyebrow(context, 'LAST TOUCHED · ${selected.lastTouched}'),
        const SizedBox(height: 26),
        Text(selected.title,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontFamily: 'Fraunces',
                fontWeight: FontWeight.w600,
                fontSize: 38,
                height: 1)),
        const SizedBox(height: 18),
        Text('Written ${selected.written}',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 30),
        Text(selected.body,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontFamily: 'Fraunces', fontSize: 17, height: 1.65)),
        const SizedBox(height: 30),
        _actionBar(context, edit: true),
      ]);

  Widget _editor(BuildContext context) => _scaffoldPage(context, 'NEW NOTE', [
        Text('Catch the thought',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontSize: 28)),
        const SizedBox(height: 10),
        Text('A place for the thought that is not a task yet.',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 26),
        _field(context, 'TITLE', 'Note title'),
        const SizedBox(height: 20),
        _field(context, 'BODY', 'Write your note here...', lines: 8),
        const SizedBox(height: 28),
        Row(children: [
          Expanded(
              child: OutlinedButton(
                  onPressed: () => setState(() => page = _NotesPage.list),
                  child: const Text('Cancel'))),
          const SizedBox(width: 10),
          Expanded(
              child: FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                      backgroundColor: DayweaveColors.marigold,
                      foregroundColor: DayweaveColors.ink),
                  child: const Text('Save note')))
        ]),
      ]);

  Widget _field(BuildContext context, String label, String hint,
          {int lines = 1}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _eyebrow(context, label),
        const SizedBox(height: 7),
        TextField(
            enabled: false,
            maxLines: lines,
            decoration: InputDecoration(
                prefixIcon: lines == 1
                    ? const Icon(Icons.inbox_outlined, size: 18)
                    : const Icon(Icons.description_outlined, size: 18),
                hintText: hint))
      ]);

  Widget _actionBar(BuildContext context, {required bool edit}) =>
      Row(children: [
        Expanded(
            child: OutlinedButton.icon(
                onPressed: () => setState(() => page = _NotesPage.editor),
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Edit note'))),
        const SizedBox(width: 10),
        Expanded(
            child: TextButton.icon(
                onPressed: () => setState(() => deletePreview = true),
                icon: const Icon(Icons.delete_outline,
                    color: DayweaveColors.coral, size: 17),
                label: const Text('Delete note',
                    style: TextStyle(color: DayweaveColors.coral))))
      ]);

  Widget _deleteSheetPreview(BuildContext context) => Stack(children: [
        _reader(context),
        Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: .22))),
        Align(
            alignment: Alignment.bottomCenter,
            child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                decoration: const BoxDecoration(
                    color: DayweaveColors.card,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20))),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 34,
                      height: 4,
                      decoration: BoxDecoration(
                          color: DayweaveColors.line,
                          borderRadius: DayweaveRadii.sm)),
                  const SizedBox(height: 22),
                  const Icon(Icons.delete_outline,
                      size: 28, color: DayweaveColors.coral),
                  const SizedBox(height: 14),
                  Text('Delete this note?',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text('This can’t be undone.',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 22),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: () =>
                                setState(() => deletePreview = false),
                            child: const Text('Keep it'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: FilledButton(
                            onPressed: () => setState(() {
                                  deletePreview = false;
                                  page = _NotesPage.list;
                                }),
                            style: FilledButton.styleFrom(
                                backgroundColor: DayweaveColors.coral),
                            child: const Text('Delete note')))
                  ]),
                ])))
      ]);

  Widget _scaffoldPage(
          BuildContext context, String label, List<Widget> children) =>
      SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  DayweaveSpacing.xl, 12, DayweaveSpacing.xl, 28),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      IconButton(
                          onPressed: () =>
                              setState(() => page = _NotesPage.list),
                          icon: const Icon(Icons.arrow_back)),
                      const SizedBox(width: 8),
                      _eyebrow(context, label),
                      const Spacer(),
                      const Icon(Icons.more_horiz)
                    ]),
                    const Divider(height: 30),
                    ...children
                  ])));

  Widget _eyebrow(BuildContext context, String text, {bool accent = false}) =>
      Text(text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: accent ? DayweaveColors.marigold : DayweaveColors.inkSoft,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5));
}

enum _NotesPage { list, reader, editor }

class _MockNote {
  const _MockNote(this.date, this.title, this.preview, this.body,
      this.lastTouched, this.written);
  final String date;
  final String title;
  final String preview;
  final String body;
  final String lastTouched;
  final String written;
}

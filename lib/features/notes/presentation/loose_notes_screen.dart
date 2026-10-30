import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/dayweave_theme.dart';
import '../../../models/domain_models.dart';
import '../../../models/note_attachment.dart';
import '../../../features/auth/application/current_user_provider.dart';
import '../../../repositories/note_attachment_repository.dart';
import '../application/notes_controller.dart';
import '../application/note_media_preparation.dart';
import 'note_attachment_gallery.dart';

class LooseNotesScreen extends ConsumerStatefulWidget {
  const LooseNotesScreen({super.key});

  @override
  ConsumerState<LooseNotesScreen> createState() => _LooseNotesScreenState();
}

class _LooseNotesScreenState extends ConsumerState<LooseNotesScreen> {
  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final List<PreparedNoteMedia> _pendingMedia = [];
  _NotesPage _page = _NotesPage.list;
  String? _selectedNoteId;
  String? _editingNoteId;
  String? _validationError;
  bool _deleteConfirmationOpen = false;
  bool _isPickingMedia = false;
  bool _isSavingNote = false;
  int _uploadTotal = 0;
  int _uploadCompleted = 0;
  String? _uploadingFileName;
  PreparedNoteMedia? _cleanupUnconfirmedMedia;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (mounted) ref.read(notesProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(currentUserIdProvider, (previous, next) {
      if (previous == next) return;
      _selectedNoteId = null;
      _editingNoteId = null;
      _page = _NotesPage.list;
      _deleteConfirmationOpen = false;
      _pendingMedia.clear();
      _isPickingMedia = false;
      _isSavingNote = false;
      _cleanupUnconfirmedMedia = null;
      _searchController.clear();
      ref.read(notesProvider.notifier).setSearchQuery('');
      ref.read(notesProvider.notifier).load();
    });
    final notesState = ref.watch(notesProvider);
    final selected = _selectedNoteId == null
        ? null
        : _findNote(notesState.notes, _selectedNoteId!);

    if (_deleteConfirmationOpen && selected != null) {
      return _deleteConfirmation(context, notesState, selected);
    }
    if (_page == _NotesPage.reader && selected != null) {
      return _reader(context, selected, notesState);
    }
    if (_page == _NotesPage.editor) {
      return _editor(context, notesState);
    }
    return _list(context, notesState);
  }

  Note? _findNote(List<Note> notes, String id) {
    for (final note in notes) {
      if (note.id == id) return note;
    }
    return null;
  }

  Widget _list(BuildContext context, NotesState state) => SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(notesProvider.notifier).load(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              DayweaveSpacing.lg,
              8,
              DayweaveSpacing.lg,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _hero(context),
                const SizedBox(height: 20),
                _notebook(context, state),
              ],
            ),
          ),
        ),
      );

  Widget _hero(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
        decoration: const BoxDecoration(
          color: DayweaveColors.bluePaper,
          borderRadius: DayweaveRadii.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _eyebrow(context, '♧  LOOSE NOTES', accent: true),
            const SizedBox(height: 12),
            Text(
              'Keep a thought\nbefore it drifts.',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontFamily: 'Fraunces',
                    fontWeight: FontWeight.w600,
                    fontSize: 34,
                    height: .98,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'A quiet shelf for questions, fragments, and the things that are not tasks yet.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _openCreate,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New note'),
              style: FilledButton.styleFrom(
                backgroundColor: DayweaveColors.ink,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 46),
              ),
            ),
          ],
        ),
      );

  Widget _notebook(BuildContext context, NotesState state) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
        decoration: BoxDecoration(
          color: DayweaveColors.card,
          border: Border.all(color: DayweaveColors.line),
          borderRadius: DayweaveRadii.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _eyebrow(context, 'YOUR NOTEBOOK'),
                      const SizedBox(height: 5),
                      Text(
                        '${state.notes.length} ${state.notes.length == 1 ? 'note' : 'notes'}',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontSize: 26),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _openCreate,
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'New note',
                ),
              ],
            ),
            const Divider(height: 18),
            TextField(
              key: const Key('notes-search-field'),
              controller: _searchController,
              onChanged: ref.read(notesProvider.notifier).setSearchQuery,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.inbox_outlined, size: 18),
                hintText: 'Search your notes',
                suffixIcon: state.query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          ref.read(notesProvider.notifier).setSearchQuery('');
                        },
                        icon: const Icon(Icons.close, size: 18),
                      ),
              ),
            ),
            if (state.isLoading && state.notes.isEmpty) ...[
              const SizedBox(height: 22),
              const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: DayweaveColors.marigold,
                ),
              ),
              const SizedBox(height: 10),
              const Center(child: Text('Loading your notes…')),
            ] else if (state.loadError != null) ...[
              _loadError(context, state),
            ] else if (state.notes.isEmpty) ...[
              _emptyList(context),
            ] else if (state.hasNoMatches) ...[
              _noMatches(context),
            ] else ...[
              if (state.isLoading) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: DayweaveColors.marigold,
                ),
              ],
              const SizedBox(height: 10),
              ...state.filteredNotes.map((note) => _noteRow(context, note)),
            ],
          ],
        ),
      );

  Widget _noteRow(BuildContext context, Note note) {
    final selected = note.id == _selectedNoteId;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedNoteId = note.id;
          _page = _NotesPage.reader;
        });
        _requestAttachments(note.id);
      },
      borderRadius: DayweaveRadii.sm,
      child: Container(
        key: Key('note-row-${note.id}'),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.fromLTRB(12, 11, 8, 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF3D9) : DayweaveColors.card,
          border: Border(
            left: BorderSide(
              color: selected ? DayweaveColors.marigold : DayweaveColors.sage,
              width: 2,
            ),
          ),
          borderRadius: DayweaveRadii.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatNoteDate(note.updatedAt.value, uppercase: true),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(fontSize: 10, letterSpacing: 1.2),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: DayweaveColors.inkSoft,
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              note.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontFamily: 'Fraunces', fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              note.body.isEmpty
                  ? 'No body yet — open to add a little more.'
                  : note.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: DayweaveColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyList(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.edit_note, size: 30, color: DayweaveColors.sage),
            const SizedBox(height: 18),
            Text(
              'Nothing loose yet.',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 7),
            Text('Give the first thought somewhere to land.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: _openCreate,
              icon: const Icon(Icons.arrow_outward, size: 16),
              label: const Text('Write a note'),
            ),
          ],
        ),
      );

  Widget _noMatches(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.explore_outlined,
                size: 28, color: DayweaveColors.sage),
            const SizedBox(height: 14),
            Text(
              'No matching notes.',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 6),
            Text('Try a different word or let the thought rest.',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );

  Widget _loadError(BuildContext context, NotesState state) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: DayweaveColors.coral),
            const SizedBox(height: 10),
            Text(
              'Your notes could not be loaded. Please try again.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: state.isLoading
                  ? null
                  : () => ref.read(notesProvider.notifier).load(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );

  Widget _reader(BuildContext context, Note note, NotesState state) =>
      _scaffoldPage(context, 'LOOSE NOTES', [
        _eyebrow(
          context,
          'LAST TOUCHED · ${_formatNoteDate(note.updatedAt.value)}',
        ),
        const SizedBox(height: 26),
        Text(
          note.title,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontFamily: 'Fraunces',
                fontWeight: FontWeight.w600,
                fontSize: 38,
                height: 1,
              ),
        ),
        const SizedBox(height: 18),
        Text(
          'Written ${_formatNoteDate(note.createdAt.value)}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 30),
        Text(
          note.body.isEmpty
              ? 'This note is waiting for its first sentence.'
              : note.body,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(fontFamily: 'Fraunces', fontSize: 17, height: 1.65),
        ),
        const SizedBox(height: 22),
        _attachmentSection(context, note, state),
        const SizedBox(height: 30),
        _actionBar(context, note, state),
      ]);

  Widget _attachmentSection(
    BuildContext context,
    Note note,
    NotesState state,
  ) {
    final attachments = state.attachmentsByNoteId[note.id];
    final error = state.attachmentLoadErrorsByNoteId[note.id];
    if (state.attachmentLoadsInFlight.contains(note.id)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: DayweaveColors.marigold,
          ),
        ),
      );
    }
    if (error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Attachments could not be loaded.',
              style: Theme.of(context).textTheme.bodyMedium),
          TextButton(
            onPressed: () => _requestAttachments(note.id),
            child: const Text('Retry'),
          ),
        ],
      );
    }
    if (attachments == null || attachments.isEmpty) {
      return const SizedBox.shrink();
    }
    return NoteAttachmentGallery(
      key: ValueKey(note.id),
      attachments: attachments,
      isDeleting: state.isMutating,
      onRefreshUrl: () => _requestAttachments(note.id),
      onDelete: (attachment) => _confirmAttachmentDelete(note, attachment),
    );
  }

  Widget _editor(BuildContext context, NotesState state) {
    final isEditing = _editingNoteId != null;
    return _scaffoldPage(context, isEditing ? 'EDIT NOTE' : 'NEW NOTE', [
      Text(
        isEditing ? 'Keep the thread' : 'Catch the thought',
        style:
            Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 28),
      ),
      const SizedBox(height: 10),
      Text(
        isEditing
            ? 'Let the note stay loose, but keep it clear.'
            : 'A place for the thought that is not a task yet.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 26),
      _field(
        context,
        'TITLE',
        'Note title',
        controller: _titleController,
        autofocus: true,
        errorText: _validationError,
      ),
      const SizedBox(height: 20),
      _field(
        context,
        'BODY',
        'Write your note here...',
        controller: _bodyController,
        lines: 8,
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        key: const Key('add-note-media'),
        onPressed: _isPickingMedia ||
                _isSavingNote ||
                state.isLoading ||
                state.isMutating
            ? null
            : _pickNoteMedia,
        icon: _isPickingMedia
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.attach_file, size: 18),
        label:
            Text(_isPickingMedia ? 'Preparing media…' : 'Add photos or videos'),
      ),
      if (_pendingMedia.isNotEmpty) ...[
        const SizedBox(height: 8),
        if (_isSavingNote && _uploadTotal > 0) ...[
          Text(
            'Uploading ${(_uploadCompleted + 1).clamp(1, _uploadTotal)} of $_uploadTotal${_uploadingFileName == null ? '' : ' · $_uploadingFileName'}',
            key: const Key('note-upload-progress-label'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            key: const Key('note-upload-progress'),
            value: _uploadCompleted / _uploadTotal,
            color: DayweaveColors.marigold,
            backgroundColor: DayweaveColors.line,
          ),
          const SizedBox(height: 8),
        ],
        ..._pendingMedia.asMap().entries.map((entry) => ListTile(
              key: Key('pending-media-${entry.key}'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                entry.value.mediaType == NoteAttachmentMediaType.image
                    ? Icons.image_outlined
                    : Icons.videocam_outlined,
              ),
              title: Text(
                entry.value.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                identical(_cleanupUnconfirmedMedia, entry.value)
                    ? 'Cleanup unconfirmed; retry is blocked'
                    : _isSavingNote && entry.key == 0
                        ? 'Uploading…'
                        : 'Ready to upload',
              ),
              trailing: IconButton(
                tooltip: 'Remove attachment',
                onPressed: _isSavingNote ||
                        identical(_cleanupUnconfirmedMedia, entry.value)
                    ? null
                    : () => setState(() => _pendingMedia.removeAt(entry.key)),
                icon: const Icon(Icons.close),
              ),
            )),
      ],
      const SizedBox(height: 28),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed:
                  state.isMutating || _isSavingNote ? null : _cancelEditor,
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: state.isMutating ||
                      _isSavingNote ||
                      _cleanupUnconfirmedMedia != null
                  ? null
                  : _saveNote,
              style: FilledButton.styleFrom(
                backgroundColor: DayweaveColors.marigold,
                foregroundColor: DayweaveColors.ink,
              ),
              child: Text(
                state.isMutating || _isSavingNote
                    ? 'Saving…'
                    : _pendingMedia.isNotEmpty && _editingNoteId != null
                        ? 'Retry upload'
                        : 'Save note',
              ),
            ),
          ),
        ],
      ),
    ]);
  }

  Widget _field(
    BuildContext context,
    String label,
    String hint, {
    required TextEditingController controller,
    int lines = 1,
    bool autofocus = false,
    String? errorText,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eyebrow(context, label),
          const SizedBox(height: 7),
          TextField(
            key: Key(label == 'TITLE' ? 'note-title-field' : 'note-body-field'),
            controller: controller,
            autofocus: autofocus,
            maxLines: lines,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              prefixIcon: Icon(
                lines == 1 ? Icons.inbox_outlined : Icons.description_outlined,
                size: 18,
              ),
              hintText: hint,
              errorText: errorText,
            ),
          ),
        ],
      );

  Widget _actionBar(BuildContext context, Note note, NotesState state) => Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: state.isMutating ? null : () => _openEdit(note),
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Edit note'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextButton.icon(
              onPressed: state.isMutating
                  ? null
                  : () => setState(() => _deleteConfirmationOpen = true),
              icon: const Icon(
                Icons.delete_outline,
                color: DayweaveColors.coral,
                size: 17,
              ),
              label: const Text(
                'Delete note',
                style: TextStyle(color: DayweaveColors.coral),
              ),
            ),
          ),
        ],
      );

  Widget _deleteConfirmation(
    BuildContext context,
    NotesState state,
    Note note,
  ) =>
      Stack(
        children: [
          _reader(context, note, state),
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: .22)),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
              decoration: const BoxDecoration(
                color: DayweaveColors.card,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: DayweaveColors.line,
                      borderRadius: DayweaveRadii.sm,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Icon(
                    Icons.delete_outline,
                    size: 28,
                    color: DayweaveColors.coral,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Delete this note?',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This can’t be undone.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: state.isMutating
                              ? null
                              : () => setState(
                                    () => _deleteConfirmationOpen = false,
                                  ),
                          child: const Text('Keep it'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          key: const Key('confirm-note-delete'),
                          onPressed: state.isMutating ? null : _deleteNote,
                          style: FilledButton.styleFrom(
                            backgroundColor: DayweaveColors.coral,
                          ),
                          child: Text(
                            state.isMutating ? 'Deleting…' : 'Delete note',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _scaffoldPage(
    BuildContext context,
    String label,
    List<Widget> children,
  ) =>
      SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            DayweaveSpacing.xl,
            12,
            DayweaveSpacing.xl,
            28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                      onPressed: _backToList,
                      icon: const Icon(Icons.arrow_back)),
                  const SizedBox(width: 8),
                  _eyebrow(context, label),
                  const Spacer(),
                  const Icon(Icons.more_horiz),
                ],
              ),
              const Divider(height: 30),
              ...children,
            ],
          ),
        ),
      );

  Widget _eyebrow(BuildContext context, String text, {bool accent = false}) =>
      Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: accent ? DayweaveColors.marigold : DayweaveColors.inkSoft,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
      );

  void _openCreate() {
    _titleController.clear();
    _bodyController.clear();
    _pendingMedia.clear();
    _cleanupUnconfirmedMedia = null;
    setState(() {
      _editingNoteId = null;
      _validationError = null;
      _page = _NotesPage.editor;
    });
  }

  void _openEdit(Note note) {
    _titleController.text = note.title;
    _bodyController.text = note.body;
    _pendingMedia.clear();
    _cleanupUnconfirmedMedia = null;
    setState(() {
      _selectedNoteId = note.id;
      _editingNoteId = note.id;
      _validationError = null;
      _page = _NotesPage.editor;
    });
  }

  void _cancelEditor() {
    FocusManager.instance.primaryFocus?.unfocus();
    final editingId = _editingNoteId;
    final returnToReader = editingId != null &&
        _findNote(ref.read(notesProvider).notes, editingId) != null;
    setState(() {
      _validationError = null;
      _page = returnToReader ? _NotesPage.reader : _NotesPage.list;
      _editingNoteId = null;
      _pendingMedia.clear();
      _cleanupUnconfirmedMedia = null;
    });
    if (returnToReader) _requestAttachments(editingId);
  }

  void _backToList() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _page = _NotesPage.list;
      _editingNoteId = null;
      _validationError = null;
    });
  }

  Future<void> _saveNote() async {
    if (_isSavingNote) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(
          () => _validationError = 'Give this note a title before saving.');
      return;
    }
    final editingId = _editingNoteId;
    final body = _bodyController.text.trim();
    final startingUserId = ref.read(notesProvider).userId;
    setState(() {
      _isSavingNote = true;
      _uploadTotal = _pendingMedia.length;
      _uploadCompleted = 0;
      _uploadingFileName = null;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final saved = editingId == null
          ? await ref
              .read(notesProvider.notifier)
              .createNote(title: title, body: body)
          : await ref
              .read(notesProvider.notifier)
              .updateNote(editingId, title: title, body: body);
      if (!mounted || ref.read(notesProvider).userId != saved.userId) return;
      if (editingId == null && _pendingMedia.isNotEmpty) {
        setState(() {
          _selectedNoteId = saved.id;
          _editingNoteId = saved.id;
        });
      }
      while (_pendingMedia.isNotEmpty) {
        final media = _pendingMedia.first;
        if (mounted) setState(() => _uploadingFileName = media.fileName);
        try {
          await ref.read(notesProvider.notifier).uploadPreparedMedia(
                noteId: saved.id,
                media: media,
              );
        } catch (error) {
          if (error is NoteAttachmentUploadCleanupException && mounted) {
            setState(() => _cleanupUnconfirmedMedia = media);
          }
          rethrow;
        }
        if (!mounted || ref.read(notesProvider).userId != saved.userId) return;
        setState(() {
          _pendingMedia.remove(media);
          _uploadCompleted++;
          _uploadingFileName = null;
        });
      }
      setState(() {
        _selectedNoteId = saved.id;
        _editingNoteId = null;
        _validationError = null;
        _page = _NotesPage.reader;
      });
      _requestAttachments(saved.id);
      _showFeedback(editingId == null ? 'Note saved' : 'Note updated');
    } catch (error) {
      if (!mounted || ref.read(notesProvider).userId != startingUserId) return;
      final message = error is NoteAttachmentUploadCleanupException
          ? 'Upload cleanup could not be confirmed. This file is blocked from retry to avoid a duplicate; it may remain in Storage and needs reconciliation.'
          : _pendingMedia.isNotEmpty && _editingNoteId != null
              ? 'Some attachments could not be uploaded. Retry to continue; completed uploads will not be sent again.'
              : _mutationMessage(
                  error, 'Note could not be saved. Please try again.');
      _showFeedback(message);
    } finally {
      if (mounted) {
        setState(() {
          _isSavingNote = false;
          _uploadingFileName = null;
        });
      }
    }
  }

  Future<void> _pickNoteMedia() async {
    if (_isPickingMedia) return;
    final startingUserId = ref.read(notesProvider).userId;
    setState(() => _isPickingMedia = true);
    try {
      final result =
          await ref.read(notesProvider.notifier).pickAndPrepareMedia();
      if (!mounted) return;
      setState(() => _pendingMedia.addAll(result.prepared));
      if (result.errors.isNotEmpty) _showFeedback(result.errors.join('\n'));
    } catch (error) {
      if (mounted && ref.read(notesProvider).userId == startingUserId) {
        _showFeedback(_mutationMessage(error, 'Media could not be selected.'));
      }
    } finally {
      if (mounted) setState(() => _isPickingMedia = false);
    }
  }

  Future<void> _confirmAttachmentDelete(
    Note note,
    NoteAttachment attachment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this attachment?'),
        content: const Text(
          'The stored media and its attachment record will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            key: const Key('confirm-attachment-delete'),
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: DayweaveColors.coral,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final startingUserId = ref.read(notesProvider).userId;
    try {
      await ref.read(notesProvider.notifier).deleteAttachment(
            noteId: note.id,
            attachment: attachment,
          );
      if (!mounted || ref.read(notesProvider).userId != startingUserId) return;
      _showFeedback('Attachment removed');
    } catch (error) {
      if (!mounted || ref.read(notesProvider).userId != startingUserId) return;
      _showFeedback(_attachmentDeletionMessage(error));
    }
  }

  String _attachmentDeletionMessage(Object error) => error
          is NoteAttachmentMetadataDeletionException
      ? 'The media file is removed, but its record could not be cleared. Tap Remove and retry to finish cleanup.'
      : error is NoteAttachmentObjectRemovalUnconfirmedException
          ? 'Storage did not confirm removal. The attachment remains listed; retry when the connection is available.'
          : 'The attachment could not be removed. It remains listed; check your connection and retry.';

  void _requestAttachments(String noteId) {
    Future<void>.microtask(
      () {
        if (mounted) ref.read(notesProvider.notifier).loadAttachments(noteId);
      },
    );
  }

  Future<void> _deleteNote() async {
    final noteId = _selectedNoteId;
    if (noteId == null) return;
    final startingUserId = ref.read(notesProvider).userId;
    try {
      await ref.read(notesProvider.notifier).deleteNote(noteId);
      if (!mounted || ref.read(notesProvider).userId != startingUserId) return;
      setState(() {
        _selectedNoteId = null;
        _editingNoteId = null;
        _deleteConfirmationOpen = false;
        _page = _NotesPage.list;
      });
      _showFeedback('Note deleted');
    } catch (error) {
      if (mounted && ref.read(notesProvider).userId == startingUserId) {
        _showFeedback(_mutationMessage(
            error, 'Note could not be deleted. Please try again.'));
      }
    }
  }

  String _mutationMessage(Object error, String fallback) {
    if (error is NoteDeletionFailure) return error.userMessage;
    return error is StateError ? error.message.toString() : fallback;
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatNoteDate(DateTime value, {bool uppercase = false}) {
    final local = value.toLocal();
    const shortMonths = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const fullMonths = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final month = uppercase
        ? shortMonths[local.month - 1].toUpperCase()
        : fullMonths[local.month - 1];
    return '$month ${local.day}, ${local.year}';
  }
}

enum _NotesPage { list, reader, editor }

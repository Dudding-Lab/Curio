import 'package:curio/features/capture/capture_suggestion.dart';
import 'package:curio/features/capture/photo_selection_service.dart';
import 'package:curio/features/capture/vision_suggestion_repository.dart';
import 'package:curio/features/taxonomy/template_catalog_repository.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Photo selection and explicit consent precede any outbound request.
/// This feature flag is deliberately false until real Auth, privacy and
/// provider billing tests have passed. No image or item is saved here.
const bool kVisionUploadEnabled = bool.fromEnvironment(
  'KOVUNELA_ENABLE_VISION_UPLOAD',
  defaultValue: false,
);

class PhotoCaptureScreen extends StatefulWidget {
  const PhotoCaptureScreen({
    super.key,
    this.photoService,
    this.visionRepository,
    this.templateRepository,
    this.enableVision = kVisionUploadEnabled,
  });

  final PhotoSelectionService? photoService;
  final VisionSuggestionRepository? visionRepository;
  final TemplateCatalogRepository? templateRepository;
  final bool enableVision;

  @override
  State<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen> {
  CapturedPhoto? _photo;
  CaptureReview? _review;
  bool _consented = false;
  bool _busy = false;
  bool _validated = false;
  String? _error;

  Future<void> _choose(PhotoSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picker = widget.photoService ??
          ImagePickerPhotoSelectionService();
      final result = await picker.select(source);
      if (!mounted || result == null) return;
      setState(() {
        _photo = result;
        _review = null;
        _consented = false;
        _validated = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppLocalizations.of(context)!.photoSelectionError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _discard() {
    setState(() {
      _photo = null;
      _review = null;
      _consented = false;
      _validated = false;
      _error = null;
    });
  }

  Future<void> _analyze() async {
    if (_busy || _photo == null || !_consented || !widget.enableVision) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _review = null;
    });
    try {
      final templates = await (widget.templateRepository ??
              SupabaseTemplateCatalogRepository(Supabase.instance.client))
          .listStandards();
      if (templates.isEmpty) throw StateError('No templates available');
      final photo = _photo!;
      final proposal = await (widget.visionRepository ??
              SupabaseVisionSuggestionRepository(Supabase.instance.client))
          .analyze(
        imageBytes: photo.bytes,
        mimeType: photo.mimeType,
        templates: templates.take(12).toList(growable: false),
      );
      final selected = templates.where(
        (template) => template.code == proposal.templateCode,
      );
      if (selected.isEmpty) throw const FormatException('Unknown template');
      final review = CaptureReview(
        template: selected.first,
        proposal: proposal,
      );
      if (!mounted) return;
      setState(() {
        _review = review;
        _validated = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppLocalizations.of(context)!.photoAnalysisError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _validateReview() {
    try {
      _review!.validatedAttributes();
      setState(() => _validated = true);
    } on FormatException {
      setState(() => _validated = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final photo = _photo;
    final review = _review;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.photoCaptureTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.photoCaptureIntro),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _choose(PhotoSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text(l10n.takePhoto),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _choose(PhotoSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(l10n.chooseFromGallery),
                  ),
                ],
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_error!, key: const ValueKey('photo-error')),
                ),
              if (photo != null) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    photo.bytes,
                    key: const ValueKey('photo-preview'),
                    fit: BoxFit.contain,
                    height: 240,
                    errorBuilder: (_, __, ___) =>
                        Text(l10n.photoSelectionError),
                  ),
                ),
                const SizedBox(height: 8),
                Text(l10n.photoSelectedInfo(
                  photo.mimeType,
                  photo.bytes.length,
                )),
                TextButton.icon(
                  onPressed: _busy ? null : _discard,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.discardSelectedPhoto),
                ),
                const Divider(height: 24),
                CheckboxListTile(
                  key: const ValueKey('photo-consent'),
                  contentPadding: EdgeInsets.zero,
                  value: _consented,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _consented = value ?? false),
                  title: Text(l10n.photoTransferConsent),
                  subtitle: Text(l10n.photoTransferExplanation),
                ),
                if (!widget.enableVision)
                  Text(l10n.photoVisionDisabled,
                      key: const ValueKey('photo-vision-disabled')),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey('analyze-photo'),
                  onPressed: !_busy && _consented && widget.enableVision
                      ? _analyze
                      : null,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(l10n.analyzeSelectedPhoto),
                ),
              ],
              if (review != null) ...[
                const Divider(height: 32),
                Text(l10n.aiReviewFields,
                    style: Theme.of(context).textTheme.titleMedium),
                TextFormField(
                  key: const ValueKey('vision-review-title'),
                  initialValue: review.reviewedTitle,
                  decoration: InputDecoration(labelText: l10n.itemTitle),
                  onChanged: (value) {
                    review.setTitle(value);
                    _validated = false;
                  },
                ),
                const SizedBox(height: 12),
                ...review.draft.fields.entries.map((field) {
                  final name = field.key;
                  final value = review.draft.values[name];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextFormField(
                      key: ValueKey('vision-review-$name'),
                      initialValue: value?.toString() ?? '',
                      keyboardType: field.value == 'number'
                          ? TextInputType.number
                          : TextInputType.text,
                      decoration: InputDecoration(labelText: name),
                      onChanged: (text) {
                        review.draft.values[name] = text;
                        _validated = false;
                      },
                    ),
                  );
                }),
                if (review.rejectedReasons.isNotEmpty)
                  Text(l10n.aiRejectedFields(review.rejectedReasons.length)),
                FilledButton.icon(
                  onPressed: _validateReview,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(l10n.validateTemplatePreview),
                ),
                Text(_validated ? l10n.aiReviewComplete : l10n.aiNeedsReview),
                Text(l10n.photoNeverAutoSaved),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

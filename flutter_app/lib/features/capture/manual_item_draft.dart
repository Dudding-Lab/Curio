/// Captured user input awaiting review. Never persisted implicitly.
class ManualItemDraft {
  const ManualItemDraft({
    required this.title,
    this.description = '',
  });

  final String title;
  final String description;

  static const maxTitleLength = 200;
  static const maxDescriptionLength = 5000;

  String? validate() {
    if (title.trim().isEmpty || title.trim().length > maxTitleLength) {
      return 'title';
    }
    if (description.length > maxDescriptionLength) {
      return 'description';
    }
    return null;
  }

  ManualItemDraft normalized() => ManualItemDraft(
        title: title.trim(),
        description: description.trim(),
      );
}

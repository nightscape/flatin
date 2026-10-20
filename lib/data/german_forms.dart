import '../models/practice_item.dart';

/// The German text of one Latin form.
/// Implemented by the German form data; read by the generators.
abstract interface class GermanForms {
  String render(PracticeItem item, FormKey key);
}

/// Renders `<lemma>@<key>`, so every form has its own German text.
/// Stands in for the German form data in tests of generators and screens.
class FakeGermanForms implements GermanForms {
  const FakeGermanForms();

  @override
  String render(PracticeItem item, FormKey key) => '${item.lemma}@$key';
}

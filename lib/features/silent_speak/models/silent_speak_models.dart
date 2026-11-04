enum SilentSpeakMode { speakForMe, listenAndUnderstand }

enum SilentSpeakIntent {
  lost('LOST'),
  feelUnwell('FEEL_UNWELL'),
  needWater('NEED_WATER'),
  needHelp('NEED_HELP'),
  contactFamily('CONTACT_FAMILY'),
  goHome('GO_HOME');

  const SilentSpeakIntent(this.code);

  final String code;
}

String buildSpeakForMeMessage(
  Iterable<SilentSpeakIntent> selected, {
  required bool inBangla,
}) {
  final chosen = selected.toSet();
  final phrases = <SilentSpeakIntent, String>{
    SilentSpeakIntent.lost: inBangla ? 'আমি পথ হারিয়ে ফেলেছি।' : 'I am lost.',
    SilentSpeakIntent.feelUnwell: inBangla
        ? 'আমার অসুস্থ লাগছে।'
        : 'I do not feel well.',
    SilentSpeakIntent.needWater: inBangla
        ? 'আমার পানি দরকার।'
        : 'I need water.',
    SilentSpeakIntent.needHelp: inBangla
        ? 'আমার সাহায্য দরকার।'
        : 'I need help.',
    SilentSpeakIntent.contactFamily: inBangla
        ? 'অনুগ্রহ করে আমার পরিবারের সঙ্গে যোগাযোগ করতে সাহায্য করুন।'
        : 'Please help me contact my family.',
    SilentSpeakIntent.goHome: inBangla
        ? 'আমি বাড়ি যেতে চাই।'
        : 'I want to go home.',
  };

  return phrases.entries
      .where((entry) => chosen.contains(entry.key))
      .map((entry) => entry.value)
      .join(' ');
}

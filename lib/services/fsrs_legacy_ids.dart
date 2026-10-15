/// Pre-2.0 content hashes of practice items that were removed as duplicates of
/// another item with the same lemma, mapped to the id of the surviving item.
///
/// Items still present in the YAML files need no entry: their hash is
/// recomputed from the data during the conversion.
const Map<String, String> deletedDuplicateIds = {
  // nouns: amīcus (the demonstration item "Der Freund" and the inference test
  // copy) -> the vocabulary item.
  '67304aa2ddc43f7bf6cb120c4540b0e52232b30ec0ebc676bc4fdb81ff5f9925':
      'nouns:amicus',
  '6001ff8ac8ceffbb7cea304a442a84c4b29635ed9866b26508a32681416dca7d':
      'nouns:amicus',
  // nouns: the inference test copies of Rōmānus, fīlius, fīlia, fēmina.
  '5b45ab46769e0580fe4a5ce432ce555a3defba00727a2af296864dfc763f57f5':
      'nouns:romanus',
  '1d0647bf076f78cc04e460019746d02156d31e8e3ea6f4ba747d89a1e0bca087':
      'nouns:filius',
  '137e477eb1f76acc5ae6cfcea8f5584accabd4da9f6888523c7e931c1cdf57ea':
      'nouns:filia',
  'aef76f2000a4e8db78c8ff6a7e9d96034e2b9a7a043fbb112b4519cf6d812a22':
      'nouns:femina',
  // verbs: the inference test copies of amāre, habēre and audīre (two).
  '2e1e4011b61a1672816b7519f88daa0813ebc2450513c3927cf73513488dfbfd':
      'verbs:amare',
  'c99bf36b8315c86439b405ec32a1401bb88937e90bef00e908bed14a7f662efc':
      'verbs:habere',
  'd893bee2ac3e5e415b19f79e36eccd39339ea12822cd9d2e4e482d338f78f0b9':
      'verbs:audire',
  '70bbad96fc1ec28dd1dd13c622ae802111035fe91f699a38357cd133c44cc4ea':
      'verbs:audire',
  // The deleted venīre and appārēre copies hashed identically to the surviving
  // items, so they need no entry.
};

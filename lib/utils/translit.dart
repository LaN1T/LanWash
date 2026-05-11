import 'package:flutter/material.dart';

const _enToRu = {
  'q':'й','w':'ц','e':'у','r':'к','t':'е','y':'н','u':'г','i':'ш','o':'щ','p':'з',
  '[':'х',']':'ъ','a':'ф','s':'ы','d':'в','f':'а','g':'п','h':'р','j':'о','k':'л',
  'l':'д',';':'ж',"'":'э','z':'я','x':'ч','c':'с','v':'м','b':'и','n':'т','m':'ь',
  ',':'б','.':'ю',
  'Q':'Й','W':'Ц','E':'У','R':'К','T':'Е','Y':'Н','U':'Г','I':'Ш','O':'Щ','P':'З',
  'A':'Ф','S':'Ы','D':'В','F':'А','G':'П','H':'Р','J':'О','K':'Л','L':'Д',
  'Z':'Я','X':'Ч','C':'С','V':'М','B':'И','N':'Т','M':'Ь',
};

const _ruToEn = {
  'й':'q','ц':'w','у':'e','к':'r','е':'t','н':'y','г':'u','ш':'i','щ':'o','з':'p',
  'ф':'a','ы':'s','в':'d','а':'f','п':'g','р':'h','о':'j','л':'k',
  'д':'l','я':'z','ч':'x','с':'c','м':'v','и':'b','т':'n','ь':'m',
  'Й':'Q','Ц':'W','У':'E','К':'R','Е':'T','Н':'Y','Г':'U','Ш':'I','Щ':'O','З':'P',
  'Ф':'A','Ы':'S','В':'D','А':'F','П':'G','Р':'H','О':'J','Л':'K','Д':'L',
  'Я':'Z','Ч':'X','С':'C','М':'V','И':'B','Т':'N','Ь':'M',
};

String translitToRu(String input) =>
    input.split('').map((c) => _enToRu[c] ?? c).join();

String translitToEn(String input) =>
    input.split('').map((c) => _ruToEn[c] ?? c).join();

void applyTranslitRu(TextEditingController ctrl, String v) {
  final converted = translitToRu(v);
  if (converted != v) {
    ctrl.value = TextEditingValue(
      text: converted,
      selection: TextSelection.collapsed(offset: converted.length),
    );
  }
}

void applyTranslitEn(TextEditingController ctrl, String v) {
  final converted = translitToEn(v);
  if (converted != v) {
    ctrl.value = TextEditingValue(
      text: converted,
      selection: TextSelection.collapsed(offset: converted.length),
    );
  }
}

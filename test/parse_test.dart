import 'package:redouble_exercises/parse.dart';
import 'package:test/test.dart';

void main() {
  test('a list gives one step for each item, with entities decoded', () {
    expect(
      stepsOf('<ol>\n<li>Grip &amp; <b>pull</b>.</li>\n<li> Lower. </li></ol>'),
      ['Grip & pull.', 'Lower.'],
    );
  });

  test('paragraphs, then lines, when there is no list', () {
    expect(stepsOf('<p>One.</p><p>Two.</p>'), ['One.', 'Two.']);
    expect(stepsOf('One.\nTwo.'), ['One.', 'Two.']);
    expect(stepsOf(''), isEmpty);
  });
}

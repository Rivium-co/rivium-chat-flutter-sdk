import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rivium_chat_ecommerce_example/main.dart';

void main() {
  test('app widget can be created', () {
    expect(const RiviumChatEcommerceApp(), isA<StatefulWidget>());
  });
}

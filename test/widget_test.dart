// Widget tests for BookSearchScreen.
//
// These use an in-memory FakeFirebaseFirestore pre-filled the same way the
// "books" collection is filled in the Firebase Console. They check the UI and
// search logic only; the real Firestore is verified by running the app.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_experiment_8_google_firestore_book_search/book_search_screen.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BookSearchScreen(collection: firestore.collection('books')),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String title) async {
    await tester.enterText(find.byType(TextField), title);
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
  }

  // The search text is also in the TextField, so look inside the result card.
  Finder inCard(String text) =>
      find.descendant(of: find.byType(Card), matching: find.text(text));

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    final books = firestore.collection('books');
    await books.add({
      'title': 'Flutter Basics',
      'author': 'John Smith',
      'copies': 5,
    });
    await books.add({
      'title': 'Python Programming',
      'author': 'David',
      'copies': 0,
    });
    await books.add({
      'title': 'Artificial Intelligence',
      'author': 'Andrew',
      'copies': 3,
    });
  });

  testWidgets('shows title, search field and button', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Library Book Search'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
  });

  testWidgets('Flutter Basics shows details without warning', (tester) async {
    await pumpScreen(tester);
    await search(tester, 'Flutter Basics');

    expect(inCard('Flutter Basics'), findsOneWidget);
    expect(find.text('John Smith'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Not Available – All Copies Issued'), findsNothing);
  });

  testWidgets('Python Programming shows red unavailable warning', (
    tester,
  ) async {
    await pumpScreen(tester);
    await search(tester, 'Python Programming');

    expect(find.text('David'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    final warning = tester.widget<Text>(
      find.text('Not Available – All Copies Issued'),
    );
    expect(warning.style!.color, Colors.red);
  });

  testWidgets('search is case-insensitive and ignores extra spaces', (
    tester,
  ) async {
    await pumpScreen(tester);
    await search(tester, '   artificial    INTELLIGENCE  ');

    expect(inCard('Artificial Intelligence'), findsOneWidget);
    expect(find.text('Andrew'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('unknown title shows Book not found', (tester) async {
    await pumpScreen(tester);
    await search(tester, 'Data Structures');

    expect(find.text('Book not found'), findsOneWidget);
  });

  testWidgets('empty field shows validation message', (tester) async {
    await pumpScreen(tester);
    await search(tester, '   ');

    expect(find.text('Please enter a book title to search'), findsOneWidget);
    expect(find.text('Book not found'), findsNothing);
  });

  testWidgets('search never writes to Firestore', (tester) async {
    await pumpScreen(tester);
    await search(tester, 'Flutter Basics');
    await search(tester, 'Unknown');

    expect((await firestore.collection('books').get()).docs, hasLength(3));
  });
}

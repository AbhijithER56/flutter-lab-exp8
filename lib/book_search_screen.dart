import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'main.dart' show kEspresso, kBrass, kPaper, kMuted;

/// Searches the Cloud Firestore collection "books" by title and shows the
/// matching book. Books are added manually in the Firebase Console; this
/// screen only reads from Firestore and never writes to it.
class BookSearchScreen extends StatefulWidget {
  const BookSearchScreen({super.key, this.collection});

  /// Optional collection override (used by tests with a fake Firestore).
  /// Defaults to FirebaseFirestore.instance.collection("books").
  final CollectionReference? collection;

  @override
  State<BookSearchScreen> createState() => _BookSearchScreenState();
}

class _BookSearchScreenState extends State<BookSearchScreen> {
  final _titlecontroller = TextEditingController();

  // Database instance
  late final CollectionReference books =
      widget.collection ?? FirebaseFirestore.instance.collection("books");

  bool _searching = false;
  Map<String, dynamic>? _book;
  String _message = "";
  bool _isError = false;

  @override
  void dispose() {
    _titlecontroller.dispose();
    super.dispose();
  }

  // Trim, collapse repeated spaces and lowercase, so "  flutter   BASICS "
  // matches "Flutter Basics".
  static String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  // Console users may store copies as a number or as text; accept both.
  static int? _parseCopies(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  // READ: fetch the "books" collection and pick the document whose title
  // matches the search text. Firestore queries are case-sensitive and the
  // documents only have title/author/copies, so matching is done here.
  Future<void> _searchBook() async {
    FocusScope.of(context).unfocus();
    final query = _normalize(_titlecontroller.text);

    if (query.isEmpty) {
      setState(() {
        _book = null;
        _message = "Please enter a book title to search";
        _isError = true;
      });
      return;
    }

    setState(() {
      _searching = true;
      _book = null;
      _message = "";
    });

    try {
      final snapshot = await books.get();
      Map<String, dynamic>? match;
      for (final doc in snapshot.docs) {
        // Read defensively: documents added by hand may be missing a field.
        final data = doc.data() as Map<String, dynamic>? ?? {};
        if (_normalize("${data['title'] ?? ''}") == query) {
          match = data;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _book = match;
        _message = match == null ? "Book not found" : "";
        _isError = match == null;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _message = "Firebase error (${e.code}): ${e.message ?? 'unknown'}";
        _isError = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = "Failed to search: $e";
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  // Shelf banner above the search box
  Widget _buildBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kEspresso,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        children: [
          Text('📚', style: TextStyle(fontSize: 40)),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The Reading Room',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Type a title to look it up on the shelves.',
                  style: TextStyle(color: Color(0xFFD9C7B0), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: c, width: w),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _titlecontroller,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) {
            if (!_searching) _searchBook();
          },
          decoration: InputDecoration(
            labelText: "Enter Book Title",
            prefixIcon: const Icon(Icons.menu_book, color: kBrass),
            filled: true,
            fillColor: kPaper,
            border: border(const Color(0xFFDCCBB3)),
            enabledBorder: border(const Color(0xFFDCCBB3)),
            focusedBorder: border(kBrass, 2),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: _searching ? null : _searchBook,
            style: FilledButton.styleFrom(
              backgroundColor: kEspresso,
              foregroundColor: Colors.white,
              disabledBackgroundColor: kMuted,
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.search),
            label: const Text("Search"),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kBrass),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: kMuted, fontSize: 13),
            ),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }

  // Result shown as a book: brass spine on the left, details on the page
  Widget _buildBookCard(Map<String, dynamic> book) {
    final copies = _parseCopies(book['copies']);
    final available = copies != null && copies > 0;
    return Card(
      color: kPaper,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE3D3BA)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 14, color: kBrass),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${book['title'] ?? '-'}",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: kEspresso,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: Color(0xFFE3D3BA), height: 1),
                    const SizedBox(height: 6),
                    _buildDetailRow(
                      Icons.person_outline,
                      "Author",
                      Text(
                        "${book['author'] ?? '-'}",
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    _buildDetailRow(
                      Icons.inventory_2_outlined,
                      "Copies Available",
                      Text(
                        "${copies ?? '-'}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: kEspresso,
                        ),
                      ),
                    ),
                    if (available) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'In stock',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    if (copies == 0) ...[
                      const SizedBox(height: 8),
                      const Text(
                        "Not Available – All Copies Issued",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: kBrass)),
      );
    }
    if (_book != null) return _buildBookCard(_book!);
    if (_message.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _isError ? Colors.red : kEspresso,
            fontSize: 16,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Library Book Search")),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          // Keep the layout readable on tablets / landscape.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBanner(),
                  const SizedBox(height: 18),
                  _buildSearchBar(),
                  const SizedBox(height: 20),
                  _buildResult(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

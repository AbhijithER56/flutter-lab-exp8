import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  Widget _buildSearchBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _titlecontroller,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) {
            if (!_searching) _searchBook();
          },
          decoration: const InputDecoration(
            labelText: "Enter Book Title",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.menu_book),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _searching ? null : _searchBook,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.deepPurple.shade200,
            ),
            icon: const Icon(Icons.search),
            label: const Text("Search"),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book) {
    final copies = _parseCopies(book['copies']);
    return Card(
      color: Colors.white,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow("Title", "${book['title'] ?? '-'}"),
            _buildDetailRow("Author", "${book['author'] ?? '-'}"),
            _buildDetailRow("Copies Available", "${copies ?? '-'}"),
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
    );
  }

  Widget _buildResult() {
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
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
            color: _isError ? Colors.red : Colors.black87,
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
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        title: const Text("Library Book Search"),
      ),
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

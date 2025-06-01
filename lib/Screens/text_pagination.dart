import 'dart:math';

class TextPagination {
  final List<String> _originalLines = [];
  final int displayLinesPerPage;
  final int maxCharsPerLine;

  // Cached wrapped lines for efficiency
  final List<String> _wrappedLines = [];
  int _currentPageIndex = 0;

  TextPagination({
    this.displayLinesPerPage = 5,
    this.maxCharsPerLine = 20, // Frame display character width
  });

  void appendLine(String newLine) {
    _originalLines.add(newLine);

    // Wrap the new line if it's too long
    final wrappedLines = _wrapText(newLine);
    _wrappedLines.addAll(wrappedLines);
  }

  List<String> _wrapText(String text) {
    if (text.length <= maxCharsPerLine) {
      return [text];
    }

    final List<String> lines = [];
    int start = 0;

    while (start < text.length) {
      int end = start + maxCharsPerLine;

      if (end >= text.length) {
        lines.add(text.substring(start));
        break;
      }

      // Try to break at a word boundary
      int lastSpace = text.lastIndexOf(' ', end);
      if (lastSpace > start) {
        end = lastSpace;
      }

      lines.add(text.substring(start, end));
      start = end + (lastSpace > start ? 1 : 0); // Skip the space
    }

    return lines;
  }

  List<String> getCurrentPage() {
    int startIndex = _currentPageIndex * displayLinesPerPage;
    int endIndex = min(startIndex + displayLinesPerPage, _wrappedLines.length);

    if (startIndex >= _wrappedLines.length) {
      return [];
    }

    return _wrappedLines.sublist(startIndex, endIndex);
  }

  bool hasNextPage() {
    return (_currentPageIndex + 1) * displayLinesPerPage < _wrappedLines.length;
  }

  bool hasPreviousPage() {
    return _currentPageIndex > 0;
  }

  void nextPage() {
    if (hasNextPage()) {
      _currentPageIndex++;
    }
  }

  void previousPage() {
    if (hasPreviousPage()) {
      _currentPageIndex--;
    }
  }

  void clear() {
    _originalLines.clear();
    _wrappedLines.clear();
    _currentPageIndex = 0;
  }

  int get totalPages {
    return (_wrappedLines.length / displayLinesPerPage).ceil();
  }

  int get currentPageNumber => _currentPageIndex + 1;
}

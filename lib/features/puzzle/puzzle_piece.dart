class PuzzlePieceModel {
  final int id;
  final int correctRow;
  final int correctCol;

  int currentRow;
  int currentCol;

  PuzzlePieceModel({
    required this.id,
    required this.correctRow,
    required this.correctCol,
    required this.currentRow,
    required this.currentCol,
  });

  bool get isCorrect => currentRow == correctRow && currentCol == correctCol;
}

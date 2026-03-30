class PuzzlePieceModel {
  final int id;
  final int correctRow;
  final int correctCol;
  
  double currentX;
  double currentY;
  
  final double width;
  final double height;
  
  bool isSnapped = false;

  PuzzlePieceModel({
    required this.id,
    required this.correctRow,
    required this.correctCol,
    required this.currentX,
    required this.currentY,
    required this.width,
    required this.height,
  });
}

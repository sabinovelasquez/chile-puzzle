import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';
import 'puzzle_piece.dart';
import 'package:chile_puzzle/core/models/location_model.dart';

class PuzzleEngine extends StatefulWidget {
  final LocationModel location;
  final int difficulty;
  final void Function(int timeSecs, int moves, int rows, int cols)? onCompleted;

  const PuzzleEngine({
    super.key,
    required this.location,
    required this.difficulty,
    this.onCompleted,
  });

  @override
  State<PuzzleEngine> createState() => _PuzzleEngineState();
}

class _PuzzleEngineState extends State<PuzzleEngine>
    with SingleTickerProviderStateMixin {
  List<PuzzlePieceModel> pieces = [];
  bool isCompleted = false;
  int rows = 0;
  int cols = 0;

  double boardWidth = 0;
  double boardHeight = 0;
  double pieceWidth = 0;
  double pieceHeight = 0;

  // Drag state
  int? _draggingId;
  Offset _dragGlobalStart = Offset.zero;
  Offset _dragPieceOrigin = Offset.zero;
  double _dragCurrentX = 0;
  double _dragCurrentY = 0;

  // Scoring state
  int _moveCount = 0;
  final Stopwatch _stopwatch = Stopwatch();

  // Completion animation
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _initializeBoard(BoxConstraints constraints) {
    if (pieces.isNotEmpty) return;

    boardWidth = constraints.maxWidth;
    boardHeight = constraints.maxHeight;

    cols = widget.difficulty;
    pieceWidth = boardWidth / cols;
    rows = (boardHeight / pieceWidth).round().clamp(1, 20);
    pieceHeight = boardHeight / rows;

    int idCounter = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        pieces.add(PuzzlePieceModel(
          id: idCounter++,
          correctRow: r,
          correctCol: c,
          currentRow: r,
          currentCol: c,
        ));
      }
    }

    final random = Random();
    for (int i = pieces.length - 1; i > 0; i--) {
      int j = random.nextInt(i + 1);
      int tmpRow = pieces[i].currentRow;
      int tmpCol = pieces[i].currentCol;
      pieces[i].currentRow = pieces[j].currentRow;
      pieces[i].currentCol = pieces[j].currentCol;
      pieces[j].currentRow = tmpRow;
      pieces[j].currentCol = tmpCol;
    }

    if (pieces.every((p) => p.isCorrect)) {
      int tmpRow = pieces[0].currentRow;
      int tmpCol = pieces[0].currentCol;
      pieces[0].currentRow = pieces[1].currentRow;
      pieces[0].currentCol = pieces[1].currentCol;
      pieces[1].currentRow = tmpRow;
      pieces[1].currentCol = tmpCol;
    }

    _stopwatch.start();
  }

  void _onDragStart(PuzzlePieceModel piece, DragStartDetails details) {
    if (isCompleted) return;
    setState(() {
      _draggingId = piece.id;
      _dragGlobalStart = details.globalPosition;
      _dragPieceOrigin = Offset(
        piece.currentCol * pieceWidth,
        piece.currentRow * pieceHeight,
      );
      _dragCurrentX = _dragPieceOrigin.dx;
      _dragCurrentY = _dragPieceOrigin.dy;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (isCompleted) return;
    setState(() {
      _dragCurrentX =
          _dragPieceOrigin.dx + (details.globalPosition.dx - _dragGlobalStart.dx);
      _dragCurrentY =
          _dragPieceOrigin.dy + (details.globalPosition.dy - _dragGlobalStart.dy);
    });
  }

  void _onDragEnd(PuzzlePieceModel piece) {
    if (isCompleted) return;
    double centerX = _dragCurrentX + pieceWidth / 2;
    double centerY = _dragCurrentY + pieceHeight / 2;
    int targetCol = (centerX / pieceWidth).floor().clamp(0, cols - 1);
    int targetRow = (centerY / pieceHeight).floor().clamp(0, rows - 1);

    if (targetRow != piece.currentRow || targetCol != piece.currentCol) {
      final target = pieces.firstWhere(
        (p) => p.currentRow == targetRow && p.currentCol == targetCol,
      );
      setState(() {
        int tmpRow = piece.currentRow;
        int tmpCol = piece.currentCol;
        piece.currentRow = target.currentRow;
        piece.currentCol = target.currentCol;
        target.currentRow = tmpRow;
        target.currentCol = tmpCol;
      });
      _moveCount++;
    }

    setState(() {
      _draggingId = null;
    });

    _checkCompletion();
  }

  void _checkCompletion() {
    if (pieces.every((p) => p.isCorrect)) {
      _stopwatch.stop();
      setState(() {
        isCompleted = true;
      });
      _fadeController.forward();
      widget.onCompleted?.call(
        _stopwatch.elapsed.inSeconds,
        _moveCount,
        rows,
        cols,
      );
    }
  }

  List<PuzzlePieceModel> _sortedPieces() {
    if (_draggingId == null) return pieces;
    final sorted = List<PuzzlePieceModel>.from(pieces);
    final dragged = sorted.firstWhere((p) => p.id == _draggingId);
    sorted.remove(dragged);
    sorted.add(dragged);
    return sorted;
  }

  Widget _buildPieceWidget(PuzzlePieceModel piece, double borderOpacity) {
    final showBorder = !piece.isCorrect && borderOpacity > 0.01;
    return Container(
      width: pieceWidth,
      height: pieceHeight,
      decoration: showBorder
          ? BoxDecoration(
              border: Border.all(
                color: Colors.black.withOpacity(0.3 * borderOpacity),
                width: 1,
              ),
            )
          : null,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: boardWidth,
          maxHeight: boardHeight,
          alignment: Alignment(
            cols > 1 ? -1.0 + (piece.correctCol * 2.0 / (cols - 1)) : 0,
            rows > 1 ? -1.0 + (piece.correctRow * 2.0 / (rows - 1)) : 0,
          ),
          child: CachedNetworkImage(
            imageUrl: widget.location.image,
            width: boardWidth,
            height: boardHeight,
            fit: BoxFit.cover,
            errorWidget: (context, url, err) => Container(color: Colors.grey),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth == 0) return const SizedBox.shrink();

        _initializeBoard(constraints);

        return AnimatedBuilder(
          animation: _fadeController,
          builder: (context, _) {
            final borderOpacity = 1.0 - _fadeController.value;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Grid lines
                if (borderOpacity > 0.01)
                  Positioned.fill(
                    child: Opacity(
                      opacity: borderOpacity,
                      child: CustomPaint(
                        painter: GridPainter(rows, cols),
                      ),
                    ),
                  ),

                // Pieces
                ..._sortedPieces().map((piece) {
                  final isDragging = piece.id == _draggingId;
                  final x = isDragging
                      ? _dragCurrentX
                      : piece.currentCol * pieceWidth;
                  final y = isDragging
                      ? _dragCurrentY
                      : piece.currentRow * pieceHeight;

                  return Positioned(
                    key: ValueKey(piece.id),
                    left: x,
                    top: y,
                    child: GestureDetector(
                      onPanStart: (details) => _onDragStart(piece, details),
                      onPanUpdate: _onDragUpdate,
                      onPanEnd: (_) => _onDragEnd(piece),
                      child: Material(
                        elevation: isDragging ? 12 : 0,
                        color: Colors.transparent,
                        child: _buildPieceWidget(piece, borderOpacity),
                      ),
                    ),
                  );
                }),

                // HUD: time + moves (top right, subtle)
                if (!isCompleted)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _TimerDisplay(stopwatch: _stopwatch, moves: _moveCount),
                  ),

                // Tap anywhere to reopen drawer
                if (isCompleted)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {},
                      behavior: HitTestBehavior.translucent,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Live timer display that rebuilds itself
class _TimerDisplay extends StatefulWidget {
  final Stopwatch stopwatch;
  final int moves;
  const _TimerDisplay({required this.stopwatch, required this.moves});

  @override
  State<_TimerDisplay> createState() => _TimerDisplayState();
}

class _TimerDisplayState extends State<_TimerDisplay> {
  late final _ticker = Stream.periodic(const Duration(seconds: 1));
  late final _sub = _ticker.listen((_) {
    if (mounted && widget.stopwatch.isRunning) setState(() {});
  });

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secs = widget.stopwatch.elapsed.inSeconds;
    final m = secs ~/ 60;
    final s = secs % 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}  ·  ${widget.moves} mov',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final int rows;
  final int cols;
  GridPainter(this.rows, this.cols);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    double cellW = size.width / cols;
    double cellH = size.height / rows;

    for (int i = 1; i < cols; i++) {
      canvas.drawLine(Offset(i * cellW, 0), Offset(i * cellW, size.height), paint);
    }
    for (int i = 1; i < rows; i++) {
      canvas.drawLine(Offset(0, i * cellH), Offset(size.width, i * cellH), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

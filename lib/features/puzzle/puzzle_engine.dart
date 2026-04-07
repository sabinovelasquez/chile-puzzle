import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';
import 'puzzle_piece.dart';
import 'package:chile_puzzle/core/models/location_model.dart';
import 'package:chile_puzzle/core/services/audio_service.dart';

class PuzzleEngine extends StatefulWidget {
  final LocationModel location;
  final int difficulty;
  final void Function(int timeSecs, int moves, int rows, int cols)? onCompleted;
  final Stopwatch stopwatch;
  final ValueNotifier<int> moveCount;
  final ValueNotifier<bool> imageLoaded;

  PuzzleEngine({
    super.key,
    required this.location,
    required this.difficulty,
    this.onCompleted,
    Stopwatch? stopwatch,
    ValueNotifier<int>? moveCount,
    ValueNotifier<bool>? imageLoaded,
  })  : stopwatch = stopwatch ?? Stopwatch(),
        moveCount = moveCount ?? ValueNotifier(0),
        imageLoaded = imageLoaded ?? ValueNotifier(false);

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

  // Completion animation
  late AnimationController _fadeController;

  Stopwatch get _stopwatch => widget.stopwatch;
  int get _moveCount => widget.moveCount.value;
  set _moveCount(int v) => widget.moveCount.value = v;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    // Start timer only after image loads
    widget.imageLoaded.addListener(_onImageLoaded);
    // Preload image
    final imageProvider = CachedNetworkImageProvider(widget.location.image);
    imageProvider.resolve(ImageConfiguration.empty).addListener(
      ImageStreamListener(
        (_, __) {
          if (mounted) widget.imageLoaded.value = true;
        },
        onError: (_, __) {
          if (mounted) widget.imageLoaded.value = true; // allow play even on error
        },
      ),
    );
  }

  void _onImageLoaded() {
    if (widget.imageLoaded.value && !_stopwatch.isRunning && !isCompleted) {
      _stopwatch.start();
    }
  }

  @override
  void dispose() {
    widget.imageLoaded.removeListener(_onImageLoaded);
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
  }

  void _onDragStart(PuzzlePieceModel piece, DragStartDetails details) {
    if (isCompleted || !widget.imageLoaded.value) return;
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
      AudioService.playAnyPiece();
      if (piece.isCorrect || target.isCorrect) {
        AudioService.playCorrectPiece();
      }
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

    // Crop: interpolated from focus region (easiest) to full image (hardest)
    final crop = widget.location.getCropForDifficulty(widget.difficulty);
    final cX = crop[0], cY = crop[1], cW = crop[2], cH = crop[3];
    final imgW = boardWidth / cW;
    final imgH = boardHeight / cH;

    // Alignment to position this piece's portion of the cropped image
    final ax = cols > 1
        ? 2 * (cX * imgW + piece.correctCol * pieceWidth) / (imgW - pieceWidth) - 1
        : 0.0;
    final ay = rows > 1
        ? 2 * (cY * imgH + piece.correctRow * pieceHeight) / (imgH - pieceHeight) - 1
        : 0.0;

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
          maxWidth: imgW,
          maxHeight: imgH,
          alignment: Alignment(ax, ay),
          child: CachedNetworkImage(
            imageUrl: widget.location.image,
            width: imgW,
            height: imgH,
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

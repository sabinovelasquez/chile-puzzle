import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';
import 'puzzle_piece.dart';
import 'package:chile_puzzle/core/models/location_model.dart';
import 'package:chile_puzzle/core/services/audio_service.dart';
import 'package:chile_puzzle/core/services/settings_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
    with TickerProviderStateMixin {
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
  Set<int>? _draggingGroup;
  Offset _dragGlobalStart = Offset.zero;
  Offset _dragPieceOrigin = Offset.zero;
  double _dragCurrentX = 0;
  double _dragCurrentY = 0;

  // Completion animation
  late AnimationController _fadeController;

  // Shine effect controllers
  final Map<int, AnimationController> _shineControllers = {};

  // Lock rejection shake
  int? _shakingPieceId;
  AnimationController? _shakeController;

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
    // Preload image (per-difficulty pre-cropped when available, else the single image)
    final imageProvider = CachedNetworkImageProvider(
      widget.location.getImageForDifficulty(widget.difficulty),
    );
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
    for (final c in _shineControllers.values) {
      c.dispose();
    }
    _shakeController?.dispose();
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
    if (SettingsService.lockInPlace && piece.isCorrect) {
      _triggerShakeRejection(piece.id);
      return;
    }
    setState(() {
      _draggingId = piece.id;
      _draggingGroup = SettingsService.multiSelect ? _findGroup(piece) : null;
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
    if (isCompleted || _draggingId == null) return;
    setState(() {
      _dragCurrentX =
          _dragPieceOrigin.dx + (details.globalPosition.dx - _dragGlobalStart.dx);
      _dragCurrentY =
          _dragPieceOrigin.dy + (details.globalPosition.dy - _dragGlobalStart.dy);
    });
  }

  void _onDragEnd(PuzzlePieceModel piece) {
    if (isCompleted || _draggingId == null) return;
    double centerX = _dragCurrentX + pieceWidth / 2;
    double centerY = _dragCurrentY + pieceHeight / 2;
    int targetCol = (centerX / pieceWidth).floor().clamp(0, cols - 1);
    int targetRow = (centerY / pieceHeight).floor().clamp(0, rows - 1);

    final deltaRow = targetRow - piece.currentRow;
    final deltaCol = targetCol - piece.currentCol;

    if (deltaRow != 0 || deltaCol != 0) {
      if (_draggingGroup != null && _draggingGroup!.length > 1) {
        _handleGroupMove(deltaRow, deltaCol);
      } else {
        _handleSingleMove(piece, targetRow, targetCol);
      }
    }

    setState(() {
      _draggingId = null;
      _draggingGroup = null;
    });

    _checkCompletion();
  }

  void _handleSingleMove(PuzzlePieceModel piece, int targetRow, int targetCol) {
    final target = pieces.firstWhere(
      (p) => p.currentRow == targetRow && p.currentCol == targetCol,
    );
    if (SettingsService.lockInPlace && target.isCorrect) return;

    setState(() {
      int tmpRow = piece.currentRow;
      int tmpCol = piece.currentCol;
      piece.currentRow = target.currentRow;
      piece.currentCol = target.currentCol;
      target.currentRow = tmpRow;
      target.currentCol = tmpCol;
    });
    _moveCount++;
    AudioService.playPiecePlaced();

    if (SettingsService.edgeShine) {
      if (piece.isCorrect) _triggerShine(piece.id);
      if (target.isCorrect) _triggerShine(target.id);
    }
  }

  void _handleGroupMove(int deltaRow, int deltaCol) {
    final groupPieces = pieces.where((p) => _draggingGroup!.contains(p.id)).toList();

    // Validate all targets in bounds
    for (final p in groupPieces) {
      final tr = p.currentRow + deltaRow;
      final tc = p.currentCol + deltaCol;
      if (tr < 0 || tr >= rows || tc < 0 || tc >= cols) return;
    }

    // Find target cells and displaced pieces
    final sourceCells = groupPieces.map((p) => (p.currentRow, p.currentCol)).toSet();
    final targetCells = groupPieces.map((p) => (p.currentRow + deltaRow, p.currentCol + deltaCol)).toSet();
    final displacedCells = targetCells.difference(sourceCells);
    final vacatedCells = sourceCells.difference(targetCells);

    final displacedPieces = <PuzzlePieceModel>[];
    for (final cell in displacedCells) {
      final p = pieces.firstWhere((p) => p.currentRow == cell.$1 && p.currentCol == cell.$2);
      if (SettingsService.lockInPlace && p.isCorrect) return; // Can't displace locked piece
      displacedPieces.add(p);
    }

    setState(() {
      // Move group pieces to target positions
      for (final p in groupPieces) {
        p.currentRow += deltaRow;
        p.currentCol += deltaCol;
      }
      // Move displaced pieces to vacated cells
      final vacatedList = vacatedCells.toList();
      for (int i = 0; i < displacedPieces.length; i++) {
        displacedPieces[i].currentRow = vacatedList[i].$1;
        displacedPieces[i].currentCol = vacatedList[i].$2;
      }
    });
    _moveCount++;
    AudioService.playPiecePlaced();

    if (SettingsService.edgeShine) {
      for (final p in groupPieces) {
        if (p.isCorrect) _triggerShine(p.id);
      }
      for (final p in displacedPieces) {
        if (p.isCorrect) _triggerShine(p.id);
      }
    }
  }

  void _triggerShine(int pieceId) {
    _shineControllers[pieceId]?.dispose();
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _shineControllers[pieceId] = controller;
    controller.forward().then((_) {
      controller.dispose();
      if (mounted) {
        setState(() {
          _shineControllers.remove(pieceId);
        });
      }
    });
  }

  void _triggerShakeRejection(int pieceId) {
    _shakeController?.dispose();
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeController = controller;
    setState(() => _shakingPieceId = pieceId);
    controller.forward().then((_) {
      controller.dispose();
      if (_shakeController == controller) _shakeController = null;
      if (mounted) {
        setState(() => _shakingPieceId = null);
      }
    });
  }

  Set<int>? _findGroup(PuzzlePieceModel startPiece) {
    final group = <int>{startPiece.id};
    final queue = <PuzzlePieceModel>[startPiece];
    const deltas = [(-1, 0), (1, 0), (0, -1), (0, 1)];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final (dr, dc) in deltas) {
        final nr = current.currentRow + dr;
        final nc = current.currentCol + dc;
        if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;

        final neighbor = pieces.firstWhere(
          (p) => p.currentRow == nr && p.currentCol == nc,
        );
        if (group.contains(neighbor.id)) continue;

        // Check relative correctness
        if ((current.correctRow - neighbor.correctRow == current.currentRow - neighbor.currentRow) &&
            (current.correctCol - neighbor.correctCol == current.currentCol - neighbor.currentCol)) {
          group.add(neighbor.id);
          queue.add(neighbor);
        }
      }
    }
    return group.length > 1 ? group : null;
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
    if (_draggingGroup != null && _draggingGroup!.length > 1) {
      final groupPieces = sorted.where((p) => _draggingGroup!.contains(p.id)).toList();
      sorted.removeWhere((p) => _draggingGroup!.contains(p.id));
      sorted.addAll(groupPieces);
    } else {
      final dragged = sorted.firstWhere((p) => p.id == _draggingId);
      sorted.remove(dragged);
      sorted.add(dragged);
    }
    return sorted;
  }

  Widget _buildPieceWidget(PuzzlePieceModel piece, double borderOpacity) {
    final showBorder = !piece.isCorrect && borderOpacity > 0.01;

    // When the backend provides a pre-rendered per-difficulty image, the whole
    // image IS the crop — skip the interpolation math. Otherwise fall back to
    // runtime extraction of the interpolated crop from the single image.
    final useCropped = widget.location.hasPreRenderedCrop(widget.difficulty);
    final imageUrl = widget.location.getImageForDifficulty(widget.difficulty);
    final crop = useCropped
        ? const [0.0, 0.0, 1.0, 1.0]
        : widget.location.getCropForDifficulty(widget.difficulty);
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
            imageUrl: imageUrl,
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
                  final isInGroup = _draggingGroup?.contains(piece.id) ?? false;
                  final isGroupDragging = isInGroup && _draggingId != null && !isDragging;

                  final x = isDragging
                      ? _dragCurrentX
                      : isGroupDragging
                          ? piece.currentCol * pieceWidth + (_dragCurrentX - _dragPieceOrigin.dx)
                          : piece.currentCol * pieceWidth;
                  final y = isDragging
                      ? _dragCurrentY
                      : isGroupDragging
                          ? piece.currentRow * pieceHeight + (_dragCurrentY - _dragPieceOrigin.dy)
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
                        elevation: (isDragging || isGroupDragging) ? 12 : 0,
                        color: Colors.transparent,
                        child: Stack(
                          children: [
                            _buildPieceWidget(piece, borderOpacity),
                            // Shine effect
                            if (_shineControllers.containsKey(piece.id))
                              AnimatedBuilder(
                                animation: _shineControllers[piece.id]!,
                                builder: (_, __) {
                                  final value = _shineControllers[piece.id]!.value;
                                  return SizedBox(
                                    width: pieceWidth,
                                    height: pieceHeight,
                                    child: ClipRect(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment(-1.0 + 3.0 * value, -1.0 + 3.0 * value),
                                            end: Alignment(-0.5 + 3.0 * value, -0.5 + 3.0 * value),
                                            colors: [
                                              Colors.white.withValues(alpha: 0),
                                              Colors.white.withValues(alpha: 0.4),
                                              Colors.white.withValues(alpha: 0),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            // Shake rejection lock icon
                            if (_shakingPieceId == piece.id && _shakeController != null)
                              AnimatedBuilder(
                                animation: _shakeController!,
                                builder: (_, __) {
                                  final t = _shakeController!.value;
                                  final shakeOffset = t < 0.6
                                      ? sin(t / 0.6 * pi * 4) * 4.0
                                      : 0.0;
                                  final opacity = t < 0.6 ? 1.0 : (1.0 - (t - 0.6) / 0.4).clamp(0.0, 1.0);
                                  return Positioned.fill(
                                    child: Opacity(
                                      opacity: opacity,
                                      child: Transform.translate(
                                        offset: Offset(shakeOffset, 0),
                                        child: Center(
                                          child: Icon(
                                            PhosphorIconsFill.lockSimple,
                                            size: 24,
                                            color: Colors.white.withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            // Lock border flash — anchors the lock icon to its piece.
                            if (_shakingPieceId == piece.id && _shakeController != null)
                              AnimatedBuilder(
                                animation: _shakeController!,
                                builder: (_, __) {
                                  final t = _shakeController!.value;
                                  double borderOpacity;
                                  if (t < 0.15) {
                                    borderOpacity = t / 0.15;
                                  } else if (t < 0.6) {
                                    borderOpacity = 1.0;
                                  } else {
                                    borderOpacity = (1.0 - (t - 0.6) / 0.4).clamp(0.0, 1.0);
                                  }
                                  return IgnorePointer(
                                    child: Container(
                                      width: pieceWidth,
                                      height: pieceHeight,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: borderOpacity),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
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

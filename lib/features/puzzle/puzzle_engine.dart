import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';
import 'puzzle_piece.dart';
import 'package:chile_puzzle/features/ads/ad_service.dart';
import 'package:chile_puzzle/core/models/location_model.dart';
import 'package:chile_puzzle/l10n/generated/app_localizations.dart';

class PuzzleEngine extends StatefulWidget {
  final LocationModel location;
  final int rows;
  final int cols;

  const PuzzleEngine({
    super.key,
    required this.location,
    required this.rows,
    required this.cols,
  });

  @override
  State<PuzzleEngine> createState() => _PuzzleEngineState();
}

class _PuzzleEngineState extends State<PuzzleEngine> {
  List<PuzzlePieceModel> pieces = [];
  bool isCompleted = false;
  
  double boardWidth = 0;
  double boardHeight = 0;
  double pieceWidth = 0;
  double pieceHeight = 0;

  @override
  void initState() {
    super.initState();
  }

  void _initializeBoard(BoxConstraints constraints) {
    if (pieces.isNotEmpty) return;
    
    // Board logic
    final padding = 20.0;
    boardWidth = constraints.maxWidth - padding * 2;
    // Assuming square images or center cropped
    boardHeight = boardWidth; 
    
    pieceWidth = boardWidth / widget.cols;
    pieceHeight = boardHeight / widget.rows;
    
    final random = Random();
    
    int idCounter = 0;
    for (int r = 0; r < widget.rows; r++) {
      for (int c = 0; c < widget.cols; c++) {
        // Random initial position inside constraints (mainly the bottom area)
        double initX = random.nextDouble() * (constraints.maxWidth - pieceWidth);
        double rangeY = constraints.maxHeight - boardHeight - padding * 2 - pieceHeight;
        double initY = boardHeight + padding * 2 + (rangeY > 0 ? random.nextDouble() * rangeY : 0);
        
        // If screen is too small, just scatter randomly
        if (initY > constraints.maxHeight - pieceHeight) {
          initY = random.nextDouble() * (constraints.maxHeight - pieceHeight);
        }

        pieces.add(PuzzlePieceModel(
          id: idCounter++,
          correctRow: r,
          correctCol: c,
          currentX: initX,
          currentY: initY,
          width: pieceWidth,
          height: pieceHeight,
        ));
      }
    }
  }

  void _onPieceDragged(PuzzlePieceModel piece, Offset offset) {
    setState(() {
      piece.currentX += offset.dx;
      piece.currentY += offset.dy;
    });
  }

  void _checkSnap(PuzzlePieceModel piece) {
    double targetX = 20.0 + piece.correctCol * pieceWidth;
    double targetY = 20.0 + piece.correctRow * pieceHeight;
    
    double dist = sqrt(pow(piece.currentX - targetX, 2) + pow(piece.currentY - targetY, 2));
    
    if (dist < 20.0) { // snapThreshold
      setState(() {
        piece.currentX = targetX;
        piece.currentY = targetY;
        piece.isSnapped = true;
      });
      _checkCompletion();
    }
  }

  void _checkCompletion() {
    if (pieces.every((p) => p.isSnapped)) {
      setState(() {
        isCompleted = true;
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _showTipDialog();
      });
    }
  }

  void _showTipDialog() {
    final langCode = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n?.puzzleCompleted ?? 'Puzzle Completed!'),
        content: Text(widget.location.getLocalizedTip(langCode)),
        actions: [
          TextButton(
            onPressed: () {
               Navigator.of(context).pop();
               AdService.showInterstitial(
                 onAdDismissed: () {
                   if (mounted) Navigator.of(context).pop();
                 }
               );
            },
            child: Text(l10n?.unlockNext ?? 'Continue'),
          )
        ],
      )
    );
  }

  Widget _buildPieceWidget(PuzzlePieceModel piece) {
    return Container(
      width: piece.width,
      height: piece.height,
      decoration: BoxDecoration(
        border: piece.isSnapped
            ? null
            : Border.all(color: Colors.white.withOpacity(0.5), width: 1),
      ),
      child: ClipRect(
        child: OverflowBox(
          maxWidth: boardWidth,
          maxHeight: boardHeight,
          alignment: Alignment(
            widget.cols > 1 ? -1.0 + (piece.correctCol * 2.0 / (widget.cols - 1)) : 0,
            widget.rows > 1 ? -1.0 + (piece.correctRow * 2.0 / (widget.rows - 1)) : 0,
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

        return Stack(
          children: [
             // Background board wrapper
            Positioned(
              left: 20,
              top: 20,
              width: boardWidth,
              height: boardHeight,
              child: Opacity(
                opacity: 0.15,
                child: CachedNetworkImage(
                  imageUrl: widget.location.image,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            
            // Grid lines
            Positioned(
              left: 20,
              top: 20,
              width: boardWidth,
              height: boardHeight,
              child: CustomPaint(
                painter: GridPainter(widget.rows, widget.cols),
              ),
            ),

            // Snapped static pieces
            ...pieces.where((p) => p.isSnapped).map((piece) {
               return Positioned(
                 left: piece.currentX,
                 top: piece.currentY,
                 child: _buildPieceWidget(piece),
               );
            }),
            
            // Unsnapped draggable pieces
            ...pieces.where((p) => !p.isSnapped).map((piece) {
               return Positioned(
                 left: piece.currentX,
                 top: piece.currentY,
                 child: GestureDetector(
                   onPanStart: (details) {
                     setState(() {
                       pieces.remove(piece);
                       pieces.add(piece); // Bring to top
                     });
                   },
                   onPanUpdate: (details) => _onPieceDragged(piece, details.delta),
                   onPanEnd: (details) => _checkSnap(piece),
                   child: Material(
                     elevation: 8,
                     color: Colors.transparent,
                     child: _buildPieceWidget(piece)
                   ),
                 ),
               );
            }),
          ],
        );
      }
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
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
      
    double cellW = size.width / cols;
    double cellH = size.height / rows;
    
    for (int i = 1; i < cols; i++) {
      canvas.drawLine(Offset(i * cellW, 0), Offset(i * cellW, size.height), paint);
    }
    for (int i = 1; i < rows; i++) {
      canvas.drawLine(Offset(0, i * cellH), Offset(size.width, i * cellH), paint);
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

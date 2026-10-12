import 'package:flutter/material.dart';

import 'theme.dart';

/// Star rating row (read-only). Shows [rating] out of 5 with amber stars.
class RatingStars extends StatelessWidget {
  final double rating;
  final double size;
  final int? reviewCount;

  const RatingStars({super.key, required this.rating, this.size = 14, this.reviewCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rating.round() ? Icons.star : Icons.star_border,
            size: size,
            color: FauridocTheme.starAmber,
          ),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(fontSize: size - 1, fontWeight: FontWeight.w700),
        ),
        if (reviewCount != null)
          Text(
            ' ($reviewCount)',
            style: TextStyle(fontSize: size - 2, color: Colors.grey[600]),
          ),
      ],
    );
  }
}

/// Interactive star input for the review form.
class StarInput extends StatefulWidget {
  final int initial;
  final ValueChanged<int> onChanged;

  const StarInput({super.key, this.initial = 5, required this.onChanged});

  @override
  State<StarInput> createState() => _StarInputState();
}

class _StarInputState extends State<StarInput> {
  late int _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: Icon(
              i <= _value ? Icons.star : Icons.star_border,
              size: 34,
              color: FauridocTheme.starAmber,
            ),
            onPressed: () {
              setState(() => _value = i);
              widget.onChanged(i);
            },
          ),
      ],
    );
  }
}

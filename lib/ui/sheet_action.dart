import 'package:flutter/material.dart';

/// One row of a ⋮ action sheet: brand-blue icon + label, like the main
/// menu. [danger] (delete) uses the error colour. Tapping pops [value].
class SheetAction extends StatelessWidget {
  const SheetAction({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = danger ? scheme.error : null;
    return InkWell(
      onTap: () => Navigator.of(context).pop(value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: 64,
          minWidth: double.infinity,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 28, color: color ?? scheme.primary),
              const SizedBox(width: 18),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Full-width, rounded, bold action button.
///
/// Default is a filled gradient (brand -> brand2). Pass `ghost: true` for an
/// outlined, transparent variant used for secondary actions.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool ghost;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.ghost = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: AppColors.ink),
          const SizedBox(width: 10),
        ],
        Text(
          label,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: ghost
                    ? null
                    : const LinearGradient(
                        colors: [AppColors.brand, AppColors.brand2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: ghost ? Colors.transparent : null,
                borderRadius: BorderRadius.circular(18),
                border: ghost
                    ? Border.all(color: AppColors.brand, width: 1.6)
                    : null,
                boxShadow: ghost
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.brand.withOpacity(0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:sampan/core/constants/protocol_constants.dart';
import 'package:sampan/core/theme/sampan_theme.dart';

/// Shared identity pickers used by onboarding and the profile editor.

/// Two-option role selector: Guide (leads the group) or Traveler.
class RolePicker extends StatelessWidget {
  const RolePicker({
    super.key,
    required this.selectedRole,
    required this.onChanged,
  });

  final String selectedRole;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _RoleOptionCard(
            key: const ValueKey<String>('role-guide'),
            title: 'Guide',
            subtitle: 'Lead the group',
            icon: Icons.explore_rounded,
            isSelected: selectedRole == 'guide',
            onTap: () => onChanged('guide'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RoleOptionCard(
            key: const ValueKey<String>('role-traveler'),
            title: 'Traveler',
            subtitle: 'Join a group',
            icon: Icons.hiking_rounded,
            isSelected: selectedRole == 'traveler',
            onTap: () => onChanged('traveler'),
          ),
        ),
      ],
    );
  }
}

/// Horizontal strip of emoji avatars.
class AvatarPicker extends StatelessWidget {
  const AvatarPicker({
    super.key,
    required this.selectedAvatar,
    required this.onChanged,
  });

  final String selectedAvatar;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: SampanConstants.avatarIcons.map((String icon) {
          final bool isSelected = icon == selectedAvatar;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              key: ValueKey<String>('avatar-$icon'),
              borderRadius: BorderRadius.circular(18),
              onTap: () => onChanged(icon),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? SampanTheme.brandViolet : scheme.surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(icon, style: const TextStyle(fontSize: 24)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Row of identity color dots.
class IdentityColorPicker extends StatelessWidget {
  const IdentityColorPicker({
    super.key,
    required this.selectedColorHex,
    required this.onChanged,
  });

  final int selectedColorHex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: SampanConstants.identityColorHexes.map((int hex) {
        final bool isSelected = hex == selectedColorHex;
        return GestureDetector(
          key: ValueKey<String>('color-${hex.toRadixString(16)}'),
          onTap: () => onChanged(hex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Color(hex),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? SampanTheme.brandLime : Colors.transparent,
                width: 3,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

/// Small bold label above a picker group.
class PickerLabel extends StatelessWidget {
  const PickerLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _RoleOptionCard extends StatelessWidget {
  const _RoleOptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? SampanTheme.brandViolet : scheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color:
                    isSelected ? SampanTheme.brandLime : scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: SampanTheme.violet900),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isSelected ? Colors.white : scheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? SampanTheme.brandLime
                          : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

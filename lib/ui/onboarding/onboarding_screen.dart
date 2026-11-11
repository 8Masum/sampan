import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sampan/core/constants/protocol_constants.dart';
import 'package:sampan/core/theme/sampan_theme.dart';
import 'package:sampan/state/sampan_providers.dart';

/// Minimalist Material Design 3 Expressive Onboarding Flow.
///
/// Generates an on-device cryptographic identity in one tap with zero accounts,
/// zero cloud servers, and zero friction.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final TextEditingController _nameController =
      TextEditingController(text: 'Tanvir Ahmed');
  String _selectedAvatar = SampanConstants.avatarIcons.first;
  int _selectedColorHex = SampanConstants.identityColorHexes.first;
  String _selectedRole = 'guide';
  bool _isGenerating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateIdentity() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);
    try {
      await ref.read(sampanControllerProvider.notifier).createOfflineIdentity(
            displayName: _nameController.text,
            avatarIcon: _selectedAvatar,
            colorHex: _selectedColorHex,
            role: _selectedRole,
          );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // M3 Expressive Hero Card (Electric Violet #6755EF + Acid Lime #F4FF90)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  color: SampanTheme.brandViolet,
                  borderRadius: BorderRadius.circular(SampanTheme.radiusLg),
                ),
                child: Column(
                  children: <Widget>[
                    // Pill Tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: SampanTheme.brandLime,
                        borderRadius:
                            BorderRadius.circular(SampanTheme.radiusPill),
                      ),
                      child: Text(
                        'WELCOME TO SAMPAN',
                        style: textTheme.labelSmall?.copyWith(
                          color: SampanTheme.violet900,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Official Brand Logo (used directly as-is, no crop or edit)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        SampanConstants.logoAssetPath,
                        width: 116,
                        height: 116,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) {
                          return Text(
                            _selectedAvatar,
                            style: const TextStyle(fontSize: 52),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'No signal?\nStay together.',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium?.copyWith(
                        color: SampanTheme.brandLime,
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      SampanConstants.tagline,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withAlpha(225),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Identity Customization Card (Soft Lavender Surface)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Your name',
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const ValueKey<String>('onboarding-display-name'),
                      controller: _nameController,
                      maxLength: 32,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Tanvir Ahmed',
                        counterText: '',
                        fillColor: scheme.surface,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _selectedAvatar,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Your role',
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _RoleOptionCard(
                            key: const ValueKey<String>('role-guide'),
                            title: 'Guide',
                            subtitle: 'Lead the trip',
                            icon: Icons.explore_rounded,
                            isSelected: _selectedRole == 'guide',
                            onTap: () =>
                                setState(() => _selectedRole = 'guide'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RoleOptionCard(
                            key: const ValueKey<String>('role-traveler'),
                            title: 'Traveler',
                            subtitle: 'Follow along',
                            icon: Icons.hiking_rounded,
                            isSelected: _selectedRole == 'traveler',
                            onTap: () =>
                                setState(() => _selectedRole = 'traveler'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Pick a vibe',
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: SampanConstants.avatarIcons.map((String icon) {
                          final bool isSelected = icon == _selectedAvatar;
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: InkWell(
                              key: ValueKey<String>('avatar-$icon'),
                              borderRadius: BorderRadius.circular(18),
                              onTap: () =>
                                  setState(() => _selectedAvatar = icon),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 50,
                                height: 50,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? SampanTheme.brandViolet
                                      : scheme.surface,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Text(
                                  icon,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: SampanConstants.identityColorHexes.map((
                        int hex,
                      ) {
                        final bool isSelected = hex == _selectedColorHex;
                        return GestureDetector(
                          key: ValueKey<String>(
                            'color-${hex.toRadixString(16)}',
                          ),
                          onTap: () => setState(() => _selectedColorHex = hex),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Color(hex),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? SampanTheme.brandLime
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Expressive Pill CTA (Acid Lime #F4FF90 + Deep Violet #1B1145)
              FilledButton(
                key: const ValueKey<String>('create-offline-identity-btn'),
                onPressed: _isGenerating ? null : _handleCreateIdentity,
                style: FilledButton.styleFrom(
                  backgroundColor: SampanTheme.brandLime,
                  foregroundColor: SampanTheme.violet900,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: const StadiumBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      _isGenerating ? 'Setting up...' : 'Start Offline',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No account needed · Works 100% offline',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? SampanTheme.brandViolet : scheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? SampanTheme.brandLime
                    : scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: SampanTheme.violet900,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: isSelected ? Colors.white : scheme.onSurface,
                        ),
                  ),
                  Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
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

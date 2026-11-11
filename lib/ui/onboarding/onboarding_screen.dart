import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sampan/core/constants/protocol_constants.dart';
import 'package:sampan/state/sampan_providers.dart';

/// Zero-Cloud Onboarding Flow (Under 10 Seconds) — Section 5.1 of
/// `SAMPAN_BLUEPRINT.md`.
///
/// Generates an on-device Ed25519 public/private keypair with zero phone
/// number, email, password, or SMS registration.
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Header Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      _selectedAvatar,
                      style: const TextStyle(fontSize: 44),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'WELCOME TO SAMPAN (সাম্পান)',
                      textAlign: TextAlign.center,
                      style: textTheme.titleLarge?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      SampanConstants.tagline,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.primaryContainer,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '100% Offline • Zero-Cloud • Ed25519 Identity',
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 1. Pick Avatar Icon
              Text(
                '1. Pick Avatar Icon',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: SampanConstants.avatarIcons.map((String icon) {
                  final bool isSelected = icon == _selectedAvatar;
                  return InkWell(
                    key: ValueKey<String>('avatar-$icon'),
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() => _selectedAvatar = icon),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 54,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? scheme.primaryContainer
                            : scheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? scheme.primary : scheme.outline,
                          width: isSelected ? 2.5 : 1.0,
                        ),
                      ),
                      child: Text(icon, style: const TextStyle(fontSize: 26)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // 2. Choose Identity Color
              Text(
                '2. Choose Identity Color',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: SampanConstants.identityColorHexes.map((int hex) {
                  final bool isSelected = hex == _selectedColorHex;
                  return GestureDetector(
                    key: ValueKey<String>('color-${hex.toRadixString(16)}'),
                    onTap: () => setState(() => _selectedColorHex = hex),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Color(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? scheme.onSurface : Colors.white,
                          width: isSelected ? 3.5 : 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // 3. Display Name
              Text(
                '3. Display Name',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey<String>('onboarding-display-name'),
                controller: _nameController,
                maxLength: 32,
                decoration: InputDecoration(
                  hintText: 'e.g., Tanvir Ahmed',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 4. Role Selection
              Text(
                '4. My Caravan Role',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _RoleOptionCard(
                      key: const ValueKey<String>('role-guide'),
                      title: 'Tour Guide / Host',
                      subtitle: 'Leads caravan & hosts SoftAP Hub',
                      icon: Icons.explore,
                      isSelected: _selectedRole == 'guide',
                      onTap: () => setState(() => _selectedRole = 'guide'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RoleOptionCard(
                      key: const ValueKey<String>('role-traveler'),
                      title: 'Traveler / Guest',
                      subtitle: 'Tracks guide & joins caravan mesh',
                      icon: Icons.hiking,
                      isSelected: _selectedRole == 'traveler',
                      onTap: () => setState(() => _selectedRole = 'traveler'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Create Offline Identity CTA
              FilledButton.icon(
                key: const ValueKey<String>('create-offline-identity-btn'),
                onPressed: _isGenerating ? null : _handleCreateIdentity,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.vpn_key_rounded),
                label: Text(
                  _isGenerating
                      ? 'Generating Ed25519 Keypair...'
                      : 'Create Offline Identity',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Zero phone number, email, or cloud servers. Your Ed25519 cryptographic identity stays 100% on your device.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
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
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? scheme.secondaryContainer : scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? scheme.secondary : scheme.outline,
            width: isSelected ? 2.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              icon,
              color: isSelected
                  ? scheme.onSecondaryContainer
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? scheme.onSecondaryContainer
                        : scheme.onSurface,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isSelected
                        ? scheme.onSecondaryContainer
                        : scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

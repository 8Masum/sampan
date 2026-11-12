import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sampan/core/constants/protocol_constants.dart';
import 'package:sampan/core/theme/sampan_theme.dart';
import 'package:sampan/state/sampan_providers.dart';
import 'package:sampan/ui/common/identity_pickers.dart';

/// Minimalist Material Design 3 Expressive onboarding.
///
/// Creates an on-device identity in one tap: no account, no cloud.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedAvatar = SampanConstants.avatarIcons.first;
  int _selectedColorHex = SampanConstants.identityColorHexes.first;
  String _selectedRole = 'traveler';
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
              const _HeroCard(),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const PickerLabel('Your name'),
                    TextField(
                      key: const ValueKey<String>('onboarding-display-name'),
                      controller: _nameController,
                      maxLength: 32,
                      textCapitalization: TextCapitalization.words,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: InputDecoration(
                        hintText: 'What should friends call you?',
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
                    const PickerLabel('Your role'),
                    RolePicker(
                      selectedRole: _selectedRole,
                      onChanged: (String role) =>
                          setState(() => _selectedRole = role),
                    ),
                    const SizedBox(height: 20),
                    const PickerLabel('Pick a vibe'),
                    AvatarPicker(
                      selectedAvatar: _selectedAvatar,
                      onChanged: (String icon) =>
                          setState(() => _selectedAvatar = icon),
                    ),
                    const SizedBox(height: 14),
                    IdentityColorPicker(
                      selectedColorHex: _selectedColorHex,
                      onChanged: (int hex) =>
                          setState(() => _selectedColorHex = hex),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey<String>('create-offline-identity-btn'),
                onPressed: _isGenerating ? null : _handleCreateIdentity,
                style: FilledButton.styleFrom(
                  backgroundColor: SampanTheme.brandLime,
                  foregroundColor: SampanTheme.violet900,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  shape: const StadiumBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        _isGenerating ? 'Setting up...' : 'Start Offline',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No account · No internet · Works anywhere',
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

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: SampanTheme.brandViolet,
        borderRadius: BorderRadius.circular(SampanTheme.radiusLg),
      ),
      child: Column(
        children: <Widget>[
          // Official brand logo, used as-is (no crop or edit).
          Image.asset(
            SampanConstants.logoAssetPath,
            width: 128,
            height: 128,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (
              BuildContext context,
              Object error,
              StackTrace? stackTrace,
            ) {
              return const Text('⛵', style: TextStyle(fontSize: 52));
            },
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
          const SizedBox(height: 18),
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _FeaturePill(icon: Icons.explore_rounded, label: 'Find friends'),
              _FeaturePill(
                icon: Icons.chat_bubble_rounded,
                label: 'Chat offline',
              ),
              _FeaturePill(icon: Icons.place_rounded, label: 'Save spots'),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(30),
        borderRadius: BorderRadius.circular(SampanTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: SampanTheme.brandLime),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

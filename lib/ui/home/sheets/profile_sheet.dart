import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sampan/core/constants/protocol_constants.dart';
import 'package:sampan/core/theme/sampan_theme.dart';
import 'package:sampan/data/models/identity_profile.dart';
import 'package:sampan/state/sampan_providers.dart';
import 'package:sampan/ui/common/identity_pickers.dart';

/// Opens the profile editor (name, role, avatar, color).
Future<void> showProfileSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext ctx) => const _ProfileSheet(),
  );
}

class _ProfileSheet extends ConsumerStatefulWidget {
  const _ProfileSheet();

  @override
  ConsumerState<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends ConsumerState<_ProfileSheet> {
  late final TextEditingController _nameController;
  late String _avatar;
  late int _colorHex;
  late String _role;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final IdentityProfile? identity =
        ref.read(sampanControllerProvider).identity;
    _nameController = TextEditingController(text: identity?.displayName ?? '');
    _avatar = identity?.avatarIcon ?? SampanConstants.avatarIcons.first;
    _colorHex = identity?.colorHex ?? SampanConstants.identityColorHexes.first;
    _role = identity?.role ?? 'traveler';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    await ref.read(sampanControllerProvider.notifier).updateProfile(
          displayName: _nameController.text,
          avatarIcon: _avatar,
          colorHex: _colorHex,
          role: _role,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(_colorHex),
                  child: Text(_avatar, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Your profile',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'This is how friends see you nearby.',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            const PickerLabel('Name'),
            TextField(
              key: const ValueKey<String>('profile-name-input'),
              controller: _nameController,
              maxLength: 32,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Your name',
                counterText: '',
              ),
            ),
            const SizedBox(height: 18),
            const PickerLabel('Role'),
            RolePicker(
              selectedRole: _role,
              onChanged: (String role) => setState(() => _role = role),
            ),
            const SizedBox(height: 18),
            const PickerLabel('Look'),
            AvatarPicker(
              selectedAvatar: _avatar,
              onChanged: (String icon) => setState(() => _avatar = icon),
            ),
            const SizedBox(height: 12),
            IdentityColorPicker(
              selectedColorHex: _colorHex,
              onChanged: (int hex) => setState(() => _colorHex = hex),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey<String>('save-profile-btn'),
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: SampanTheme.brandViolet,
                foregroundColor: SampanTheme.brandLime,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

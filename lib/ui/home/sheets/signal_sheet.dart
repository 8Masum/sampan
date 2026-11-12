import 'package:flutter/material.dart';
import 'package:sampan/core/math/geo_math.dart';
import 'package:sampan/core/protocol/wire_protocol.dart';
import 'package:sampan/data/models/identity_profile.dart';
import 'package:sampan/state/sampan_providers.dart';

/// Shows this phone's offline identity, GPS position, and BLE beacon bytes.
void showSignalSheet(BuildContext context, SampanAppState state) {
  final IdentityProfile? id = state.identity;
  final TelemetryPacket samplePacket = TelemetryPacket(
    isGuide: id?.isGuide ?? true,
    latitude: state.userLatitude,
    longitude: state.userLongitude,
    speedMetersPerSecond: 1.1,
    truncatedKeyHex: id?.truncated14ByteHex ?? '7a8b9c0d1e2f3a4b5c6d7e8f9a0b',
  );
  final String hexWire = SampanWireProtocol.bytesToHex(
    SampanWireProtocol.encodeTelemetryPacket(samplePacket),
  );

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext ctx) {
      final ColorScheme scheme = Theme.of(ctx).colorScheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'My Offline Signal',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your phone is broadcasting an offline beacon to nearby friends.',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    id?.fingerprintUri ?? 'sampan:ed25519:uninitialized',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    state.hasLocationFix
                        ? 'GPS: ${GeoMath.formatCoordinates(state.userLatitude, state.userLongitude, fractionDigits: 5)}'
                        : 'GPS: waiting for a fix…',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    hexWire,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

/*
 * Copyright (C) 2024 Yubico.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../android/state.dart';
import '../../app/message.dart';
import '../../app/models.dart';
import '../../app/state.dart';
import '../../app/views/app_page.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../management/models.dart';
import '../../widgets/choice_filter_chip.dart';
import '../../widgets/product_image.dart';
import 'key_actions.dart';
import 'manage_label_dialog.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final YubiKeyData deviceData;
  const HomeScreen(this.deviceData, {super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool hide = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final serial = widget.deviceData.info.serial;
    final keyCustomization = ref.watch(keyCustomizationManagerProvider)[serial];
    final enabledCapabilities = widget.deviceData.info.config
            .enabledCapabilities[widget.deviceData.node.transport] ??
        0;
    final primaryColor = ref.watch(defaultColorProvider);

    // We need this to avoid unwanted app switch animation
    if (hide) {
      Timer.run(() {
        setState(() {
          hide = false;
        });
      });
    }

    return AppPage(
      title: hide ? null : l10n.s_home,
      delayedContent: hide,
      keyActionsBuilder: (context) =>
          homeBuildActions(context, widget.deviceData, ref),
      builder: (context, expanded) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DeviceContent(widget.deviceData, keyCustomization),
              const SizedBox(height: 16.0),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    flex: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 4,
                          runSpacing: 8,
                          children: Capability.values
                              .where((c) => enabledCapabilities & c.value != 0)
                              .map((c) => CapabilityBadge(c))
                              .toList(),
                        ),
                        if (serial != null) ...[
                          const SizedBox(height: 32.0),
                          _DeviceColor(
                              deviceData: widget.deviceData,
                              initialCustomization: keyCustomization ??
                                  KeyCustomization(serial: serial))
                        ]
                      ],
                    ),
                  ),
                  if (widget.deviceData.info.version != const Version(0, 0, 0))
                    Flexible(
                      flex: 6,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: _HeroAvatar(
                          color: keyCustomization?.color ?? primaryColor,
                          child: ProductImage(
                            name: widget.deviceData.name,
                            formFactor: widget.deviceData.info.formFactor,
                            isNfc: widget.deviceData.info.supportedCapabilities
                                .containsKey(Transport.nfc),
                          ),
                        ),
                      ),
                    )
                ],
              )
            ],
          ),
        );
      },
    );
  }
}

class _DeviceContent extends ConsumerWidget {
  final YubiKeyData deviceData;
  final KeyCustomization? initialCustomization;
  const _DeviceContent(this.deviceData, this.initialCustomization);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    final name = deviceData.name;
    final serial = deviceData.info.serial;
    final version = deviceData.info.version;

    final label = initialCustomization?.name;
    String displayName = label != null ? '$label ($name)' : name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                displayName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (serial != null)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: IconButton(
                  icon: const Icon(Symbols.edit),
                  onPressed: () async {
                    await ref.read(withContextProvider)((context) async {
                      await _showManageLabelDialog(
                        initialCustomization ??
                            KeyCustomization(serial: serial),
                        context,
                      );
                    });
                  },
                ),
              )
          ],
        ),
        const SizedBox(
          height: 12,
        ),
        if (serial != null)
          Text(
            l10n.l_serial_number(serial),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.apply(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        if (version != const Version(0, 0, 0))
          Text(
            l10n.l_firmware_version(version),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.apply(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }

  Future<void> _showManageLabelDialog(
      KeyCustomization keyCustomization, BuildContext context) async {
    await showBlurDialog(
      context: context,
      builder: (context) => ManageLabelDialog(
        initialCustomization: keyCustomization,
      ),
    );
  }
}

class _DeviceColor extends ConsumerWidget {
  final YubiKeyData deviceData;
  final KeyCustomization initialCustomization;
  const _DeviceColor(
      {required this.deviceData, required this.initialCustomization});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final primaryColor = ref.watch(defaultColorProvider);
    final defaultColor =
        (isAndroid && ref.read(androidSdkVersionProvider) >= 31)
            ? theme.colorScheme.onSurface
            : primaryColor;
    final customColor = initialCustomization.color;

    return ChoiceFilterChip<Color?>(
      disableHover: true,
      value: customColor,
      items: const [null],
      selected: customColor != null && customColor != defaultColor,
      itemBuilder: (e) => Wrap(
        alignment: WrapAlignment.center,
        runSpacing: 8,
        spacing: 16,
        children: [
          ...[
            Colors.teal,
            Colors.cyan,
            Colors.blueAccent,
            Colors.deepPurple,
            Colors.red,
            Colors.orange,
            Colors.yellow,
            // add nice color to devices with dynamic color
            if (isAndroid && ref.read(androidSdkVersionProvider) >= 31)
              Colors.lightGreen
          ].map((e) => _ColorButton(
                color: e,
                isSelected: customColor == e,
                onPressed: () {
                  _updateColor(e, ref);
                  Navigator.of(context).pop();
                },
              )),

          // remove color button
          RawMaterialButton(
            onPressed: () {
              _updateColor(null, ref);
              Navigator.of(context).pop();
            },
            constraints: const BoxConstraints(minWidth: 26.0, minHeight: 26.0),
            fillColor: (isAndroid && ref.read(androidSdkVersionProvider) >= 31)
                ? theme.colorScheme.onSurface
                : primaryColor,
            hoverColor: Colors.black12,
            shape: const CircleBorder(),
            child: Icon(
              Symbols.cancel,
              size: 16,
              color: customColor == null
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.surface.withOpacity(0.2),
            ),
          ),
        ],
      ),
      labelBuilder: (e) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 22.0, minHeight: 22.0),
            decoration: BoxDecoration(
                color: customColor ?? defaultColor, shape: BoxShape.circle),
          ),
          const SizedBox(
            width: 12,
          ),
          Flexible(child: Text(l10n.s_color))
        ],
      ),
      onChanged: (e) {},
    );
  }

  void _updateColor(Color? color, WidgetRef ref) async {
    final manager = ref.read(keyCustomizationManagerProvider.notifier);
    await manager.set(
      serial: initialCustomization.serial,
      name: initialCustomization.name,
      color: color,
    );
  }
}

class _ColorButton extends StatefulWidget {
  final Color? color;
  final bool isSelected;
  final Function()? onPressed;

  const _ColorButton({
    required this.color,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  State<_ColorButton> createState() => _ColorButtonState();
}

class _ColorButtonState extends State<_ColorButton> {
  @override
  Widget build(BuildContext context) {
    return RawMaterialButton(
      onPressed: widget.onPressed,
      constraints: const BoxConstraints(minWidth: 26.0, minHeight: 26.0),
      fillColor: widget.color,
      hoverColor: Colors.black12,
      shape: const CircleBorder(),
      child: Icon(
        Symbols.circle,
        fill: 1,
        size: 16,
        color: widget.isSelected ? Colors.white : Colors.transparent,
      ),
    );
  }
}

class _HeroAvatar extends StatelessWidget {
  final Widget child;
  final Color color;

  const _HeroAvatar({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.6),
            color.withOpacity(0.25),
            (DialogTheme.of(context).backgroundColor ??
                    theme.dialogBackgroundColor)
                .withOpacity(0),
          ],
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Theme(
        // Give the avatar a transparent background
        data: theme.copyWith(
            colorScheme:
                theme.colorScheme.copyWith(surfaceVariant: Colors.transparent)),
        child: child,
      ),
    );
  }
}

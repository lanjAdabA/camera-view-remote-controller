import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // FORCE LANDSCAPE MODE
  // ============================================================

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // ============================================================
  // HIDE SYSTEM UI
  // ============================================================

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  runApp(const RoverRemoteApp());
}

// =================================================================
// APP
// =================================================================

class RoverRemoteApp extends StatelessWidget {
  const RoverRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RC Camera Remote',

      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF35D0BA),
          brightness: Brightness.dark,
        ),

        scaffoldBackgroundColor:
            const Color(0xFF081313),
      ),

      home: const CameraRemotePage(),
    );
  }
}

// =================================================================
// MAIN CAMERA REMOTE PAGE
// =================================================================

class CameraRemotePage extends StatefulWidget {
  const CameraRemotePage({super.key});

  @override
  State<CameraRemotePage> createState() =>
      _CameraRemotePageState();
}

class _CameraRemotePageState
    extends State<CameraRemotePage> {
  // ============================================================
  // CONNECTION SETTINGS
  // ============================================================

  String _streamUrl = '';

  String _controlBaseUrl =
      'http://192.168.10.1';

  String _connectionStatus =
      'CONNECT TO ESP';

  // ============================================================
  // JOYSTICK POSITIONS
  // ============================================================

  Offset _movementOffset = Offset.zero;

  Offset _cameraOffset = Offset.zero;

  // ============================================================
  // JOYSTICK VISIBILITY
  //
  // 0.02 = 2%
  // 0.05 = 5%
  // 0.38 = 38%
  // 1.00 = 100%
  // ============================================================

  double _joystickOpacity = 0.38;

  // ============================================================
  // COMMAND RATE LIMITING
  // ============================================================

  DateTime? _lastMovementSentAt;

  DateTime? _lastCameraSentAt;

  // ============================================================
  // OPEN SETTINGS
  // ============================================================

  Future<void> _editConnections() async {
    final result = await showDialog<ConnectionSettings>(
      context: context,

      // Prevent the dialog from becoming excessively tall.
      useSafeArea: true,

      builder: (dialogContext) {
        return _ConnectionSettingsDialog(
          streamUrl: _streamUrl,
          controlBaseUrl: _controlBaseUrl,
          joystickOpacity: _joystickOpacity,
        );
      },
    );

    // The dialog returns null when Cancel is pressed.
    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _streamUrl = result.streamUrl;

      _controlBaseUrl =
          result.controlBaseUrl;

      _joystickOpacity =
          result.joystickOpacity;

      _connectionStatus =
          _streamUrl.isEmpty
              ? 'CAMERA URL NOT SET'
              : 'CONNECTING...';
    });
  }

  // ============================================================
  // MOVEMENT JOYSTICK
  // ============================================================

  void _onMovementMove(
    double x,
    double y,
  ) {
    final now = DateTime.now();

    final lastSent =
        _lastMovementSentAt;

    // Send commands approximately every
    // 120 milliseconds.
    if (lastSent != null &&
        now
                .difference(lastSent)
                .inMilliseconds <
            120) {
      return;
    }

    _lastMovementSentAt = now;

    unawaited(
      _sendMovement(
        x,
        y,
      ),
    );
  }

  // ============================================================
  // SEND MOVEMENT COMMAND
  // ============================================================

  Future<void> _sendMovement(
    double x,
    double y,
  ) async {
    final base =
        _controlBaseUrl.trim();

    if (base.isEmpty) {
      return;
    }

    try {
      final uri =
          Uri.parse('$base/move')
              .replace(
        queryParameters: {
          'x': x.toStringAsFixed(2),
          'y': y.toStringAsFixed(2),
        },
      );

      final response =
          await http
              .get(uri)
              .timeout(
                const Duration(
                  seconds: 2,
                ),
              );

      if (mounted) {
        setState(() {
          _connectionStatus =
              response.statusCode < 400
                  ? 'CONNECTED'
                  : 'ESP ERROR ${response.statusCode}';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _connectionStatus =
              'CONTROL LINK LOST';
        });
      }
    }
  }

  // ============================================================
  // STOP ROVER
  // ============================================================

  Future<void> _stopMovement() async {
    if (mounted) {
      setState(() {
        _movementOffset =
            Offset.zero;
      });
    }

    final base =
        _controlBaseUrl.trim();

    if (base.isEmpty) {
      return;
    }

    try {
      final response =
          await http
              .get(
                Uri.parse(
                  '$base/stop',
                ),
              )
              .timeout(
                const Duration(
                  seconds: 2,
                ),
              );

      if (mounted) {
        setState(() {
          _connectionStatus =
              response.statusCode < 400
                  ? 'CONNECTED'
                  : 'ESP ERROR ${response.statusCode}';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _connectionStatus =
              'CONTROL LINK LOST';
        });
      }
    }
  }

  // ============================================================
  // CAMERA JOYSTICK
  // ============================================================

  void _onCameraMove(
    double x,
    double y,
  ) {
    final now = DateTime.now();

    final lastSent =
        _lastCameraSentAt;

    if (lastSent != null &&
        now
                .difference(lastSent)
                .inMilliseconds <
            120) {
      return;
    }

    _lastCameraSentAt = now;

    unawaited(
      _sendCameraMovement(
        x,
        y,
      ),
    );
  }

  // ============================================================
  // SEND CAMERA PAN/TILT COMMAND
  // ============================================================

  Future<void> _sendCameraMovement(
    double x,
    double y,
  ) async {
    final base =
        _controlBaseUrl.trim();

    if (base.isEmpty) {
      return;
    }

    try {
      final uri =
          Uri.parse('$base/camera')
              .replace(
        queryParameters: {
          'x': x.toStringAsFixed(2),
          'y': y.toStringAsFixed(2),
        },
      );

      await http
          .get(uri)
          .timeout(
            const Duration(
              seconds: 2,
            ),
          );
    } catch (_) {
      // Camera command errors are
      // intentionally silent.
    }
  }

  // ============================================================
  // CAMERA BACKGROUND
  // ============================================================

  Widget _cameraBackground(
    BuildContext context,
  ) {
    // ----------------------------------------------------------
    // NO CAMERA URL
    // ----------------------------------------------------------

    if (_streamUrl.isEmpty) {
      return const _CameraPlaceholder(
        icon:
            Icons.videocam_outlined,

        title:
            'CAMERA OFFLINE',

        detail:
            'Open settings and enter the ESP camera stream URL.',
      );
    }

    // ----------------------------------------------------------
    // MJPEG STREAM
    // ----------------------------------------------------------

    return Mjpeg(
      key:
          ValueKey(_streamUrl),

      stream:
          _streamUrl,

      isLive:
          true,

      fit:
          BoxFit.cover,

      timeout:
          const Duration(
        seconds: 5,
      ),

      // --------------------------------------------------------
      // CAMERA ERROR
      // --------------------------------------------------------

      error: (
        context,
        error,
        stack,
      ) {
        return const _CameraPlaceholder(
          icon:
              Icons.videocam_off_outlined,

          title:
              'CAMERA NOT AVAILABLE',

          detail:
              'Check the ESP Wi-Fi connection and camera stream URL.',
        );
      },

      // --------------------------------------------------------
      // CAMERA LOADING
      // --------------------------------------------------------

      loading: (context) {
        return const _CameraPlaceholder(
          icon:
              Icons.wifi_tethering_rounded,

          title:
              'CONNECTING TO CAMERA',

          detail:
              'Connect your device to the ESP Wi-Fi network.',
        );
      },
    );
  }

  // ============================================================
  // MAIN UI
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      body: Stack(
        fit:
            StackFit.expand,

        children: [
          // ======================================================
          // CAMERA
          // ======================================================

          _cameraBackground(
            context,
          ),

          // ======================================================
          // GAME OVERLAY
          // ======================================================

          const _GameOverlay(),

          // ======================================================
          // SETTINGS BUTTON
          //
          // TOP RIGHT
          // ======================================================

          SafeArea(
            child: Align(
              alignment:
                  Alignment.topRight,

              child: Padding(
                padding:
                    const EdgeInsets.all(
                  14,
                ),

                child: Container(
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.black.withValues(
                      alpha: 0.45,
                    ),

                    shape:
                        BoxShape.circle,

                    border:
                        Border.all(
                      color:
                          Colors.white24,
                    ),
                  ),

                  child: IconButton(
                    tooltip:
                        'Connection settings',

                    onPressed:
                        _editConnections,

                    icon:
                        const Icon(
                      Icons
                          .settings_rounded,

                      color:
                          Colors.white,

                      size: 21,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ======================================================
          // LEFT MOVEMENT JOYSTICK
          // ======================================================

          Positioned(
            left: 28,
            bottom: 22,

            child:
                _GameJoystick(
              offset:
                  _movementOffset,

              opacity:
                  _joystickOpacity,

              accent:
                  const Color(
                0xFF35D0BA,
              ),

              title:
                  'MOVE',

              onMove:
                  (
                x,
                y,
                visualOffset,
              ) {
                setState(() {
                  _movementOffset =
                      visualOffset;
                });

                _onMovementMove(
                  x,
                  y,
                );
              },

              onRelease:
                  _stopMovement,
            ),
          ),

          // ======================================================
          // RIGHT CAMERA JOYSTICK
          // ======================================================

          Positioned(
            right: 28,
            bottom: 22,

            child:
                _GameJoystick(
              offset:
                  _cameraOffset,

              opacity:
                  _joystickOpacity,

              accent:
                  const Color(
                0xFF6CA8FF,
              ),

              title:
                  'CAMERA',

              onMove:
                  (
                x,
                y,
                visualOffset,
              ) {
                setState(() {
                  _cameraOffset =
                      visualOffset;
                });

                _onCameraMove(
                  x,
                  y,
                );
              },

              onRelease: () {
                setState(() {
                  _cameraOffset =
                      Offset.zero;
                });
              },
            ),
          ),

          // ======================================================
          // BOTTOM-CENTER STATUS
          // ======================================================

          Positioned(
            left: 0,
            right: 0,
            bottom: 18,

            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),

                  decoration:
                      BoxDecoration(
                    color:
                        Colors.black.withValues(
                      alpha: 0.45,
                    ),

                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),

                    border:
                        Border.all(
                      color:
                          Colors.white24,
                    ),
                  ),

                  child: Row(
                    mainAxisSize:
                        MainAxisSize.min,

                    children: [
                      // Status indicator
                      Container(
                        width: 7,
                        height: 7,

                        decoration:
                            const BoxDecoration(
                          shape:
                              BoxShape.circle,

                          color:
                              Color(
                            0xFF35D0BA,
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 7,
                      ),

                      Text(
                        _connectionStatus,

                        style:
                            const TextStyle(
                          color:
                              Colors.white,

                          fontSize: 10,

                          fontWeight:
                              FontWeight.w700,

                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ======================================================
          // CENTER CROSSHAIR
          // ======================================================

          const Center(
            child:
                _CenterCrosshair(),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// CONNECTION SETTINGS RESULT
// =================================================================

class ConnectionSettings {
  const ConnectionSettings({
    required this.streamUrl,
    required this.controlBaseUrl,
    required this.joystickOpacity,
  });

  final String streamUrl;

  final String controlBaseUrl;

  final double joystickOpacity;
}

// =================================================================
// CONNECTION SETTINGS DIALOG
// =================================================================
//
// This widget owns its own TextEditingControllers.
//
// IMPORTANT:
// This fixes:
//
// "A TextEditingController was used after being disposed."
//
// The controllers are now disposed ONLY when this dialog widget
// itself is removed.
// =================================================================

class _ConnectionSettingsDialog
    extends StatefulWidget {
  const _ConnectionSettingsDialog({
    required this.streamUrl,
    required this.controlBaseUrl,
    required this.joystickOpacity,
  });

  final String streamUrl;

  final String controlBaseUrl;

  final double joystickOpacity;

  @override
  State<_ConnectionSettingsDialog>
      createState() =>
          _ConnectionSettingsDialogState();
}

class _ConnectionSettingsDialogState
    extends State<_ConnectionSettingsDialog> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  late final TextEditingController
      _streamController;

  late final TextEditingController
      _controlController;

  // ============================================================
  // TEMPORARY SLIDER VALUE
  // ============================================================

  late double _temporaryOpacity;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _streamController =
        TextEditingController(
      text: widget.streamUrl,
    );

    _controlController =
        TextEditingController(
      text: widget.controlBaseUrl,
    );

    _temporaryOpacity =
        widget.joystickOpacity;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _streamController.dispose();

    _controlController.dispose();

    super.dispose();
  }

  // ============================================================
  // SAVE
  // ============================================================

  void _save() {
    final streamUrl =
        _streamController.text.trim();

    final controlBaseUrl =
        _controlController.text
            .trim()
            .replaceFirst(
              RegExp(r'/+$'),
              '',
            );

    Navigator.of(context).pop(
      ConnectionSettings(
        streamUrl:
            streamUrl,

        controlBaseUrl:
            controlBaseUrl,

        joystickOpacity:
            _temporaryOpacity,
      ),
    );
  }

  // ============================================================
  // BUILD DIALOG
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    // Get available screen size.
    final media =
        MediaQuery.of(context);

    // Keyboard height.
    final keyboardHeight =
        media.viewInsets.bottom;

    // Available screen height after
    // keyboard is shown.
    final availableHeight =
        media.size.height -
            keyboardHeight;

    // Give the dialog a safe maximum height.
    final maxDialogHeight =
        availableHeight * 0.82;

    return AlertDialog(
      // ========================================================
      // IMPORTANT
      //
      // scrollable:true makes the dialog
      // handle small landscape heights
      // much more safely.
      // ========================================================

      scrollable: true,

      insetPadding:
          const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 18,
      ),

      title:
          const Text(
        'Connection settings',
      ),

      content: ConstrainedBox(
        constraints:
            BoxConstraints(
          maxHeight:
              maxDialogHeight.clamp(
            180.0,
            500.0,
          ),
        ),

        child: SingleChildScrollView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior
                  .onDrag,

          child: Column(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              // ==================================================
              // CAMERA URL
              // ==================================================

              TextField(
                controller:
                    _streamController,

                keyboardType:
                    TextInputType.url,

                textInputAction:
                    TextInputAction.next,

                decoration:
                    const InputDecoration(
                  labelText:
                      'Camera MJPEG URL',

                  hintText:
                      'http://192.168.10.1:81/stream',

                  helperText:
                      'Enter the exact camera stream URL from your ESP.',
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              // ==================================================
              // ESP CONTROL URL
              // ==================================================

              TextField(
                controller:
                    _controlController,

                keyboardType:
                    TextInputType.url,

                textInputAction:
                    TextInputAction.done,

                decoration:
                    const InputDecoration(
                  labelText:
                      'ESP control base URL',

                  hintText:
                      'http://192.168.10.1',

                  helperText:
                      'The app uses /move, /stop and /camera.',
                ),
              ),

              const SizedBox(
                height: 22,
              ),

              // ==================================================
              // JOYSTICK VISIBILITY
              // ==================================================

              Row(
                children: [
                  const Icon(
                    Icons.gamepad_rounded,
                    size: 20,
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  const Expanded(
                    child: Text(
                      'Joystick visibility',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),

                  Text(
                    '${(_temporaryOpacity * 100).round()}%',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ],
              ),

              // ==================================================
              // VISIBILITY SLIDER
              //
              // MINIMUM = 2%
              // MAXIMUM = 100%
              // ==================================================

              Slider(
                value:
                    _temporaryOpacity,

                min:
                    0.02,

                max:
                    1.0,

                divisions:
                    98,

                label:
                    '${(_temporaryOpacity * 100).round()}%',

                onChanged:
                    (value) {
                  setState(() {
                    _temporaryOpacity =
                        value;
                  });
                },
              ),

              const Text(
                'Controls the visibility of the entire joystick display.',
                style:
                    TextStyle(
                  fontSize: 12,
                  color:
                      Colors.white54,
                ),
              ),

              const SizedBox(
                height: 6,
              ),
            ],
          ),
        ),
      ),

      // ========================================================
      // BUTTONS
      // ========================================================

      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },

          child:
              const Text('Cancel'),
        ),

        FilledButton(
          onPressed:
              _save,

          child:
              const Text('Save'),
        ),
      ],
    );
  }
}

// =================================================================
// JOYSTICK
// =================================================================

class _GameJoystick
    extends StatelessWidget {
  const _GameJoystick({
    required this.offset,
    required this.onMove,
    required this.onRelease,
    required this.accent,
    required this.title,
    required this.opacity,
  });

  final Offset offset;

  final void Function(
    double x,
    double y,
    Offset visualOffset,
  ) onMove;

  final VoidCallback onRelease;

  final Color accent;

  final String title;

  // Entire joystick opacity.
  final double opacity;

  static const double
      joystickRadius = 62;

  // ============================================================
  // CALCULATE FINGER POSITION
  // ============================================================

  void _handlePosition(
    Offset position,
    Size size,
  ) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final delta =
        position - center;

    final distance =
        delta.distance;

    // Limit thumb movement.
    final limited =
        distance > joystickRadius
            ? delta *
                (joystickRadius /
                    distance)
            : delta;

    // X:
    // -1 = left
    //  0 = center
    // +1 = right
    final x =
        (limited.dx /
                joystickRadius)
            .clamp(
              -1.0,
              1.0,
            )
            .toDouble();

    // Y:
    // +1 = up
    //  0 = center
    // -1 = down
    final y =
        (-limited.dy /
                joystickRadius)
            .clamp(
              -1.0,
              1.0,
            )
            .toDouble();

    onMove(
      x,
      y,
      limited,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return SizedBox(
      width: 210,
      height: 210,

      child: LayoutBuilder(
        builder: (
          context,
          constraints,
        ) {
          final size = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );

          return GestureDetector(
            behavior:
                HitTestBehavior.opaque,

            // --------------------------------------------------
            // TOUCH START
            // --------------------------------------------------

            onPanStart:
                (details) {
              _handlePosition(
                details.localPosition,
                size,
              );
            },

            // --------------------------------------------------
            // TOUCH MOVE
            // --------------------------------------------------

            onPanUpdate:
                (details) {
              _handlePosition(
                details.localPosition,
                size,
              );
            },

            // --------------------------------------------------
            // TOUCH RELEASE
            // --------------------------------------------------

            onPanEnd:
                (_) {
              onRelease();
            },

            // --------------------------------------------------
            // TOUCH CANCEL
            // --------------------------------------------------

            onPanCancel:
                onRelease,

            child: Opacity(
              // =================================================
              // ENTIRE JOYSTICK OPACITY
              //
              // 2%   = almost invisible
              // 5%   = very faint
              // 38%  = default
              // 100% = fully visible
              // =================================================

              opacity:
                  opacity,

              child: Stack(
                alignment:
                    Alignment.center,

                children: [
                  // =============================================
                  // OUTER CIRCLE
                  // =============================================

                  Container(
                    width: 188,
                    height: 188,

                    decoration:
                        BoxDecoration(
                      shape:
                          BoxShape.circle,

                      color:
                          Colors.black
                              .withValues(
                        alpha:
                            0.65,
                      ),

                      border:
                          Border.all(
                        color:
                            Colors.white24,

                        width: 1.5,
                      ),

                      boxShadow: [
                        const BoxShadow(
                          color:
                              Colors.black54,

                          blurRadius:
                              20,

                          spreadRadius:
                              2,
                        ),
                      ],
                    ),
                  ),

                  // =============================================
                  // INNER CIRCLE
                  // =============================================

                  Container(
                    width: 130,
                    height: 130,

                    decoration:
                        BoxDecoration(
                      shape:
                          BoxShape.circle,

                      border:
                          Border.all(
                        color:
                            Colors.white38,

                        width: 1,
                      ),
                    ),
                  ),

                  // =============================================
                  // TOP LABEL
                  // =============================================

                  Positioned(
                    top: 15,

                    child: Text(
                      title ==
                              'MOVE'
                          ? 'FORWARD'
                          : 'UP',

                      style:
                          const TextStyle(
                        color:
                            Colors.white70,

                        fontSize: 8,

                        letterSpacing:
                            1,

                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),

                  // =============================================
                  // BOTTOM LABEL
                  // =============================================

                  Positioned(
                    bottom: 15,

                    child: Text(
                      title ==
                              'MOVE'
                          ? 'REVERSE'
                          : 'DOWN',

                      style:
                          const TextStyle(
                        color:
                            Colors.white70,

                        fontSize: 8,

                        letterSpacing:
                            1,

                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),

                  // =============================================
                  // LEFT LABEL
                  // =============================================

                  Positioned(
                    left: 12,

                    child: Text(
                      'LEFT',

                      style:
                          const TextStyle(
                        color:
                            Colors.white70,

                        fontSize: 8,

                        letterSpacing:
                            1,

                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),

                  // =============================================
                  // RIGHT LABEL
                  // =============================================

                  Positioned(
                    right: 12,

                    child: Text(
                      'RIGHT',

                      style:
                          const TextStyle(
                        color:
                            Colors.white70,

                        fontSize: 8,

                        letterSpacing:
                            1,

                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),

                  // =============================================
                  // MOVING THUMB
                  // =============================================

                  Transform.translate(
                    offset:
                        offset,

                    child:
                        Container(
                      width: 68,
                      height: 68,

                      decoration:
                          BoxDecoration(
                        shape:
                            BoxShape.circle,

                        color:
                            accent,

                        border:
                            Border.all(
                          color:
                              Colors.white70,

                          width: 2,
                        ),

                        boxShadow: [
                          const BoxShadow(
                            color:
                                Colors.black54,

                            blurRadius:
                                18,

                            offset:
                                Offset(
                              0,
                              7,
                            ),
                          ),
                        ],
                      ),

                      child: Icon(
                        title ==
                                'MOVE'
                            ? Icons
                                .gamepad_rounded
                            : Icons
                                .videocam_rounded,

                        color:
                            const Color(
                          0xFF061A1A,
                        ),

                        size:
                            28,
                      ),
                    ),
                  ),

                  // =============================================
                  // JOYSTICK NAME
                  // =============================================

                  Positioned(
                    bottom:
                        -1,

                    child:
                        Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal:
                            10,

                        vertical:
                            4,
                      ),

                      decoration:
                          BoxDecoration(
                        color:
                            Colors.black54,

                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                      ),

                      child:
                          Text(
                        title,

                        style:
                            TextStyle(
                          color:
                              accent,

                          fontSize:
                              9,

                          letterSpacing:
                              1.5,

                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// =================================================================
// CENTER CROSSHAIR
// =================================================================

class _CenterCrosshair
    extends StatelessWidget {
  const _CenterCrosshair();

  @override
  Widget build(
    BuildContext context,
  ) {
    return IgnorePointer(
      child: SizedBox(
        width: 28,
        height: 28,

        child: Stack(
          alignment:
              Alignment.center,

          children: [
            // Center dot
            Container(
              width: 4,
              height: 4,

              decoration:
                  const BoxDecoration(
                color:
                    Colors.white,

                shape:
                    BoxShape.circle,
              ),
            ),

            // Outer circle
            Container(
              width: 20,
              height: 20,

              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,

                border:
                    Border.all(
                  color:
                      Colors.white38,

                  width: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// CAMERA PLACEHOLDER
// =================================================================

class _CameraPlaceholder
    extends StatelessWidget {
  const _CameraPlaceholder({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;

  final String title;

  final String detail;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      color:
          const Color(0xFF071111),

      alignment:
          Alignment.center,

      child: Column(
        mainAxisSize:
            MainAxisSize.min,

        children: [
          Icon(
            icon,

            size: 60,

            color:
                const Color(
              0xFF35D0BA,
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          Text(
            title,

            style:
                const TextStyle(
              color:
                  Colors.white,

              fontSize: 20,

              fontWeight:
                  FontWeight.w800,

              letterSpacing:
                  1.5,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Padding(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 30,
            ),

            child: Text(
              detail,

              textAlign:
                  TextAlign.center,

              style:
                  const TextStyle(
                color:
                    Colors.white54,

                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// GAME OVERLAY
// =================================================================

class _GameOverlay
    extends StatelessWidget {
  const _GameOverlay();

  @override
  Widget build(
    BuildContext context,
  ) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration:
            BoxDecoration(
          gradient:
              LinearGradient(
            begin:
                Alignment.topCenter,

            end:
                Alignment.bottomCenter,

            colors: [
              Colors.black
                  .withValues(
                alpha:
                    0.45,
              ),

              Colors.transparent,

              Colors.transparent,

              Colors.black
                  .withValues(
                alpha:
                    0.50,
              ),
            ],

            stops: const [
              0,
              0.25,
              0.60,
              1,
            ],
          ),
        ),
      ),
    );
  }
}
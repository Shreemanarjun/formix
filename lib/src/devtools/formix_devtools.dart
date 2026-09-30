import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart'; // Added for lastOrNull
import '../controllers/formix_base_controller.dart';
import '../controllers/field_id.dart';

/// Service for interacting with the Formix DevTools extension.
///
/// The payload/action logic is factored into pure static methods
/// ([listFormsPayload], [formDetailsPayload], [applyAction]) so it can be unit
/// tested directly; the thin `dart:developer` service-extension bridge that wires
/// them to the DevTools UI is registered in [_maybeRegisterExtensions].
class FormixDevToolsService {
  static final Map<String, FormixBaseController> _activeControllers = {};
  static final Set<String> _allFormHistory = <String>{};
  static String? _latestActiveId;

  static bool _extensionsRegistered = false;

  /// Register a controller for DevTools monitoring.
  static void registerController(String id, FormixBaseController controller) {
    _activeControllers[id] = controller;

    // Refresh history order: move to end
    _allFormHistory.remove(id);
    _allFormHistory.add(id);

    _latestActiveId = id;
    _maybeRegisterExtensions();
  }

  /// Unregister a controller.
  static void unregisterController(String id) {
    _activeControllers.remove(id);
    // We keep it in _allFormHistory but it's no longer in _activeControllers.
    if (_latestActiveId == id) {
      _latestActiveId = _activeControllers.keys.lastOrNull;
    }
  }

  /// The id of the most recently registered still-active form, if any.
  @visibleForTesting
  static String? get latestActiveId => _latestActiveId;

  /// Payload listing all known forms (active + historical), newest first.
  @visibleForTesting
  static Map<String, dynamic> listFormsPayload() {
    return {
      'latestActiveId': _latestActiveId,
      'forms': _allFormHistory.toList().reversed.map((id) => {'id': id, 'isActive': _activeControllers.containsKey(id)}).toList(),
    };
  }

  /// Full inspector payload for [formId], or null if the form is not active.
  @visibleForTesting
  static Map<String, dynamic>? formDetailsPayload(String? formId) {
    final controller = _activeControllers[formId];
    if (controller == null) return null;

    final state = controller.state;
    return <String, dynamic>{
      'values': state.values,
      'nestedValues': state.toNestedMap(),
      'validations': {
        for (final entry in state.validations.entries)
          entry.key: {
            'isValid': entry.value.isValid,
            'errorMessage': entry.value.errorMessage,
            'isValidating': entry.value.isValidating,
          },
      },
      'dirtyStates': state.dirtyStates,
      'touchedStates': state.touchedStates,
      'pendingStates': state.pendingStates,
      'isSubmitting': state.isSubmitting,
      'fieldCount': state.values.length,
      'errorCount': state.errorCount,
      'dirtyCount': state.dirtyCount,
      'pendingCount': state.pendingCount,
      'resetCount': state.resetCount,
      'validationDurations': {
        for (final entry in controller.validationDurations.entries) entry.key: entry.value.inMicroseconds,
      },
      'dependentsMap': {
        for (final entry in controller.dependentsMap.entries) entry.key: entry.value.map((e) => e.toString()).toList(),
      },
      'dependsOnMap': {
        for (final entry in controller.formFieldDefinitions.entries) entry.key: entry.value.dependsOn.map((e) => e.key).toList(),
      },
      'canUndo': controller.canUndo,
      'canRedo': controller.canRedo,
    };
  }

  /// Encodes a DevTools payload to JSON, rendering [DateTime] as ISO-8601 and
  /// falling back to `toString` for any other non-encodable value.
  @visibleForTesting
  static String encodePayload(Object? payload) {
    return jsonEncode(
      payload,
      toEncodable: (nonEncodable) {
        if (nonEncodable is DateTime) return nonEncodable.toIso8601String();
        return nonEncodable.toString();
      },
    );
  }

  /// Applies a mutating DevTools [action] (`resetForm`, `undo`, `redo`,
  /// `validateField`, `updateFieldValue`, `setFormState`, `debugFillDummyData`)
  /// to the form named by `params['formId']`.
  ///
  /// Returns true on success, false if the form/params are invalid. Throws only
  /// on malformed JSON in value-bearing actions (callers surface it as an error).
  @visibleForTesting
  static bool applyAction(String action, Map<String, String?> params) {
    final controller = _activeControllers[params['formId']];
    if (controller == null) return false;

    switch (action) {
      case 'debugFillDummyData':
        controller.debugFillDummyData();
        return true;
      case 'resetForm':
        controller.reset();
        return true;
      case 'undo':
        controller.undo();
        return true;
      case 'redo':
        controller.redo();
        return true;
      case 'validateField':
        final fieldId = params['fieldId'];
        if (fieldId == null) return false;
        controller.validate(fields: [FormixFieldID<dynamic>(fieldId)]);
        return true;
      case 'updateFieldValue':
        final fieldId = params['fieldId'];
        final valueJson = params['value'];
        if (fieldId == null || valueJson == null) return false;
        controller.setValue(FormixFieldID<dynamic>(fieldId), jsonDecode(valueJson));
        return true;
      case 'setFormState':
        final stateJson = params['state'];
        if (stateJson == null) return false;
        final newState = (jsonDecode(stateJson) as Map).cast<String, dynamic>();
        for (final entry in newState.entries) {
          controller.setValue(FormixFieldID<dynamic>(entry.key), entry.value);
        }
        return true;
    }
    return false;
  }

  // coverage:ignore-start
  // The block below is the `dart:developer` service-extension bridge. It only
  // executes when the Formix DevTools extension is attached at runtime, so it is
  // excluded from coverage; its behaviour is exercised through the pure methods
  // above (listFormsPayload / formDetailsPayload / applyAction / encodePayload).
  static void _maybeRegisterExtensions() {
    if (_extensionsRegistered) return;
    if (!kDebugMode) return;
    _extensionsRegistered = true;

    if (!kIsWeb) {
      dev.Service.getInfo()
          .then((info) {
            final serverUri = info.serverUri;
            if (serverUri != null) {
              final String base = serverUri.toString();
              final String wsScheme = serverUri.scheme == 'https' ? 'wss' : 'ws';
              final String wsBase = base.replaceFirst(serverUri.scheme, wsScheme);
              final String wsUri = wsBase.endsWith('/') ? '${wsBase}ws' : '$wsBase/ws';
              final String devToolsBase = base.endsWith('/') ? '${base}devtools/' : '$base/devtools/';
              final String fullUrl = "${devToolsBase}formix_ext?uri=$wsUri";
              debugPrint('\x1B[32m[Formix]\x1B[0m 🛠️  Inspector: $fullUrl');
            }
          })
          .catchError((e) {
            debugPrint('[Formix] Failed to get DevTools info: $e');
          });
    }

    dev.registerExtension('ext.formix.listForms', (method, parameters) async {
      try {
        return dev.ServiceExtensionResponse.result(encodePayload(listFormsPayload()));
      } catch (e) {
        return dev.ServiceExtensionResponse.error(dev.ServiceExtensionResponse.extensionError, e.toString());
      }
    });

    dev.registerExtension('ext.formix.getFormDetails', (method, parameters) async {
      try {
        final payload = formDetailsPayload(parameters['formId']);
        if (payload == null) {
          return dev.ServiceExtensionResponse.error(dev.ServiceExtensionResponse.invalidParams, 'Form not found: ${parameters['formId']}');
        }
        return dev.ServiceExtensionResponse.result(encodePayload(payload));
      } catch (e) {
        return dev.ServiceExtensionResponse.error(dev.ServiceExtensionResponse.extensionError, e.toString());
      }
    });

    dev.registerExtension('ext.formix.debugForceSubmit', (method, parameters) async {
      final controller = _activeControllers[parameters['formId']];
      if (controller == null) {
        return dev.ServiceExtensionResponse.error(dev.ServiceExtensionResponse.invalidParams, 'Form not found');
      }
      controller.setSubmitting(true);
      await Future.delayed(const Duration(milliseconds: 500));
      controller.setSubmitting(false);
      return dev.ServiceExtensionResponse.result(encodePayload({'success': true}));
    });

    for (final action in ['debugFillDummyData', 'resetForm', 'undo', 'redo', 'validateField', 'updateFieldValue', 'setFormState']) {
      dev.registerExtension('ext.formix.$action', (method, parameters) async {
        try {
          final ok = applyAction(action, parameters);
          if (!ok) {
            return dev.ServiceExtensionResponse.error(dev.ServiceExtensionResponse.invalidParams, 'Form or params invalid');
          }
          return dev.ServiceExtensionResponse.result(encodePayload({'success': true}));
        } catch (e) {
          return dev.ServiceExtensionResponse.error(dev.ServiceExtensionResponse.extensionError, e.toString());
        }
      });
    }
  }
  // coverage:ignore-end
}

import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart'; // Added for lastOrNull
import '../controllers/formix_base_controller.dart';
import '../controllers/field_id.dart';

/// Service for interacting with DevTools extension.
class FormixDevToolsService {
  static final Map<String, FormixBaseController> _activeControllers = {};
  static final Set<String> _allFormHistory = <String>{};
  static String? _latestActiveId; // Added

  static bool _extensionsRegistered = false;

  /// Register a controller for DevTools monitoring.
  static void registerController(String id, FormixBaseController controller) {
    _activeControllers[id] = controller;

    // Refresh history order: move to end
    _allFormHistory.remove(id);
    _allFormHistory.add(id);

    _latestActiveId = id; // Added
    _maybeRegisterExtensions();
  }

  /// Unregister a controller.
  static void unregisterController(String id) {
    _activeControllers.remove(id);
    // We keep it in _allFormHistory but it's no longer in _activeControllers
    if (_latestActiveId == id) {
      // Added
      _latestActiveId = _activeControllers.keys.lastOrNull; // Added
    } // Added
  }

  static void _maybeRegisterExtensions() {
    if (_extensionsRegistered) return;

    // Use a local variable to avoid issues with static access during async
    if (!kDebugMode) return;
    _extensionsRegistered = true;

    // Log the DevTools URL for easy access (Native only)
    if (!kIsWeb) {
      dev.Service.getInfo()
          .then((info) {
            final serverUri = info.serverUri;
            if (serverUri != null) {
              final String base = serverUri.toString();

              // Construct the WebSocket URI (ws://.../token/ws)
              final String wsScheme = serverUri.scheme == 'https' ? 'wss' : 'ws';
              final String wsBase = base.replaceFirst(
                serverUri.scheme,
                wsScheme,
              );
              final String wsUri = wsBase.endsWith('/') ? '${wsBase}ws' : '$wsBase/ws';

              // Construct the DevTools Base (http://.../token/devtools/)
              final String devToolsBase = base.endsWith('/') ? '${base}devtools/' : '$base/devtools/';

              // Build the final deep link to the formix_ext route
              final String fullUrl = "${devToolsBase}formix_ext?uri=$wsUri";

              debugPrint('\x1B[32m[Formix]\x1B[0m 🛠️  Inspector: $fullUrl');
            }
          })
          .catchError((e) {
            debugPrint('[Formix] Failed to get DevTools info: $e');
          });
    }

    // List all form IDs (active and history)
    dev.registerExtension('ext.formix.listForms', (method, parameters) async {
      try {
        return dev.ServiceExtensionResponse.result(
          jsonEncode({
            'latestActiveId': _latestActiveId,
            'forms': _allFormHistory
                .toList()
                .reversed
                .map(
                  (id) => {
                    'id': id,
                    'isActive': _activeControllers.containsKey(id),
                  },
                )
                .toList(),
          }),
        );
      } catch (e) {
        return dev.ServiceExtensionResponse.error(
          dev.ServiceExtensionResponse.extensionError,
          e.toString(),
        );
      }
    });

    // Get detail for a specific form
    dev.registerExtension('ext.formix.getFormDetails', (
      method,
      parameters,
    ) async {
      try {
        final formId = parameters['formId'];
        final controller = _activeControllers[formId];

        if (controller == null) {
          return dev.ServiceExtensionResponse.error(
            dev.ServiceExtensionResponse.invalidParams,
            'Form not found: $formId',
          );
        }

        final state = controller.state;
        return dev.ServiceExtensionResponse.result(
          jsonEncode(
            <String, dynamic>{
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
            },
            toEncodable: (nonEncodable) {
              if (nonEncodable is DateTime) {
                return nonEncodable.toIso8601String();
              }
              return nonEncodable.toString();
            },
          ),
        );
      } catch (e) {
        return dev.ServiceExtensionResponse.error(
          dev.ServiceExtensionResponse.extensionError,
          e.toString(),
        );
      }
    });

    // Fill dummy data
    dev.registerExtension('ext.formix.debugFillDummyData', (
      method,
      parameters,
    ) async {
      final formId = parameters['formId'];
      final controller = _activeControllers[formId];
      if (controller != null) {
        controller.debugFillDummyData();
        return dev.ServiceExtensionResponse.result(jsonEncode({'success': true}));
      }
      return dev.ServiceExtensionResponse.error(
        dev.ServiceExtensionResponse.invalidParams,
        'Form not found',
      );
    });

    // Force submit
    dev.registerExtension('ext.formix.debugForceSubmit', (
      method,
      parameters,
    ) async {
      final formId = parameters['formId'];
      final controller = _activeControllers[formId];
      if (controller != null) {
        // We can't easily pass a callback over RPC, but we can set the submitting state
        // or trigger a "fake" successful submit for the devtools to see.
        // For now, let's just trigger a validation and then set state.
        controller.setSubmitting(true);
        await Future.delayed(const Duration(milliseconds: 500));
        controller.setSubmitting(false);
        return dev.ServiceExtensionResponse.result(jsonEncode({'success': true}));
      }
      return dev.ServiceExtensionResponse.error(
        dev.ServiceExtensionResponse.invalidParams,
        'Form not found',
      );
    });

    // Update field value
    dev.registerExtension('ext.formix.updateFieldValue', (
      method,
      parameters,
    ) async {
      try {
        final formId = parameters['formId'];
        final fieldId = parameters['fieldId'];
        final valueJson = parameters['value'];
        final controller = _activeControllers[formId];

        if (controller == null) {
          return dev.ServiceExtensionResponse.error(
            dev.ServiceExtensionResponse.invalidParams,
            'Form not found',
          );
        }

        if (fieldId == null || valueJson == null) {
          return dev.ServiceExtensionResponse.error(
            dev.ServiceExtensionResponse.invalidParams,
            'Missing fieldId or value',
          );
        }

        // Try to parse the value
        final dynamic value = jsonDecode(valueJson);

        // We use a generic ID because we don't know the exact type T here,
        // but setValue handles dynamic values by runtime type checking.
        final id = FormixFieldID<dynamic>(fieldId);
        controller.setValue(id, value);

        return dev.ServiceExtensionResponse.result(jsonEncode({'success': true}));
      } catch (e) {
        return dev.ServiceExtensionResponse.error(
          dev.ServiceExtensionResponse.extensionError,
          e.toString(),
        );
      }
    });

    // Reset Form
    dev.registerExtension('ext.formix.resetForm', (method, parameters) async {
      final formId = parameters['formId'];
      final controller = _activeControllers[formId];
      if (controller != null) {
        controller.reset();
        return dev.ServiceExtensionResponse.result(jsonEncode({'success': true}));
      }
      return dev.ServiceExtensionResponse.error(dev.ServiceExtensionResponse.invalidParams, 'Form not found');
    });

    // Undo
    dev.registerExtension('ext.formix.undo', (method, parameters) async {
      final formId = parameters['formId'];
      final controller = _activeControllers[formId];
      if (controller != null) {
        controller.undo();
        return dev.ServiceExtensionResponse.result(jsonEncode({'success': true}));
      }
      return dev.ServiceExtensionResponse.error(dev.ServiceExtensionResponse.invalidParams, 'Form not found');
    });

    // Redo
    dev.registerExtension('ext.formix.redo', (method, parameters) async {
      final formId = parameters['formId'];
      final controller = _activeControllers[formId];
      if (controller != null) {
        controller.redo();
        return dev.ServiceExtensionResponse.result(jsonEncode({'success': true}));
      }
      return dev.ServiceExtensionResponse.error(dev.ServiceExtensionResponse.invalidParams, 'Form not found');
    });

    // Validate specific field
    dev.registerExtension('ext.formix.validateField', (method, parameters) async {
      final formId = parameters['formId'];
      final fieldId = parameters['fieldId'];
      final controller = _activeControllers[formId];

      if (controller != null && fieldId != null) {
        final id = FormixFieldID<dynamic>(fieldId);
        controller.validate(fields: [id]);
        return dev.ServiceExtensionResponse.result(jsonEncode({'success': true}));
      }
      return dev.ServiceExtensionResponse.error(dev.ServiceExtensionResponse.invalidParams, 'Form or Field not found');
    });

    // Set entire form state
    dev.registerExtension('ext.formix.setFormState', (method, parameters) async {
      try {
        final formId = parameters['formId'];
        final stateJson = parameters['state'];
        final controller = _activeControllers[formId];

        if (controller != null && stateJson != null) {
          final Map<String, dynamic> newState = (jsonDecode(stateJson) as Map).cast<String, dynamic>();

          for (final entry in newState.entries) {
            final id = FormixFieldID<dynamic>(entry.key);
            controller.setValue(id, entry.value);
          }

          return dev.ServiceExtensionResponse.result(jsonEncode({'success': true}));
        }
        return dev.ServiceExtensionResponse.error(dev.ServiceExtensionResponse.invalidParams, 'Form or state missing');
      } catch (e) {
        return dev.ServiceExtensionResponse.error(dev.ServiceExtensionResponse.extensionError, e.toString());
      }
    });
  }
}

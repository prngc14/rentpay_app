import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/firestore_service.dart';
import '../../widgets/app_warning_banner.dart';

class UploadQrScreen extends StatefulWidget {
  const UploadQrScreen({super.key});

  @override
  State<UploadQrScreen> createState() => _UploadQrScreenState();
}

class _UploadQrScreenState extends State<UploadQrScreen> {
  final FirestoreService firestore = FirestoreService();

  File? gcashImage;
  File? mayaImage;

  String? gcashUrl;
  String? mayaUrl;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadExistingQr();
  }

  Future<void> loadExistingQr() async {
    try {
      final data = await firestore.getOwnerQrData();

      if (data != null && mounted) {
        setState(() {
          gcashUrl = data['gcashQr'];
          mayaUrl = data['paymayaQr'];
        });
      }
    } catch (e) {
      debugPrint("Error loading QR: $e");
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> pickImage(String type) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

    if (picked != null && mounted) {
      setState(() {
        if (type == "gcash") {
          gcashImage = File(picked.path);
        } else {
          mayaImage = File(picked.path);
        }
      });
    }
  }

  Future<void> uploadQr(String type) async {
    try {
      setState(() {
        isLoading = true;
      });

      final File? selectedFile = type == "gcash" ? gcashImage : mayaImage;

      if (selectedFile == null) {
        if (mounted) {
          showAppWarningBanner(
            context,
            "Please select a $type QR image first",
          );
        }

        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }

        return;
      }

      await firestore.uploadOwnerQr(
        file: selectedFile,
        type: type,
      );

      await loadExistingQr();

      if (!mounted) return;

      showAppSuccessBanner(
        context,
        "${type.toUpperCase()} QR uploaded successfully",
      );
    } catch (e) {
      if (mounted) {
        showAppWarningBanner(
          context,
          friendlyAuthError(e),
        );
      }
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget buildQrSection({
    required String title,
    required File? localFile,
    required String? networkUrl,
    required VoidCallback onPick,
    required VoidCallback onUpload,
  }) {
    final theme = Theme.of(context);

    final bool hasImage =
        localFile != null || (networkUrl != null && networkUrl.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // =====================================================
        // QR TITLE
        // =====================================================

        Center(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
        ),

        const SizedBox(height: 10),

        // =====================================================
        // QR IMAGE
        // =====================================================

        GestureDetector(
          onTap: () {
            if (!hasImage) return;

            showDialog(
              context: context,
              builder: (_) {
                return Dialog(
                  backgroundColor: theme.cardColor,
                  insetPadding: const EdgeInsets.all(20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      children: [
                        InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: localFile != null
                              ? Image.file(
                                  localFile,
                                  fit: BoxFit.contain,
                                )
                              : Image.network(
                                  networkUrl!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (
                                    context,
                                    error,
                                    stackTrace,
                                  ) {
                                    return Padding(
                                      padding: const EdgeInsets.all(30),
                                      child: Center(
                                        child: Text(
                                          "Failed to load QR image",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: theme
                                                .textTheme.bodyMedium?.color,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: Icon(
                              Icons.close,
                              size: 22,
                              color: theme.iconTheme.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: localFile != null
                ? Image.file(
                    localFile,
                    fit: BoxFit.contain,
                  )
                : (networkUrl != null && networkUrl.isNotEmpty)
                    ? Image.network(
                        networkUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (
                          context,
                          error,
                          stackTrace,
                        ) {
                          return Center(
                            child: Text(
                              "Failed to load QR image",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.textTheme.bodySmall?.color,
                                fontSize: 11,
                              ),
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Text(
                          "No QR uploaded yet",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.textTheme.bodySmall?.color,
                            fontSize: 12,
                          ),
                        ),
                      ),
          ),
        ),

        const SizedBox(height: 10),

        // =====================================================
        // ACTION BUTTONS
        // =====================================================

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // SELECT IMAGE
            GestureDetector(
              onTap: onPick,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  "Select Image",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // UPLOAD QR
            GestureDetector(
              onTap: onUpload,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  "Upload QR",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      // =====================================================
      // APP BAR
      // =====================================================

      appBar: AppBar(
        title: Text(
          "Rentpay",
          style: TextStyle(
            fontFamily: 'RentpayScript',
            fontSize: 32,
            fontWeight: FontWeight.w400,
            color: theme.textTheme.titleLarge?.color,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: theme.iconTheme.color,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),

      // =====================================================
      // BODY
      // =====================================================

      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: colorScheme.primary,
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  25,
                  16,
                  24,
                ),
                child: Column(
                  children: [
                    // =================================================
                    // GCASH QR
                    // =================================================

                    buildQrSection(
                      title: "GCash QR",
                      localFile: gcashImage,
                      networkUrl: gcashUrl,
                      onPick: () => pickImage("gcash"),
                      onUpload: () => uploadQr("gcash"),
                    ),

                    const SizedBox(height: 75),

                    // =================================================
                    // PAYMAYA QR
                    // =================================================

                    buildQrSection(
                      title: "PayMaya QR",
                      localFile: mayaImage,
                      networkUrl: mayaUrl,
                      onPick: () => pickImage("maya"),
                      onUpload: () => uploadQr("maya"),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}

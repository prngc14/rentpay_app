import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/cloudinary_service.dart';
import '../../widgets/app_warning_banner.dart';
import '../../widgets/rentpay_backdrop.dart';
import '../../widgets/rentpay_glass_panel.dart';

class TenantProfileScreen extends StatefulWidget {
  const TenantProfileScreen({super.key});

  @override
  State<TenantProfileScreen> createState() => _TenantProfileScreenState();
}

class _TenantProfileScreenState extends State<TenantProfileScreen> {
  final nameController = TextEditingController();
  final jobController = TextEditingController();
  final phoneController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;

  File? selectedWorkIdImage;

  String? workIdUrl;


  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _primaryText =>
      _isDark ? const Color(0xFFE8EEF0) : const Color(0xFF123E5A);

  Color get _secondaryText =>
      _isDark ? const Color(0xFFA9B4B8) : const Color(0xFF587287);

  Color get _fieldFill =>
      _isDark ? const Color(0xFF171C1E) : const Color(0xFFF7F9FA);

  @override
  void initState() {
    super.initState();
    loadProfile();
  }


  Future<void> loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};

        nameController.text = (data["name"] ?? "").toString();

        jobController.text = (data["job"] ?? "").toString();

        phoneController.text = (data["phone"] ?? "").toString();

        workIdUrl = data["workIdUrl"];
      }
    } catch (e) {
      if (!mounted) return;

      showAppWarningBanner(
        context,
        friendlyAuthError(e),
      );
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }


  Future<void> pickWorkIdImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (picked == null) return;

    setState(() {
      selectedWorkIdImage = File(picked.path);
    });
  }


  Future<void> saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    if (nameController.text.trim().isEmpty ||
        jobController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty) {
      showAppWarningBanner(
        context,
        "Please fill all fields",
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      String? uploadedWorkIdUrl = workIdUrl;

      // UPLOAD WORK ID IMAGE

      if (selectedWorkIdImage != null) {
        uploadedWorkIdUrl = await uploadToCloudinary(
          selectedWorkIdImage!,
        );
      }

    

      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .update({
        "name": nameController.text.trim(),
        "job": jobController.text.trim(),
        "phone": phoneController.text.trim(),
        "workIdUrl": uploadedWorkIdUrl,
      });

      if (!mounted) return;

      setState(() {
        workIdUrl = uploadedWorkIdUrl;
        isSaving = false;
      });

      showAppSuccessBanner(
        context,
        "Profile saved successfully",
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      showAppWarningBanner(
        context,
        friendlyAuthError(e),
      );
    }
  }



  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      cursorColor: _primaryText,
      style: TextStyle(
        color: _primaryText,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        labelStyle: TextStyle(
          color: _secondaryText,
          fontSize: 13,
        ),
        floatingLabelStyle: TextStyle(color: _primaryText),
        prefixIcon: Icon(
          icon,
          color: _secondaryText,
          size: 20,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        filled: true,
        fillColor: _fieldFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _isDark ? Colors.white54 : const Color(0xFF123E5A),
          ),
        ),
      ),
    );
  }



  Widget _buildWorkIdCard({double? height}) {
    ImageProvider? imageProvider;

    if (selectedWorkIdImage != null) {
      imageProvider = FileImage(selectedWorkIdImage!);
    } else if (workIdUrl != null && workIdUrl!.isNotEmpty) {
      imageProvider = NetworkImage(workIdUrl!);
    }

    return GestureDetector(
      onTap: pickWorkIdImage,
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: _fieldFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isDark ? Colors.white12 : Colors.grey.shade300,
          ),
          image: imageProvider != null
              ? DecorationImage(
                  image: imageProvider,
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: imageProvider == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.upload_file,
                    size: 38,
                    color: _secondaryText,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tap to upload Work ID",
                    style: TextStyle(
                      color: _secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              )
            : Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ),
      ),
    );
  }



  Widget _buildPersonalInfoPanel() {
    return RentpayGlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RentpayPanelHeader(
            icon: Icons.person_outline,
            title: "Personal Information",
            dense: true,
          ),
          const SizedBox(height: 10),
          _buildInputField(
            controller: nameController,
            label: "Full Name",
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 10),
          _buildInputField(
            controller: jobController,
            label: "Job",
            icon: Icons.work_outline,
          ),
          const SizedBox(height: 10),
          _buildInputField(
            controller: phoneController,
            label: "Phone Number",
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkIdPanel({required bool expand}) {
    return RentpayGlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RentpayPanelHeader(
            icon: Icons.badge_outlined,
            title: "Work ID",
            dense: true,
          ),
          const SizedBox(height: 10),
          if (expand)
            Expanded(child: _buildWorkIdCard())
          else
            _buildWorkIdCard(height: 225),
        ],
      ),
    );
  }

  // Maliit at walang kulay; kapareho ng "Upload Payment Screenshot" at
  // ng mga buttons sa owner QR screen.
  Widget _buildSaveButton() {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isSaving ? null : saveProfile,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 26,
                vertical: 10,
              ),
              child: isSaving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _primaryText,
                      ),
                    )
                  : Text(
                      "Save Profile",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _primaryText,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: _primaryText,
        ),
      );
    }

    return RentPayBackdrop(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const EdgeInsets padding = EdgeInsets.fromLTRB(16, 8, 16, 8);


            final bool scrollMode = constraints.maxHeight < 520;

            if (scrollMode) {
              return SingleChildScrollView(
                padding: padding,
                child: Column(
                  children: [
                    _buildPersonalInfoPanel(),
                    const SizedBox(height: 10),
                    _buildWorkIdPanel(expand: false),
                    const SizedBox(height: 10),
                    _buildSaveButton(),
                  ],
                ),
              );
            }


            return Padding(
              padding: padding,
              child: Column(
                children: [
                  _buildPersonalInfoPanel(),
                  const SizedBox(height: 10),
                  Expanded(child: _buildWorkIdPanel(expand: true)),
                  const SizedBox(height: 10),
                  _buildSaveButton(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    jobController.dispose();
    phoneController.dispose();
    super.dispose();
  }
}

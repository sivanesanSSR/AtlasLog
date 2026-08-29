import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../theme/app_theme.dart';

/// A circular avatar that opens a camera/gallery/remove picker sheet on
/// tap. Shows [existingPhoto] if provided and no new file has been
/// picked yet, otherwise shows the newly picked file. Reports changes
/// via [onChanged] — passing a File means "use this new photo",
/// null with [wasRemoved] true means "remove the current photo".
class MemberPhotoPicker extends StatefulWidget {
  final File? existingPhoto;
  final void Function(File? newFile, bool wasRemoved) onChanged;

  const MemberPhotoPicker({
    super.key,
    this.existingPhoto,
    required this.onChanged,
  });

  @override
  State<MemberPhotoPicker> createState() => _MemberPhotoPickerState();
}

class _MemberPhotoPickerState extends State<MemberPhotoPicker> {
  File? _pickedFile;
  bool _removed = false;

  Future<void> _showPickerSheet() async {
    final picker = ImagePicker();
    await showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final image = await picker.pickImage(source: ImageSource.camera, maxWidth: 1200, imageQuality: 90);
                if (image != null) await _cropAndApply(File(image.path));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 90);
                if (image != null) await _cropAndApply(File(image.path));
              },
            ),
            if (_currentDisplayFile != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() {
                    _pickedFile = null;
                    _removed = true;
                  });
                  widget.onChanged(null, true);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _cropAndApply(File sourceFile) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: sourceFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: AppTheme.secondary,
          toolbarWidgetColor: Colors.white,
          statusBarColor: AppTheme.secondary,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Crop Photo',
          aspectRatioLockEnabled: true,
        ),
      ],
    );

    // If the user cancels cropping, fall back to the original picked file
    // rather than discarding the selection entirely.
    final finalFile = cropped != null ? File(cropped.path) : sourceFile;
    _applyPicked(finalFile);
  }

  void _applyPicked(File file) {
    setState(() {
      _pickedFile = file;
      _removed = false;
    });
    widget.onChanged(file, false);
  }

  File? get _currentDisplayFile {
    if (_removed) return null;
    return _pickedFile ?? widget.existingPhoto;
  }

  @override
  Widget build(BuildContext context) {
    final displayFile = _currentDisplayFile;
    return GestureDetector(
      onTap: _showPickerSheet,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: displayFile != null ? FileImage(displayFile) : null,
            child: displayFile == null
                ? const Icon(Icons.person, size: 44, color: Colors.grey)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

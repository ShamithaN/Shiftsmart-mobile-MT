import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shiftsmart/providers/user_provider.dart';

class ProfileAvatar extends StatefulWidget {
  final bool editable;
  final File? initialImage;
  final Function(File)? onImageSelected;

  const ProfileAvatar({
    super.key,
    this.editable = true,
    this.initialImage,
    this.onImageSelected,
  });

  @override
  _ProfileAvatarState createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  File? _selectedImageFile;

  @override
  void initState() {
    super.initState();
    _selectedImageFile = widget.initialImage;
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 85);
    if (image != null) {
      setState(() {
        _selectedImageFile = File(image.path);
      });

      if (widget.onImageSelected != null) {
        widget.onImageSelected!(_selectedImageFile!);
      }
    }
  }

  Future<void> _showImageSourceOptions(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1E2433),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white),
                title: const Text('Take photo', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white),
                title: const Text('Choose from gallery', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.close, color: Colors.white),
                title: const Text('Cancel', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      },
    );

    if (source != null) {
      await _pickImageFromSource(source);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = Provider.of<UserProvider>(context, listen: false)
        .userProfile["profilePicture"];

    final avatar = Container(
      width: 100,
      height: 100,
      alignment: Alignment.center,
      child: ClipOval(
        child: _selectedImageFile != null
            ? Image.file(
                _selectedImageFile!,
                fit: BoxFit.cover,
                width: 100,
                height: 100,
              )
            : (imageUrl != null && imageUrl.isNotEmpty)
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: 100,
                    height: 100,
                  )
                : const Icon(Icons.account_circle,
                    size: 100, color: Colors.white),
      ),
    );

    return Stack(
      children: [
        widget.editable
            ? GestureDetector(
                onTap: () => _showImageSourceOptions(context),
                child: avatar,
              )
            : avatar,
        if (widget.editable)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit, color: Colors.black54, size: 18),
            ),
          ),
      ],
    );
  }
}

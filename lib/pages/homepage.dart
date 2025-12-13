import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? profile;
  bool loading = true;
  bool uploading = false;

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  // 1️⃣ Fetch user profile
  Future<void> fetchProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final data = await supabase
        .from('users')
        .select()
        .eq('id', user.id)
        .single();

    setState(() {
      profile = data;
      loading = false;
    });
  }

  // 2️⃣ Pick image dialog
  Future<void> showImagePickerDialog() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change profile picture'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Gallery'),
              onTap: () async {
                final image = await pickImage(ImageSource.gallery);
                if (image != null) uploadAvatar(image);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () async {
                Navigator.pop(context);
                final image = await pickImage(ImageSource.camera);
                if (image != null) uploadAvatar(image);
              },
            ),
          ],
        ),
      ),
    );
  }

  // 3️⃣ Pick image
  Future<File?> pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return null;
    return File(picked.path);
  }

  // 4️⃣ Upload avatar to Supabase
  Future<void> uploadAvatar(File imageFile) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => uploading = true);

    final fileExt = imageFile.path.split('.').last;
    final filePath = '${user.id}/avatar.$fileExt';

    try {
      await supabase.storage
          .from('avatars')
          .upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

      final imageUrl = supabase.storage.from('avatars').getPublicUrl(filePath);

      // Save URL in DB
      await supabase
          .from('users')
          .update({'avatar_url': imageUrl})
          .eq('id', user.id);

      await fetchProfile();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }

    setState(() => uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Home'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 5️⃣ Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: profile?['avatar_url'] != null
                      ? NetworkImage(profile!['avatar_url'])
                      : null,
                  child: profile?['avatar_url'] == null
                      ? const Icon(Icons.person, size: 60)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: uploading ? null : showImagePickerDialog,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.blue,
                      child: uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.edit, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 6️⃣ User info
            Text(
              profile?['name'] ?? '',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              profile?['email'] ?? '',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

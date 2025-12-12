import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // For Brand Icons
import 'package:url_launcher/url_launcher.dart';

class AboutMeScreen extends StatelessWidget {
  const AboutMeScreen({super.key});

  // --- Configuration Data ---
  static const String _name = "Yash Makwana";
  static const String _title = "Computer Science Student | Flutter Developer";
  static const String _bio = 
      "I'm a passionate Computer Science student at RK University who loves transforming ideas into real, impactful products. "
      "Whether it's developing a mobile app, crafting a web service, or designing a clean interface, I enjoy solving problems through code.";
  
  static const String _email = "yashmakwana2275@gmail.com";
  static const String _githubUrl = "https://github.com/yashmakwana03";
  static const String _linkedinUrl = "https://www.linkedin.com/in/yashmakwana03/";
  static const String _instagramUrl = "https://instagram.com/yashmakwana03";

  // --- Launch URL Helper ---
  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $urlString';
      }
    } catch (e) {
      debugPrint("Error launching URL: $e");
    }
  }

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: _email,
      query: 'subject=Hello from Attendance App&body=Hi Yash,', 
    );
    await launchUrl(emailLaunchUri);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("About Developer"),
        elevation: 0,
        backgroundColor: primaryColor,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- Top Header Section ---
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Red Background
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                ),
                // Profile Picture
                Positioned(
                  top: 60, 
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey,
                      backgroundImage: AssetImage('assets/profile.jpeg'), 
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 70), // Spacer for the overlapping profile pic

            // --- Info Section ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    _name,
                    style: const TextStyle(
                      fontSize: 26, 
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16, 
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Bio Card
                  Card(
                    elevation: 2,
                    color: Colors.grey[50],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _bio,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- Tech Stack ---
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Tech Stack",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _TechChip(label: "Flutter"),
                      _TechChip(label: "Dart"),
                      _TechChip(label: "C#"),
                      _TechChip(label: "Python"),
                      _TechChip(label: "MySQL"),
                      _TechChip(label: "Git"),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // --- Connect Buttons ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _SocialButton(
                        icon: FontAwesomeIcons.github,
                        color: Colors.black,
                        onTap: () => _launchUrl(_githubUrl),
                      ),
                      _SocialButton(
                        icon: FontAwesomeIcons.linkedin,
                        color: const Color(0xFF0077B5),
                        onTap: () => _launchUrl(_linkedinUrl),
                      ),
                      _SocialButton(
                        icon: FontAwesomeIcons.instagram,
                        color: const Color(0xFFE4405F),
                        onTap: () => _launchUrl(_instagramUrl),
                      ),
                      _SocialButton(
                        icon: Icons.email,
                        color: const Color(0xFFDB4437),
                        onTap: _launchEmail,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Footer / University Name
                  Opacity(
                    opacity: 0.5,
                    child: Column(
                      children: const [
                        Text("RK University", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("Computer Engineering (2023-2027)"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Helper Widgets ---

class _TechChip extends StatelessWidget {
  final String label;
  const _TechChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: Colors.black87, // Black chips
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: FaIcon(icon, color: color, size: 28),
      ),
    );
  }
}
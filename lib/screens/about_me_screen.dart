import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutMeScreen extends StatelessWidget {
  const AboutMeScreen({super.key});

  // --- Developer Info ---
  static const String _devName = "Yash Makwana";
  static const String _devTitle = "Flutter Developer | MERN Stack Enthusiast";
  static const String _devBio = 
      "Computer Science student at RK University. I build tools that solve real-world problems. "
      "Currently mastering the MERN Stack to become a full-stack expert.";

  // --- Project Info ---
  static const String _appName = "Attendance Manager";
  static const String _appDesc = 
      "A smart mobile solution designed to eliminate paper-based attendance. "
      "It allows faculty to track daily attendance, manage student records, and generate instant reports for analysis.";

  // --- Links ---
  static const String _email = "yashmakwana2275@gmail.com";
  static const String _githubUrl = "https://github.com/yashmakwana03";
  static const String _linkedinUrl = "https://www.linkedin.com/in/yashmakwana03/";
  static const String _instagramUrl = "https://instagram.com/yashmakwana03";

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $urlString';
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: _email,
      query: 'subject=Inquiry regarding Attendance App', 
    );
    await launchUrl(emailLaunchUri);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Light grey background
      appBar: AppBar(
        title: const Text("About & Credits"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER (Profile) ---
            _buildHeader(context, primaryColor),
            
            const SizedBox(height: 60),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- DEVELOPER SECTION ---
                  Center(
                    child: Column(
                      children: [
                        Text(_devName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        Text(_devTitle, style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildBioCard(),

                  const SizedBox(height: 30),
                  const Text("The Project", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 10),

                  // --- PROJECT DETAILS CARD ---
                  _buildProjectCard(primaryColor),

                  const SizedBox(height: 20),
                  const Text("Under the Hood", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 10),

                  // --- TECHNICAL DETAILS (How we did it) ---
                  _buildTechnicalCard(),

                  const SizedBox(height: 30),
                  
                  // --- TECH STACK CHIPS ---
                  const Text("Tech Stack", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: const [
                      _TechChip(label: "Flutter & Dart"),
                      _TechChip(label: "SQLite (Local DB)"),
                      _TechChip(label: "React.js"),
                      _TechChip(label: "Node.js"),
                      _TechChip(label: "MongoDB"),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // --- SOCIAL LINKS ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _SocialButton(icon: FontAwesomeIcons.github, color: Colors.black, onTap: () => _launchUrl(_githubUrl)),
                      _SocialButton(icon: FontAwesomeIcons.linkedin, color: const Color(0xFF0077B5), onTap: () => _launchUrl(_linkedinUrl)),
                      _SocialButton(icon: FontAwesomeIcons.instagram, color: const Color(0xFFE4405F), onTap: () => _launchUrl(_instagramUrl)),
                      _SocialButton(icon: Icons.email, color: const Color(0xFFDB4437), onTap: _launchEmail),
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                  Center(
                    child: Opacity(
                      opacity: 0.5,
                      child: Column(
                        children: const [
                          Text("Designed with ❤️ at", style: TextStyle(fontSize: 12)),
                          Text("RK University (Computer Dept)", style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
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

  // --- WIDGET BUILDERS ---

  Widget _buildHeader(BuildContext context, Color primaryColor) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          height: 100,
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
        ),
        Positioned(
          top: 40,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: const CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey,
              backgroundImage: AssetImage('assets/profile.jpeg'), // Ensure image exists
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBioCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          _devBio,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _buildProjectCard(Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // APP LOGO PLACEHOLDER
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.school, color: color, size: 30),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_appName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const Text("v1.0.0 (Stable)", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_appDesc, style: TextStyle(color: Colors.grey[700], height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: Column(
        children: [
          _buildTechTile(Icons.storage, "SQLite Database", "Stores students, departments, and logs locally on the device for offline access."),
          const Divider(height: 1),
          _buildTechTile(Icons.code, "Flutter Framework", "Built using a modular UI architecture for smooth performance on Android & iOS."),
          const Divider(height: 1),
          _buildTechTile(Icons.share, "Smart Export", "Generates HTML/Text reports and shares directly via WhatsApp or Email."),
        ],
      ),
    );
  }

  Widget _buildTechTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[700]),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
    );
  }
}

// --- Small Components ---

class _TechChip extends StatelessWidget {
  final String label;
  const _TechChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      backgroundColor: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SocialButton({required this.icon, required this.color, required this.onTap});

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
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
          border: Border.all(color: color.withOpacity(0.1), width: 1),
        ),
        child: FaIcon(icon, color: color, size: 24),
      ),
    );
  }
}
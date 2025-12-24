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
      "Track daily attendance, manage records, and generate instant analytics.";
  
  
  static const String _projectRepoUrl = "https://github.com/yashmakwana03/absent_message/";

  static const String _mobileNumber = "+918401811288"; 
  
  static const String _email = "yashmakwana2275@gmail.com";
  static const String _githubUrl = "https://github.com/yashmakwana03";
  static const String _linkedinUrl = "https://www.linkedin.com/in/yashmakwana03/";
  static const String _instagramUrl = "https://instagram.com/yashmakwana03";

  // --- Launchers ---
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
      query: 'subject=Attendance App Feedback&body=Hello Yash,', 
    );
    try {
      await launchUrl(emailLaunchUri);
    } catch (e) {
      debugPrint("Error launching email");
    }
  }

  Future<void> _launchPhone() async {
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: _mobileNumber,
    );
    try {
      await launchUrl(phoneUri);
    } catch (e) {
      debugPrint("Error launching phone");
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final gradientColors = [primaryColor, primaryColor.withValues(alpha: 0.7)];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.zero, 
        child: Column(
          children: [
            // --- HEADER ---
            _buildHeader(context, gradientColors),
            
            const SizedBox(height: 60), 

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // --- IDENTITY ---
                  Text(_devName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(_devTitle, style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                  
                  const SizedBox(height: 24),
                  _buildBioCard(),

                  const SizedBox(height: 30),
                  
                  // --- PROJECT SECTION ---
                  _buildSectionTitle("The Project"),
                  _buildProjectCard(primaryColor),

                  const SizedBox(height: 20),
                  _buildSectionTitle("Under the Hood"),
                  _buildTechnicalCard(),

                  const SizedBox(height: 30),
                  
                  // --- SKILLS SECTION (Kept MERN Stack) ---
                  _buildSectionTitle("Tech Stack & Skills"),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: const [
                      _TechChip(label: "Flutter", color: Colors.blue),
                      _TechChip(label: "Dart", color: Colors.blue),
                      _TechChip(label: "SQLite", color: Colors.indigo),
                      _TechChip(label: "Share Plus", color: Colors.teal),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _TechChip(label: "MERN Stack", color: Colors.grey.shade800),
                      _TechChip(label: "MongoDB", color: Colors.grey.shade800),
                      _TechChip(label: "Express.js", color: Colors.grey.shade800),
                      _TechChip(label: "React.js", color: Colors.grey.shade800),
                      _TechChip(label: "Node.js", color: Colors.grey.shade800),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // --- SOCIAL LINKS ---
                  const Text("Contact Me", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SocialButton(icon: FontAwesomeIcons.github, color: Colors.black, onTap: () => _launchUrl(_githubUrl)),
                      const SizedBox(width: 16),
                      _SocialButton(icon: FontAwesomeIcons.linkedin, color: const Color(0xFF0077B5), onTap: () => _launchUrl(_linkedinUrl)),
                      const SizedBox(width: 16),
                      _SocialButton(icon: FontAwesomeIcons.instagram, color: const Color(0xFFE4405F), onTap: () => _launchUrl(_instagramUrl)),
                      const SizedBox(width: 16),
                      // ✅ Phone Button
                      _SocialButton(icon: Icons.call, color: Colors.green, onTap: _launchPhone),
                      const SizedBox(width: 16),
                      _SocialButton(icon: Icons.email, color: const Color(0xFFDB4437), onTap: _launchEmail),
                    ],
                  ),
                  
                  const SizedBox(height: 50),
                  
                  // --- FOOTER ---
                  Opacity(
                    opacity: 0.6,
                    child: Column(
                      children: const [
                        Text("Designed by Yash", style: TextStyle(fontSize: 13)),
                        SizedBox(height: 4),
                        Text("RK University (Computer Dept)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title, 
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<Color> gradientColors) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        ClipPath(
          clipper: _HeaderClipper(),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -50,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 5),
              // ✅ Fixed Deprecation
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: const CircleAvatar(
              radius: 65,
              backgroundColor: Colors.white,
              // Ensure this image exists in your assets folder!
              backgroundImage: AssetImage('assets/profile.jpeg'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBioCard() {
    return Text(
      _devBio,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 15, height: 1.6, color: Colors.grey[800]),
    );
  }

  Widget _buildProjectCard(Color color) {
    return Card(
      elevation: 4,
      // ✅ Fixed Deprecation
      shadowColor: color.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              // ✅ Fixed Deprecation
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.school_rounded, color: color, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_appName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                            child: Text("v3.0.0 Stable", style: TextStyle(fontSize: 10, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(_appDesc, style: TextStyle(color: Colors.grey[700], height: 1.5)),
                const SizedBox(height: 16),
                // ✅ ADDED: View Source Code Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _launchUrl(_projectRepoUrl),
                    icon: const Icon(FontAwesomeIcons.github, size: 16),
                    label: const Text("View Source Code"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Column(
        children: [
          _buildTechTile(Icons.storage_rounded, "SQLite Database", "Offline-first architecture. Data stays local."),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildTechTile(Icons.flutter_dash_rounded, "Flutter UI", "Built with a component-based architecture."),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildTechTile(Icons.share_rounded, "Smart Export", "Generates formatted WhatsApp & HTML reports."),
        ],
      ),
    );
  }

  Widget _buildTechTile(IconData icon, String title, String subtitle) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: Colors.grey[800], size: 24),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, height: 1.4)),
    );
  }
}

// --- Custom Clipper ---
class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(size.width / 2, size.height, size.width, size.height - 50);
    path.lineTo(size.width, 0);
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// --- Components ---

class _TechChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TechChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        // ✅ Fixed Deprecation
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label, 
        // ✅ Fixed Deprecation (removed redundant withOpacity)
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
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
          color: Colors.white,
          shape: BoxShape.circle,
          // ✅ Fixed Deprecation
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: FaIcon(icon, color: color, size: 22),
      ),
    );
  }
}
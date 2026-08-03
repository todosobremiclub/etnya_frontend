import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SocialFooter extends StatelessWidget {
  const SocialFooter({super.key});

  Future<void> _openWhatsApp() async {
    const phone = '5491151192428';
    final uri = Uri.parse(
      'https://wa.me/$phone?text=Hola%20Etnya%20Pilates',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openInstagram() async {
    final uri = Uri.parse(
        'https://www.instagram.com/etnyapilates?utm_source=ig_web_button_share_sheet&igsh=ZDNlZDc0MzIxNw==');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openYoutube() async {
    final uri = Uri.parse('https://www.youtube.com/@etnyapilates6759');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18, top: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _icon(
            icon: FontAwesomeIcons.whatsapp,
            border: const Color(0xFF25D366),
            color: const Color(0xFF25D366),
            onTap: _openWhatsApp,
          ),
          const SizedBox(width: 18),
          _icon(
            icon: FontAwesomeIcons.instagram,
            border: Colors.pinkAccent,
            color: Colors.pinkAccent,
            onTap: _openInstagram,
          ),
          const SizedBox(width: 18),
          _icon(
            icon: FontAwesomeIcons.youtube,
            border: Colors.redAccent,
            color: Colors.redAccent,
            onTap: _openYoutube,
          ),
        ],
      ),
    );
  }

Widget _icon({
    required FaIconData icon,
    required VoidCallback onTap,
    required Color border,
    required Color color,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: border, width: 2),
          boxShadow: [
            BoxShadow(
              color: border.withOpacity(0.18),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: FaIcon(
            icon,
            color: color,
            size: 22,
          ),
        ),
      ),
    );
  }
}
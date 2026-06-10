import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/logic/auth_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final isLoggedIn = authState.maybeWhen(
      data: (user) => user != null,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Impressum'),
            subtitle: const Text('Rechtliche Informationen'),
            onTap: () => _showImpressum(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Datenschutz'),
            subtitle: const Text('Datenschutzerklärung ansehen'),
            onTap: () => _showDataPrivacy(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.security_outlined),
            title: const Text('Sicherheit'),
            subtitle: const Text('Sicherheitseinstellungen'),
            onTap: () => _showSecurity(context),
          ),
          if (isLoggedIn) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Abmelden'),
              subtitle: const Text('Von diesem Gerät abmelden'),
              onTap: () => _showLogoutDialog(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Abmelden'),
        content: const Text('Möchten Sie sich wirklich abmelden?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Abmelden'),
          ),
        ],
      ),
    );
  }

  void _showImpressum(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Impressum'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Angaben gemäß § 5 TMG',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('Musterfirma GmbH'),
              Text('Musterstraße 123'),
              Text('12345 Musterstadt'),
              SizedBox(height: 16),
              Text(
                'Kontakt',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Telefon: +49 (0) 123 456789'),
              Text('E-Mail: info@example.com'),
              SizedBox(height: 16),
              Text(
                'Vertretungsberechtigte Geschäftsführer',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Max Mustermann'),
              SizedBox(height: 16),
              Text(
                'Registereintrag',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Handelsregister: HRB 12345'),
              Text('Registergericht: Amtsgericht Musterstadt'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  void _showDataPrivacy(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Datenschutzerklärung'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '1. Datenschutz auf einen Blick',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Diese App erhebt und verarbeitet personenbezogene Daten im Rahmen der DSGVO.',
              ),
              SizedBox(height: 16),
              Text(
                '2. Welche Daten sammeln wir?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• E-Mail-Adresse (für die Authentifizierung)'),
              Text('• Benutzername'),
              Text('• Standortdaten (für Ortungsvorschläge)'),
              Text('• Favoriten und Präferenzen'),
              SizedBox(height: 16),
              Text(
                '3. Wie verwenden wir Ihre Daten?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Ihre Daten werden ausschließlich zur Bereitstellung der App-Funktionen verwendet und nicht an Dritte weitergegeben.',
              ),
              SizedBox(height: 16),
              Text(
                '4. Ihre Rechte',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Sie haben das Recht auf:'),
              Text('• Auskunft über Ihre gespeicherten Daten'),
              Text('• Berichtigung unrichtiger Daten'),
              Text('• Löschung Ihrer Daten'),
              Text('• Widerspruch gegen die Verarbeitung'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  void _showSecurity(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sicherheit'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sicherheitsmaßnahmen',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('✓ Ende-zu-Ende-Verschlüsselung'),
              SizedBox(height: 8),
              Text('✓ Sichere Firebase-Authentifizierung'),
              SizedBox(height: 8),
              Text('✓ Verschlüsselte Datenübertragung (HTTPS)'),
              SizedBox(height: 8),
              Text('✓ Regelmäßige Sicherheitsupdates'),
              SizedBox(height: 16),
              Text(
                'Empfehlungen',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Verwenden Sie ein starkes Passwort'),
              Text('• Melden Sie sich auf fremden Geräten ab'),
              Text('• Halten Sie die App aktuell'),
              SizedBox(height: 16),
              Text(
                'Hinweis: Passwort ändern und Zwei-Faktor-Authentifizierung werden in einer zukünftigen Version verfügbar sein.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }
}

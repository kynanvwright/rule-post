import 'package:flutter/material.dart';

class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        'question': 'How do I reset my password?',
        'answer': 'Go to Settings > Account > Reset Password and follow the prompts.'
      },
      {
        'question': 'How can I contact support?',
        'answer': 'You can contact support via the Help section in the app or email support@example.com.'
      },
      {
        'question': 'Where can I find my enquiries?',
        'answer': 'Navigate to the Home screen and tap on "My Enquiries" to view them.'
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & FAQ'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Frequently Asked Questions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...faqs.map((faq) => Card(
                child: ExpansionTile(
                  title: Text(faq['question']!),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(faq['answer']!),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('Still need help?'),
            subtitle: const Text('Contact our support team'),
            onTap: () {
              // TODO: Add your support contact logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Contact support tapped')),
              );
            },
          ),
        ],
      ),
    );
  }
}

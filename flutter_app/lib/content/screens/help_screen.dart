import "package:flutter/material.dart";
import '../../core/widgets/back_button.dart';

class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      // 🧭 GENERAL
      {
        "header": "🧭 General",
        "items": [
          {
            "question": "What is a Rule Enquiry?",
            "answer":
                "A request for interpretation or amendment of the America's Cup Class Rules and Specifications."
          },
          {
            "question": "What are enquiries, responses, comments and posts?",
            "answer":
                "Enquiry refers to both the initial question and the entire discussion thread. Responses are formal replies from teams to the initial enquiry and the Rules Committee's proposals. Comments allow teams to directly engage directly to each other's responses. Post is a general term for any of these submission types."
          },
          {
            "question": "How can I keep up to date with new posts?",
            "answer":
                "Click the 'Account' button in the top right, and select 'Profile'. Enable email notifications to receive updates when new posts are made."
          },
          {
            "question": "How do I get an account?",
            "answer":
                "Accounts are only for team members of America's Cup Competitors. Each Competitor has a nominated 'team admin' who can add/delete users."
          },


        ]
      },

      // 📝 ENQUIRIES
      {
        "header": "✏️ How to Submit",
        "items": [
          {
            "question": "How do I submit a new enquiry?",
            "answer":
                "Log in, and click the '+ New' button next to 'Rule Enquiries' at the top left of the screen."
          },
          {
            "question": "How do I submit a new response?",
            "answer":
                "Log in, and navigate to the parent enquiry using the navigation pane on the left. Click the '+ New' button in the 'Responses' section."
          },
          {
            "question": "How do I submit a new comment?",
            "answer":
                "Log in, and navigate to the parent response using the navigation pane on the left. Click the '+ New' button in the 'Comments' section."
          },
        ]  
      },
         
      {
        "header": "📋 Posts",
        "items": [
          {
            "question": "Are posts anonymous?",
            "answer":
                "Yes. However, there is Competitor colour-coding unique to each enquiry, to make post threads more readable."
          },
          {
            "question": "Why didn't my post publish after I submitted it?",
            "answer":
                "Posts are delayed to specific times, detailed in the AC Technical Regulations. The draft should be viewable if you are logged in."
          },
          {
            "question": "Can I edit or delete a post after submitting it?",
            "answer":
                "Not yet, but this is a planned future feature. Contact the Rules Committee if you need to issue a correction or withdrawal."
          },
          {
            "question": "What types of files can I upload?",
            "answer":
                "PDF and Word (.docx) files are supported. Files are automatically renamed for storage to include the enquiry number."
          },
          {
            "question": "Why can't I submit?",
            "answer":
                "The enquiry is probably at the incorrect stage for your submission type. If you don't believe this is correct, contact the Rules Committee."
          },
        ]
      },

      // ⏰ TIMING & STAGES
      {
        "header": "⏰ Timing & Stages",
        "items": [
          {
            "question": "How do I find a submission deadline?",
            "answer":
                "Enquiries have an 'Enquiry Stage' section, which details the current enquiry stage, when it ends, and what the next one will be."
          },
          {
            "question": "How are deadlines calculated?",
            "answer":
                "They are based on the AC Technical Regulations. The general flow is as follows: Enquiry is submitted, teams respond, teams comment on each other's responses, Rules Committee responds. Those last three steps repeat until the enquiry is closed."
          },
          {
            "question": "What if I miss a deadline?",
            "answer":
                "There is currently no mechanism for allowing late submissions, but contact the Rules Committee if you believe this website facilitated the submission error."
          },
        ]
      },

      // ⚙️ TECHNICAL / TROUBLESHOOTING
      {
        "header": "⚙️ Technical / Troubleshooting",
        "items": [
          {
            "question": "I can’t upload a file — what should I check?",
            "answer":
                "Confirm it’s under the size limit (e.g. 10 MB) and in an allowed format (.pdf or .docx)."
          },
          {
            "question": "Why is the “+ New” button greyed out?",
            "answer":
                "The submission window may have closed, or your team has already submitted for this round."
          },
          {
            "question": "Why do I get “permission denied”?",
            "answer":
                "Your account might not have the right role (Team vs Rules Committee) or the enquiry is locked."
          },
        ]
      },
    ];

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(12),
          child: BackButtonCompact(),
        ),
        title: const Text("Help & FAQ"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Frequently Asked Questions",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          for (final section in faqs) ...[
            Text(
              section["header"] as String,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...(section["items"] as List<Map<String, String>>).map(
              (faq) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ExpansionTile(
                  title: Text(faq["question"]!),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(faq["answer"]!),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text("Still need help?"),
            subtitle: const Text("Contact our support team"),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Contact support tapped")),
              );
            },
          ),
        ],
      ),
    );
  }
}

Widget buildAnswerText(BuildContext context, String text) {
  final regex = RegExp(r"\*\*(.+?)\*\*");
  final spans = <TextSpan>[];
  int lastIndex = 0;

  for (final match in regex.allMatches(text)) {
    if (match.start > lastIndex) {
      spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
    }
    spans.add(TextSpan(
      text: match.group(1),
      style: const TextStyle(fontWeight: FontWeight.bold),
    ));
    lastIndex = match.end;
  }

  if (lastIndex < text.length) {
    spans.add(TextSpan(text: text.substring(lastIndex)));
  }

  return RichText(
    text: TextSpan(
      style: DefaultTextStyle.of(context).style,
      children: spans,
    ),
  );
}

from fpdf import FPDF

class PDF(FPDF):
    def header(self):
        self.set_fill_color(20, 40, 80)
        self.rect(0, 0, 210, 15, 'F')
        self.set_font('Helvetica', 'B', 10)
        self.set_text_color(200, 220, 255)
        self.set_y(4)
        self.cell(0, 7, 'AegisMind -- Project Overview', align='C')
        self.set_text_color(0, 0, 0)
        self.ln(13)

    def footer(self):
        self.set_y(-12)
        self.set_font('Helvetica', 'I', 8)
        self.set_text_color(150, 150, 150)
        self.cell(0, 8, f'Page {self.page_no()}', align='C')
        self.set_text_color(0, 0, 0)

    def chapter_title(self, text):
        self.ln(6)
        self.set_fill_color(20, 40, 80)
        self.set_text_color(255, 255, 255)
        self.set_font('Helvetica', 'B', 13)
        self.set_x(self.l_margin)
        self.multi_cell(0, 9, '  ' + text, fill=True, new_x='LMARGIN', new_y='NEXT')
        self.set_text_color(0, 0, 0)
        self.ln(2)

    def paragraph(self, text):
        self.set_font('Helvetica', '', 10)
        self.set_text_color(30, 30, 30)
        self.set_x(self.l_margin)
        self.multi_cell(0, 6, text, new_x='LMARGIN', new_y='NEXT')
        self.set_text_color(0, 0, 0)
        self.ln(3)

    def highlight_box(self, text):
        self.set_fill_color(235, 242, 255)
        self.set_draw_color(100, 140, 220)
        self.set_font('Helvetica', 'I', 10)
        self.set_text_color(30, 50, 100)
        self.set_x(self.l_margin)
        self.multi_cell(0, 6, '  ' + text + '  ', fill=True, border=1,
                        new_x='LMARGIN', new_y='NEXT')
        self.set_draw_color(0, 0, 0)
        self.set_text_color(0, 0, 0)
        self.ln(3)


pdf = PDF()
pdf.set_auto_page_break(auto=True, margin=16)
pdf.set_margins(18, 18, 18)
pdf.add_page()

# ── COVER ──────────────────────────────────────────────────────────────────
pdf.ln(12)
pdf.set_fill_color(20, 40, 80)
pdf.rect(8, pdf.get_y(), 194, 58, 'F')

pdf.set_font('Helvetica', 'B', 30)
pdf.set_text_color(200, 225, 255)
pdf.set_y(pdf.get_y() + 10)
pdf.cell(0, 14, 'AegisMind', align='C', new_x='LMARGIN', new_y='NEXT')

pdf.set_font('Helvetica', '', 13)
pdf.set_text_color(160, 200, 255)
pdf.cell(0, 8, 'An AI-Powered Safety System for Children', align='C', new_x='LMARGIN', new_y='NEXT')

pdf.set_font('Helvetica', 'I', 10)
pdf.set_text_color(130, 170, 220)
pdf.cell(0, 7, 'Project Overview Document', align='C', new_x='LMARGIN', new_y='NEXT')
pdf.set_text_color(0, 0, 0)
pdf.ln(28)

pdf.set_font('Helvetica', '', 11)
pdf.set_text_color(50, 50, 50)
pdf.set_x(pdf.l_margin)
pdf.multi_cell(0, 7,
    'This document explains the AegisMind project in plain language -- what it is, '
    'what problem it solves, how it works, and what each part of the system does.',
    new_x='LMARGIN', new_y='NEXT')
pdf.set_text_color(0, 0, 0)

# ── 1. WHAT IS AEGISMIND ───────────────────────────────────────────────────
pdf.chapter_title('1.  What Is AegisMind?')

pdf.paragraph(
    'AegisMind is a safety platform designed to protect children when they interact with '
    'artificial intelligence. As AI chatbots become more common, children are increasingly '
    'using them for homework help, curiosity, and entertainment. However, these tools can '
    'sometimes be tricked into providing harmful, dangerous, or inappropriate responses. '
    'AegisMind sits between the child and the AI to make sure that does not happen.'
)

pdf.paragraph(
    'The system works as a mobile application built for Android and iOS. A child opens the '
    'app, types a question or message, and AegisMind evaluates it before deciding what to do. '
    'If the message is safe, the system answers it and double-checks its own answer for accuracy. '
    'If the message looks dangerous, it is blocked immediately. If the system is unsure, it holds '
    'the message and asks a parent to review it.'
)

pdf.highlight_box(
    'In short: AegisMind is a smart filter and fact-checker for AI conversations, '
    'with parents always in control of the final decision.'
)

# ── 2. THE PROBLEM BEING SOLVED ────────────────────────────────────────────
pdf.chapter_title('2.  The Problem Being Solved')

pdf.paragraph(
    'Children who use AI chatbots face two distinct risks. The first is harmful input -- '
    'a child (or someone else) might deliberately or accidentally ask the AI questions about '
    'violence, self-harm, drugs, or ways to bypass parental rules. Without a safety layer, '
    'the AI may answer these questions openly.'
)

pdf.paragraph(
    'The second risk is misinformation. AI models sometimes produce responses that sound '
    'confident and detailed but are factually wrong -- a phenomenon known as "hallucination." '
    'For a child doing homework or trying to learn something new, receiving incorrect information '
    'presented as fact can be genuinely harmful to their education and understanding.'
)

pdf.paragraph(
    'AegisMind addresses both problems at once: it blocks harmful requests before they '
    'reach any AI, and it verifies the accuracy of every allowed response by checking it '
    'against real sources on the internet.'
)

# ── 3. HOW THE SYSTEM WORKS ────────────────────────────────────────────────
pdf.chapter_title('3.  How the System Works -- A Step-by-Step Overview')

pdf.paragraph(
    'When a child sends a message, AegisMind does not immediately pass it to an AI. '
    'Instead, it runs the message through a series of checks, each building on the last. '
    'Think of it as a series of security doors, where the message must pass through each '
    'one before a response is generated.'
)

pdf.paragraph(
    'Step 1 -- The Safety Gate. The first thing AegisMind does is measure how dangerous '
    'the message might be. It uses two independent tools for this. The first is a machine '
    'learning model that was trained specifically to recognise unsafe prompts -- it reads '
    'the message and produces a risk score between zero (completely safe) and one (clearly '
    'dangerous). The second tool compares the message against a library of known harmful '
    'patterns, such as attempts to convince the AI to role-play as a character with no rules, '
    'or requests involving weapons and self-harm. Together, these two scores are combined '
    'into a single final risk level.'
)

pdf.paragraph(
    'If the risk level is high, the message is blocked right away and the child sees a '
    'message explaining that their request cannot be answered. If the risk level is moderate '
    'and the system is uncertain, the message is flagged and placed in a queue for the parent '
    'to review. If the risk level is low, the system proceeds to answer the question.'
)

pdf.paragraph(
    'Step 2 -- Breaking the Question Down. For messages that pass the safety gate, '
    'AegisMind does not simply hand the question to an AI and return whatever it says. '
    'Instead, it first breaks the question into smaller, more specific sub-questions. '
    'For example, a question like "Why is the sky blue and how is it different from sunsets?" '
    'would be split into: what causes the sky to appear blue, what causes the colours at sunset, '
    'and how do the two phenomena differ. This makes it much easier to check the accuracy of '
    'each individual part of the answer.'
)

pdf.paragraph(
    'Step 3 -- Generating a Reasoned Answer. Each sub-question is sent to a locally running '
    'AI model, which generates a detailed explanation. The system uses a model called Phi-3, '
    'which runs entirely on the device\'s own hardware without sending data to the internet. '
    'The responses are collected and stitched together into a complete answer.'
)

pdf.paragraph(
    'Step 4 -- Extracting Facts and Checking Them. From the AI\'s response, AegisMind '
    'automatically pulls out the specific factual claims that were made -- statements like '
    '"The sky appears blue due to Rayleigh scattering" or "Sunsets appear red because of '
    'longer wavelengths." It then searches the internet for each claim using Google, reads '
    'the relevant web pages, and compares what the AI said against what those pages actually '
    'contain. Each claim is rated as supported by evidence, weakly supported, or unsupported. '
    'The overall fact-check score is shown to the child alongside the answer.'
)

pdf.paragraph(
    'Step 5 -- Asking Three AIs and Comparing Their Answers. As a final quality check, '
    'AegisMind sends the original question to three completely separate AI models -- Phi-3, '
    'Llama-3, and Mistral -- and compares their answers. If all three models give similar '
    'responses, the system is confident the answer is reliable and marks it as "Consensus." '
    'If they partially disagree, it flags the response as possibly unreliable. If they '
    'strongly disagree with each other, it alerts the parent that the AI may have produced '
    'a hallucinated or inaccurate response.'
)

pdf.highlight_box(
    'The entire pipeline -- safety gate, decomposition, reasoning, fact-checking, and '
    'consensus -- runs automatically in the background within seconds of the child sending a message.'
)

# ── 4. THE MOBILE APP ──────────────────────────────────────────────────────
pdf.chapter_title('4.  The Mobile Application')

pdf.paragraph(
    'The front end of AegisMind is a mobile app built with Flutter, which means it runs '
    'on both Android and iOS from a single codebase. The app has three different experiences '
    'depending on who is logged in: a child view, a parent view, and an admin view.'
)

pdf.paragraph(
    'The child view is a simple chat interface that looks and feels like any other messaging '
    'app. The child types a question, sends it, and receives a response. Beneath the response, '
    'a small dashboard shows the safety score of their original message, a progress bar for '
    'each stage of the pipeline, and a final verdict on whether the AI\'s answer was verified '
    'or potentially unreliable. If their message was blocked, they see a clear, friendly '
    'explanation rather than a confusing error.'
)

pdf.paragraph(
    'The parent view gives parents a review queue. Any message that the system was unsure '
    'about -- those in the middle range of the safety score -- appears here for the parent to '
    'read. The parent can see the exact message their child sent, the risk score the system '
    'assigned, and the reason it was flagged. They then decide whether to allow it or keep '
    'it blocked. This decision is stored and used to improve the safety system over time.'
)

pdf.paragraph(
    'The admin view is designed for system administrators. It shows flags raised by the '
    'quality monitoring system, such as cases where the AI models repeatedly disagreed with '
    'each other, or where the fact-checking found weak evidence. Administrators can use this '
    'view to understand where the system is performing poorly and take action.'
)

# ── 5. HOW THE SYSTEM LEARNS ──────────────────────────────────────────────
pdf.chapter_title('5.  How the System Learns and Improves Over Time')

pdf.paragraph(
    'One of the most important features of AegisMind is that it does not stay static. '
    'The safety model at the heart of the system -- the one that assigns a risk score to '
    'every message -- can be retrained using the feedback that parents provide.'
)

pdf.paragraph(
    'Every time a parent looks at a flagged message and decides whether it should be allowed '
    'or blocked, that decision is saved. Over time, as hundreds of these decisions accumulate, '
    'the system uses them to fine-tune the safety model. Messages that parents consistently '
    'judge as safe will teach the model to be less restrictive in similar cases. Messages '
    'that parents consistently block will teach it to be more cautious. This process -- '
    'using human feedback to improve a machine learning model -- is called Reinforcement '
    'Learning from Human Feedback, or RLHF.'
)

pdf.paragraph(
    'The retraining process is triggered by an administrator once enough feedback has '
    'been collected. The system automatically prepares the training data, runs the fine-tuning '
    'process, checks whether the new model performs better than the old one, and if it does, '
    'replaces the old model. If the new model is actually worse, the system keeps the previous '
    'version and does not deploy the change. This ensures the safety of the system is never '
    'accidentally reduced.'
)

# ── 6. THE QUALITY MONITORING SYSTEM ─────────────────────────────────────
pdf.chapter_title('6.  Quality Monitoring and Parent Alerts')

pdf.paragraph(
    'AegisMind continuously monitors its own quality. After every completed conversation, '
    'it checks several signals: Did the three AI models agree with each other? Did the '
    'fact-checking find real evidence? Did the user rate the response as helpful or unhelpful?'
)

pdf.paragraph(
    'When a user marks a response as bad, the system analyses what went wrong. It classifies '
    'the problem into one of four categories. If the three AI models strongly disagreed with '
    'each other and the user confirmed the answer was wrong, it is classified as a confirmed '
    'hallucination. If the models all agreed but the answer was still wrong, it suggests a '
    'more subtle failure in the AI\'s knowledge. If the fact-checking found some evidence '
    'but the response was still poor, it indicates the AI\'s knowledge base needs expanding. '
    'Finally, if many hallucinations occur in a short period, the system automatically raises '
    'a high-priority alert indicating that the AI models may be degrading in quality.'
)

pdf.paragraph(
    'Parents are also directly notified when the three AI models cannot agree on an answer '
    'for their child\'s question. This means that even without the child or parent manually '
    'flagging a problem, the system proactively alerts parents when there is reason to doubt '
    'the reliability of a response.'
)

# ── 7. THE TECHNOLOGY STACK ────────────────────────────────────────────────
pdf.chapter_title('7.  The Technology Behind AegisMind')

pdf.paragraph(
    'The backend of AegisMind is written in Python using the Flask web framework. It runs '
    'on a local server and exposes a set of API endpoints that the mobile app communicates '
    'with. All AI inference is performed locally using Ollama, a tool that lets large language '
    'models run on standard hardware without requiring an internet connection for the AI itself. '
    'This is an important privacy feature -- the child\'s messages are never sent to an '
    'external AI company.'
)

pdf.paragraph(
    'The safety models -- the BERT-based prompt guard and the DeBERTa fact-checker -- are '
    'stored locally on the server. The sentence embedding model used for semantic comparisons '
    'also runs locally. Only the internet search step for fact-checking contacts an external '
    'service, which is Google\'s Custom Search API, and only anonymised search queries are sent.'
)

pdf.paragraph(
    'User accounts, parental relationships, and location data are managed through Firebase, '
    'Google\'s cloud platform. Firebase handles secure login and real-time data synchronisation '
    'between the mobile app and the backend. Case data and parent notifications are stored '
    'locally in a lightweight SQLite database on the server, keeping sensitive conversation '
    'history off third-party infrastructure.'
)

pdf.paragraph(
    'The mobile app is built with Flutter, which allows a single codebase to produce native '
    'applications for both Android and iOS. State management is handled with Riverpod, and '
    'the app is designed to work even with a poor internet connection thanks to Firebase\'s '
    'offline persistence feature.'
)

# ── 8. SUMMARY ────────────────────────────────────────────────────────────
pdf.chapter_title('8.  Summary')

pdf.paragraph(
    'AegisMind is a complete, end-to-end safety system for children using AI. It combines '
    'machine learning, natural language processing, web-based fact-checking, and human '
    'oversight into a single seamless experience. Children get helpful, verified answers. '
    'Parents stay informed and in control. Administrators can monitor system quality and '
    'trigger improvements. And the whole system quietly learns and gets better with every '
    'parent decision.'
)

pdf.highlight_box(
    'AegisMind does not simply block harmful content -- it builds trust in AI responses '
    'by verifying them, flagging uncertainty, and keeping humans in the loop at every stage.'
)

# ── SAVE ──────────────────────────────────────────────────────────────────
out = r'c:\Users\DELL\Desktop\AegisMind_Overview.pdf'
pdf.output(out)
print('PDF saved:', out)

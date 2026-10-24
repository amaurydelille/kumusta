import { LegalPage } from "../components/site-shell";

export const metadata = { title: "Terms of Use | VietBuddy" };

export default function TermsPage() {
  return (
    <LegalPage eyebrow="LEGAL" title="Terms of Use" updated="31 July 2026">
      <p className="legal-lead">These Terms govern your use of VietBuddy. By creating an account or using the app, you agree to them.</p>
      <section><h2>The service</h2><p>VietBuddy provides personalized Vietnamese-learning content, audio practice, progress tools, and related features. Lessons are educational aids, not a substitute for professional translation, legal advice, or immigration advice.</p></section>
      <section><h2>Your account</h2><p>You are responsible for keeping your account credentials secure and for activity carried out through your account. Please provide accurate information and let us know if you suspect unauthorized access.</p></section>
      <section><h2>Subscriptions and payments</h2><p>Some features may require a paid subscription. Prices, trial terms, and renewal details are shown before purchase. Apple processes App Store purchases and manages refunds according to its policies. You can manage or cancel an App Store subscription in your Apple ID subscription settings.</p></section>
      <section><h2>Acceptable use</h2><p>Do not misuse VietBuddy, interfere with the service, attempt to bypass access controls or payment systems, scrape content, reverse engineer the app where prohibited, or use the service to create unlawful, harmful, or abusive content.</p></section>
      <section><h2>Our content and your feedback</h2><p>VietBuddy and its content are protected by intellectual-property laws. We grant you a personal, limited, non-transferable right to use the service while you comply with these Terms. If you send feedback, you allow us to use it to improve VietBuddy without compensation to you.</p></section>
      <section><h2>Availability and disclaimers</h2><p>We work to keep VietBuddy reliable, but it is provided on an “as is” and “as available” basis to the extent allowed by law. AI-generated material can occasionally be incomplete or inaccurate; use your judgment, especially in high-stakes situations.</p></section>
      <section><h2>Limitation of liability</h2><p>To the fullest extent permitted by law, VietBuddy will not be liable for indirect, incidental, special, consequential, or punitive damages, or loss of data, profits, or goodwill arising from your use of the service.</p></section>
      <section><h2>Changes and contact</h2><p>We may change these Terms as the service evolves. Continued use after an update means you accept the updated Terms where permitted by law. Questions can be sent to <a href="mailto:contact@vietbuddy.app">contact@vietbuddy.app</a>.</p></section>
    </LegalPage>
  );
}

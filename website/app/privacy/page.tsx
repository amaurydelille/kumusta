import { LegalPage } from "../components/site-shell";

export const metadata = { title: "Privacy Policy | VietBuddy" };

export default function PrivacyPage() {
  return (
    <LegalPage eyebrow="LEGAL" title="Privacy Policy" updated="31 July 2026">
      <p className="legal-lead">VietBuddy is designed to help you speak Vietnamese with confidence. We collect only what is needed to operate your learning account, personalize lessons, and keep the service safe.</p>
      <section><h2>What we collect</h2><p>Depending on how you use VietBuddy, we may process your name, email address, learning preferences, accent and level choices, lesson activity, saved vocabulary, subscription status, and support messages.</p><p>When you complete a speaking exercise, a short audio recording may be securely sent to our speech-processing provider solely to create a transcription and feedback. The recording is deleted from the device after upload and is not used to train our models.</p></section>
      <section><h2>Why we use it</h2><p>We use this information to provide your account, generate and adapt lessons, remember your progress, deliver audio, process subscriptions, prevent abuse, and respond to support requests. We do not sell personal information or use it for targeted advertising.</p></section>
      <section><h2>Service providers</h2><p>We use carefully selected providers to run VietBuddy, including Supabase for authenticated data storage, ElevenLabs for speech generation and transcription, Mistral AI for lesson generation and feedback, and RevenueCat for subscription management. They may process information only to provide their services to us and subject to their applicable contractual safeguards.</p></section>
      <section><h2>Retention and security</h2><p>We retain account and learning data while your account is active, unless a longer period is necessary for legal, security, or billing obligations. We use access controls, encryption in transit, row-level data controls, and least-privilege service access. No system is perfectly secure, so please contact us promptly if you believe your account has been compromised.</p></section>
      <section><h2>Your choices</h2><p>You can update learning preferences in the app, request access or correction where applicable, and delete your account through our <a href="/delete-account">account deletion page</a>. Deleting your account removes your profile and associated learning data, subject to limited legal and financial record-keeping requirements.</p></section>
      <section><h2>Children</h2><p>VietBuddy is not directed to children under 13, and we do not knowingly collect personal information from them. If you believe a child has provided us information, contact us and we will take appropriate action.</p></section>
      <section><h2>Changes and contact</h2><p>We may update this policy as VietBuddy evolves. Material changes will be reflected by a new date here or communicated in the app when appropriate. For privacy questions or requests, contact <a href="mailto:contact@vietbuddy.app">contact@vietbuddy.app</a>.</p></section>
    </LegalPage>
  );
}

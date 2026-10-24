import { LegalPage } from "../components/site-shell";

export const metadata = { title: "Support | VietBuddy" };

export default function SupportPage() {
  return (
    <LegalPage eyebrow="SUPPORT" title="A human will help." updated="31 July 2026">
      <p className="legal-lead">Need a hand with your account, a lesson, speech feedback, or a subscription? Write to us and include as much context as you can.</p>
      <section><h2>Contact support</h2><p><a className="legal-contact" href="mailto:contact@vietbuddy.app">contact@vietbuddy.app</a></p><p>For faster help, include the email on your account, your iPhone model and iOS version, and a screenshot or short description of what happened. Never send passwords, payment card details, or one-time codes.</p></section>
      <section><h2>Subscription help</h2><p>Apple manages all App Store billing, cancellations, and refunds. You can manage a subscription from your Apple ID settings. If access is not updating after a purchase, email us and we will help investigate.</p></section>
      <section><h2>Data and privacy</h2><p>For data requests, see our <a href="/privacy">Privacy Policy</a> or use the <a href="/delete-account">account deletion page</a>.</p></section>
    </LegalPage>
  );
}

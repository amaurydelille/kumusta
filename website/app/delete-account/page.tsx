import { LegalPage } from "../components/site-shell";

export const metadata = { title: "Delete your account | VietBuddy" };

export default function DeleteAccountPage() {
  return (
    <LegalPage eyebrow="ACCOUNT" title="Delete your VietBuddy account" updated="31 July 2026">
      <p className="legal-lead">You can delete your VietBuddy account directly from the Profile tab in the app. This permanently removes your account and associated learning data.</p>
      <section><h2>In the app</h2><ol><li>Open <strong>Profile</strong>.</li><li>Choose <strong>Your data &amp; help</strong>.</li><li>Choose <strong>Delete account</strong> and confirm.</li></ol></section>
      <section><h2>If you cannot sign in</h2><p><a href="mailto:contact@vietbuddy.app?subject=VietBuddy%20access%20help">Contact support</a> for help recovering access. Support is not required for account deletion when you can open the app.</p></section>
      <section><h2>What deletion means</h2><p>Deletion removes your profile, learning history, saved words, preferences, and account-linked content from active systems. Some limited records may remain where required for legal, fraud-prevention, or financial accounting reasons. Deleting your account does not automatically cancel an Apple subscription; manage that separately in Apple ID subscription settings.</p></section>
    </LegalPage>
  );
}

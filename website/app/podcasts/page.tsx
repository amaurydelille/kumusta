import { SiteFooter, SiteHeader } from "../components/site-shell";
import { PodcastSearch } from "./podcast-search";

export default function PodcastsPage() {
  return (
    <main className="podcast-page" id="main-content">
      <SiteHeader active="podcast" />
      <PodcastSearch />
      <SiteFooter />
    </main>
  );
}

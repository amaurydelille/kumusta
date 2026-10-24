import { SiteFooter, SiteHeader } from "../components/site-shell";
import { BlogSearch } from "./blog-search";

export default function BlogPage() {
  return (
    <main className="blog-page" id="main-content">
      <SiteHeader active="blog" />
      <BlogSearch />
      <SiteFooter />
    </main>
  );
}

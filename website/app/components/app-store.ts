// Routes App Store clicks through the tracked campaign redirect (see worker/app-store-redirect.ts).
// Placements are prefixed with "site_" to keep them apart from shared campaign links.
export function appStoreHref(placement: string) {
  return `/?from=site_${placement}`;
}

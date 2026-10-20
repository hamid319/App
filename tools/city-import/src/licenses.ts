// Which Commons licences we accept, and their display name.
//
// Accepted: public domain / CC0 and Creative Commons BY and BY-SA, any
// version (2.0, 2.5, 3.0, 4.0, including national ports such as 3.0 DE).
// All of them allow commercial use and resizing with attribution, which the
// app shows next to every photo. Rejected: NC/ND variants, GFDL-only, fair
// use and anything without a clear licence.

export interface License {
  /** Short name shown in the app, e.g. "CC BY-SA 3.0". */
  name: string;
  url?: string;
}

const CC_PATTERN = /^cc[ -]by(?:[ -]sa)?[ -](?:1\.0|2\.0|2\.5|3\.0|4\.0)(?:[ -][a-z]{2})?$/;

export function normalizeLicense(shortName: string | undefined, licenseUrl: string | undefined): License | null {
  const raw = (shortName ?? "").trim();
  const name = raw.toLowerCase().replace(/_/g, " ").replace(/\s+/g, " ");
  if (!name) return null;
  if (/(^|[ -])(nc|nd)([ -]|$)/.test(name)) return null;

  if (name === "cc0" || name === "cc0 1.0") {
    return { name: "CC0", url: "https://creativecommons.org/publicdomain/zero/1.0/" };
  }
  if (name === "public domain" || name === "pd") {
    return { name: "Public domain" };
  }
  if (CC_PATTERN.test(name)) {
    return { name: raw.replace(/_/g, " ").replace(/\s+/g, " ").toUpperCase(), url: safeCcUrl(licenseUrl) };
  }
  return null;
}

function safeCcUrl(value: string | undefined): string | undefined {
  if (!value) return undefined;
  try {
    const url = new URL(value.trim().replace(/^\/\//, "https://"));
    if (url.hostname !== "creativecommons.org") return undefined;
    url.protocol = "https:";
    return url.toString();
  } catch {
    return undefined;
  }
}

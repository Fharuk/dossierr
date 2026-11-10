// Hides credentials in anything printed about a connection string: the
// password, the user's password in a URL written by hand, and Neon keys.

/** `url` with its password replaced; passwords of the form npg_… too. */
export function redact(text) {
  return String(text)
    // postgresql://user:secret@host → postgresql://user:***@host
    .replace(/(postgres(?:ql)?:\/\/[^:/@\s]+:)([^@\s]+)(@)/gi, "$1***$3")
    // pg passwords anywhere (Neon's look like npg_…)
    .replace(/\bnpg_[A-Za-z0-9]{8,}/g, "npg_***")
    .replace(/\b(AIza|AQ\.)[A-Za-z0-9_.-]{10,}/g, "$1***");
}

import { DOCS_URL } from '~/constants';
import { logError } from '~/lib/logger';

/**
 * Computes a list of trusted URLs for the Duo Chat component.
 * Includes GitLab.com, documentation URLs, the current GitLab instance,
 * and any additional URLs passed as props.
 *
 * @param {Array<string>} [trustedUrls=[]] - Additional URLs to trust
 * @returns {Array<string>} Array of unique trusted URL hostnames
 */
export function computeTrustedUrls(trustedUrls = []) {
  const docsUrlHost = new URL(DOCS_URL).hostname;
  const baseUrls = ['gitlab.com', docsUrlHost];

  // Add the instance hostname from gon if available
  if (window.gon?.gitlab_url) {
    try {
      const url = new URL(window.gon.gitlab_url);
      baseUrls.push(url.hostname);
    } catch (err) {
      logError('Failed to parse gitlab_url', err);
    }
  }

  // Include any additional URLs passed as props
  if (trustedUrls && Array.isArray(trustedUrls)) {
    baseUrls.push(...trustedUrls);
  }

  // Remove duplicates and return
  return [...new Set(baseUrls)];
}

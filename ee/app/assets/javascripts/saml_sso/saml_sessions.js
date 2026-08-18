import axios from '~/lib/utils/axios_utils';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';

/**
 * Fetches the SAML sessions for the current user
 * @param {string} url
 */
async function getSamlSessions(url) {
  const { data } = await axios.get(url);
  return convertObjectPropsToCamelCase(data, { deep: true });
}

/**
 * Fetches the SAML sessions for the current user and returns information of the
 * expiring session (providerId and timeRemainingMs), otherwise it returns undefined.
 *
 * @param {object} options
 *   @param {number} options.samlProviderId - SAML provider ID for the top-level group
 *   @param {string} options.url
 *
 * @returns {Promise<{providerId: number, timeRemainingMs: number}|undefined>}
 */
export async function getExpiringSamlSession({ samlProviderId, url }) {
  const sessions = await getSamlSessions(url);

  const expiring = sessions.find(
    ({ providerId, timeRemainingMs }) => providerId === samlProviderId && timeRemainingMs > 0,
  );

  return expiring;
}

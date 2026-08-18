/* eslint-disable @gitlab/no-hardcoded-urls -- REST API routes using Api.buildUrl is acceptable */
import { buildApiUrl } from '~/api/api_utils';
import axios from '~/lib/utils/axios_utils';

export const PASSWORD_COMPLEXITY_PATH = '/users/password/complexity';

export function validatePasswordComplexity(newUserParams) {
  const url = buildApiUrl(PASSWORD_COMPLEXITY_PATH);

  return axios.post(url, { user: newUserParams });
}

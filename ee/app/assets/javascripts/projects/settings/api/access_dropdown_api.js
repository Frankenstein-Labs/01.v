import axios from '~/lib/utils/axios_utils';
import { buildApiUrl } from '~/api/api_utils';

export {
  buildUrl,
  getUsers,
  getGroups,
  getDeployKeys,
} from '~/projects/settings/api/access_dropdown_api';

const MEMBER_ROLES_PATH = '/api/:version/groups/:id/member_roles';

export const getMemberRoles = (namespaceId) => {
  if (!namespaceId) {
    return Promise.reject(new Error('namespaceId is required'));
  }
  return axios.get(buildApiUrl(MEMBER_ROLES_PATH).replace(':id', encodeURIComponent(namespaceId)));
};

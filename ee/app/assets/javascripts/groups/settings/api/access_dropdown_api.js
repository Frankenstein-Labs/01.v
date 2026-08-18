import axios from '~/lib/utils/axios_utils';
import { getGroupMembers } from '~/rest_api';
import { autocompleteGroupSubgroupsPath } from 'ee/lib/utils/path_helpers/autocomplete';

const defaultOptions = {
  includeParentDescendants: false,
  includeParentSharedGroups: false,
  search: '',
};

export const getSubGroups = (options = defaultOptions) => {
  const { includeParentDescendants, includeParentSharedGroups, search } = options;

  return axios.get(autocompleteGroupSubgroupsPath(), {
    params: {
      group_id: gon.current_group_id,
      include_parent_descendants: includeParentDescendants,
      include_parent_shared_groups: includeParentSharedGroups,
      search,
    },
  });
};

export const getUsers = (query, inherited = false) => {
  return getGroupMembers(gon.current_group_id, inherited, {
    query,
    per_page: 20,
  });
};

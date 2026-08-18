import produce from 'immer';
import userWorkspacesTabListQuery from '../../common/graphql/queries/user_workspaces_tab_list.query.graphql';
import { WORKSPACES_LIST_PAGE_SIZE } from '../constants';

export const addWorkspace = (store, workspace) => {
  store.updateQuery(
    {
      query: userWorkspacesTabListQuery,
      variables: {
        first: WORKSPACES_LIST_PAGE_SIZE,
        activeAfter: null,
        activeBefore: null,
        terminatedAfter: null,
        terminatedBefore: null,
      },
    },
    (sourceData) =>
      produce(sourceData, (draftData) => {
        // If there's nothing in the query we don't really need to update it. It should just refetch naturally.
        if (!draftData) {
          return;
        }

        draftData.currentUser.activeWorkspaces.nodes.unshift(workspace);
      }),
  );
};

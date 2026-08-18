import { s__ } from '~/locale';
import sidebarEventHub from '~/sidebar/event_hub';
import userPermissionsQuery from '~/merge_requests/components/reviewers/queries/user_permissions.query.graphql';

export default {
  apollo: {
    userPermissions: {
      query: userPermissionsQuery,
      variables() {
        return {
          fullPath: this.mr.targetProjectFullPath,
          iid: `${this.mr.iid}`,
        };
      },
      update: (data) => data.project?.mergeRequest?.userPermissions || {},
    },
  },
  data() {
    return {
      userPermissions: {},
    };
  },
  computed: {
    tertiaryActionsButtons() {
      return [
        this.userPermissions.adminMergeRequest &&
          this.mr.mergeRequestApproversAvailable && {
            text: s__('MergeChecks|Assign reviewers'),
            onClick() {
              sidebarEventHub.$emit('sidebar.toggleReviewerDrawer');
            },
          },
      ].filter((x) => x);
    },
  },
};

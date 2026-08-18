<script>
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPE_WORKSPACE } from '~/graphql_shared/constants';
import { s__ } from '~/locale';
import { logError } from '~/lib/logger';
import { getSlotFunction, normalizeRender } from '~/lib/utils/vue3compat/normalize_render';
import workspaceUpdateMutation from '../graphql/mutations/workspace_update.mutation.graphql';

export const i18n = {
  updateWorkspaceFailedMessage: s__('Workspaces|Failed to update workspace'),
};

export default normalizeRender({
  emits: ['update-failed', 'update-succeed'],
  methods: {
    async update(id, state = {}) {
      try {
        // noinspection JSCheckFunctionSignatures - TODO: Address in https://gitlab.com/gitlab-org/gitlab/-/issues/437600
        const { data } = await this.$apollo.mutate({
          mutation: workspaceUpdateMutation,
          variables: {
            input: {
              id: convertToGraphQLId(TYPE_WORKSPACE, id),
              ...state,
            },
          },
        });

        const {
          errors: [error],
        } = data.workspaceUpdate;

        if (error) {
          this.$emit('update-failed', { error });
        } else {
          this.$emit('update-succeed');
        }
      } catch (e) {
        logError(e);
        this.$emit('update-failed', { error: i18n.updateWorkspaceFailedMessage });
      }
    },
  },
  render() {
    return getSlotFunction(this)({ update: this.update });
  },
});
</script>

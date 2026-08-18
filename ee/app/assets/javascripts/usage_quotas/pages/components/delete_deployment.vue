<script>
import { GlButton } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import deletePagesDeploymentMutation from '~/gitlab_pages/queries/delete_pages_deployment.mutation.graphql';
import restorePagesDeploymentMutation from '~/gitlab_pages/queries/restore_pages_deployment.mutation.graphql';

export default {
  name: 'DeleteDeployment',
  components: { GlButton },
  props: {
    id: {
      type: String,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      deleteInProgress: false,
      restoreInProgress: false,
      hasError: false,
    };
  },
  methods: {
    async deleteDeployment() {
      this.hasError = false;
      this.deleteInProgress = true;
      try {
        await this.$apollo.mutate({
          mutation: deletePagesDeploymentMutation,
          variables: {
            deploymentId: this.id,
          },
        });
      } catch (error) {
        createAlert({
          message: s__('Pages|There was an error trying to delete the deployment'),
          captureError: true,
          error,
        });
      } finally {
        this.deleteInProgress = false;
      }
    },
    async restoreDeployment() {
      this.hasError = false;
      this.restoreInProgress = true;
      try {
        await this.$apollo.mutate({
          mutation: restorePagesDeploymentMutation,
          variables: {
            deploymentId: this.id,
          },
        });
      } catch (error) {
        createAlert({
          message: s__('Pages|There was an error trying to restore the deployment'),
          captureError: true,
          error,
        });
      } finally {
        this.restoreInProgress = false;
      }
    },
  },
};
</script>

<template>
  <span>
    <gl-button
      v-if="active"
      icon="remove"
      size="small"
      variant="danger"
      category="tertiary"
      :loading="deleteInProgress"
      :aria-label="__('Delete deployment')"
      data-testid="delete-deployment"
      @click="deleteDeployment"
    />
    <gl-button
      v-else
      icon="redo"
      size="small"
      variant="confirm"
      category="tertiary"
      :loading="restoreInProgress"
      :aria-label="__('Restore deployment')"
      data-testid="restore-deployment"
      @click="restoreDeployment"
    />
  </span>
</template>

<style scoped></style>

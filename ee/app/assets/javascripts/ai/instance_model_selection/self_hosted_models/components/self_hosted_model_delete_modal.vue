<script>
import { GlModal, GlSprintf } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { __, s__ } from '~/locale';
import deleteSelfHostedModelMutation from '../graphql/mutations/delete_self_hosted_model.mutation.graphql';
import getSelfHostedModelsQuery from '../graphql/queries/get_self_hosted_models.query.graphql';
import getAiFeatureSettingsQuery from '../../feature_settings/graphql/queries/get_ai_feature_settings.query.graphql';

export default {
  name: 'DeleteModalEE',
  components: {
    GlModal,
    GlSprintf,
  },
  props: {
    id: {
      type: String,
      required: true,
    },
    model: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      isDeleting: false,
    };
  },
  computed: {
    modelDeploymentName() {
      return { modelName: this.model.name };
    },
    modalActionPrimary() {
      return {
        text: __('Delete'),
        attributes: {
          variant: 'danger',
          loading: this.isDeleting,
          type: 'submit',
        },
      };
    },
    modalActionSecondary() {
      return {
        text: __('Cancel'),
        attributes: {
          loading: this.isDeleting,
        },
      };
    },
  },
  methods: {
    async onDelete() {
      this.isDeleting = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: deleteSelfHostedModelMutation,
          variables: {
            input: {
              id: this.model.id,
            },
          },
          refetchQueries: [
            {
              query: getSelfHostedModelsQuery,
            },
            {
              query: getAiFeatureSettingsQuery,
            },
          ],
        });

        if (data) {
          const errors = data.aiSelfHostedModelDelete?.errors;

          if (errors.length > 0) {
            throw new Error(errors[0]);
          }
        }
        createAlert({
          message: s__('AdminSelfHostedModels|Your self-hosted model was successfully deleted.'),
          variant: 'success',
        });
      } catch (error) {
        const defaultErrorMessage = s__(
          'AdminSelfHostedModels|An error occurred while deleting your self-hosted model. Please try again.',
        );
        createAlert({
          message: error?.message || defaultErrorMessage,
          error,
          captureError: true,
        });
      } finally {
        this.isDeleting = false;
      }
    },
  },
};
</script>
<template>
  <gl-modal
    :modal-id="id"
    :title="s__('AdminSelfHostedModels|Delete self-hosted model')"
    size="sm"
    :no-focus-on-show="true"
    :action-primary="modalActionPrimary"
    :action-cancel="modalActionSecondary"
    @primary="onDelete"
  >
    <div data-testid="delete-model-confirmation-message">
      <gl-sprintf
        :message="
          sprintf(
            s__(
              'AdminSelfHostedModels|You are about to delete the %{boldStart}%{modelName}%{boldEnd} self-hosted model. This action cannot be undone.',
            ),
            modelDeploymentName,
          )
        "
      >
        <template #bold="{ content }">
          <b>
            {{ content }}
          </b>
        </template>
      </gl-sprintf>
    </div>
    <br />
    {{ __('Are you sure you want to proceed?') }}
  </gl-modal>
</template>

<script>
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import updateSelfHostedModelMutation from '../graphql/mutations/update_self_hosted_model.mutation.graphql';
import getSelfHostedModelByIdQuery from '../graphql/queries/get_self_hosted_model_by_id.query.graphql';
import { SELF_HOSTED_MODEL_MUTATIONS } from '../constants';
import SelfHostedModelForm from './self_hosted_model_form.vue';

export default {
  name: 'EditSelfHostedModel',
  components: {
    SelfHostedModelForm,
  },
  props: {
    modelId: {
      type: Number,
      required: true,
    },
  },
  i18n: {
    title: s__('AdminSelfHostedModels|Edit self-hosted model'),
    description: s__(
      'AdminSelfHostedModels|Edit the AI model that can be used for GitLab Duo self-hosted features.',
    ),
    errorMessage: s__(
      'AdminSelfHostedModels|An error occurred while loading the self-hosted model. Please try again.',
    ),
  },
  mutationData: {
    name: SELF_HOSTED_MODEL_MUTATIONS.UPDATE,
    mutation: updateSelfHostedModelMutation,
  },
  data() {
    return {
      selfHostedModel: null,
    };
  },
  apollo: {
    selfHostedModel: {
      query: getSelfHostedModelByIdQuery,
      variables() {
        return {
          id: convertToGraphQLId('Ai::SelfHostedModel', this.modelId),
        };
      },
      update(data) {
        return data.aiSelfHostedModels?.nodes[0];
      },
      error(error) {
        createAlert({
          message: this.$options.i18n.errorMessage,
          error,
          captureError: true,
        });
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.loading;
    },
  },
};
</script>
<template>
  <div>
    <h1>{{ $options.i18n.title }}</h1>
    <p class="gl-pb-2 gl-pt-3">
      {{ $options.i18n.description }}
    </p>
    <self-hosted-model-form
      v-if="!isLoading"
      :initial-form-values="selfHostedModel"
      :mutation-data="$options.mutationData"
      :submit-button-text="__('Save changes')"
    />
  </div>
</template>

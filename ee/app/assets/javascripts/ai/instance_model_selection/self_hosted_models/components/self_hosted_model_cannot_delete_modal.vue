<script>
import { GlModal, GlSprintf } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { INSTANCE_MODEL_SELECTION_ROUTE_NAMES } from 'ee/ai/instance_model_selection/constants';

export default {
  name: 'CannotDeleteModal',
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
  computed: {
    modelDeploymentName() {
      return { modelName: this.model.name };
    },
    featureSettings() {
      return this.model.featureSettings?.nodes || [];
    },
    modalActionPrimary() {
      return {
        text: s__('AdminSelfHostedModels|View AI-native features'),
        attributes: {
          variant: 'default',
        },
      };
    },
    modalActionSecondary() {
      return {
        text: __('Cancel'),
      };
    },
  },
  methods: {
    navigateToFeaturesTab() {
      this.$router.push({ name: INSTANCE_MODEL_SELECTION_ROUTE_NAMES.FEATURES });
    },
  },
};
</script>
<template>
  <gl-modal
    :modal-id="id"
    :title="s__('AdminSelfHostedModels|This self-hosted model cannot be deleted')"
    size="sm"
    :no-focus-on-show="true"
    :action-primary="modalActionPrimary"
    :action-cancel="modalActionSecondary"
    @primary="navigateToFeaturesTab"
  >
    <p>
      <gl-sprintf
        :message="
          sprintf(
            s__(
              'AdminSelfHostedModels|To remove %{boldStart}%{modelName}%{boldEnd}, you must first remove it from the following AI Feature(s):',
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
    </p>
    <ul>
      <li v-for="feature in featureSettings" :key="feature.feature">
        {{ feature.title }}
      </li>
    </ul>
    <p>
      {{
        s__(
          'AdminSelfHostedModels|Once the model is no longer in use, you can return here to delete it.',
        )
      }}
    </p>
  </gl-modal>
</template>

<script>
import { GlAlert, GlButton, GlFormCheckbox, GlToastMixin } from '@gitlab/ui';
import { __ } from '~/locale';
import Tracking from '~/tracking';
import MavenForm from 'ee_component/packages_and_registries/settings/project/components/maven_form.vue';
import updateDependencyProxyPackagesSettings from 'ee_component/packages_and_registries/settings/project/graphql/mutations/update_dependency_proxy_packages_settings.mutation.graphql';

export default {
  name: 'DependencyProxyPackagesSettingsForm',
  components: {
    GlAlert,
    GlButton,
    GlFormCheckbox,
    MavenForm,
  },
  mixins: [Tracking.mixin(), GlToastMixin],
  inject: ['projectPath'],
  props: {
    data: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      alertMessage: '',
      updateInProgress: false,
      enabled: this.data.enabled,
      mavenFormData: {
        mavenExternalRegistryUrl: this.data.mavenExternalRegistryUrl,
        mavenExternalRegistryUsername: this.data.mavenExternalRegistryUsername,
        mavenExternalRegistryPassword: null,
      },
    };
  },
  computed: {
    mutationVariables() {
      return {
        projectPath: this.projectPath,
        enabled: this.enabled,
        mavenExternalRegistryUrl: this.mavenFormData.mavenExternalRegistryUrl,
        mavenExternalRegistryUsername: this.mavenFormData.mavenExternalRegistryUsername,
        mavenExternalRegistryPassword: this.mavenFormData.mavenExternalRegistryPassword,
      };
    },
    showAlert() {
      return this.alertMessage;
    },
  },
  methods: {
    setAlertMessage(message) {
      this.alertMessage = message;
    },
    async submit() {
      this.track('submit_dependency_proxy_packages_settings', {
        label: 'dependendency_proxy_packages_settings',
      });
      this.updateInProgress = true;
      this.alertMessage = '';
      await this.$apollo
        .mutate({
          mutation: updateDependencyProxyPackagesSettings,
          variables: {
            input: this.mutationVariables,
          },
        })
        .then(({ data }) => {
          const [errorMessage] = data?.updateDependencyProxyPackagesSettings?.errors ?? [];
          if (errorMessage) {
            throw errorMessage;
          }
          this.mavenFormData.mavenExternalRegistryPassword = null;
          this.$toast.show(__('Settings saved successfully.'));
        })
        .catch((errorMessage) => {
          this.setAlertMessage(errorMessage);
        })
        .finally(() => {
          this.updateInProgress = false;
        });
    },
  },
};
</script>

<template>
  <form @submit.prevent="submit">
    <gl-alert
      v-if="showAlert"
      variant="danger"
      class="gl-my-4"
      dismissible
      @dismiss="setAlertMessage('')"
    >
      {{ alertMessage }}
    </gl-alert>
    <gl-form-checkbox v-model="enabled">
      {{ s__('DependencyProxy|Enable Dependency Proxy') }}
    </gl-form-checkbox>
    <maven-form v-model="mavenFormData" />
    <div class="gl-mt-5 gl-flex gl-items-center">
      <gl-button
        type="submit"
        :disabled="updateInProgress"
        :loading="updateInProgress"
        category="primary"
        variant="confirm"
        class="js-no-auto-disable gl-mr-4"
      >
        {{ __('Save changes') }}
      </gl-button>
    </div>
  </form>
</template>

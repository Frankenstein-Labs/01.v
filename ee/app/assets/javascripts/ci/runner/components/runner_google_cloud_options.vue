<script>
import { GOOGLE_CLOUD_PLATFORM, GOOGLE_KUBERNETES_ENGINE } from '~/ci/runner/constants';
import RunnerPlatformsRadio from '~/ci/runner/components/runner_platforms_radio.vue';

import canReadProjectRunnerCloudProvisioningInfo from '../graphql/register/can_read_project_runner_cloud_provisioning_info.query.graphql';
import canReadGroupRunnerCloudProvisioningInfo from '../graphql/register/can_read_group_runner_cloud_provisioning_info.query.graphql';

export default {
  name: 'RunnerGoogleCloudOptions',
  GOOGLE_CLOUD_PLATFORM,
  GOOGLE_KUBERNETES_ENGINE,
  components: {
    RunnerPlatformsRadio,
  },
  model: {
    event: 'input',
    prop: 'checked',
  },
  props: {
    checked: {
      type: String,
      required: false,
      default: null,
    },
    projectPath: {
      type: String,
      required: false,
      default: null,
    },
    groupPath: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['input'],
  data() {
    return {
      canReadProjectInfo: false,
      canReadGroupInfo: false,
    };
  },
  computed: {
    canReadRunnerCloudProvisioningInfo() {
      return this.canReadProjectInfo || this.canReadGroupInfo;
    },
  },
  apollo: {
    canReadProjectInfo: {
      query: canReadProjectRunnerCloudProvisioningInfo,
      skip() {
        return !this.projectPath;
      },
      variables() {
        return { fullPath: this.projectPath };
      },
      update(data) {
        return data?.project?.userPermissions?.readRunnerCloudProvisioningInfo || false;
      },
    },
    canReadGroupInfo: {
      query: canReadGroupRunnerCloudProvisioningInfo,
      skip() {
        return !this.groupPath;
      },
      variables() {
        return { fullPath: this.groupPath };
      },
      update(data) {
        return data?.group?.userPermissions?.readRunnerCloudProvisioningInfo || false;
      },
    },
  },
};
</script>

<template>
  <div v-if="canReadRunnerCloudProvisioningInfo" class="gl-mb-6 gl-mt-3">
    <label>{{ s__('Runners|Cloud') }}</label>

    <div class="gl-flex gl-flex-wrap gl-gap-3">
      <runner-platforms-radio
        :checked="checked"
        :value="$options.GOOGLE_CLOUD_PLATFORM"
        @input="$emit('input', $event)"
      >
        <!-- eslint-disable @gitlab/vue-require-i18n-strings -->
        Google Cloud
        <!-- eslint-enable @gitlab/vue-require-i18n-strings -->
      </runner-platforms-radio>
      <runner-platforms-radio
        :checked="checked"
        :value="$options.GOOGLE_KUBERNETES_ENGINE"
        @input="$emit('input', $event)"
      >
        <!-- eslint-disable @gitlab/vue-require-i18n-strings -->
        GKE
        <!-- eslint-enable @gitlab/vue-require-i18n-strings -->
      </runner-platforms-radio>
    </div>
  </div>
</template>

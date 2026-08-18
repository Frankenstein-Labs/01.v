<script>
import { GlButton, GlFormGroup, GlToastMixin } from '@gitlab/ui';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { __, s__ } from '~/locale';
import { CONTEXT_TYPE } from '~/members/constants';

export default {
  name: 'ResetButton',
  components: {
    GlButton,
    GlFormGroup,
  },
  mixins: [GlToastMixin],
  inject: {
    resetMinutesPath: {
      default: '',
    },
    contextType: {
      default: CONTEXT_TYPE.GROUP,
    },
  },
  data() {
    return {
      loading: false,
    };
  },
  computed: {
    isUserContext() {
      return this.contextType === CONTEXT_TYPE.USER;
    },
    labelDescription() {
      return this.isUserContext
        ? s__('SharedRunnersMinutesSettings|Changes the compute usage for this user to zero.')
        : s__('SharedRunnersMinutesSettings|Changes the compute usage for this group to zero.');
    },
    resetSuccessMessage() {
      return this.isUserContext
        ? s__('SharedRunnersMinutesSettings|Reset compute usage for this user.')
        : s__('SharedRunnersMinutesSettings|Reset compute usage for this group.');
    },
  },
  methods: {
    async resetPipelineMinutes() {
      this.loading = true;
      try {
        const response = await axios.post(this.resetMinutesPath);
        if (response.status === HTTP_STATUS_OK) {
          this.$toast.show(this.resetSuccessMessage);
        }
      } catch (e) {
        this.$toast.show(__('An error occurred while resetting the compute usage.'));
      } finally {
        this.loading = false;
      }
    },
  },
};
</script>
<template>
  <gl-form-group
    :label="s__('SharedRunnersMinutesSettings|Reset compute usage')"
    :label-description="labelDescription"
    label-for="reset-pipeline-minutes"
  >
    <gl-button id="reset-pipeline-minutes" :loading="loading" @click="resetPipelineMinutes">
      {{ s__('SharedRunnersMinutesSettings|Reset compute usage') }}
    </gl-button>
  </gl-form-group>
</template>

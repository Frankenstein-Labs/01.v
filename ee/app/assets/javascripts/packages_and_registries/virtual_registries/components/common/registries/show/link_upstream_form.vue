<script>
import { GlAlert, GlButton, GlCard, GlForm, GlFormGroup, GlSkeletonLoader } from '@gitlab/ui';
import { sprintf, n__ } from '~/locale';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';
import TestUpstreamButton from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/test_button.vue';
import UpstreamSelector from './upstream_selector.vue';

export default {
  name: 'LinkUpstreamForm',
  components: {
    GlAlert,
    GlButton,
    GlCard,
    GlForm,
    GlFormGroup,
    GlSkeletonLoader,
    TestUpstreamButton,
    UpstreamSelector,
  },
  inject: {
    getUpstreamSummaryQuery: { default: null },
    isMavenUpstream: { default: false },
  },
  props: {
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    linkedUpstreamIds: {
      type: Array,
      required: true,
    },
  },
  /**
   * @event submit - Emitted when the form is submitted
   * @property {String} upstreamId - The ID of the selected upstream
   */
  /**
   * @event cancel - Emitted when the "Cancel" button is clicked
   */
  emits: ['submit', 'cancel'],
  data() {
    return {
      fetchUpstreamDetailsError: false,
      isFetchingUpstreamDetails: 0,
      selectedUpstream: null,
      selectedUpstreamDetails: null,
    };
  },
  apollo: {
    selectedUpstreamDetails: {
      query() {
        return this.getUpstreamSummaryQuery;
      },
      loadingKey: 'isFetchingUpstreamDetails',
      skip() {
        return this.selectedUpstream === null;
      },
      variables() {
        return {
          id: this.selectedUpstream,
        };
      },
      update: (data) => data.upstream,
      error(error) {
        this.fetchUpstreamDetailsError = true;
        captureException({ error, component: this.$options.name });
      },
    },
  },
  methods: {
    async selectUpstream(upstreamId) {
      if (!upstreamId) return;

      this.selectedUpstream = upstreamId;
    },
    getCacheValidityHoursLabel(cacheValidityHours) {
      return sprintf(
        n__('VirtualRegistry|%{hours} hour', 'VirtualRegistry|%{hours} hours', cacheValidityHours),
        { hours: cacheValidityHours },
      );
    },
    submit() {
      if (this.selectedUpstream) {
        this.$emit('submit', this.selectedUpstream);
      }
    },
    cancel() {
      this.$emit('cancel');
    },
  },
  rowClass: '@md/panel:gl-text-right @md/panel:gl-basis-26',
};
</script>

<template>
  <gl-form @submit.prevent="submit">
    <gl-form-group
      id="upstream-select-group"
      :label="s__('VirtualRegistry|Select an upstream')"
      label-for="upstream-select"
      class="@md/panel:gl-w-3/10"
    >
      <upstream-selector :linked-upstream-ids="linkedUpstreamIds" @select="selectUpstream" />
    </gl-form-group>
    <gl-card class="gl-my-3" header-class="gl-bg-subtle" body-class="gl-p-0">
      <template #header>
        <span class="gl-font-bold">{{ s__('VirtualRegistry|Upstream summary') }}</span>
      </template>
      <template #default>
        <div v-if="selectedUpstreamDetails">
          <div
            class="gl-border-b gl-flex gl-flex-col gl-px-5 gl-py-4 @md/panel:gl-flex-row @md/panel:gl-gap-5"
          >
            <span :class="$options.rowClass"> {{ s__('VirtualRegistry|URL') }}</span>
            <span> {{ selectedUpstreamDetails.url }}</span>
          </div>
          <div
            v-if="selectedUpstreamDetails.description"
            class="gl-border-b gl-flex gl-flex-col gl-px-5 gl-py-4 @md/panel:gl-flex-row @md/panel:gl-gap-5"
          >
            <span :class="$options.rowClass">
              {{ s__('VirtualRegistry|Description') }}
            </span>
            <span> {{ selectedUpstreamDetails.description }} </span>
          </div>
          <div
            class="gl-flex gl-flex-col gl-px-5 gl-py-4 @md/panel:gl-flex-row @md/panel:gl-gap-5"
            :class="{ 'gl-border-b': isMavenUpstream }"
          >
            <span :class="$options.rowClass">
              {{ s__('VirtualRegistry|Artifact caching period') }}
            </span>
            <span>
              {{ getCacheValidityHoursLabel(selectedUpstreamDetails.cacheValidityHours) }}
            </span>
          </div>
          <div
            v-if="isMavenUpstream"
            class="gl-flex gl-flex-col gl-px-5 gl-py-4 @md/panel:gl-flex-row @md/panel:gl-gap-5"
          >
            <span :class="$options.rowClass">
              {{ s__('VirtualRegistry|Metadata caching period') }}
            </span>
            <span>
              {{ getCacheValidityHoursLabel(selectedUpstreamDetails.metadataCacheValidityHours) }}
            </span>
          </div>
        </div>
        <div v-else class="gl-px-5 gl-py-4">
          <gl-skeleton-loader v-if="isFetchingUpstreamDetails" :lines="3" />
          <gl-alert
            v-else-if="fetchUpstreamDetailsError"
            variant="danger"
            @dismiss="fetchUpstreamDetailsError = false"
          >
            {{ s__('VirtualRegistry|Failed to fetch upstream summary.') }}
          </gl-alert>
          <div v-else>
            {{ s__('VirtualRegistry|To view summary, select an upstream.') }}
          </div>
        </div>
      </template>
    </gl-card>
    <div class="gl-flex gl-gap-3">
      <gl-button
        data-testid="submit-button"
        class="js-no-auto-disable"
        variant="confirm"
        category="primary"
        type="submit"
        :loading="loading"
      >
        {{ s__('VirtualRegistry|Add upstream') }}
      </gl-button>
      <gl-button data-testid="cancel-button" category="secondary" @click="cancel">
        {{ __('Cancel') }}
      </gl-button>
      <test-upstream-button v-if="selectedUpstream" :upstream-id="selectedUpstream" />
    </div>
  </gl-form>
</template>

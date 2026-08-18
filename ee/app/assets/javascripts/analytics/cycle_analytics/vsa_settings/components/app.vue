<script>
import { GlLoadingIcon, GlAlert } from '@gitlab/ui';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { generateInitialStageData } from '../utils';
import getValueStream from '../graphql/get_value_stream.query.graphql';
import ValueStreamFormContent from './value_stream_form_content.vue';

export default {
  name: 'VSASettingsApp',
  components: {
    ValueStreamFormContent,
    GlLoadingIcon,
    GlAlert,
  },
  inject: ['defaultStages', 'fullPath', 'isProject', 'valueStreamGid'],
  data() {
    return {
      valueStream: {},
      stages: [],
      showError: false,
    };
  },
  computed: {
    isEditing() {
      return Boolean(this.valueStreamGid);
    },
    pageHeader() {
      return this.isEditing
        ? s__('CreateValueStreamForm|Edit value stream')
        : s__('CreateValueStreamForm|New value stream');
    },
    isLoading() {
      return this.$apollo.queries.valueStream.loading;
    },
    initialData() {
      return this.isEditing
        ? {
            ...this.valueStream,
            stages: generateInitialStageData(this.defaultStages, this.stages),
          }
        : {
            name: '',
            stages: [],
          };
    },
  },
  apollo: {
    valueStream: {
      query: getValueStream,
      variables() {
        return {
          fullPath: this.fullPath,
          isProject: this.isProject,
          valueStreamId: this.valueStreamGid,
        };
      },
      skip() {
        return !this.isEditing;
      },
      update({ group, project }) {
        try {
          const {
            valueStreams: {
              nodes: [valueStream],
            },
          } = group || project;

          const { id, name, stages } = valueStream;
          this.stages = stages.map(({ startEventIdentifier, endEventIdentifier, ...rest }) => ({
            startEventIdentifier: startEventIdentifier.toLowerCase(),
            endEventIdentifier: endEventIdentifier.toLowerCase(),
            ...rest,
          }));
          return { id, name };
        } catch (e) {
          this.handleError(e);
          return {};
        }
      },
      error(e) {
        this.handleError(e);
      },
    },
  },
  methods: {
    handleError(e) {
      this.showError = true;
      Sentry.captureException(e);
    },
  },
};
</script>
<template>
  <div>
    <h1 data-testid="vsa-settings-page-header" class="page-title gl-text-size-h-display">
      {{ pageHeader }}
    </h1>
    <gl-loading-icon v-if="isLoading" class="gl-pt-7" size="lg" />
    <gl-alert v-else-if="showError" variant="danger" :dismissible="false">
      {{ s__('CreateValueStreamForm|There was an error fetching the value stream.') }}
    </gl-alert>
    <value-stream-form-content v-else :initial-data="initialData" />
  </div>
</template>

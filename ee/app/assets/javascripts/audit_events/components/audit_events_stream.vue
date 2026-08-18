<script>
import { GlAlert, GlLoadingIcon, GlDisclosureDropdown } from '@gitlab/ui';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import {
  ADD_STREAM,
  ADD_HTTP,
  ADD_GCP_LOGGING,
  ADD_AMAZON_S3,
  ADD_STREAM_MESSAGE,
  AUDIT_STREAMS_NETWORK_ERRORS,
  DELETE_STREAM_MESSAGE,
  streamsLabel,
  DESTINATION_TYPE_HTTP,
  DESTINATION_TYPE_GCP_LOGGING,
  DESTINATION_TYPE_AMAZON_S3,
} from '../constants';
import { removeAuditEventsStreamingDestinationFromCache } from '../graphql/cache_update_consolidated_api';
import groupStreamingDestinationsQuery from '../graphql/queries/get_group_streaming_destinations.query.graphql';
import instanceStreamingDestinationsQuery from '../graphql/queries/get_instance_streaming_destinations.query.graphql';
import StreamEmptyState from './stream/stream_empty_state.vue';
import StreamDestinationEditor from './stream/stream_destination_editor.vue';
import StreamItem from './stream/stream_item.vue';

const { FETCHING_ERROR } = AUDIT_STREAMS_NETWORK_ERRORS;
export default {
  name: 'AuditEventsStream',
  components: {
    GlAlert,
    GlLoadingIcon,
    GlDisclosureDropdown,
    StreamDestinationEditor,
    StreamEmptyState,
    StreamItem,
  },
  inject: ['groupPath'],
  data() {
    return {
      streamingDestinations: null,
      isEditorVisible: false,
      successMessage: null,
      editorType: DESTINATION_TYPE_HTTP,
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.streamingDestinations.loading;
    },
    isInstance() {
      return this.groupPath === 'instance';
    },
    showEmptyState() {
      return !this.streamingDestinationsCount && !this.isEditorVisible;
    },
    streamingDestinationsCount() {
      return this.streamingDestinations?.length ?? 0;
    },
    totalCount() {
      return this.streamingDestinationsCount;
    },
    streamingDestinationsQuery() {
      return this.isInstance ? instanceStreamingDestinationsQuery : groupStreamingDestinationsQuery;
    },
    newDestination() {
      return {
        name: '',
        config: {},
        category: this.editorType,
        namespaceFilters: [],
        eventTypeFilters: [],
      };
    },
    destinationOptions() {
      return [
        {
          text: ADD_HTTP,
          action: () => {
            this.showEditor(DESTINATION_TYPE_HTTP);
          },
        },
        {
          text: ADD_GCP_LOGGING,
          action: () => {
            this.showEditor(DESTINATION_TYPE_GCP_LOGGING);
          },
        },
        {
          text: ADD_AMAZON_S3,
          action: () => {
            this.showEditor(DESTINATION_TYPE_AMAZON_S3);
          },
        },
      ];
    },
  },
  methods: {
    showEditor(type) {
      this.editorType = type;
      this.isEditorVisible = true;
    },
    hideEditor() {
      this.isEditorVisible = false;
    },
    clearSuccessMessage() {
      this.successMessage = null;
    },
    async onAddedDestination() {
      this.hideEditor();
      this.successMessage = ADD_STREAM_MESSAGE;
    },
    async onUpdatedDestination() {
      this.hideEditor();
    },
    async onDeletedDestination(id) {
      removeAuditEventsStreamingDestinationFromCache({
        store: this.$apollo.provider.defaultClient,
        isInstance: this.isInstance,
        fullPath: this.groupPath,
        destinationId: id,
      });

      if (this.totalCount > 1) {
        this.successMessage = DELETE_STREAM_MESSAGE;
      } else {
        this.clearSuccessMessage();
      }
    },
  },
  apollo: {
    streamingDestinations: {
      query() {
        return this.streamingDestinationsQuery;
      },
      variables() {
        return {
          fullPath: this.groupPath,
        };
      },
      skip() {
        return !this.groupPath;
      },
      update(data) {
        const items = this.isInstance
          ? data?.auditEventsInstanceStreamingDestinations?.nodes
          : data?.group?.externalAuditEventStreamingDestinations?.nodes;

        return items?.map((destination) => {
          let category;

          switch (destination.category) {
            case 'http':
              category = DESTINATION_TYPE_HTTP;
              break;
            case 'gcp':
              category = DESTINATION_TYPE_GCP_LOGGING;
              break;
            case 'aws':
              category = DESTINATION_TYPE_AMAZON_S3;
              break;
            default:
              category = destination.category;
              Sentry.captureException(
                Error(`Unknown destination category: ${destination.category}`),
              );
          }

          return {
            ...destination,
            category,
          };
        });
      },
      error(error) {
        Sentry.captureException(error);
        createAlert({
          message: FETCHING_ERROR,
        });

        this.clearSuccessMessage();
      },
    },
  },
  i18n: {
    ADD_STREAM,
    ADD_HTTP,
    ADD_GCP_LOGGING,
    ADD_AMAZON_S3,
    FETCHING_ERROR,
    streamsLabel,
  },
  DESTINATION_TYPE_HTTP,
  DESTINATION_TYPE_GCP_LOGGING,
  DESTINATION_TYPE_AMAZON_S3,
};
</script>

<template>
  <gl-loading-icon v-if="isLoading" size="lg" />
  <stream-empty-state v-else-if="showEmptyState" @add="showEditor" />
  <div v-else>
    <gl-alert
      v-if="successMessage"
      :dismissible="true"
      class="gl-mb-4"
      variant="success"
      @dismiss="clearSuccessMessage"
    >
      {{ successMessage }}
    </gl-alert>
    <div class="gl-mb-6 gl-mt-3 gl-flex gl-items-center gl-justify-between">
      <h4 class="gl-m-0">
        {{ $options.i18n.streamsLabel(totalCount) }}
      </h4>
      <gl-disclosure-dropdown
        :toggle-text="$options.i18n.ADD_STREAM"
        category="primary"
        variant="confirm"
        data-testid="dropdown-toggle"
        :items="destinationOptions"
      />
    </div>
    <div v-if="isEditorVisible" class="gl-border gl-mb-4 gl-rounded-base gl-p-4">
      <stream-destination-editor
        :item="newDestination"
        @added="onAddedDestination"
        @error="clearSuccessMessage"
        @cancel="hideEditor"
      />
    </div>
    <ul class="content-list gl-border-t gl-border-subtle" data-testid="all-stream-destinations">
      <stream-item
        v-for="item in streamingDestinations"
        :key="item.id"
        :item="item"
        :type="item.category"
        @deleted="onDeletedDestination(item.id)"
        @updated="onUpdatedDestination"
        @error="clearSuccessMessage"
      />
    </ul>
  </div>
</template>

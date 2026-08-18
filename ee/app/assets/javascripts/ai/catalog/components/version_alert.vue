<script>
import { GlAlert, GlToastMixin } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { visitUrl } from '~/lib/utils/url_utility';
import {
  AI_CATALOG_CONSUMER_TYPE_GROUP,
  AI_CATALOG_CONSUMER_TYPE_PROJECT,
  AI_CATALOG_CONSUMER_LABELS,
  AI_CATALOG_ITEM_LABELS,
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
  AI_CATALOG_TYPE_FLOW,
} from 'ee/ai/catalog/constants';
import {
  exploreAiCatalogAgentPath,
  exploreAiCatalogFlowPath,
} from 'ee/lib/utils/path_helpers/explore';
import { prerequisitesError } from '../utils';
import aiCatalogAgentQuery from '../graphql/queries/ai_catalog_agent.query.graphql';
import aiCatalogFlowQuery from '../graphql/queries/ai_catalog_flow.query.graphql';
import updateAiCatalogConfiguredItem from '../graphql/mutations/update_ai_catalog_item_consumer.mutation.graphql';

const AGENT_MESSAGES = {
  groupUpdateMessage: s__(
    "AICatalog|Updating an agent in this group does not update the agents enabled in this group's projects.",
  ),
  projectUpdateMessage: s__(
    'AICatalog|Only this agent in this project will be updated. Other projects using this agent will not be affected.',
  ),
  successMessage: s__('AICatalog|Agent is now at version %{newVersion}.'),
};

const ITEM_TYPE_MESSAGES = {
  [AI_CATALOG_TYPE_FLOW]: {
    groupUpdateMessage: s__(
      "AICatalog|Updating a flow in this group does not update the flows enabled in this group's projects.",
    ),
    projectUpdateMessage: s__(
      'AICatalog|Only this flow in this project will be updated. Other projects using this flow will not be affected.',
    ),
    successMessage: s__('AICatalog|Flow is now at version %{newVersion}.'),
  },
  [AI_CATALOG_TYPE_AGENT]: AGENT_MESSAGES,
  [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: AGENT_MESSAGES,
};

export default {
  name: 'VersionAlert',
  components: {
    GlAlert,
  },
  mixins: [GlToastMixin],
  inject: {
    isProjectNamespace: {},
    isGroupNamespace: {},
  },
  props: {
    itemType: {
      type: String,
      required: true,
      validator: (value) =>
        [AI_CATALOG_TYPE_FLOW, AI_CATALOG_TYPE_AGENT, AI_CATALOG_TYPE_THIRD_PARTY_FLOW].includes(
          value,
        ),
    },
    itemId: {
      type: String,
      required: true,
    },
    configuration: {
      type: Object,
      required: true,
    },
    latestVersion: {
      type: Object,
      required: true,
    },
  },
  emits: ['error'],
  computed: {
    updateMessage() {
      const messages = ITEM_TYPE_MESSAGES[this.itemType];
      return this.isGroupNamespace ? messages.groupUpdateMessage : messages.projectUpdateMessage;
    },
    exploreItemUrl() {
      const itemId = getIdFromGraphQLId(this.itemId);
      if (this.itemType === AI_CATALOG_TYPE_FLOW) {
        return exploreAiCatalogFlowPath(itemId);
      }
      // AI_CATALOG_TYPE_AGENT and AI_CATALOG_TYPE_THIRD_PARTY_FLOW
      return exploreAiCatalogAgentPath(itemId);
    },
    refetchQuery() {
      switch (this.itemType) {
        case AI_CATALOG_TYPE_FLOW:
          return aiCatalogFlowQuery;
        default:
          // AI_CATALOG_TYPE_AGENT and AI_CATALOG_TYPE_THIRD_PARTY_FLOW
          return aiCatalogAgentQuery;
      }
    },
  },
  methods: {
    viewLatestVersion() {
      visitUrl(this.exploreItemUrl, true);
    },
    emitUpdateError(error) {
      const targetType = this.isProjectNamespace
        ? AI_CATALOG_CONSUMER_TYPE_PROJECT
        : AI_CATALOG_CONSUMER_TYPE_GROUP;
      this.$emit('error', {
        errors: [
          prerequisitesError(s__('AICatalog|Could not update %{itemType} in the %{target}.'), {
            target: AI_CATALOG_CONSUMER_LABELS[targetType],
            itemType: AI_CATALOG_ITEM_LABELS[this.itemType],
          }),
        ],
      });
      Sentry.captureException(error);
    },
    async updateVersion() {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: updateAiCatalogConfiguredItem,
          variables: {
            input: {
              id: this.configuration.id,
              pinnedVersionPrefix: this.latestVersion.versionName,
            },
          },
          refetchQueries: [this.refetchQuery],
        });
        if (!data) {
          // eslint-disable-next-line @gitlab/require-i18n-strings -- Sentry message, not user-facing UI
          this.emitUpdateError(new Error('AI Catalog update returned null data'));
          return;
        }

        const { errors } = data.aiCatalogItemConsumerUpdate;
        if (errors.length > 0) {
          this.$emit('error', {
            title: sprintf(s__('AICatalog|Could not update %{itemType}.'), {
              itemType: AI_CATALOG_ITEM_LABELS[this.itemType],
            }),
            errors,
          });
          return;
        }

        this.$toast.show(
          sprintf(ITEM_TYPE_MESSAGES[this.itemType].successMessage, {
            newVersion: data.aiCatalogItemConsumerUpdate.itemConsumer.pinnedVersionPrefix,
          }),
        );
      } catch (error) {
        this.emitUpdateError(error);
      }
    },
  },
};
</script>

<template>
  <!-- eslint-disable vue/v-on-event-hyphenation -->
  <gl-alert
    :dismissible="false"
    :title="s__('AICatalog|A new version is available')"
    :primary-button-text="s__('AICatalog|Update')"
    :secondary-button-text="s__('AICatalog|View latest version')"
    @primaryAction="updateVersion"
    @secondaryAction="viewLatestVersion"
  >
    {{ updateMessage }}
  </gl-alert>
  <!-- eslint-enable vue/v-on-event-hyphenation -->
</template>

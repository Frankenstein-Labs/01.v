<script>
import { GlAlert, GlToastMixin } from '@gitlab/ui';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { __, s__, sprintf } from '~/locale';
import { InternalEvents } from '~/tracking';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import {
  AI_CATALOG_CONSUMER_TYPE_GROUP,
  AI_CATALOG_CONSUMER_TYPE_PROJECT,
  AI_CATALOG_CONSUMER_LABELS,
  TRACK_EVENT_VIEW_AI_CATALOG_ITEM,
} from 'ee/ai/catalog/constants';
import { buildAiCatalogEventProperties } from 'ee/ai/catalog/event_properties';
import FoundationalIcon from 'ee/ai/components/foundational_icon.vue';
import { isAiCatalogItemRestricted } from '../capabilities';
import { isItemTypeEnabledInDuoSettings } from '../permissions';
import {
  prerequisitesError,
  itemTypeDisabledAlertLink,
  getByVersionKey,
  isGitLabMaintainedItem,
} from '../utils';
import AiCatalogItemActions from '../components/ai_catalog_item_actions.vue';
import AiCatalogItemView from '../components/ai_catalog_item_view.vue';
import VersionAlert from '../components/version_alert.vue';
import createAiCatalogItemConsumer from '../graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import createAiCatalogItemConsumerBulk from '../graphql/mutations/create_ai_catalog_item_consumer_bulk.mutation.graphql';
import reportAiCatalogItem from '../graphql/mutations/report_ai_catalog_item.mutation.graphql';
import deleteAiCatalogItemConsumer from '../graphql/mutations/delete_ai_catalog_item_consumer.mutation.graphql';
import AiCatalogItemMetadata from '../components/ai_catalog_item_metadata.vue';
import { getRegistryItem } from '../item_type_registry';

export default {
  name: 'AiCatalogItemShow',
  components: {
    AiCatalogItemMetadata,
    GlAlert,
    FoundationalIcon,
    ErrorsAlert,
    PageHeading,
    AiCatalogItemActions,
    AiCatalogItemView,
    VersionAlert,
  },
  directives: {
    SafeHtml,
  },
  mixins: [InternalEvents.mixin(), glAbilitiesMixin(), glFeatureFlagsMixin(), GlToastMixin],
  inject: {
    isGlobalNamespace: {},
    isProjectNamespace: {},
    duoSettings: {
      default: {},
    },
    projectId: {
      default: null,
    },
  },
  props: {
    aiCatalogItem: {
      type: Object,
      required: true,
    },
    version: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      errors: [],
      errorTitle: null,
    };
  },
  computed: {
    canAdmin() {
      return Boolean(this.glAbilities.adminAiCatalogItem);
    },
    itemType() {
      return this.aiCatalogItem.itemType;
    },
    itemRegistry() {
      return getRegistryItem(this.itemType);
    },
    isItemTypeEnabled() {
      if (this.isGlobalNamespace) return true;
      return isItemTypeEnabledInDuoSettings({
        duoSettings: this.duoSettings,
        itemType: this.itemType,
      });
    },
    isGitLabMaintained() {
      return isGitLabMaintainedItem(this.aiCatalogItem);
    },
    disabledItemTypeMessage() {
      const message = this.canAdmin
        ? this.itemRegistry.index.itemTypeDisabledCanAdminAlert
        : this.itemRegistry.index.itemTypeDisabledAlert;
      return itemTypeDisabledAlertLink(message, this.duoSettings.duoSettingsPath);
    },
    showConfig() {
      return this.itemRegistry.show;
    },
    configuration() {
      return this.isProjectNamespace
        ? this.aiCatalogItem.configurationForProject
        : this.aiCatalogItem.configurationForGroup;
    },
    namespaceTypeLabel() {
      return this.isProjectNamespace
        ? AI_CATALOG_CONSUMER_LABELS[AI_CATALOG_CONSUMER_TYPE_PROJECT]
        : AI_CATALOG_CONSUMER_LABELS[AI_CATALOG_CONSUMER_TYPE_GROUP];
    },
    disableConfirmMessage() {
      return this.isProjectNamespace
        ? this.itemRegistry.disable.confirmMessageProject
        : this.itemRegistry.disable.confirmMessageGroup;
    },
    itemRoutes() {
      const { duplicate, edit } = this.itemRegistry.routes;
      return { duplicate, edit };
    },
    activeVersion() {
      return getByVersionKey(this.aiCatalogItem, this.version.activeVersionKey);
    },
    canEnableOnMultipleProjects() {
      const isPublicOrRestricted =
        this.aiCatalogItem.public || isAiCatalogItemRestricted(this.aiCatalogItem, this.glFeatures);
      return isPublicOrRestricted && this.glFeatures.aiCatalogBulkItemConsumerCreate;
    },
    enableMutation() {
      return this.canEnableOnMultipleProjects
        ? createAiCatalogItemConsumerBulk
        : createAiCatalogItemConsumer;
    },
  },
  mounted() {
    this.trackEvent(TRACK_EVENT_VIEW_AI_CATALOG_ITEM, {
      label: this.itemRegistry.trackLabel,
      ...buildAiCatalogEventProperties(this.aiCatalogItem, { version: this.activeVersion }),
    });
  },
  methods: {
    setErrors({ title = null, errors = [] } = {}) {
      this.errorTitle = title;
      this.errors = errors;
    },
    handleEnableError(error, targetTypeLabel) {
      if (Array.isArray(error)) {
        this.setErrors({
          title: this.showConfig.enableErrorTitle,
          errors: error,
        });
      } else {
        this.setErrors({
          errors: [
            prerequisitesError(this.showConfig.enableErrorTemplate, { target: targetTypeLabel }),
          ],
        });
        Sentry.captureException(error);
      }
    },
    showEnableToast({ name, href }) {
      this.setErrors();
      const message = sprintf(this.showConfig.enableToastTemplate, { name });
      if (href) {
        this.$toast.show(message, { action: { text: __('View'), href } });
      } else {
        this.$toast.show(message);
      }
    },
    async addItemToTarget({ target, triggerTypes, triggerFilter }) {
      const isGroupTarget = Boolean(target.groupId);
      const targetType = isGroupTarget
        ? AI_CATALOG_CONSUMER_TYPE_GROUP
        : AI_CATALOG_CONSUMER_TYPE_PROJECT;
      const targetTypeLabel = AI_CATALOG_CONSUMER_LABELS[targetType];

      const input = {
        itemId: this.aiCatalogItem.id,
      };

      const pinnedVersion = getByVersionKey(
        this.aiCatalogItem,
        this.version.activeVersionKey,
      )?.versionName;
      if (pinnedVersion && !this.canEnableOnMultipleProjects) {
        input.pinnedVersion = pinnedVersion;
      }

      if (this.canEnableOnMultipleProjects) {
        input.projectIds = target;
      } else {
        input.target = target;
      }

      if (!isGroupTarget && triggerTypes) {
        input.triggerTypes = triggerTypes;
        if (triggerFilter && Object.keys(triggerFilter).length > 0) {
          input.triggerFilter = triggerFilter;
        }
      }

      try {
        const { data } = await this.$apollo.mutate({
          mutation: this.enableMutation,
          variables: { input },
          refetchQueries: [this.itemRegistry.queries.item],
          awaitRefetchQueries: true,
        });

        if (this.canEnableOnMultipleProjects) {
          const { errors } = data.aiCatalogItemConsumerBulkCreate;
          if (errors.length > 0) {
            throw errors;
          }

          this.setErrors();
          this.$toast.show(s__('AICatalog|Enabled in selected project(s).'));
        } else {
          const { errors } = data.aiCatalogItemConsumerCreate;
          if (errors.length > 0) {
            throw errors;
          }

          const { itemConsumer } = data.aiCatalogItemConsumerCreate;
          const targetData = itemConsumer[targetType];
          const isCurrentProject =
            this.isProjectNamespace && getIdFromGraphQLId(targetData.id) === Number(this.projectId);
          const showViewLink = this.isGlobalNamespace || !isCurrentProject;
          this.showEnableToast({
            name: targetData.name,
            href: showViewLink ? itemConsumer.webPath : null,
          });
        }
      } catch (error) {
        this.handleEnableError(error, targetTypeLabel);
      }
    },
    async deleteItem(forceHardDelete) {
      const { id } = this.aiCatalogItem;
      const config = this.itemRegistry.mutations.delete;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: config.mutation,
          variables: { id, forceHardDelete },
        });

        const deleteResponse = data[config.responseKey];
        if (!deleteResponse.success) {
          this.setErrors({
            errors: [
              sprintf(this.showConfig.deleteErrorTemplate, {
                error: deleteResponse.errors?.[0],
              }),
            ],
          });
          return;
        }

        const toastMessage = forceHardDelete
          ? this.showConfig.hardDeletedToast
          : this.showConfig.softDeletedToast;
        this.$toast.show(toastMessage);
        this.$router.push({ name: this.itemRegistry.routes.list });
      } catch (error) {
        this.setErrors({
          errors: [sprintf(this.showConfig.deleteErrorTemplate, { error })],
        });
        Sentry.captureException(error);
      }
    },
    async disableItem() {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: deleteAiCatalogItemConsumer,
          variables: { id: this.configuration.id },
          refetchQueries: [this.itemRegistry.queries.item],
          awaitRefetchQueries: true,
        });

        if (!data.aiCatalogItemConsumerDelete.success) {
          this.setErrors({
            errors: [
              sprintf(this.showConfig.disableErrorTemplate, {
                error: data.aiCatalogItemConsumerDelete.errors?.[0],
              }),
            ],
          });
          return;
        }

        this.version.setActiveVersionKey(null); // let the parent re-compute this
        this.$toast.show(
          sprintf(this.itemRegistry.disable.success, { namespaceType: this.namespaceTypeLabel }),
        );
      } catch (error) {
        this.setErrors({
          errors: [sprintf(this.showConfig.disableErrorTemplate, { error })],
        });
        Sentry.captureException(error);
      }
    },
    async reportItem({ reason, body }) {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: reportAiCatalogItem,
          variables: { input: { id: this.aiCatalogItem.id, reason, body } },
        });

        if (data.aiCatalogItemReport.errors?.length > 0) {
          this.setErrors({ errors: data.aiCatalogItemReport.errors });
          return;
        }

        this.$toast.show(s__('AICatalog|Report submitted successfully.'));
      } catch (error) {
        this.setErrors({
          errors: [sprintf(this.showConfig.reportErrorTemplate, { error })],
        });
        Sentry.captureException(error);
      }
    },
    dismissErrors() {
      this.setErrors();
    },
  },
};
</script>

<template>
  <div>
    <errors-alert class="gl-mt-5" :title="errorTitle" :errors="errors" @dismiss="dismissErrors" />
    <gl-alert
      v-if="!isItemTypeEnabled"
      data-testid="disabled-type-alert"
      class="gl-my-5"
      :dismissible="false"
    >
      <span v-safe-html="disabledItemTypeMessage"></span>
    </gl-alert>
    <page-heading>
      <template #heading>
        <div class="gl-flex gl-items-baseline gl-gap-3">
          <span class="gl-line-clamp-1 gl-wrap-anywhere">
            {{ aiCatalogItem.name }}
          </span>
          <foundational-icon
            v-if="isGitLabMaintained"
            :resource-id="aiCatalogItem.id"
            :item-type="aiCatalogItem.itemType"
          />
        </div>
      </template>
      <template #description>
        <ai-catalog-item-metadata :item="aiCatalogItem" :version-key="version.activeVersionKey" />
        <div
          v-if="aiCatalogItem.descriptionHtml"
          v-safe-html="aiCatalogItem.descriptionHtml"
          class="md"
        ></div>
        <p v-else-if="aiCatalogItem.description">{{ aiCatalogItem.description }}</p>
        <version-alert
          v-if="version.isUpdateAvailable"
          :configuration="configuration"
          :item-id="aiCatalogItem.id"
          :item-type="aiCatalogItem.itemType"
          :latest-version="aiCatalogItem.latestVersion"
          class="gl-mt-4"
          @error="setErrors"
        />
      </template>
      <template #actions>
        <ai-catalog-item-actions
          :item="aiCatalogItem"
          :version="activeVersion"
          :item-routes="itemRoutes"
          :disable-fn="disableItem"
          :delete-fn="deleteItem"
          :disable-confirm-message="disableConfirmMessage"
          @add-to-target="addItemToTarget"
          @report-item="reportItem"
        />
      </template>
    </page-heading>
    <ai-catalog-item-view :item="aiCatalogItem" :version-key="version.activeVersionKey" />
  </div>
</template>

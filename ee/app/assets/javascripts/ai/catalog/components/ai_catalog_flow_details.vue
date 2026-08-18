<script>
import { GlLink } from '@gitlab/ui';
import {
  FLOW_VISIBILITY_LEVEL_DESCRIPTIONS,
  FOUNDATIONAL_FLOW_REFERENCE_CODE_REVIEW,
} from '../constants';
import { getByVersionKey, isGitLabMaintainedItem } from '../utils';
import AiCatalogItemField from './ai_catalog_item_field.vue';
import AiCatalogItemFieldServiceAccount from './ai_catalog_item_field_service_account.vue';
import AiCatalogItemVisibilityField from './ai_catalog_item_visibility_field.vue';
import TriggerField from './trigger_field.vue';
import FormFlowDefinition from './form_flow_definition.vue';
import FormSection from './form_section.vue';

export default {
  name: 'AiCatalogFlowDetails',
  components: {
    GlLink,
    AiCatalogItemField,
    AiCatalogItemFieldServiceAccount,
    AiCatalogItemVisibilityField,
    FormFlowDefinition,
    FormSection,
    TriggerField,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
    versionKey: {
      type: String,
      required: true,
    },
  },
  computed: {
    isGitLabMaintained() {
      return isGitLabMaintainedItem(this.item);
    },
    projectName() {
      return this.item.project?.nameWithNamespace;
    },
    hasProjectConfiguration() {
      return Boolean(this.item.configurationForProject);
    },
    definition() {
      return getByVersionKey(this.item, this.versionKey).definition;
    },
    serviceAccount() {
      if (this.hasProjectConfiguration && !this.item.foundational) {
        return this.item.configurationForProject?.flowTrigger?.user;
      }
      return this.item.configurationForGroup?.serviceAccount;
    },
    isCodeReviewFoundational() {
      return (
        this.item.foundational &&
        this.item.foundationalFlowReference === FOUNDATIONAL_FLOW_REFERENCE_CODE_REVIEW
      );
    },
    hasConfigurationContent() {
      if (this.isCodeReviewFoundational) return false;
      return Boolean(this.hasProjectConfiguration || !this.item.foundational);
    },
  },
  FLOW_VISIBILITY_LEVEL_DESCRIPTIONS,
};
</script>

<template>
  <div>
    <h3 class="gl-heading-3 gl-mb-4 gl-mt-0 gl-font-semibold">
      {{ s__('AICatalog|Flow configuration') }}
    </h3>
    <dl class="gl-flex gl-flex-col gl-gap-5">
      <form-section :title="s__('AICatalog|Visibility & access')" is-display>
        <ai-catalog-item-field
          v-if="projectName || isGitLabMaintained"
          :title="s__('AICatalog|Managed by')"
          data-testid="managed-by-field"
        >
          <gl-link v-if="!isGitLabMaintained" :href="item.project.webUrl">{{
            projectName
          }}</gl-link>
          <span v-else>{{ s__('AICatalog|GitLab') }}</span>
        </ai-catalog-item-field>
        <ai-catalog-item-visibility-field
          :public="item.public"
          :visibility="item.visibility"
          :description-texts="$options.FLOW_VISIBILITY_LEVEL_DESCRIPTIONS"
        />
      </form-section>
      <form-section v-if="serviceAccount" :title="s__('AICatalog|Service account')" is-display>
        <ai-catalog-item-field-service-account
          :service-account="serviceAccount"
          :item-type="item.itemType"
          :foundational-flow-reference="item.foundationalFlowReference"
          data-testid="service-account-field"
        />
      </form-section>
      <form-section
        v-if="hasConfigurationContent"
        :title="s__('AICatalog|Configuration')"
        is-display
      >
        <trigger-field v-if="hasProjectConfiguration" :item="item" />
        <ai-catalog-item-field
          v-if="!item.foundational"
          :title="s__('AICatalog|YAML configuration')"
          data-testid="configuration-field"
        >
          <form-flow-definition :value="definition" read-only class="gl-mt-3" />
        </ai-catalog-item-field>
      </form-section>
    </dl>
  </div>
</template>

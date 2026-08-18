<script>
import { GlAlert } from '@gitlab/ui';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import {
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
  AI_CATALOG_ITEM_CONSUMER_DISCLAIMER_TEXTS,
} from '../constants';

export default {
  name: 'AiCatalogItemConsumerDisclaimer',
  components: {
    GlAlert,
    HelpPageLink,
  },
  props: {
    itemType: {
      type: String,
      required: true,
      validator: (value) =>
        [AI_CATALOG_TYPE_AGENT, AI_CATALOG_TYPE_FLOW, AI_CATALOG_TYPE_THIRD_PARTY_FLOW].includes(
          value,
        ),
    },
    canEnable: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    disclaimerTexts() {
      return AI_CATALOG_ITEM_CONSUMER_DISCLAIMER_TEXTS[this.itemType];
    },
    isAgent() {
      return this.itemType === AI_CATALOG_TYPE_AGENT;
    },
  },
};
</script>

<template>
  <gl-alert variant="info" :dismissible="false">
    <template v-if="canEnable">
      <ul v-if="isAgent" class="gl-mb-0 gl-pl-5">
        <li>{{ disclaimerTexts.enabledForMembers }}</li>
        <li>{{ disclaimerTexts.projectAccess }}</li>
      </ul>
      <p v-else class="gl-mb-0">
        {{ disclaimerTexts.compositeIdentity }}
        <help-page-link href="user/duo_agent_platform/composite_identity">{{
          s__('AICatalog|Learn more about composite identity.')
        }}</help-page-link>
      </p>
    </template>
    <p v-else class="gl-mb-0">{{ disclaimerTexts.restricted }}</p>
  </gl-alert>
</template>

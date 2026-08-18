<script>
import { GlLink, GlSprintf, GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { AI_CATALOG_ITEM_LABELS, FOUNDATIONAL_FLOW_REFERENCE_CODE_REVIEW } from '../constants';
import AiCatalogItemField from './ai_catalog_item_field.vue';
import ServiceAccountProjectMemberships from './service_account_project_memberships.vue';
import ServiceAccountAvatar from './service_account_avatar.vue';

export default {
  name: 'AiCatalogItemFieldServiceAccount',
  components: {
    GlLink,
    GlSprintf,
    GlButton,
    AiCatalogItemField,
    ServiceAccountProjectMemberships,
    ServiceAccountAvatar,
  },
  props: {
    serviceAccount: {
      type: Object,
      required: true,
    },
    itemType: {
      type: String,
      required: true,
    },
    foundationalFlowReference: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      isDrawerOpen: false,
    };
  },
  computed: {
    itemTypeLabel() {
      return AI_CATALOG_ITEM_LABELS[this.itemType];
    },
    isCodeReviewFoundational() {
      return this.foundationalFlowReference === FOUNDATIONAL_FLOW_REFERENCE_CODE_REVIEW;
    },
    helpMessage() {
      if (this.isCodeReviewFoundational) {
        return s__(
          'AICatalog|This %{linkStart}service account%{linkEnd} is created automatically and used internally by the Code Review flow. To trigger the flow, assign %{boldStart}@GitLabDuo%{boldEnd} as a reviewer on a merge request — do not assign or mention this account.',
        );
      }
      return s__(
        'AICatalog|%{linkStart}Service accounts%{linkEnd} represent non-human entities. This is the account that you mention or assign to trigger the %{itemType}.',
      );
    },
  },
  methods: {
    openDrawer() {
      this.isDrawerOpen = true;
    },
    closeDrawer() {
      this.isDrawerOpen = false;
    },
  },
  serviceAccountsDocsLink: helpPagePath('user/profile/service_accounts'),
};
</script>

<template>
  <ai-catalog-item-field>
    <p class="gl-mb-0 gl-text-subtle">
      <gl-sprintf :message="helpMessage">
        <template #link="{ content }">
          <gl-link :href="$options.serviceAccountsDocsLink">{{ content }}</gl-link>
        </template>
        <template #itemType>{{ itemTypeLabel }}</template>
        <template #bold="{ content }">
          <strong>{{ content }}</strong>
        </template>
      </gl-sprintf>
    </p>
    <service-account-avatar :service-account="serviceAccount" class="gl-mt-3" />
    <br />
    <gl-button category="tertiary" variant="link" class="gl-mt-3" @click="openDrawer">
      {{ s__('AICatalog|View projects and permissions of this service account') }}
    </gl-button>
    <service-account-project-memberships
      :service-account="serviceAccount"
      :is-open="isDrawerOpen"
      @close="closeDrawer"
    />
  </ai-catalog-item-field>
</template>

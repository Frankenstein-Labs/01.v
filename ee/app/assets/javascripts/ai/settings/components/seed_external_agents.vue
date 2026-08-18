<script>
import { GlButton, GlCard, GlToastMixin } from '@gitlab/ui';
import { s__ } from '~/locale';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_CREATED } from '~/lib/utils/http_status';
import {
  AI_CATALOG_ALREADY_SEEDED_ERROR,
  AI_CATALOG_SEED_EXTERNAL_AGENTS_PATH,
} from '../constants';

export default {
  name: 'SeedExternalAgents',
  components: {
    GlButton,
    GlCard,
  },
  mixins: [GlToastMixin],
  data() {
    return {
      isLoadingSeedExternalAgents: false,
      isDisabledSeedExternalAgents: false,
    };
  },
  methods: {
    async seedExternalAgents() {
      this.isLoadingSeedExternalAgents = true;
      try {
        const response = await axios.post(AI_CATALOG_SEED_EXTERNAL_AGENTS_PATH);
        if (response.status === HTTP_STATUS_CREATED) {
          this.$toast.show(s__('AICatalog|Agents successfully added to AI Catalog.'));
          this.isDisabledSeedExternalAgents = true;
        }
      } catch (e) {
        if (e?.response?.data?.message === AI_CATALOG_ALREADY_SEEDED_ERROR) {
          this.$toast.show(s__('AICatalog|Agents already in AI Catalog.'));
          this.isDisabledSeedExternalAgents = true;
        } else {
          this.$toast.show(s__('AICatalog|Failed to add agents to AI Catalog.'));
        }
      } finally {
        this.isLoadingSeedExternalAgents = false;
      }
    },
  },
};
</script>

<template>
  <gl-card
    header-class="gl-heading-scale-300"
    footer-class="gl-bg-transparent gl-border-none gl-flex-end"
  >
    <template #header>
      <h3 class="gl-m-0">{{ s__('AICatalog|GitLab-managed external agents') }}</h3>
    </template>
    <template #default>
      <p class="gl-mb-0">
        {{ s__("AICatalog|Add GitLab-managed external agents to the instance's AI Catalog.") }}
      </p>
    </template>
    <template #footer>
      <gl-button
        data-testid="seed-external-agents-button"
        variant="default"
        category="primary"
        :loading="isLoadingSeedExternalAgents"
        :disabled="isDisabledSeedExternalAgents"
        @click="seedExternalAgents"
      >
        {{ s__('AICatalog|Add to AI Catalog') }}
      </gl-button>
    </template>
  </gl-card>
</template>

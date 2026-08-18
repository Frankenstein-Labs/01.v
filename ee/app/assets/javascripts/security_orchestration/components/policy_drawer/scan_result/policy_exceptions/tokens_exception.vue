<script>
import { GlAccordion, GlAccordionItem } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';

export default {
  name: 'TokensException',
  components: {
    GlAccordion,
    GlAccordionItem,
  },
  inject: ['availableAccessTokens'],
  props: {
    tokens: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  computed: {
    hasAvailableTokens() {
      return this.availableAccessTokens?.length > 0;
    },
    selectedTokensIds() {
      return this.tokens?.map(({ id }) => id) || [];
    },
    selectedTokens() {
      return (
        this.availableAccessTokens?.filter(({ id }) => this.selectedTokensIds.includes(id)) || []
      );
    },
    title() {
      return sprintf(s__('SecurityOrchestration|Access tokens (%{count})'), {
        count: this.tokens.length,
      });
    },
  },
};
</script>

<template>
  <gl-accordion :header-level="3">
    <gl-accordion-item :title="title">
      <ul v-if="hasAvailableTokens" class="gl-list-none gl-pl-4" data-testid="token-list">
        <li v-for="token in selectedTokens" :key="token.id" data-testid="token-item">
          {{ token.name }}
        </li>
      </ul>
      <ul v-else class="gl-list-none gl-pl-4" data-testid="token-list-fallback">
        <li v-for="token in tokens" :key="token.id" data-testid="token-item-fallback">
          {{ __('id:') }} {{ token.id }}
        </li>
      </ul>
    </gl-accordion-item>
  </gl-accordion>
</template>

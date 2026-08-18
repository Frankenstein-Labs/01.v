<script>
import { GlAccordion, GlAccordionItem } from '@gitlab/ui';
import { s__, __, sprintf } from '~/locale';
import Api from '~/api';
import PolicyExceptionsLoader from './policy_exceptions_loader.vue';

export default {
  i18n: {
    label: __('Loading accounts'),
  },
  name: 'ServiceAccountsException',
  components: {
    GlAccordion,
    GlAccordionItem,
    PolicyExceptionsLoader,
  },
  inject: ['rootNamespacePath'],
  props: {
    serviceAccounts: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      loadingError: false,
      loading: false,
      accounts: [],
    };
  },
  computed: {
    title() {
      return sprintf(s__('SecurityOrchestration|Accounts exceptions (%{count})'), {
        count: this.serviceAccounts.length,
      });
    },
    serviceAccountsIds() {
      return this.serviceAccounts.map(({ id }) => id);
    },
    selectedAccounts() {
      return this.accounts?.filter(({ id }) => this.serviceAccountsIds.includes(id)) || [];
    },
    hasLoadedAccounts() {
      return this.accounts?.length > 0;
    },
  },
  methods: {
    async loadAccounts() {
      try {
        this.loading = true;
        this.loadingError = false;

        const { data = [] } = await Api.groupServiceAccounts(this.rootNamespacePath);
        this.accounts = data;
      } catch {
        this.loadingError = true;
        this.accounts = [];
      } finally {
        this.loading = false;
      }
    },
    toggleAccordion(opened) {
      if (opened && !this.hasLoadedAccounts) {
        this.loadAccounts();
      }
    },
  },
};
</script>

<template>
  <div>
    <gl-accordion :header-level="3">
      <gl-accordion-item :title="title" @input="toggleAccordion">
        <div v-if="loadingError">
          <ul class="gl-list-none gl-pl-4">
            <li
              v-for="account in serviceAccounts"
              :key="account.id"
              data-testid="backup-account-item"
            >
              {{ __('id:') }} {{ account.id }}
            </li>
          </ul>
        </div>
        <div v-else>
          <policy-exceptions-loader v-if="loading" class="gl-mb-2" :label="$options.i18n.label" />
          <ul v-else class="gl-list-none gl-pl-4">
            <li
              v-for="account in selectedAccounts"
              :key="account.id"
              class="gl-mb-2"
              data-testid="account-item"
            >
              {{ account.name }}
            </li>
          </ul>
        </div>
      </gl-accordion-item>
    </gl-accordion>
  </div>
</template>

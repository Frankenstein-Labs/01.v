<script>
import {
  GlAlert,
  GlButton,
  GlFormInput,
  GlKeysetPagination,
  GlSearchBoxByType,
  GlToastMixin,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import autofocusonshow from '~/vue_shared/directives/autofocusonshow';
import getAiDomainSettings from '../graphql/queries/get_ai_domain_settings.query.graphql';
import getGroupAiDomainSettings from '../graphql/queries/get_group_ai_domain_settings.query.graphql';
import aiDomainSettingsInstanceUpdateMutation from '../graphql/mutations/ai_domain_settings_instance_update.mutation.graphql';
import aiDomainSettingsNamespaceUpdateMutation from '../graphql/mutations/ai_domain_settings_namespace_update.mutation.graphql';

const PAGE_SIZE = 20;

export default {
  name: 'DomainListCard',

  components: {
    CrudComponent,
    GlAlert,
    GlButton,
    GlFormInput,
    GlKeysetPagination,
    GlSearchBoxByType,
  },

  directives: {
    autofocusonshow,
  },
  mixins: [GlToastMixin],

  props: {
    domainType: {
      type: String,
      required: true,
      validator: (value) => ['ALLOWED', 'DENIED'].includes(value),
    },
    title: {
      type: String,
      required: true,
    },
    emptyStateText: {
      type: String,
      required: true,
    },
    errorText: {
      type: String,
      required: true,
    },
    groupFullPath: {
      type: String,
      required: false,
      default: null,
    },
  },

  i18n: {
    addDomain: s__('AiPowered|Add domain'),
    search: s__('AiPowered|Search'),
    searchDomains: s__('AiPowered|Search domains'),
    remove: s__('AiPowered|Remove'),
    add: s__('AiPowered|Add'),
    domainAdded: s__('AiPowered|Domain added.'),
    domainRemoved: s__('AiPowered|Domain removed.'),
    mutationFailed: s__('AiPowered|An error occurred. Please try again.'),
    domainEmpty: s__('AiPowered|Domain cannot be empty.'),
  },

  apollo: {
    domains: {
      query() {
        return this.groupFullPath ? getGroupAiDomainSettings : getAiDomainSettings;
      },
      variables() {
        return this.queryVariables;
      },
      update(data) {
        const settings = this.groupFullPath
          ? data.namespace?.aiDomainSettings
          : data.aiDomainSettings;
        return settings?.nodes ?? [];
      },
      result({ data }) {
        const settings = this.groupFullPath
          ? data?.namespace?.aiDomainSettings
          : data?.aiDomainSettings;
        this.pageInfo = settings?.pageInfo ?? {};
        const isFirstPage = !this.cursor.after && !this.cursor.before;
        if (!this.searchTerm && isFirstPage) {
          const nodeCount = settings?.nodes?.length ?? 0;
          this.totalCount = this.pageInfo.hasNextPage ? `${nodeCount}+` : nodeCount;
        }
        if (this.groupFullPath) {
          this.namespaceId = data?.namespace?.id ?? null;
        }
        this.hasLoadedOnce = true;
      },
      error() {
        this.hasError = true;
      },
      debounce: DEFAULT_DEBOUNCE_AND_THROTTLE_MS,
    },
  },

  data() {
    return {
      domains: [],
      cursor: { first: PAGE_SIZE },
      pageInfo: {},
      totalCount: 0,
      hasError: false,
      hasLoadedOnce: false,
      newDomain: '',
      searchTerm: '',
      isSearchMode: false,
      namespaceId: null,
      isSaving: false,
      mutationError: '',
    };
  },

  computed: {
    isLoading() {
      return this.$apollo.queries.domains.loading && !this.hasLoadedOnce;
    },
    queryVariables() {
      return {
        type: this.domainType,
        ...this.cursor,
        ...(this.searchTerm && { search: this.searchTerm }),
        ...(this.groupFullPath && { fullPath: this.groupFullPath }),
      };
    },
    mutation() {
      return this.groupFullPath
        ? aiDomainSettingsNamespaceUpdateMutation
        : aiDomainSettingsInstanceUpdateMutation;
    },

    canSearch() {
      return this.domains.length > 0 || (this.searchTerm && !this.isSearchMode);
    },
  },

  methods: {
    buildMutationVariables(action, domains) {
      return {
        input: {
          action,
          domainSettingType: this.domainType,
          domains,
          ...(this.groupFullPath && { namespaceId: this.namespaceId }),
        },
      };
    },
    getMutationErrors(data) {
      const responseKey = this.groupFullPath
        ? 'aiDomainSettingsNamespaceUpdate'
        : 'aiDomainSettingsInstanceUpdate';

      return data?.[responseKey]?.errors ?? [];
    },
    async addDomain(hideForm) {
      if (this.isSaving) return;

      const domain = this.newDomain.trim();
      if (!domain) {
        this.mutationError = this.$options.i18n.domainEmpty;
        return;
      }

      this.isSaving = true;
      this.mutationError = '';

      try {
        const { data } = await this.$apollo.mutate({
          mutation: this.mutation,
          variables: this.buildMutationVariables('ADD', [domain]),
        });
        const errors = this.getMutationErrors(data);

        if (errors.length) {
          this.mutationError = errors.join(', ');
          return;
        }

        await this.$apollo.queries.domains.refetch();
        this.$toast.show(this.$options.i18n.domainAdded);
        hideForm();
        this.clearSearch();
        this.newDomain = '';
      } catch {
        this.mutationError = this.$options.i18n.mutationFailed;
      } finally {
        this.isSaving = false;
      }
    },
    async removeDomain(domain) {
      if (this.isSaving) return;

      this.isSaving = true;
      this.mutationError = '';

      try {
        const { data } = await this.$apollo.mutate({
          mutation: this.mutation,
          variables: this.buildMutationVariables('REMOVE', [domain]),
        });
        const errors = this.getMutationErrors(data);

        if (errors.length) {
          this.mutationError = errors.join(', ');
          return;
        }

        await this.$apollo.queries.domains.refetch();
        this.$toast.show(this.$options.i18n.domainRemoved);
      } catch {
        this.mutationError = this.$options.i18n.mutationFailed;
      } finally {
        this.isSaving = false;
      }
    },
    resetCursor() {
      this.cursor = { first: PAGE_SIZE };
    },
    handleNextPage() {
      this.cursor = { first: PAGE_SIZE, after: this.pageInfo.endCursor };
    },
    handlePrevPage() {
      this.cursor = { last: PAGE_SIZE, before: this.pageInfo.startCursor };
    },
    toggleSearch(showForm, isFormVisible) {
      if (isFormVisible && this.isSearchMode) {
        this.$refs.crud.hideForm();
        return;
      }
      this.isSearchMode = true;
      showForm();
      this.$nextTick(() => {
        this.$refs.searchInput?.focusInput();
      });
    },
    toggleAdd(showForm, isFormVisible) {
      if (isFormVisible && !this.isSearchMode) {
        this.$refs.crud.hideForm();
        return;
      }
      if (this.isSearchMode) {
        this.newDomain = this.searchTerm;
      }
      this.isSearchMode = false;
      showForm();
    },
    clearSearch() {
      this.searchTerm = '';
      this.resetCursor();
    },
    onSearchInput(term) {
      this.searchTerm = term;
      this.resetCursor();
    },
  },
};
</script>

<template>
  <div>
    <gl-alert
      v-if="hasError"
      variant="danger"
      :dismissible="false"
      class="gl-mb-4"
      data-testid="domain-error"
    >
      {{ errorText }}
    </gl-alert>

    <gl-alert
      v-if="mutationError"
      variant="danger"
      class="gl-mb-4"
      data-testid="domain-mutation-error"
      @dismiss="mutationError = ''"
    >
      {{ mutationError }}
    </gl-alert>

    <crud-component
      ref="crud"
      :title="title"
      :count="totalCount"
      :show-zero-count="true"
      :is-collapsible="true"
      :is-loading="isLoading"
      body-class="!gl-p-0"
      data-testid="domain-list-card"
    >
      <template #actions="{ showForm, isFormVisible }">
        <gl-button
          v-if="canSearch"
          icon="search"
          size="small"
          category="tertiary"
          :aria-label="$options.i18n.search"
          data-testid="search-domain-btn"
          @click="toggleSearch(showForm, isFormVisible)"
        />
        <gl-button
          icon="plus"
          size="small"
          category="tertiary"
          :aria-label="$options.i18n.addDomain"
          data-testid="add-domain-btn"
          @click="toggleAdd(showForm, isFormVisible)"
        />
      </template>

      <template #form="{ hideForm }">
        <gl-search-box-by-type
          v-if="isSearchMode"
          ref="searchInput"
          :placeholder="$options.i18n.searchDomains"
          :value="searchTerm"
          data-testid="search-input"
          @input="onSearchInput"
          @clear="clearSearch"
        />
        <div v-else class="gl-flex gl-items-center gl-gap-3">
          <gl-form-input
            v-model="newDomain"
            v-autofocusonshow
            class="gl-grow"
            :placeholder="$options.i18n.addDomain"
            data-testid="domain-input"
            @keydown.enter="addDomain(hideForm)"
          />
          <gl-button
            variant="confirm"
            size="small"
            class="gl-shrink-0"
            :disabled="isSaving"
            :loading="isSaving"
            data-testid="confirm-add-domain-btn"
            @click="addDomain(hideForm)"
          >
            {{ $options.i18n.add }}
          </gl-button>
        </div>
      </template>

      <template #default="{ showForm, isFormVisible }">
        <div
          v-if="domains.length === 0"
          class="gl-flex gl-flex-col gl-items-center gl-gap-3 gl-py-4"
        >
          <span data-testid="empty-state-text">{{ emptyStateText }}</span>
          <gl-button
            size="small"
            icon="plus"
            data-testid="empty-add-domain-btn"
            @click="toggleAdd(showForm, isFormVisible)"
          >
            {{ $options.i18n.addDomain }}
          </gl-button>
        </div>
        <ul v-else class="gl-m-0 gl-list-none gl-p-0">
          <li
            v-for="domain in domains"
            :key="domain"
            class="gl-border-b gl-flex gl-items-center gl-justify-between gl-py-3 gl-pl-3 gl-pr-2 last:gl-border-b-0"
            data-testid="domain-row"
          >
            <span>{{ domain }}</span>
            <gl-button
              icon="close"
              size="small"
              category="tertiary"
              :aria-label="$options.i18n.remove"
              data-testid="remove-domain-btn"
              @click="removeDomain(domain)"
            />
          </li>
        </ul>
      </template>

      <template #pagination>
        <gl-keyset-pagination
          v-bind="pageInfo"
          class="gl-mt-3"
          data-testid="domain-pagination"
          @prev="handlePrevPage"
          @next="handleNextPage"
        />
      </template>
    </crud-component>
  </div>
</template>

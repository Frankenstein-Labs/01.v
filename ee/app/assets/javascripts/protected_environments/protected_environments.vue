<script>
import { GlBadge, GlButton, GlCollapse, GlIcon, GlModal, GlToastMixin } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';
import Pagination from '~/vue_shared/components/pagination_links.vue';
import { n__, s__, __, sprintf } from '~/locale';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { DEPLOYER_RULE_KEY, APPROVER_RULE_KEY } from './constants';
import CreateProtectedEnvironment from './create_protected_environment.vue';

export default {
  components: {
    GlBadge,
    GlButton,
    GlCollapse,
    GlIcon,
    GlModal,
    Pagination,
    CrudComponent,
    CreateProtectedEnvironment,
  },
  mixins: [GlToastMixin],
  inject: ['entityType'],
  props: {
    environments: {
      required: true,
      type: Array,
    },
  },
  emits: ['unprotect'],
  i18n: {
    title: s__('ProtectedEnvironments|Protected environments'),
    newProtectedEnvironment: s__('ProtectedEnvironments|Protect an environment'),
    emptyMessage: {
      projects: s__('ProtectedEnvironment|No environments in this project are protected.'),
      groups: s__('ProtectedEnvironment|No environments in this group are protected.'),
    },
  },
  data() {
    return {
      expanded: {},
      environmentToUnprotect: null,
      isAddFormVisible: false,
    };
  },
  computed: {
    ...mapState(['pageInfo']),
    confirmUnprotectText() {
      return sprintf(
        s__(
          'ProtectedEnvironment|Users with at least the Developer role can write to unprotected environments. Are you sure you want to unprotect %{environment_name}?',
        ),
        { environment_name: this.environmentToUnprotect?.name },
      );
    },
    isUnprotectModalVisible() {
      return Boolean(this.environmentToUnprotect);
    },
    showPagination() {
      return this.pageInfo?.totalPages > 1;
    },
    protectedEnvironmentsCount() {
      return this.environments.length.toString();
    },
    showEmptyMessage() {
      return this.environments.length === 0 && !this.isAddFormVisible;
    },
    emptyMessage() {
      return this.$options.i18n.emptyMessage[this.entityType];
    },
  },
  methods: {
    ...mapActions(['setPage', 'fetchProtectedEnvironments']),
    toggleCollapse({ name }) {
      this.expanded = {
        ...this.expanded,
        [name]: !this.expanded[name],
      };
    },
    isExpanded({ name }) {
      return this.expanded[name];
    },
    icon(environment) {
      return this.isExpanded(environment) ? 'chevron-up' : 'chevron-down';
    },
    approvalRulesText({ [APPROVER_RULE_KEY]: approvalRules }) {
      return n__(
        'ProtectedEnvironments|%d approval rule',
        'ProtectedEnvironments|%d approval rules',
        approvalRules.length,
      );
    },
    deploymentRulesText({ [DEPLOYER_RULE_KEY]: deploymentRules }) {
      return n__(
        'ProtectedEnvironments|%d deployment rule',
        'ProtectedEnvironments|%d deployment rules',
        deploymentRules.length,
      );
    },
    confirmUnprotect(environment) {
      this.environmentToUnprotect = environment;
    },
    unprotect() {
      this.$emit('unprotect', this.environmentToUnprotect);
      this.$toast.show(
        sprintf(s__('ProtectedEnvironment|Environment %{environmentName} is unprotected.'), {
          environmentName: this.environmentToUnprotect.name,
        }),
      );
    },
    clearEnvironment() {
      this.environmentToUnprotect = null;
    },
    hideAddForm() {
      this.isAddFormVisible = false;
      this.$refs.crud.hideForm();
    },
    completeAddForm(environmentToProtect) {
      this.hideAddForm();
      this.fetchProtectedEnvironments();
      this.$toast.show(
        sprintf(s__('ProtectedEnvironment|Environment %{environmentName} is protected.'), {
          environmentName: environmentToProtect.name,
        }),
      );
    },
  },
  modalOptions: {
    modalId: 'confirm-unprotect-environment',
    size: 'sm',
    actionPrimary: {
      text: __('OK'),
      attributes: { variant: 'danger' },
    },
    actionSecondary: {
      text: __('Cancel'),
    },
  },
};
</script>
<template>
  <div class="gl-mb-5">
    <crud-component
      ref="crud"
      :title="$options.i18n.title"
      icon="environment"
      :count="protectedEnvironmentsCount"
      :toggle-text="$options.i18n.newProtectedEnvironment"
      data-testid="new-protected-environment"
    >
      <template #form>
        <create-protected-environment @success="completeAddForm" @cancel="hideAddForm" />
      </template>

      <gl-modal
        :visible="isUnprotectModalVisible"
        v-bind="$options.modalOptions"
        @primary="unprotect"
        @hide="clearEnvironment"
      >
        {{ confirmUnprotectText }}
      </gl-modal>

      <div v-if="showEmptyMessage" class="gl-text-subtle">
        {{ emptyMessage }}
      </div>
      <template v-else>
        <div v-for="environment in environments" :key="environment.name" class="gl-border-b">
          <gl-button
            block
            category="tertiary"
            variant="confirm"
            class="!gl-rounded-none !gl-px-5 !gl-py-4"
            button-text-classes="gl-flex gl-w-full gl-items-baseline"
            :aria-label="environment.name"
            data-testid="protected-environment-item-toggle"
            @click="toggleCollapse(environment)"
          >
            <span class="gl-py-2 gl-text-default">{{ environment.name }}</span>
            <gl-badge v-if="!isExpanded(environment)" class="gl-ml-auto">
              {{ deploymentRulesText(environment) }}
            </gl-badge>
            <gl-badge v-if="!isExpanded(environment)" class="gl-ml-3">
              {{ approvalRulesText(environment) }}
            </gl-badge>
            <gl-icon
              :name="icon(environment)"
              :size="14"
              :class="{
                'gl-ml-3': !isExpanded(environment),
                'gl-ml-auto': isExpanded(environment),
              }"
              variant="subtle"
            />
          </gl-button>
          <gl-collapse
            :visible="isExpanded(environment)"
            class="gl-flex gl-flex-col gl-rounded-b-base gl-bg-default gl-pb-5"
          >
            <slot :environment="environment"></slot>
            <gl-button
              category="secondary"
              variant="danger"
              class="gl-mr-5 gl-mt-5 gl-self-end"
              @click="confirmUnprotect(environment)"
            >
              {{ s__('ProtectedEnvironments|Unprotect') }}
            </gl-button>
          </gl-collapse>
        </div>
      </template>
      <template v-if="showPagination" #pagination>
        <pagination :change="setPage" :page-info="pageInfo" align="center" />
      </template>
    </crud-component>
  </div>
</template>

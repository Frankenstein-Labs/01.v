<script>
import { GlButton, GlModal } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import {
  ACCOUNTS,
  ROLES,
  GROUPS,
  TOKENS,
  USERS,
  SOURCE_BRANCH_PATTERNS,
  EXCEPTIONS_FULL_OPTIONS_MAP,
} from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/constants';
import RolesSelector from './roles_selector.vue';
import GroupsSelector from './groups_selector.vue';
import TokensSelector from './tokens_selector.vue';
import UsersSelector from './users_selector.vue';
import BranchPatternSelector from './branch_pattern_selector.vue';
import PolicyExceptionsSelector from './policy_exceptions_selector.vue';
import ServiceAccountsSelector from './service_accounts_selector.vue';

export default {
  ROLES,
  GROUPS,
  ACCOUNTS,
  USERS,
  SOURCE_BRANCH_PATTERNS,
  EXCEPTIONS_FULL_OPTIONS_MAP,
  TOKENS,
  i18n: {
    modalTitle: s__('ScanResultPolicy|Add policy exception'),
    cancelAction: __('Cancel'),
    backAction: __('Back'),
    primaryAction: __('Add exception(s)'),
  },
  name: 'PolicyExceptionsModal',
  components: {
    GlButton,
    GlModal,
    BranchPatternSelector,
    GroupsSelector,
    TokensSelector,
    RolesSelector,
    PolicyExceptionsSelector,
    ServiceAccountsSelector,
    UsersSelector,
  },
  props: {
    exceptions: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    selectedTab: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['changed', 'select-tab'],
  data() {
    return {
      selectedExceptions: this.exceptions,
    };
  },
  computed: {
    modalTitle() {
      return EXCEPTIONS_FULL_OPTIONS_MAP[this.selectedTab]?.header || this.$options.i18n.modalTitle;
    },
    modalSubtitle() {
      return EXCEPTIONS_FULL_OPTIONS_MAP[this.selectedTab]?.subHeader || '';
    },
    branches() {
      return this.selectedExceptions?.branches || [];
    },
    accessTokens() {
      return this.selectedExceptions?.access_tokens || [];
    },
    accounts() {
      return this.selectedExceptions?.service_accounts || [];
    },
    groups() {
      return this.selectedExceptions?.groups || [];
    },
    users() {
      return this.selectedExceptions?.users || [];
    },
    roles() {
      const roles = this.selectedExceptions?.roles || [];
      const customRoles =
        this.selectedExceptions?.custom_roles
          ?.filter((role) => role && role.id)
          .map(({ id }) => id) || [];
      return [...roles, ...customRoles];
    },
  },
  watch: {
    exceptions(newVal) {
      this.selectedExceptions = newVal;
    },
  },
  methods: {
    tabSelected(tab) {
      return this.selectedTab === tab;
    },
    hideModalWindow() {
      this.$refs.modal.hide();
    },
    /**
     * Used in a parent component
     */
    // eslint-disable-next-line vue/no-unused-properties
    showModalWindow() {
      this.$refs.modal.show();
    },
    selectTab(tab) {
      this.$emit('select-tab', tab);
    },
    setAccounts(accounts) {
      this.selectedExceptions = {
        ...this.selectedExceptions,
        service_accounts: accounts,
      };
    },
    setBranches(branches) {
      this.selectedExceptions = {
        ...this.selectedExceptions,
        branches,
      };
    },
    setGroups(groups) {
      this.selectedExceptions = {
        ...this.selectedExceptions,
        groups,
      };
    },
    setUsers(users) {
      this.selectedExceptions = {
        ...this.selectedExceptions,
        users,
      };
    },
    setRoles({ roles, custom_roles }) {
      this.selectedExceptions = {
        ...this.selectedExceptions,
        roles,
        custom_roles,
      };
    },
    setAccessTokens(accessTokens) {
      this.selectedExceptions = {
        ...this.selectedExceptions,
        access_tokens: accessTokens,
      };
    },
    saveChanges() {
      this.$emit('changed', this.selectedExceptions);
      this.hideModalWindow();
    },
  },
};
</script>

<template>
  <gl-modal
    ref="modal"
    :action-cancel="$options.ACTION_CANCEL"
    :action-primary="$options.PRIMARY_ACTION"
    scrollable
    size="md"
    content-class="security-policies-variables-modal-min-height"
    modal-id="deny-allow-list-modal"
    @canceled="hideModalWindow"
  >
    <template #modal-header>
      <div>
        <h4 data-testid="modal-title" class="gl-mb-2">{{ modalTitle }}</h4>
        <p v-if="modalSubtitle" data-testid="modal-subtitle" class="gl-mb-0 gl-text-subtle">
          {{ modalSubtitle }}
        </p>
      </div>
    </template>

    <div
      v-if="selectedTab"
      class="security-policies-exceptions-modal-height gl-border-t gl-flex gl-w-full gl-flex-col @md/panel:gl-flex-row"
    >
      <roles-selector
        v-if="tabSelected($options.ROLES)"
        :selected-roles="roles"
        @set-roles="setRoles"
      />
      <users-selector
        v-if="tabSelected($options.USERS)"
        :selected-users="users"
        @set-users="setUsers"
      />
      <groups-selector
        v-if="tabSelected($options.GROUPS)"
        :selected-groups="groups"
        @set-groups="setGroups"
      />
      <tokens-selector
        v-if="tabSelected($options.TOKENS)"
        :selected-tokens="accessTokens"
        @set-access-tokens="setAccessTokens"
      />
      <service-accounts-selector
        v-if="tabSelected($options.ACCOUNTS)"
        :selected-accounts="accounts"
        @set-accounts="setAccounts"
      />
      <branch-pattern-selector
        v-if="tabSelected($options.SOURCE_BRANCH_PATTERNS)"
        :branches="branches"
        @set-branches="setBranches"
      />
    </div>

    <policy-exceptions-selector v-else :selected-exceptions="exceptions" @select="selectTab" />

    <template #modal-footer>
      <div v-if="!selectedTab"></div>
      <div v-else class="gl-flex gl-w-full">
        <gl-button category="secondary" variant="confirm" @click="selectTab(null)">{{
          $options.i18n.backAction
        }}</gl-button>
        <div class="gl-ml-auto">
          <gl-button
            data-testid="save-button"
            category="primary"
            variant="confirm"
            @click="saveChanges"
            >{{ $options.i18n.primaryAction }}</gl-button
          >

          <gl-button category="secondary" variant="confirm" @click="hideModalWindow">{{
            $options.i18n.cancelAction
          }}</gl-button>
        </div>
      </div>
    </template>
  </gl-modal>
</template>

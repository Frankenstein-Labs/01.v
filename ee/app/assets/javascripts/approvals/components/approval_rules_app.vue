<script>
import { GlButton, GlLoadingIcon } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';
import { __ } from '~/locale';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import showToast from '~/vue_shared/plugins/global_toast';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import DrawerRuleCreate from './rule_drawer/create_rule.vue';
import ModalRuleRemove from './rule_modal/remove_rule.vue';

export default {
  name: 'ApprovalRulesApp',
  components: {
    DrawerRuleCreate,
    ModalRuleRemove,
    CrudComponent,
    GlButton,
    GlLoadingIcon,
  },
  mixins: [glSlotsMixin, glListenersMixin],
  props: {
    isMrEdit: {
      type: Boolean,
      default: true,
      required: false,
    },
    isBranchRulesEdit: {
      type: Boolean,
      default: false,
      required: false,
    },
  },
  computed: {
    ...mapState({
      settings: 'settings',
      rules: (state) => state.approvals.rules,
      pagination: (state) => state.approvals.rulesPagination,
      isLoading: (state) => state.approvals.isLoading,
      drawerOpen: (state) => state.approvals.drawerOpen,
      hasLoaded: (state) => state.approvals.hasLoaded,
      targetBranch: (state) => state.approvals.targetBranch,
    }),
    removeModalId() {
      return `${this.settings.prefix}-approvals-remove-modal`;
    },
    checkShowResetButton() {
      return this.targetBranch && this.settings.canEdit && this.settings.allowMultiRule;
    },
    rulesLength() {
      return this.isMrEdit || this.isBranchRulesEdit ? this.rules.length : this.pagination.total;
    },
    canAddApprovalRule() {
      const canEditAndAllowMultiRule = this.settings.canEdit && this.settings.allowMultiRule;

      return canEditAndAllowMultiRule;
    },
  },
  mounted() {
    if (!this.isBranchRulesEdit) {
      this.fetchRules({ targetBranch: this.targetBranch });
    }
  },
  methods: {
    ...mapActions(['fetchRules', 'undoRulesChange']),
    ...mapActions({ openCreateDrawer: 'openCreateDrawer' }),
    ...mapActions({ closeCreateDrawer: 'closeCreateDrawer' }),
    resetToProjectDefaults() {
      const { targetBranch } = this;

      return this.fetchRules({ targetBranch, resetToDefault: true }).then(() => {
        showToast(__('Approval rules reset to project defaults'), {
          action: {
            text: __('Undo'),
            onClick: (_, toast) => {
              this.undoRulesChange();
              toast.hide();
            },
          },
        });
      });
    },
    handleAddRule() {
      this.openCreateDrawer();
    },
  },
};
</script>

<template>
  <crud-component
    :title="__('Approval rules')"
    icon="approval"
    :count="rulesLength"
    class="gl-mt-3"
    data-testid="mr-approval-rules"
  >
    <template v-if="canAddApprovalRule" #actions>
      <gl-button
        :disabled="isLoading"
        category="secondary"
        size="small"
        data-testid="add-approval-rule"
        @click="handleAddRule()"
      >
        {{ __('Add approval rule') }}
      </gl-button>
    </template>

    <template v-if="glSlots().description" #description>
      <slot name="description"></slot>
    </template>

    <gl-loading-icon v-if="!hasLoaded" size="sm" class="gl-m-5" />
    <template v-else>
      <slot name="rules"></slot>
      <div v-if="checkShowResetButton" class="!gl-border-b !gl-border-b-gray-300 !gl-px-5 !gl-py-5">
        <div class="gl-flex">
          <gl-button
            v-if="targetBranch"
            :disabled="isLoading"
            size="small"
            data-testid="reset-to-defaults"
            @click="resetToProjectDefaults"
          >
            {{ __('Reset to project defaults') }}
          </gl-button>
        </div>
      </div>
    </template>
    <template v-if="glSlots().footer" #footer>
      <slot name="footer"></slot>
    </template>
    <drawer-rule-create
      :is-mr-edit="isMrEdit"
      :is-branch-rules-edit="isBranchRulesEdit"
      :is-open="drawerOpen"
      v-on="glListeners()"
      @close="closeCreateDrawer"
    />
    <modal-rule-remove :modal-id="removeModalId" />
  </crud-component>
</template>

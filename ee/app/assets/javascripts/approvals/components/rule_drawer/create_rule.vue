<script>
// eslint-disable-next-line no-restricted-imports
import { mapState } from 'vuex';
import { GlDrawer, GlButton } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { __ } from '~/locale';
import {
  BRANCH_RULE_DETAILS_LABEL,
  REPOSITORY_SETTINGS_LABEL,
  CHANGED_MERGE_REQUEST_APPROVALS,
} from 'ee_else_ce/projects/settings/branch_rules/tracking/constants';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import RuleForm from '../rules/rule_form.vue';

const I18N = {
  addApprovalRule: __('Add approval rule'),
  editApprovalRule: __('Edit approval rule'),
  saveChanges: __('Save changes'),
  cancel: __('Cancel'),
};

export default {
  name: 'CreateRule',
  DRAWER_Z_INDEX,
  I18N,
  components: {
    GlDrawer,
    RuleForm,
    GlButton,
  },
  mixins: [glListenersMixin],
  props: {
    isOpen: {
      type: Boolean,
      required: true,
    },
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
  emits: ['close'],
  data() {
    return { isLoading: false };
  },
  computed: {
    ...mapState({
      rule: (state) => state.approvals.editRule,
    }),
    title() {
      return !this.rule || this.defaultRuleName ? I18N.addApprovalRule : I18N.editApprovalRule;
    },
    defaultRuleName() {
      return this.rule?.defaultRuleName;
    },
    getDrawerHeaderHeight() {
      return getContentWrapperHeight();
    },
  },
  methods: {
    async submit() {
      InternalEvents.trackEvent(CHANGED_MERGE_REQUEST_APPROVALS, {
        label: this.isBranchRulesEdit ? BRANCH_RULE_DETAILS_LABEL : REPOSITORY_SETTINGS_LABEL,
      });

      this.isLoading = true;
      await this.$refs.form.submit();
      this.isLoading = false;
    },
  },
};
</script>

<template>
  <gl-drawer
    :header-height="getDrawerHeaderHeight"
    :z-index="$options.DRAWER_Z_INDEX"
    :open="isOpen"
    @ok.prevent="submit"
    v-on="glListeners()"
  >
    <template #title>
      <h2 class="gl-mt-0 gl-text-size-h2">{{ title }}</h2>
    </template>

    <div>
      <rule-form
        ref="form"
        :init-rule="rule"
        :is-mr-edit="isMrEdit"
        :is-branch-rules-edit="isBranchRulesEdit"
        :default-rule-name="defaultRuleName"
        v-on="glListeners()"
      />

      <div class="gl-flex gl-gap-3">
        <gl-button
          variant="confirm"
          data-testid="save-approval-rule-button"
          :loading="isLoading"
          @click="submit"
        >
          {{ $options.I18N.saveChanges }}
        </gl-button>
        <gl-button data-testid="cancel-button" @click="$emit('close')">
          {{ $options.I18N.cancel }}
        </gl-button>
      </div>
    </div>
  </gl-drawer>
</template>

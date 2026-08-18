<script>
import { GlFormGroup, GlFormInput } from '@gitlab/ui';
import { groupBy, isEqual, isNumber } from 'lodash-es';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';
import ProtectedBranchesSelector from 'ee/vue_shared/components/branches_selector/protected_branches_selector.vue';
import ListSelector from '~/vue_shared/components/list_selector/index.vue';
import { GROUPS_TYPE, USERS_TYPE } from '~/vue_shared/components/list_selector/constants';
import { sprintf } from '~/locale';
import {
  ALL_BRANCHES,
  ALL_PROTECTED_BRANCHES,
} from 'ee/vue_shared/components/branches_selector/constants';
import {
  TYPE_USER,
  TYPE_GROUP,
  TYPE_HIDDEN_GROUPS,
  COVERAGE_CHECK_NAME,
  APPROVAL_DIALOG_I18N,
} from '../../constants';

const DEFAULT_NAME = 'Default';

export const READONLY_NAMES = [COVERAGE_CHECK_NAME];

function mapServerResponseToValidationErrors(messages) {
  return Object.entries(messages).flatMap(([key, msgs]) => msgs.map((msg) => `${key} ${msg}`));
}

export default {
  name: 'RuleForm',
  GROUPS_TYPE,
  USERS_TYPE,
  components: {
    ListSelector,
    GlFormGroup,
    GlFormInput,
    ProtectedBranchesSelector,
  },
  props: {
    initRule: {
      type: Object,
      required: false,
      default: null,
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
    defaultRuleName: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['close', 'submitted'],
  data() {
    return {
      name: this.defaultRuleName,
      approvalsRequired: 1,
      minApprovalsRequired: 0,
      approvers: [],
      approversToAdd: [],
      branches: [],
      branchesToAdd: [],
      showValidation: false,
      isFallback: false,
      containsHiddenGroups: false,
      serverValidationErrors: [],
      ...this.getInitialData(),
    };
  },
  computed: {
    ...mapState(['settings']),
    approversByType() {
      return groupBy(this.approvers, (x) => x.type);
    },
    users() {
      return this.approversByType[TYPE_USER] || [];
    },
    groups() {
      return this.approversByType[TYPE_GROUP] || [];
    },
    userIds() {
      return this.users.map((x) => x.id);
    },
    groupIds() {
      return this.groups.map((x) => x.id);
    },
    invalidName() {
      if (this.isMultiSubmission) {
        if (this.serverValidationErrors.includes('name has already been taken')) {
          return APPROVAL_DIALOG_I18N.validations.ruleNameTaken;
        }

        if (!this.name) {
          return APPROVAL_DIALOG_I18N.validations.ruleNameMissing;
        }

        const lengthError = this.serverValidationErrors.find((error) =>
          /name is too long \(maximum is \d+ characters\)/.test(error),
        );

        if (lengthError) {
          const match = lengthError.match(/name is too long \(maximum is (\d+) characters\)/);
          const maxLength = match[1];

          return sprintf(APPROVAL_DIALOG_I18N.validations.ruleNameTooLong, {
            number: maxLength,
          });
        }
      }

      return '';
    },
    invalidApprovalsRequired() {
      if (!isNumber(this.approvalsRequired)) {
        return APPROVAL_DIALOG_I18N.validations.approvalsRequiredNotNumber;
      }

      if (this.approvalsRequired < 0) {
        return APPROVAL_DIALOG_I18N.validations.approvalsRequiredNegativeNumber;
      }

      if (this.approvalsRequired < this.minApprovalsRequired) {
        return sprintf(APPROVAL_DIALOG_I18N.validations.approvalsRequiredMinimum, {
          number: this.minApprovalsRequired,
        });
      }

      return '';
    },
    invalidApprovers() {
      if (this.isMultiSubmission && this.approvers.length <= 0) {
        return APPROVAL_DIALOG_I18N.validations.approversRequired;
      }

      return '';
    },
    invalidBranches() {
      if (
        !this.isMrEdit &&
        !this.branches.every(
          (branch) =>
            isEqual(branch, ALL_BRANCHES) ||
            isEqual(branch, ALL_PROTECTED_BRANCHES) ||
            isNumber(branch?.id),
        )
      ) {
        return APPROVAL_DIALOG_I18N.validations.branchesRequired;
      }

      return '';
    },
    isValid() {
      return (
        this.isValidName &&
        this.isValidBranches &&
        this.isValidApprovalsRequired &&
        this.isValidApprovers
      );
    },
    isValidName() {
      return !this.showValidation || !this.invalidName;
    },
    isValidBranches() {
      return !this.showValidation || !this.invalidBranches;
    },
    isValidApprovalsRequired() {
      return !this.showValidation || !this.invalidApprovalsRequired;
    },
    isValidApprovers() {
      return !this.showValidation || !this.invalidApprovers;
    },
    isMultiSubmission() {
      return this.settings.allowMultiRule && !this.isFallbackSubmission;
    },
    isFallbackSubmission() {
      return (
        this.settings.allowMultiRule && this.isFallback && !this.name && !this.approvers.length
      );
    },
    isPersisted() {
      return this.initRule && this.initRule.id;
    },
    showName() {
      return !this.settings.lockedApprovalsRuleName;
    },
    isNameDisabled() {
      return (
        Boolean(this.isPersisted || this.defaultRuleName) && READONLY_NAMES.includes(this.name)
      );
    },
    showProtectedBranch() {
      return !this.isMrEdit && this.settings.allowMultiRule;
    },
    removeHiddenGroups() {
      return this.containsHiddenGroups && !this.approversByType[TYPE_HIDDEN_GROUPS];
    },
    submissionData() {
      const appliesToAllProtectedBranches = this.branches.some(
        (x) => x.id === ALL_PROTECTED_BRANCHES.id,
      );
      const protectedBranchIds = this.branches
        .map((x) => x.id)
        .filter((x) => x !== ALL_BRANCHES.id && x !== ALL_PROTECTED_BRANCHES.id);

      return {
        id: this.initRule && this.initRule.id,
        name: this.settings.lockedApprovalsRuleName || this.name || DEFAULT_NAME,
        appliesToAllProtectedBranches,
        approvalsRequired: this.approvalsRequired,
        users: this.userIds,
        groups: this.groupIds,
        userRecords: this.users,
        groupRecords: this.groups,
        removeHiddenGroups: this.removeHiddenGroups,
        protectedBranchIds,
      };
    },
    selectedBranchNames() {
      return [this.settings.targetBranch];
    },
  },
  watch: {
    approversToAdd(value) {
      this.approvers.push(value[0]);
    },
    branchesToAdd(value) {
      this.branches = value ? [value] : [];
    },
  },
  methods: {
    ...mapActions(['putFallbackRule', 'postRule', 'putRule', 'deleteRule', 'postRegularRule']),
    /**
     * Validate and submit the form based on what type it is.
     * - Fallback rule?
     * - Single rule?
     * - Multi rule?
     */
    async submit() {
      let submission;

      this.serverValidationErrors = [];
      this.showValidation = true;

      if (!this.isValid) {
        submission = Promise.resolve;
      } else if (this.isFallbackSubmission) {
        submission = this.submitFallback;
      } else if (!this.isMultiSubmission) {
        submission = this.submitSingleRule;
      } else {
        submission = this.submitRule;
      }

      try {
        await submission();
        this.$emit('submitted');
        this.$emit('close');
      } catch (failureResponse) {
        this.serverValidationErrors = mapServerResponseToValidationErrors(
          failureResponse?.response?.data?.message || {},
        );
      }
    },
    /**
     * Submit the rule, by either put-ing or post-ing.
     */
    submitRule() {
      const data = this.submissionData;

      if (!this.settings.allowMultiRule && this.settings.prefix === 'mr-edit') {
        return data.id ? this.putRule(data) : this.postRegularRule(data);
      }

      return data.id ? this.putRule(data) : this.postRule(data);
    },
    /**
     * Submit as a fallback rule.
     */
    submitFallback() {
      return this.putFallbackRule({ approvalsRequired: this.approvalsRequired });
    },
    /**
     * Submit as a single rule. This is determined by the settings.
     */
    submitSingleRule() {
      if (!this.approvers.length) {
        return this.submitEmptySingleRule();
      }

      return this.submitRule();
    },
    /**
     * Submit as a single rule without approvers, so submit the fallback.
     * Also delete the rule if necessary.
     */
    submitEmptySingleRule() {
      const id = this.initRule && this.initRule.id;

      return Promise.all([this.submitFallback(), id ? this.deleteRule(id) : Promise.resolve()]);
    },
    getInitialData() {
      if (!this.initRule || this.defaultRuleName) {
        return {};
      }

      if (this.initRule.isFallback) {
        return {
          approvalsRequired: this.initRule.approvalsRequired,
          isFallback: this.initRule.isFallback,
        };
      }

      const { containsHiddenGroups = false, removeHiddenGroups = false } = this.initRule;

      const users = this.initRule.users.map((x) => ({ ...x, type: TYPE_USER }));
      const groups = this.initRule.groups.map((x) => ({ ...x, type: TYPE_GROUP }));
      const branches = [];

      if (this.initRule.appliesToAllProtectedBranches) {
        branches.push(ALL_PROTECTED_BRANCHES);
      } else if (this.initRule.protectedBranches?.length > 0) {
        branches.push(...this.initRule.protectedBranches);
      }

      if (!branches.length) {
        branches.push(ALL_BRANCHES);
      }

      return {
        name: this.initRule.name || '',
        approvalsRequired: this.initRule.approvalsRequired || 0,
        minApprovalsRequired: this.initRule.minApprovalsRequired || 0,
        containsHiddenGroups,
        approvers: groups
          .concat(users)
          .concat(
            containsHiddenGroups && !removeHiddenGroups ? [{ type: TYPE_HIDDEN_GROUPS }] : [],
          ),
        branches,
      };
    },
    handleDeleteApprover(id) {
      const approverIndex = this.approvers.findIndex((approver) => approver.id === id);
      this.approvers.splice(approverIndex, 1);
    },
    handleSelectApprover(approver, type) {
      this.approvers.push({ ...approver, type });
    },
  },
  APPROVAL_DIALOG_I18N,
  ruleNameInput: 'rule-name-input',
  approvalsRequiredInput: 'approvals-required-input',
};
</script>

<template>
  <form novalidate @submit.prevent.stop="submit" @keydown.enter="submit">
    <gl-form-group
      v-if="showName"
      :label="$options.APPROVAL_DIALOG_I18N.form.nameLabel"
      :label-for="$options.ruleNameInput"
      :description="$options.APPROVAL_DIALOG_I18N.form.nameDescription"
      :state="isValidName"
      :invalid-feedback="invalidName"
      data-testid="name-group"
    >
      <gl-form-input
        :id="$options.ruleNameInput"
        v-model="name"
        :disabled="isNameDisabled"
        :state="isValidName"
        data-testid="rule-name-field"
        autofocus
      />
    </gl-form-group>
    <gl-form-group
      v-show="!isBranchRulesEdit"
      v-if="showProtectedBranch"
      :label="$options.APPROVAL_DIALOG_I18N.form.protectedBranchLabel"
      :description="$options.APPROVAL_DIALOG_I18N.form.protectedBranchDescription"
      :state="isValidBranches"
      :invalid-feedback="invalidBranches"
      data-testid="branches-group"
    >
      <protected-branches-selector
        v-model="branchesToAdd"
        :project-id="settings.projectId"
        :is-invalid="!isValidBranches"
        :allow-all-protected-branches-option="settings.allowAllProtectedBranchesOption"
        :selected-branches="branches"
        :selected-branches-names="selectedBranchNames"
      />
    </gl-form-group>
    <gl-form-group
      class="gl-mb-3"
      :label="$options.APPROVAL_DIALOG_I18N.form.approvalsRequiredLabel"
      :label-for="$options.approvalsRequiredInput"
      :state="isValidApprovalsRequired"
      :invalid-feedback="invalidApprovalsRequired"
      data-testid="approvals-required-group"
    >
      <gl-form-input
        :id="$options.approvalsRequiredInput"
        v-model.number="approvalsRequired"
        :state="isValidApprovalsRequired"
        :min="minApprovalsRequired"
        class="mw-6em"
        type="number"
        data-testid="approvals-required"
      />
    </gl-form-group>
    <gl-form-group
      :state="isValidApprovers"
      :invalid-feedback="invalidApprovers"
      data-testid="approvers-group"
    >
      <list-selector
        :type="$options.USERS_TYPE"
        data-testid="users-selector"
        :selected-items="users"
        :project-path="settings.projectId"
        @delete="handleDeleteApprover"
        @select="(approver) => handleSelectApprover(approver, 'user')"
      />
      <list-selector
        :type="$options.GROUPS_TYPE"
        data-testid="groups-selector"
        class="gl-mt-5"
        is-project-scoped
        :project-path="settings.projectId"
        :selected-items="groups"
        @delete="handleDeleteApprover"
        @select="(approver) => handleSelectApprover(approver, 'group')"
      />
    </gl-form-group>
  </form>
</template>

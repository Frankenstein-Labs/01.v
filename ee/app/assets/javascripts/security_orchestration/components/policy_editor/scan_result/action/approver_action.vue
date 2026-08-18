<script>
import { isNumber } from 'lodash-es';
import { GlSprintf, GlFormInput, GlButton } from '@gitlab/ui';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import {
  getDefaultHumanizedTemplate,
  WARN_TEMPLATE,
  ADD_APPROVER_LABEL,
  APPROVER_TYPE_LIST_ITEMS,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import { EMPTY_TYPE, GROUP_TYPE, ROLE_TYPE, USER_TYPE } from 'ee/security_orchestration/constants';
import { mapYamlApproversActionsToSelectedApproverTypes } from 'ee/security_orchestration/components/policy_editor/scan_result/lib/actions';
import ApproverSelect from './approver_select.vue';

export default {
  WARN_ID: 'warn-help-text',
  i18n: {
    WARN_TEMPLATE,
    ADD_APPROVER_LABEL,
  },
  name: 'ApproverAction',
  components: {
    GlButton,
    ApproverSelect,
    GlFormInput,
    GlSprintf,
    SectionLayout,
  },
  props: {
    actionIndex: {
      type: Number,
      required: true,
    },
    initAction: {
      type: Object,
      required: true,
    },
    isWarnType: {
      type: Boolean,
      required: false,
      default: false,
    },
    errors: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['changed', 'error'],
  data() {
    return {
      selectedApproverTypes: mapYamlApproversActionsToSelectedApproverTypes(this.initAction),
    };
  },
  computed: {
    allTypesSelected() {
      return (
        this.selectedApproverTypes.includes(GROUP_TYPE) &&
        this.selectedApproverTypes.includes(ROLE_TYPE) &&
        this.selectedApproverTypes.includes(USER_TYPE)
      );
    },
    selectedGroupIds() {
      return this.initAction.group_approvers_ids || [];
    },
    selectedGroupNames() {
      return this.initAction.group_approvers || [];
    },
    selectedUserIds() {
      return this.initAction.user_approvers_ids || [];
    },
    selectedUserNames() {
      return this.initAction.user_approvers || [];
    },
    selectedRoles() {
      return this.initAction.role_approvers || [];
    },
    approvalsRequiredValid() {
      const { approvals_required: approvalsRequired } = this.initAction;
      const isValidNumber = isNumber(approvalsRequired) && !Number.isNaN(approvalsRequired);

      return isValidNumber && approvalsRequired >= 1;
    },
    approvalsRequired() {
      return this.approvalsRequiredValid ? this.initAction.approvals_required : 1;
    },
    approvalsRequiredFieldValid() {
      return this.approvalsRequiredValid && this.isApproverFieldValid;
    },
    humanizedTemplate() {
      return getDefaultHumanizedTemplate(this.approvalsRequired, this.isWarnType);
    },
    isApproverFieldValid() {
      return this.errors
        .filter((error) => error.index === this.actionIndex)
        .every((error) => error.field !== 'actions');
    },
    showAddButton() {
      return this.selectedApproverTypes.length < APPROVER_TYPE_LIST_ITEMS.length;
    },
    showRemoveButton() {
      return this.selectedApproverTypes.length > 1;
    },
  },
  methods: {
    disabledTypesForIndex(index) {
      const currentType = this.selectedApproverTypes[index];
      return this.selectedApproverTypes.filter((type) => type !== currentType);
    },
    addApproval() {
      this.selectedApproverTypes.push(EMPTY_TYPE);
    },
    updateApprovalsRequired(value) {
      const updatedAction = { ...this.initAction, approvals_required: parseInt(value, 10) };
      this.updatePolicy(updatedAction);
    },
    updatePolicy(updatedAction) {
      this.$emit('changed', updatedAction);
    },
    selectItems(payload, type) {
      const action = this.removePropertyFromApprover(type, payload);
      this.$emit('changed', { ...action, ...payload });
    },
    selectType(type, index) {
      const alreadySelectedType = this.selectedApproverTypes[index];

      if (alreadySelectedType && alreadySelectedType !== type) {
        const action = this.removePropertyFromApprover(alreadySelectedType);
        this.$emit('changed', action);
      }

      this.selectedApproverTypes.splice(index, 1, type);
    },
    removePropertyFromApprover(type) {
      const action = { ...this.initAction };

      switch (type) {
        case GROUP_TYPE:
          delete action.group_approvers_ids;
          delete action.group_approvers;
          break;
        case USER_TYPE:
          delete action.user_approvers_ids;
          delete action.user_approvers;
          break;
        case ROLE_TYPE:
          delete action.role_approvers;
          break;
        default:
          break;
      }

      return action;
    },
    removeApprover(index, type) {
      const action = this.removePropertyFromApprover(type);

      this.selectedApproverTypes.splice(index, 1);
      this.$emit('changed', action);
    },
    showAdditionalText(index) {
      return index < this.selectedApproverTypes.length - 1;
    },
    getSelectedItems(type) {
      switch (type) {
        case GROUP_TYPE:
          return this.selectedGroupIds;
        case USER_TYPE:
          return this.selectedUserIds;
        case ROLE_TYPE:
          return this.selectedRoles;
        default:
          return [];
      }
    },
    getSelectedNames(type) {
      switch (type) {
        case GROUP_TYPE:
          return this.selectedGroupNames;
        case USER_TYPE:
          return this.selectedUserNames;
        case ROLE_TYPE:
          return this.selectedRoles;
        default:
          return [];
      }
    },
  },
};
</script>

<template>
  <section-layout
    class="gl-pr-0"
    content-classes="gl-py-5 gl-pr-2 gl-bg-default"
    :show-remove-button="false"
  >
    <template #content>
      <div v-if="isWarnType" class="gl-mb-3 gl-ml-5">
        <gl-sprintf :message="$options.i18n.WARN_TEMPLATE">
          <template #require="{ content }">
            <strong>{{ content }}</strong>
          </template>
        </gl-sprintf>
      </div>

      <div class="gl-mb-3 gl-ml-5 gl-flex gl-items-center">
        <gl-sprintf :message="humanizedTemplate">
          <template #require="{ content }">
            <strong class="gl-pl-2">{{ content }}</strong>
          </template>

          <template #approvalsRequired>
            <gl-form-input
              :state="approvalsRequiredFieldValid"
              :value="approvalsRequired"
              data-testid="approvals-required-input"
              type="number"
              class="gl-mx-3 !gl-w-11"
              :min="1"
              :max="100"
              @update="updateApprovalsRequired"
            />
          </template>

          <template #approval="{ content }">
            <strong class="gl-mr-3">{{ content }}</strong>
          </template>
        </gl-sprintf>
      </div>

      <approver-select
        v-for="(type, index) in selectedApproverTypes"
        :key="type"
        :action-index="actionIndex"
        :errors="errors"
        :selected-items="getSelectedItems(type)"
        :selected-names="getSelectedNames(type)"
        :disabled="allTypesSelected"
        :disabled-types="disabledTypesForIndex(index)"
        :selected-type="type"
        :show-additional-text="showAdditionalText(index)"
        :show-remove-button="showRemoveButton"
        @error="$emit('error')"
        @remove="removeApprover(index, type)"
        @select-items="selectItems($event, type)"
        @select-type="selectType($event, index)"
      />

      <gl-button
        v-if="showAddButton"
        class="gl-ml-5 gl-mt-4"
        variant="link"
        data-testid="add-approver"
        @click="addApproval"
      >
        {{ $options.i18n.ADD_APPROVER_LABEL }}
      </gl-button>
    </template>
  </section-layout>
</template>

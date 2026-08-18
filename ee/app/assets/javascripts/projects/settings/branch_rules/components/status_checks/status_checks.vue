<script>
import { GlAlert, GlToastMixin } from '@gitlab/ui';
import produce from 'immer';
import { s__ } from '~/locale';
import { InternalEvents } from '~/tracking';
import branchRulesQuery from 'ee_else_ce/projects/settings/branch_rules/queries/branch_rules_details.query.graphql';
import {
  BRANCH_RULE_DETAILS_LABEL,
  CHANGED_STATUS_CHECKS,
} from 'ee_else_ce/projects/settings/branch_rules/tracking/constants';
import createStatusCheckMutation from '../../mutations/external_status_check_create.mutation.graphql';
import updateStatusCheckMutation from '../../mutations/external_status_check_update.mutation.graphql';
import deleteStatusCheckMutation from '../../mutations/external_status_check_delete.mutation.graphql';
import StatusChecksTable from './status_checks_table.vue';
import StatusChecksDrawer from './status_checks_drawer.vue';
import StatusChecksDeleteModal from './status_checks_delete_modal.vue';

export default {
  name: 'StatusChecks',
  i18n: {
    statusChecksCreateSuccessMessage: s__('BranchRules|Status check created'),
    statusChecksUpdateSuccessMessage: s__('BranchRules|Status check updated'),
    statusChecksDeleteSuccessMessage: s__('BranchRules|Status check deleted'),
    createStatusCheckError: s__('StatusChecks|Unable to create status check. Please try again.'),
    updateStatusCheckError: s__('StatusChecks|Unable to update status check. Please try again.'),
    deleteStatusCheckError: s__('StatusChecks|Unable to delete status check. Please try again.'),
    noChangesToast: s__('StatusChecks|No changes were made to the status check.'),
  },
  components: {
    StatusChecksTable,
    StatusChecksDrawer,
    StatusChecksDeleteModal,
    GlAlert,
  },
  mixins: [GlToastMixin],
  props: {
    statusChecks: {
      type: Array,
      required: false,
      default: () => [],
    },
    branchRuleId: {
      type: String,
      required: true,
    },
    projectPath: {
      type: String,
      required: true,
    },
    isAllBranchesRule: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      errorMessages: [],
      isStatusChecksDrawerOpen: false,
      isStatusChecksDeleteModalOpen: false,
      selectedStatusCheck: null,
      isStatusChecksLoading: false,
      serverValidationErrors: [],
    };
  },
  methods: {
    openStatusCheckDrawer(selectedStatusCheck) {
      this.isStatusChecksDrawerOpen = true;
      this.selectedStatusCheck = selectedStatusCheck;
    },
    closeStatusCheckDrawer() {
      this.isStatusChecksDrawerOpen = false;
      this.selectedStatusCheck = null;
      this.serverValidationErrors = [];
    },
    saveStatusCheckChange(statusCheck, type) {
      if (type === 'create') {
        this.createStatusCheck({
          statusCheck,
        });
      } else {
        this.updateStatusCheck({
          statusCheck,
        });
      }
    },
    openStatusCheckDeleteModal(selectedStatusCheck) {
      this.selectedStatusCheck = selectedStatusCheck;
      this.isStatusChecksDeleteModalOpen = true;
    },
    createStatusCheck({ statusCheck }) {
      this.isStatusChecksLoading = true;
      this.$apollo
        .mutate({
          mutation: createStatusCheckMutation,
          variables: {
            branchRuleId: this.branchRuleId,
            ...statusCheck,
          },
          update: (
            store,
            {
              data: {
                branchRuleExternalStatusCheckCreate: { externalStatusCheck, errors },
              },
            },
          ) => {
            if (errors.length > 0) {
              return;
            }
            this.updateCacheAfterStatusCheckChange(
              store,
              (draftData, currentBranchIndex) => {
                draftData.project.branchRules.nodes[
                  currentBranchIndex
                ].externalStatusChecks.nodes.push(externalStatusCheck);
              },
              this.$options.i18n.statusChecksCreateSuccessMessage,
            );
          },
        })
        .then(
          ({
            data: {
              branchRuleExternalStatusCheckCreate: { errors },
            },
          }) => {
            if (errors.length > 0) {
              this.serverValidationErrors = errors;
              return;
            }
            InternalEvents.trackEvent(CHANGED_STATUS_CHECKS, {
              label: BRANCH_RULE_DETAILS_LABEL,
            });
            this.closeStatusCheckDrawer();
            this.$toast.show(this.$options.i18n.statusChecksCreateSuccessMessage);
          },
        )
        .catch(() => {
          this.errorMessages.push(this.$options.i18n.createStatusCheckError);
        })
        .finally(() => {
          this.isStatusChecksLoading = false;
        });
    },
    updateStatusCheck({ statusCheck }) {
      const hasChanges = this.checkForChanges(this.selectedStatusCheck, statusCheck);
      if (!hasChanges) {
        this.closeStatusCheckDrawer();
        this.$toast.show(this.$options.i18n.noChangesToast);
        return;
      }

      this.isStatusChecksLoading = true;
      this.$apollo
        .mutate({
          mutation: updateStatusCheckMutation,
          variables: {
            branchRuleId: this.branchRuleId,
            ...statusCheck,
          },
        })
        .then(
          ({
            data: {
              branchRuleExternalStatusCheckUpdate: { errors },
            },
          }) => {
            if (errors.length > 0) {
              this.serverValidationErrors = errors;
              return;
            }
            InternalEvents.trackEvent(CHANGED_STATUS_CHECKS, {
              label: BRANCH_RULE_DETAILS_LABEL,
            });
            this.closeStatusCheckDrawer();
            this.$toast.show(this.$options.i18n.statusChecksUpdateSuccessMessage);
          },
        )
        .catch(() => {
          this.errorMessages.push(this.$options.i18n.updateStatusCheckError);
        })
        .finally(() => {
          this.isStatusChecksLoading = false;
        });
    },
    deleteStatusCheck(statusCheckId) {
      this.isStatusChecksLoading = true;
      this.$apollo
        .mutate({
          mutation: deleteStatusCheckMutation,
          variables: {
            branchRuleId: this.branchRuleId,
            id: statusCheckId,
          },
          update: (
            store,
            {
              data: {
                branchRuleExternalStatusCheckDestroy: { errors },
              },
            },
          ) => {
            if (errors.length > 0) {
              return;
            }
            this.updateCacheAfterStatusCheckChange(
              store,
              (draftData, currentBranchIndex) => {
                draftData.project.branchRules.nodes[currentBranchIndex].externalStatusChecks.nodes =
                  draftData.project.branchRules.nodes[
                    currentBranchIndex
                  ].externalStatusChecks.nodes.filter((check) => check.id !== statusCheckId);
              },
              this.$options.i18n.statusChecksDeleteSuccessMessage,
            );
          },
        })
        .then(
          ({
            data: {
              branchRuleExternalStatusCheckDestroy: { errors },
            },
          }) => {
            if (errors.length > 0) {
              this.errorMessages.push(this.$options.i18n.deleteStatusCheckError);
            } else {
              InternalEvents.trackEvent(CHANGED_STATUS_CHECKS, {
                label: BRANCH_RULE_DETAILS_LABEL,
              });
              this.$toast.show(this.$options.i18n.statusChecksDeleteSuccessMessage);
            }
          },
        )
        .catch(() => {
          this.errorMessages.push(this.$options.i18n.deleteStatusCheckError);
        })
        .finally(() => {
          this.isStatusChecksDeleteModalOpen = false;
          this.isStatusChecksLoading = false;
        });
    },
    checkForChanges(originalStatusCheck, updatedStatusCheck) {
      const fieldsToCompare = ['name', 'externalUrl'];
      const hasFieldChanges = fieldsToCompare.some(
        (field) => originalStatusCheck[field] !== updatedStatusCheck[field],
      );

      const hasSharedSecretChange = Boolean(updatedStatusCheck.sharedSecret);
      return hasFieldChanges || hasSharedSecretChange;
    },
    updateCacheAfterStatusCheckChange(store, updateFunction, errorMessage) {
      const sourceData = store.readQuery({
        query: branchRulesQuery,
        variables: { projectPath: this.projectPath, buildMissing: this.isAllBranchesRule },
      });
      const data = produce(sourceData, (draftData) => {
        const currentBranchIndex = sourceData.project.branchRules.nodes.findIndex(
          (branchRule) => branchRule.id === this.branchRuleId,
        );
        if (currentBranchIndex !== -1) {
          updateFunction(draftData, currentBranchIndex);
        } else {
          this.errorMessages.push(errorMessage);
        }
      });
      store.writeQuery({
        query: branchRulesQuery,
        variables: { projectPath: this.projectPath },
        data,
      });
    },
    removeDismissedError(index) {
      this.errorMessages = this.errorMessages.splice(index, 1);
    },
  },
};
</script>

<template>
  <div>
    <gl-alert
      v-for="(item, index) in errorMessages"
      :key="index"
      variant="danger"
      class="gl-mt-3"
      @dismiss="removeDismissedError(item)"
    >
      {{ item }}
    </gl-alert>
    <status-checks-table
      :status-checks="statusChecks"
      data-testid="status-checks-table"
      @open-status-check-drawer="openStatusCheckDrawer"
      @open-status-check-delete-modal="openStatusCheckDeleteModal"
    />
    <status-checks-drawer
      :is-open="isStatusChecksDrawerOpen"
      :is-loading="isStatusChecksLoading"
      :selected-status-check="selectedStatusCheck"
      :server-validation-errors="serverValidationErrors"
      data-testid="status-checks-drawer"
      @close-status-check-drawer="closeStatusCheckDrawer"
      @save-status-check-change="saveStatusCheckChange"
    />
    <status-checks-delete-modal
      :is-open="isStatusChecksDeleteModalOpen"
      :selected-status-check="selectedStatusCheck"
      :is-loading="isStatusChecksLoading"
      @close-modal="isStatusChecksDeleteModalOpen = false"
      @delete-status-check="deleteStatusCheck"
    />
  </div>
</template>

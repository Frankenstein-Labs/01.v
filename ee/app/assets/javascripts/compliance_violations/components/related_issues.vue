<script>
import { createAlert } from '~/alert';
import { TYPE_ISSUE } from '~/issues/constants';
import { sprintf, s__ } from '~/locale';
import RelatedIssuesBlock from '~/related_issues/components/related_issues_block.vue';
import { PathIdSeparator } from '~/related_issues/constants';
import RelatedIssuesStore from '~/related_issues/stores/related_issues_store';
import { getFormattedIssue, getAddRelatedIssueRequestParams } from '../helpers';
import linkProjectComplianceViolationIssue from '../graphql/mutations/link_project_compliance_violation_issue.mutation.graphql';
import unlinkProjectComplianceViolationIssue from '../graphql/mutations/unlink_project_compliance_violation_issue.mutation.graphql';

export default {
  name: 'ComplianceViolationRelatedIssues',
  components: {
    RelatedIssuesBlock,
  },
  props: {
    issues: {
      type: Array,
      required: true,
      validator: (issues) =>
        issues.every(
          (issue) => issue.id && issue.state && issue.title && issue.webUrl && issue.iid,
        ),
    },
    violationId: {
      type: String,
      required: true,
    },
    projectPath: {
      type: String,
      required: true,
    },
  },
  data() {
    const store = new RelatedIssuesStore();

    return {
      state: store.state,
      isFetching: false,
      isSubmitting: false,
      isFormVisible: false,
      errorMessage: null,
      inputValue: '',
      store,
    };
  },
  created() {
    this.setInitialRelatedIssues();
  },
  methods: {
    setInitialRelatedIssues() {
      const formattedIssues = this.issues.map((issue) =>
        getFormattedIssue(issue, this.projectPath),
      );
      this.store.setRelatedIssues(formattedIssues);
    },
    resetForm() {
      this.errorMessage = null;
      this.isFormVisible = false;
      this.store.setPendingReferences([]);
      this.inputValue = '';
    },
    addRelatedIssue({ pendingReferences }) {
      this.processAllReferences(pendingReferences);
      this.errorMessage = null;
      this.isSubmitting = true;
      const errors = [];

      // Process each pending reference
      const requests = this.state.pendingReferences.map((reference) => {
        const { issueIid, projectPath } = getAddRelatedIssueRequestParams(
          reference,
          this.projectPath,
        );

        return this.$apollo
          .mutate({
            mutation: linkProjectComplianceViolationIssue,
            variables: {
              input: {
                violationId: this.violationId,
                projectPath,
                issueIid: issueIid.toString(),
              },
            },
          })
          .then(({ data }) => {
            if (data?.linkProjectComplianceViolationIssue?.errors?.length > 0) {
              throw new Error(data.linkProjectComplianceViolationIssue.errors.join(', '));
            }

            // Get the updated issues from the mutation response
            const updatedIssues = data.linkProjectComplianceViolationIssue.violation.issues.nodes;
            const newIssue = updatedIssues.find(
              (issue) => issue.iid.toString() === issueIid.toString(),
            );

            if (newIssue) {
              const formattedIssue = getFormattedIssue(newIssue);
              const index = this.state.pendingReferences.indexOf(reference);
              this.removePendingReference(index);
              this.store.addRelatedIssues(formattedIssue);
            }
          })
          .catch((error) => {
            errors.push({
              issueReference: reference,
              errorMessage: error.message ?? s__('ComplianceViolation|invalid issue link or ID'),
            });
          });
      });

      return Promise.all(requests).then(() => {
        this.isSubmitting = false;
        const hasErrors = Boolean(errors.length);
        this.isFormVisible = hasErrors;

        if (hasErrors) {
          const messages = errors.map((error) =>
            sprintf(
              s__('ComplianceViolation|Could not process %{issueReference}: %{errorMessage}.'),
              error,
            ),
          );
          this.errorMessage = messages.join(' ');
        }
      });
    },
    removeRelatedIssue(idToRemove) {
      const issue = this.state.relatedIssues.find(({ id }) => id === idToRemove);

      this.$apollo
        .mutate({
          mutation: unlinkProjectComplianceViolationIssue,
          variables: {
            input: {
              violationId: this.violationId,
              projectPath: issue.projectPath || this.projectPath,
              issueIid: issue.iid.toString(),
            },
          },
        })
        .then(({ data }) => {
          if (data?.unlinkProjectComplianceViolationIssue?.errors?.length > 0) {
            throw new Error(data.unlinkProjectComplianceViolationIssue.errors.join(', '));
          }
          this.store.removeRelatedIssue(issue);
        })
        .catch(() => {
          createAlert({
            message: s__(
              'ComplianceViolation|Something went wrong while trying to unlink the issue. Please try again later.',
            ),
          });
        });
    },
    addPendingReferences({ untouchedRawReferences, touchedReference = '' }) {
      this.store.addPendingReferences(untouchedRawReferences);
      this.inputValue = touchedReference;
    },
    removePendingReference(indexToRemove) {
      this.store.removePendingRelatedIssue(indexToRemove);
    },
    processAllReferences(value = '') {
      const rawReferences = value.split(/\s+/).filter((reference) => reference.trim().length > 0);
      this.addPendingReferences({ untouchedRawReferences: rawReferences });
    },
  },
  autoCompleteSources: gl?.GfmAutoComplete?.dataSources,
  issuableType: TYPE_ISSUE,
  pathIdSeparator: PathIdSeparator.Issue,
};
</script>

<template>
  <related-issues-block
    can-admin
    :header-text="s__('ComplianceViolation|Related issues')"
    :add-button-text="s__('ComplianceViolation|Add existing issue')"
    :is-fetching="isFetching"
    :is-submitting="isSubmitting"
    :related-issues="state.relatedIssues"
    :pending-references="state.pendingReferences"
    :is-form-visible="isFormVisible"
    :input-value="inputValue"
    :auto-complete-sources="$options.autoCompleteSources"
    :issuable-type="$options.issuableType"
    :path-id-separator="$options.pathIdSeparator"
    :show-categorized-issues="false"
    :has-error="Boolean(errorMessage)"
    :item-add-failure-message="errorMessage"
    @add-issuable-form-input="addPendingReferences"
    @add-issuable-form-blur="processAllReferences"
    @add-issuable-form-submit="addRelatedIssue"
    @add-issuable-form-cancel="resetForm"
    @pending-issuable-remove-request="removePendingReference"
    @related-issue-remove-request="removeRelatedIssue"
    @show-form="isFormVisible = true"
    @hide-form="isFormVisible = false"
  />
</template>

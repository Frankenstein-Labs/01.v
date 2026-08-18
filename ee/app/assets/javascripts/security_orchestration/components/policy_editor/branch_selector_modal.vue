<script>
import { GlButton, GlFormTextarea, GlLoadingIcon, GlModal, GlSprintf } from '@gitlab/ui';
import { s__, __, sprintf } from '~/locale';
import {
  findItemsWithErrors,
  hasDuplicates,
  mapBranchesToExceptions,
  mapObjectsToString,
} from 'ee/security_orchestration/components/policy_editor/utils';
import branchesQuery from '~/projects/settings/branch_rules/queries/branches.query.graphql';
import { BRANCH_TYPES, REGULAR_BRANCH, PROTECTED_BRANCH } from './constants';

export default {
  i18n: {
    buttonText: __('Add'),
    buttonCancelText: __('Cancel'),
    duplicateErrorMessage: s__('SecurityOrchestration|Please remove duplicated values'),
    errorMessage: s__(
      'SecurityOrchestration|Add project full path after @ to following branches: %{branches}',
    ),
    modalDescription: s__(
      'SecurityOrchestration|List branches in the format %{boldStart}branch-name@group-name/project-name,%{boldEnd} separated by a comma (,).',
    ),
    validationBranchesMessage: s__(
      'SecurityOrchestration|Validating branch names, which might take a while.',
    ),
    validationErrorMessage: s__(
      'SecurityOrchestration|Branch: %{boldStart}%{branchName}%{boldEnd} was not found in project: %{boldStart}%{projectName}%{boldEnd}. Edit or remove this entry.',
    ),
    noProjectError: s__(
      "SecurityOrchestration|Can't find project: %{boldStart}%{projectName}%{boldEnd}. Edit or remove this entry.",
    ),
  },
  name: 'BranchSelectorModal',
  components: {
    GlButton,
    GlFormTextarea,
    GlLoadingIcon,
    GlModal,
    GlSprintf,
  },
  inject: ['namespacePath'],
  props: {
    branches: {
      type: Array,
      required: false,
      default: () => [],
    },
    forProtectedBranches: {
      type: Boolean,
      required: false,
      default: false,
    },
    hasValidation: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['add-branches'],
  data() {
    return {
      loadingValidation: false,
      hasDuplicates: false,
      parsedBranches: this.branches,
      parsedWithErrorsBranches: [],
      asyncValidationErrors: '',
    };
  },
  computed: {
    hasAsyncValidationError() {
      return this.asyncValidationErrors.length > 0;
    },
    convertedToStringBranches() {
      return mapObjectsToString(this.branches);
    },
    defaultProjectName() {
      return this.hasValidation ? undefined : this.namespacePath;
    },
    errorMessage() {
      return sprintf(this.$options.i18n.errorMessage, {
        branches: this.parsedWithErrorsBranches.join(' '),
      });
    },
    modalTitle() {
      return BRANCH_TYPES[this.selectedBranchType] || BRANCH_TYPES[PROTECTED_BRANCH];
    },
    hasValidationError() {
      return this.parsedWithErrorsBranches.length && this.hasValidation;
    },
    selectedBranchType() {
      return this.forProtectedBranches ? PROTECTED_BRANCH : REGULAR_BRANCH;
    },
  },
  methods: {
    mapBranchValidationRequests(branches = []) {
      if (!this.hasValidation) {
        return branches.map(({ name, fullPath }) => ({
          name,
          branch: fullPath,
          exists: true,
          projectExists: true,
        }));
      }

      return branches.map(({ name, fullPath }) => this.doesBranchExist(fullPath, name));
    },
    async doesBranchExist(fullPath, branch) {
      const formatResponse = ({ branchExists = false, projectExists = true } = {}) => ({
        fullPath,
        branch,
        exists: branchExists,
        projectExists,
      });

      try {
        const { data: { project } = {} } = await this.$apollo.query({
          query: branchesQuery,
          variables: {
            projectPath: fullPath,
            searchPattern: `*${branch}*`,
          },
        });

        if (!project) {
          return formatResponse({ branchExists: false, projectExists: false });
        }

        const doesBranchExist =
          Boolean(project) && project.repository?.branchNames?.includes(branch);
        return formatResponse({ branchExists: doesBranchExist });
      } catch {
        return formatResponse({ branchExists: false });
      }
    },
    parseBranches(branches) {
      const split = branches?.split(/[ ,]+/).filter(Boolean) || [];

      this.parsedWithErrorsBranches = [];
      this.asyncValidationErrors = '';

      this.parsedBranches = split.map((item) => {
        const [name, fullPath = this.defaultProjectName] = item.split('@');

        return {
          name,
          fullPath,
          value: item,
        };
      });
    },
    async selectBranches() {
      this.parsedWithErrorsBranches = findItemsWithErrors(this.parsedBranches);
      this.hasDuplicates = hasDuplicates(this.parsedBranches);

      if (this.hasValidationError || this.hasDuplicates) return;

      const parsedSelectedBranches = mapBranchesToExceptions(this.parsedBranches);

      this.loadingValidation = true;
      const branches = await Promise.all(this.mapBranchValidationRequests(parsedSelectedBranches));
      this.loadingValidation = false;

      const failedValidations = branches.filter(
        ({ exists, projectExists }) => !exists || !projectExists,
      );

      this.asyncValidationErrors = failedValidations
        .map(({ fullPath, branch, projectExists }) => {
          const message = !projectExists
            ? this.$options.i18n.noProjectError
            : this.$options.i18n.validationErrorMessage;

          return sprintf(message, {
            branchName: branch,
            projectName: fullPath,
          });
        })
        .join('\r\n');

      if (this.hasAsyncValidationError) {
        return;
      }

      this.hideModalWindow();
      this.$emit('add-branches', parsedSelectedBranches);
    },
    // eslint-disable-next-line vue/no-unused-properties -- used by parent via $refs to open modal
    showModalWindow() {
      this.$refs.modal.show();
    },
    hideModalWindow() {
      this.$refs.modal.hide();
    },
  },
};
</script>

<template>
  <gl-modal
    ref="modal"
    :title="modalTitle"
    modal-id="branch-exceptions-modal"
    @primary.prevent="selectBranches"
  >
    <p data-testid="branch-exceptions-modal-description">
      <gl-sprintf :message="$options.i18n.modalDescription">
        <template #bold="{ content }">
          <b>{{ content }}</b>
        </template>
      </gl-sprintf>
    </p>

    <gl-form-textarea
      class="security-policies-textarea-min-height"
      :no-resize="false"
      :value="convertedToStringBranches"
      :disabled="loadingValidation"
      @input="parseBranches"
    />

    <p v-if="hasValidationError" data-testid="validation-error" class="gl-my-2 gl-text-danger">
      {{ errorMessage }}
    </p>

    <p v-if="hasDuplicates" data-testid="duplicate-error" class="gl-my-2 gl-text-danger">
      {{ $options.i18n.duplicateErrorMessage }}
    </p>

    <p
      v-if="hasAsyncValidationError"
      data-testid="async-validation-error"
      class="gl-my-2 gl-whitespace-pre-line gl-text-danger"
    >
      <gl-sprintf :message="asyncValidationErrors">
        <template #bold="{ content }">
          <strong>{{ content }}</strong>
        </template>
      </gl-sprintf>
    </p>

    <div
      v-if="loadingValidation"
      class="gl-mt-2 gl-flex gl-items-center"
      data-testid="loading-state"
    >
      <gl-loading-icon size="sm" />
      <p class="gl-m-0 gl-ml-3">{{ $options.i18n.validationBranchesMessage }}</p>
    </div>

    <template #modal-footer>
      <gl-button
        class="gl-mt-2"
        data-testid="cancel-button"
        variant="default"
        @click="hideModalWindow"
      >
        {{ $options.i18n.buttonCancelText }}
      </gl-button>

      <gl-button class="gl-mt-2" data-testid="add-button" variant="confirm" @click="selectBranches">
        {{ $options.i18n.buttonText }}
      </gl-button>
    </template>
  </gl-modal>
</template>

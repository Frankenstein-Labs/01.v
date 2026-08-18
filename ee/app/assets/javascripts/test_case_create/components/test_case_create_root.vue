<script>
import { GlButton } from '@gitlab/ui';
import { createAlert } from '~/alert';
import IssuableCreate from '~/vue_shared/issuable/create/components/issuable_create_root.vue';
import { visitUrl } from '~/lib/utils/url_utility';
import { TYPE_TEST_CASE } from '~/issues/constants';

import { s__ } from '~/locale';

import createTestCase from '../queries/create_test_case.mutation.graphql';

export default {
  name: 'TestCaseCreateRoot',
  TYPE_TEST_CASE,
  components: {
    GlButton,
    IssuableCreate,
  },
  inject: [
    'projectFullPath',
    'projectTestCasesPath',
    'descriptionPreviewPath',
    'descriptionHelpPath',
    'labelsFetchPath',
    'labelsManagePath',
  ],
  data() {
    return {
      createTestCaseRequestActive: false,
    };
  },
  methods: {
    handleTestCaseSubmitClick({
      issuableTitle,
      issuableDescription,
      issuableConfidential,
      selectedLabels,
    }) {
      this.createTestCaseRequestActive = true;
      return this.$apollo
        .mutate({
          mutation: createTestCase,
          variables: {
            createTestCaseInput: {
              projectPath: this.projectFullPath,
              title: issuableTitle,
              description: issuableDescription,
              confidential: issuableConfidential,
              labelIds: selectedLabels.map((label) => label.id),
            },
          },
        })
        .then(({ data = {} }) => {
          const errors = data.createTestCase?.errors;
          if (errors?.length) {
            const error = errors[0];
            createAlert({
              message: error,
              captureError: true,
              error,
            });
            return;
          }
          visitUrl(this.projectTestCasesPath);
        })
        .catch((error) => {
          createAlert({
            message: s__('TestCases|Something went wrong while creating a test case.'),
            captureError: true,
            error,
          });
        })
        .finally(() => {
          this.createTestCaseRequestActive = false;
        });
    },
  },
};
</script>

<template>
  <issuable-create
    :description-preview-path="descriptionPreviewPath"
    :description-help-path="descriptionHelpPath"
    :labels-fetch-path="labelsFetchPath"
    :labels-manage-path="labelsManagePath"
    :issuable-type="$options.TYPE_TEST_CASE"
  >
    <template #title>
      <h1 class="page-title gl-text-size-h-display">{{ s__('TestCases|New test case') }}</h1>
    </template>
    <template #actions="{ issuableMeta }">
      <gl-button
        data-testid="submit-test-case"
        category="primary"
        variant="confirm"
        :loading="createTestCaseRequestActive"
        :disabled="!issuableMeta.issuableTitle.length"
        class="gl-mr-2"
        @click="handleTestCaseSubmitClick(issuableMeta)"
        >{{ s__('TestCases|Submit test case') }}</gl-button
      >
      <gl-button
        data-testid="cancel-test-case"
        :disabled="createTestCaseRequestActive"
        :href="projectTestCasesPath"
        >{{ __('Cancel') }}</gl-button
      >
    </template>
  </issuable-create>
</template>

<script>
import { mapState } from 'pinia';

import { useIntegrationForm } from '~/integrations/edit/store';
import JiraVerificationFields from '../jira_verification_fields.vue';

export default {
  name: 'IntegrationSectionJiraVerification',
  components: {
    JiraVerificationFields,
  },
  computed: {
    ...mapState(useIntegrationForm, ['currentKey', 'propsSource']),
  },
};
</script>

<template>
  <div>
    <jira-verification-fields
      :key="`${currentKey}-jira-verification-fields`"
      v-bind="propsSource.jiraVerificationProps"
    />
  </div>
</template>

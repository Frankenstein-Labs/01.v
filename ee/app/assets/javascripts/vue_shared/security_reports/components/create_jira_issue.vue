<script>
import { GlButton } from '@gitlab/ui';
import vulnerabilityExternalIssueLinkCreate from 'ee/vue_shared/security_reports/graphql/vulnerability_external_issue_link_create.mutation.graphql';
import { TYPENAME_VULNERABILITY } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { s__ } from '~/locale';

export const i18n = {
  createIssueText: s__('VulnerabilityManagement|Create Jira issue'),
};

export default {
  name: 'CreateJiraIssue',
  i18n,
  components: {
    GlButton,
  },
  inject: {
    createJiraIssueUrl: {
      default: '',
    },
    customizeJiraIssueEnabled: {
      default: false,
    },
  },
  props: {
    vulnerabilityId: {
      type: Number,
      required: true,
    },
    size: {
      type: String,
      required: false,
      default: 'medium',
    },
  },
  emits: ['create-jira-issue-error', 'mutated'],
  data() {
    return {
      isLoading: false,
    };
  },
  computed: {
    showCustomizeJiraIssue() {
      return this.createJiraIssueUrl && this.customizeJiraIssueEnabled;
    },
  },
  methods: {
    async createJiraIssue() {
      this.isLoading = true;
      try {
        const { data } = await this.$apollo.mutate({
          mutation: vulnerabilityExternalIssueLinkCreate,
          variables: {
            input: {
              externalTracker: 'JIRA',
              linkType: 'CREATED',
              id: convertToGraphQLId(TYPENAME_VULNERABILITY, this.vulnerabilityId),
            },
          },
        });

        const { errors } = data.vulnerabilityExternalIssueLinkCreate;

        if (errors.length > 0) {
          throw new Error(errors[0]);
        }
        this.$emit('mutated');
      } catch (e) {
        this.$emit('create-jira-issue-error', e.message);
      } finally {
        this.isLoading = false;
      }
    },
  },
};
</script>

<template>
  <gl-button
    v-if="showCustomizeJiraIssue"
    variant="confirm"
    category="secondary"
    :size="size"
    :href="createJiraIssueUrl"
    icon="external-link"
    target="_blank"
    data-testid="customize-jira-issue"
    >{{ $options.i18n.createIssueText }}</gl-button
  >
  <gl-button
    v-else
    variant="confirm"
    category="secondary"
    :size="size"
    :loading="isLoading"
    data-testid="create-new-jira-issue"
    @click="createJiraIssue"
  >
    {{ $options.i18n.createIssueText }}
  </gl-button>
</template>

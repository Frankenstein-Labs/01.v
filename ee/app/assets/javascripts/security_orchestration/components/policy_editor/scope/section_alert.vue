<script>
import { GlAlert } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import {
  ALL_PROJECTS_IN_GROUP,
  ALL_PROJECTS_IN_LINKED_GROUPS,
  PROJECTS_WITH_FRAMEWORK,
  SPECIFIC_PROJECTS,
} from 'ee/security_orchestration/components/policy_editor/scope/constants';

export default {
  i18n: {
    alertTitle: __('Error'),
    complianceFrameworkErrorMessage: s__(
      'SecurityOrchestration|You must select one or more compliance frameworks to which this policy should apply.',
    ),
    exceptionProjectsErrorMessage: s__(
      'SecurityOrchestration|You must select one or more projects to be excluded from this policy.',
    ),
    linkedGroupsErrorMessage: s__(
      'SecurityOrchestration|You must select one or more groups from this policy.',
    ),
    specificProjectsErrorMessage: s__(
      'SecurityOrchestration|You must select one or more projects to which this policy should apply.',
    ),
  },
  name: 'ScopeSectionAlert',
  components: {
    GlAlert,
  },
  props: {
    projectScopeType: {
      type: String,
      required: false,
      default: PROJECTS_WITH_FRAMEWORK,
    },
    projectEmpty: {
      type: Boolean,
      required: false,
      default: false,
    },
    groupsEmpty: {
      type: Boolean,
      required: false,
      default: false,
    },
    complianceFrameworksEmpty: {
      type: Boolean,
      required: false,
      default: false,
    },
    isProjectsWithoutExceptions: {
      type: Boolean,
      required: false,
      default: false,
    },
    isDirty: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    errorDescription() {
      const typeErrorMap = {
        [PROJECTS_WITH_FRAMEWORK]: this.$options.i18n.complianceFrameworkErrorMessage,
        [ALL_PROJECTS_IN_LINKED_GROUPS]: this.$options.i18n.linkedGroupsErrorMessage,
        [ALL_PROJECTS_IN_GROUP]: this.$options.i18n.exceptionProjectsErrorMessage,
        [SPECIFIC_PROJECTS]: this.$options.i18n.specificProjectsErrorMessage,
      };

      return typeErrorMap[this.projectScopeType];
    },
    allProjectsInGroup() {
      return this.projectScopeType === ALL_PROJECTS_IN_GROUP;
    },
    allProjectsInLinkedGroup() {
      return this.projectScopeType === ALL_PROJECTS_IN_LINKED_GROUPS;
    },
    specificProjects() {
      return this.projectScopeType === SPECIFIC_PROJECTS;
    },
    projectsWithFrameworks() {
      return this.projectScopeType === PROJECTS_WITH_FRAMEWORK;
    },
    showAlert() {
      if (!this.isDirty) {
        return false;
      }

      if (this.allProjectsInGroup && this.isProjectsWithoutExceptions) {
        return false;
      }

      if (this.allProjectsInGroup || this.specificProjects) {
        return this.projectEmpty;
      }

      if (this.allProjectsInLinkedGroup) {
        return this.groupsEmpty;
      }

      if (this.projectsWithFrameworks) {
        return this.complianceFrameworksEmpty;
      }

      return false;
    },
  },
};
</script>

<template>
  <gl-alert
    v-if="showAlert"
    :title="$options.i18n.alertTitle"
    class="gl-mb-5"
    variant="danger"
    :dismissible="false"
  >
    {{ errorDescription }}
  </gl-alert>
</template>

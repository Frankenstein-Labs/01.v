<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { isEmpty } from 'lodash-es';
import { s__ } from '~/locale';
import {
  ALL_PROJECTS_IN_GROUP,
  EXCEPT_PROJECTS,
  EXCEPT_PERSONAL_PROJECTS,
  EXCEPT_GROUPS,
  EXCLUDING,
  INCLUDING,
  WITHOUT_EXCEPTIONS,
  EXCEPTION_TYPE_LISTBOX_ITEMS,
  EXCEPTION_WITH_PERSONAL_TYPE_LISTBOX_ITEMS,
  EXCEPTION_TYPE_TEXTS,
  GROUP_EXCEPTION_TYPE_LISTBOX_ITEMS,
  GROUP_EXCEPTION_TYPE_TEXTS,
  PROJECT_EXCEPTION_TYPE_PAYLOADS,
  GROUP_EXCEPTION_TYPE_PAYLOADS,
} from 'ee/security_orchestration/components/policy_editor/scope/constants';
import GroupProjectsDropdown from 'ee/security_orchestration/components/shared/group_projects_dropdown.vue';
import LinkedGroupsProjectsDropdown from 'ee/security_orchestration/components/shared/linked_groups_projects_dropdown.vue';
import EligibleProjectsDropdown from 'ee/security_orchestration/components/shared/eligible_projects_dropdown.vue';
import InstanceProjectsDropdown from 'ee/security_orchestration/components/shared/instance_projects_dropdown.vue';
import ScopedGroupsDropdown from 'ee/security_orchestration/components/shared/scoped_groups_dropdown.vue';
import { isGroup } from 'ee/security_orchestration/components/utils';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_PROJECT, TYPENAME_GROUP } from '~/graphql_shared/constants';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';

export default {
  GROUP_EXCEPTION_TYPE_LISTBOX_ITEMS,
  PROJECT_EXCEPTION_TYPE_PAYLOADS,
  GROUP_EXCEPTION_TYPE_PAYLOADS,
  i18n: {
    groupProjectErrorDescription: s__('SecurityOrchestration|Failed to load group projects'),
    groupErrorDescription: s__('SecurityOrchestration|Failed to load groups'),
  },
  name: 'ScopeProjectSelector',
  components: {
    GlCollapsibleListbox,
    GroupProjectsDropdown,
    LinkedGroupsProjectsDropdown,
    EligibleProjectsDropdown,
    InstanceProjectsDropdown,
    ScopedGroupsDropdown,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: {
    designatedAsCsp: { default: false },
    assignedPolicyProject: { default: null },
    namespaceType: { default: '' },
  },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    projects: {
      type: Object,
      required: true,
      default: () => ({}),
    },
    groups: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    groupFullPath: {
      type: String,
      required: false,
      default: null,
    },
    exceptionType: {
      type: String,
      required: false,
      default: WITHOUT_EXCEPTIONS,
    },
    groupExceptionType: {
      type: String,
      required: false,
      default: WITHOUT_EXCEPTIONS,
    },
    isDirty: {
      type: Boolean,
      required: false,
      default: false,
    },
    projectScopeType: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['error', 'changed', 'select-exception-type', 'select-group-exception-type'],
  computed: {
    exceptionTypeListboxItems() {
      return this.designatedAsCsp
        ? EXCEPTION_WITH_PERSONAL_TYPE_LISTBOX_ITEMS
        : EXCEPTION_TYPE_LISTBOX_ITEMS;
    },
    payloadKey() {
      return this.showExceptions ? EXCLUDING : INCLUDING;
    },
    showExceptions() {
      return Boolean(this.projects?.excluding) || isEmpty(this.projects);
    },
    projectIds() {
      /**
       * Protection from manual yaml input as objects
       * Filter out items without id (e.g. { type: 'personal' })
       * return Array of objects with mapped to GraphQl format ids
       */
      const projects = Array.isArray(this.projects?.[this.payloadKey])
        ? this.projects?.[this.payloadKey]
        : [];

      const projectIds = projects.filter((project) => project?.id).map(({ id }) => id);

      if (this.designatedAsCsp) {
        return projectIds;
      }

      // Non-CSP project selector uses graphql
      return projectIds.map((id) => convertToGraphQLId(TYPENAME_PROJECT, id));
    },
    excludingGroupIds() {
      const excludingGroups = Array.isArray(this.groups?.excluding) ? this.groups.excluding : [];

      return excludingGroups
        .filter((group) => group?.id)
        .map(({ id }) => convertToGraphQLId(TYPENAME_GROUP, id));
    },
    selectedExceptionTypeText() {
      return EXCEPTION_TYPE_TEXTS[this.exceptionType];
    },
    selectedGroupExceptionTypeText() {
      return (
        GROUP_EXCEPTION_TYPE_TEXTS[this.groupExceptionType] ||
        GROUP_EXCEPTION_TYPE_TEXTS[WITHOUT_EXCEPTIONS]
      );
    },
    showProjectsDropdown() {
      return this.exceptionType === EXCEPT_PROJECTS || !this.showExceptions;
    },
    showGroupsDropdown() {
      return this.projectScopeType === ALL_PROJECTS_IN_GROUP;
    },
    showGroupsSelectionDropdown() {
      return this.groupExceptionType === EXCEPT_GROUPS;
    },
    projectsEmpty() {
      return this.projectIds.length === 0;
    },
    isFieldValid() {
      // If we're excluding personal projects, that's a valid non-empty state
      return (
        !this.projectsEmpty || this.exceptionType === EXCEPT_PERSONAL_PROJECTS || !this.isDirty
      );
    },
    isGroupLevel() {
      return isGroup(this.namespaceType);
    },
    useSppProjectsDropdown() {
      // Load projects from all groups linked to the SPP when:
      // 1. We are at group level, AND
      // 2. A security policy project is already assigned
      // For new policies in groups without an assigned SPP, load projects from the group namespace only
      return this.isGroupLevel && Boolean(this.assignedPolicyProject?.fullPath);
    },
    sppProjectsDropdown() {
      return this.glFeatures.securityPolicyEligibleProjectsDropdown
        ? EligibleProjectsDropdown
        : LinkedGroupsProjectsDropdown;
    },
  },
  methods: {
    emitError(message) {
      this.$emit('error', message);
    },
    selectExceptionType(type, { payloads, event }) {
      const payload = payloads[type];
      if (payload) {
        this.$emit('changed', payload);
      }

      this.$emit(event, type);
    },
    setSelectedItems(items, { key, payloadKey }) {
      const ids = items.map(({ id }) => ({ id: getIdFromGraphQLId(id) }));
      this.$emit('changed', { [key]: { [payloadKey]: ids } });
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-gap-3">
    <gl-collapsible-listbox
      v-if="showExceptions"
      data-testid="exception-type"
      :disabled="disabled"
      :items="exceptionTypeListboxItems"
      :toggle-text="selectedExceptionTypeText"
      :selected="exceptionType"
      @select="
        selectExceptionType($event, {
          payloads: $options.PROJECT_EXCEPTION_TYPE_PAYLOADS,
          event: 'select-exception-type',
        })
      "
    />

    <template v-if="showProjectsDropdown">
      <instance-projects-dropdown
        v-if="designatedAsCsp"
        :disabled="disabled"
        :selected="projectIds"
        :state="isFieldValid"
        @projects-query-error="emitError($options.i18n.groupProjectErrorDescription)"
        @select="setSelectedItems($event, { key: 'projects', payloadKey })"
      />

      <component
        :is="sppProjectsDropdown"
        v-else-if="useSppProjectsDropdown"
        with-project-count
        :disabled="disabled"
        :selected="projectIds"
        :state="isFieldValid"
        @projects-query-error="emitError"
        @select="setSelectedItems($event, { key: 'projects', payloadKey })"
      />

      <group-projects-dropdown
        v-else
        with-project-count
        :disabled="disabled"
        :group-full-path="groupFullPath"
        :selected="projectIds"
        :state="isFieldValid"
        @projects-query-error="emitError($options.i18n.groupProjectErrorDescription)"
        @select="setSelectedItems($event, { key: 'projects', payloadKey })"
      />
    </template>

    <template v-if="showGroupsDropdown">
      <gl-collapsible-listbox
        data-testid="group-exception-type"
        :disabled="disabled"
        :items="$options.GROUP_EXCEPTION_TYPE_LISTBOX_ITEMS"
        :toggle-text="selectedGroupExceptionTypeText"
        :selected="groupExceptionType"
        @select="
          selectExceptionType($event, {
            payloads: $options.GROUP_EXCEPTION_TYPE_PAYLOADS,
            event: 'select-group-exception-type',
          })
        "
      />

      <scoped-groups-dropdown
        v-if="showGroupsSelectionDropdown"
        data-testid="excluding-groups-dropdown"
        with-project-count
        :full-path="groupFullPath"
        :disabled="disabled"
        :selected="excludingGroupIds"
        :state="true"
        :use-descendant-groups="!designatedAsCsp"
        @linked-items-query-error="emitError($options.i18n.groupErrorDescription)"
        @select="setSelectedItems($event, { key: 'groups', payloadKey: 'excluding' })"
      />
    </template>
  </div>
</template>

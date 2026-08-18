<script>
import { GlAccordion, GlAccordionItem, GlLink } from '@gitlab/ui';
import { s__, n__, sprintf } from '~/locale';
import { getSecurityPolicyListUrl } from '~/editor/extensions/source_editor_security_policy_schema_ext';

export default {
  i18n: {
    groupsHeader: s__('SecurityOrchestration|Linked groups'),
    groupsInlineListHeader: s__('SecurityOrchestration|All projects in linked groups'),
    groupsInlineListSubHeader: s__('SecurityOrchestration|(%{groups})'),
    projectsHeader: s__('SecurityOrchestration|Excluded projects'),
    personalProjectsText: s__('SecurityOrchestration|personal projects'),
  },
  name: 'GroupsToggleList',
  components: {
    GlAccordion,
    GlAccordionItem,
    GlLink,
  },
  props: {
    inlineList: {
      type: Boolean,
      required: false,
      default: false,
    },
    groups: {
      type: Array,
      required: false,
      default: () => [],
    },
    projects: {
      type: Array,
      required: false,
      default: () => [],
    },
    isLink: {
      type: Boolean,
      required: false,
      default: false,
    },
    excludingPersonalProjects: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    hasProjects() {
      return this.projectsLength > 0 || this.excludingPersonalProjects;
    },
    hasGroups() {
      return this.groupsLength > 0;
    },
    groupsLength() {
      return this.groups.length;
    },
    projectsLength() {
      return this.projects.length;
    },
    groupsHeader() {
      const template = this.hasProjects
        ? n__(
            'All projects in %{groupsLength} group, with exclusions:',
            'All projects in %{groupsLength} groups, with exclusions:',
            this.groupsLength,
          )
        : n__(
            'All projects in %{groupsLength} group:',
            'All projects in %{groupsLength} groups:',
            this.groupsLength,
          );

      return sprintf(template, { groupsLength: this.groupsLength });
    },
    groupsInlineListSubHeader() {
      const groupsMessage = sprintf(
        n__('%{groupsLength} group', '%{groupsLength} groups', this.groupsLength),
        {
          groupsLength: this.groupsLength,
        },
      );

      return sprintf(this.$options.i18n.groupsInlineListSubHeader, {
        groups: groupsMessage,
      });
    },
  },
  methods: {
    getSecurityPolicyListUrl(source, namespaceType = 'group') {
      return getSecurityPolicyListUrl({ namespacePath: source?.fullPath || '', namespaceType });
    },
  },
};
</script>

<template>
  <div>
    <div v-if="inlineList" data-testid="groups-list-inline-header">
      <p class="gl-mb-2">{{ $options.i18n.groupsInlineListHeader }}</p>
      <p v-if="hasGroups" class="gl-m-0">{{ groupsInlineListSubHeader }}</p>
    </div>

    <template v-else>
      <p class="gl-mb-3" data-testid="groups-list-header">{{ groupsHeader }}</p>

      <gl-accordion :header-level="3" :class="{ 'gl-mb-2': hasProjects }">
        <gl-accordion-item :title="$options.i18n.groupsHeader" data-testid="groups-list">
          <ul>
            <li v-for="group of groups" :key="group.fullPath" data-testid="group-item">
              <template v-if="isLink">
                <gl-link :href="getSecurityPolicyListUrl(group)" target="_blank">{{
                  group.name
                }}</gl-link>
              </template>
              <span v-else>{{ group.name }}</span>
            </li>
          </ul>
        </gl-accordion-item>
      </gl-accordion>

      <gl-accordion v-if="hasProjects" :header-level="3">
        <gl-accordion-item :title="$options.i18n.projectsHeader" data-testid="projects-list">
          <ul>
            <li v-if="excludingPersonalProjects" data-testid="personal-projects-item">
              <span>{{ $options.i18n.personalProjectsText }}</span>
            </li>
            <li v-for="project of projects" :key="project.fullPath" data-testid="project-item">
              <template v-if="isLink">
                <gl-link :href="getSecurityPolicyListUrl(project, 'project')" target="_blank">{{
                  project.name
                }}</gl-link>
              </template>
              <span v-else>{{ project.name }}</span>
            </li>
          </ul>
        </gl-accordion-item>
      </gl-accordion>
    </template>
  </div>
</template>

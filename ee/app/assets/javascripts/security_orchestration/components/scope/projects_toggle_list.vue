<script>
import { s__, n__, sprintf, __ } from '~/locale';
import ToggleList from './toggle_list.vue';

export default {
  name: 'ProjectsToggleList',
  components: {
    ToggleList,
  },
  i18n: {
    allProjectsButtonText: s__('SecurityOrchestration|Show all included projects'),
    hideProjectsButtonText: s__('SecurityOrchestration|Hide extra projects'),
    showMoreProjectsLabel: s__('SecurityOrchestration|Show more projects'),
    hideMoreProjectsLabel: s__('SecurityOrchestration|Hide extra projects'),
    allLabel: __('All'),
    projectsLabel: __('projects'),
  },
  props: {
    isInstanceLevel: {
      type: Boolean,
      required: false,
      default: false,
    },
    projects: {
      type: Array,
      required: false,
      default: () => [],
    },
    including: {
      type: Boolean,
      required: false,
      default: false,
    },
    projectsToShow: {
      type: Number,
      required: false,
      default: 0,
    },
    bulletStyle: {
      type: Boolean,
      required: false,
      default: true,
    },
    inlineList: {
      type: Boolean,
      required: false,
      default: false,
    },
    isGroup: {
      type: Boolean,
      required: false,
      default: true,
    },
    excludingPersonalProjects: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    allProjects() {
      return !this.including && this.projects.length === 0 && !this.excludingPersonalProjects;
    },
    allProjectsExcept() {
      return !this.including && (this.projects.length > 0 || this.excludingPersonalProjects);
    },
    customButtonText() {
      return this.allProjects ? this.$options.i18n.allProjectsButtonText : null;
    },
    projectIncludingText() {
      const projects = n__('project', 'projects', this.projects.length);
      return sprintf(__('%{projectLength} %{projects}:'), {
        projectLength: this.projects.length,
        projects,
      });
    },
    header() {
      if (this.allProjects) {
        return this.renderHeader(
          s__('SecurityOrchestration|%{allLabel}%{projectCount} %{projectLabel} in this group'),
        );
      }

      if (this.allProjectsExcept) {
        if (this.isInstanceLevel) {
          return s__('SecurityOrchestration|All projects in this instance except:');
        }

        if (this.isGroup) {
          return s__('SecurityOrchestration|All projects in this group except:');
        }

        return s__('SecurityOrchestration|All projects linked to this project except:');
      }

      return this.projectIncludingText;
    },
    projectNames() {
      return this.projects.map(({ name }) => name);
    },
    toggleListItems() {
      return this.excludingPersonalProjects
        ? [s__('SecurityOrchestration|personal projects'), ...this.projectNames]
        : this.projectNames;
    },
  },
  methods: {
    renderHeader(message) {
      const projectLength = this.projects.length;
      const projectLabel = n__('project', 'projects', projectLength);

      return sprintf(message, {
        allLabel: projectLength === 0 ? this.$options.i18n.allLabel : '',
        projectCount: projectLength > 0 ? ` ${projectLength}` : '',
        projectLabel,
      }).trim();
    },
  },
};
</script>

<template>
  <div>
    <p class="gl-mb-2" data-testid="toggle-list-header">{{ header }}</p>

    <toggle-list
      v-if="toggleListItems.length"
      :bullet-style="bulletStyle"
      :custom-button-text="$options.i18n.showMoreProjectsLabel"
      :custom-close-button-text="$options.i18n.hideMoreProjectsLabel"
      :inline-list="inlineList"
      :default-button-text="customButtonText"
      :default-close-button-text="$options.i18n.hideProjectsButtonText"
      :items="toggleListItems"
      :items-to-show="projectsToShow"
    />
  </div>
</template>

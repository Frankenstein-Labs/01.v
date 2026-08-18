<script>
import { GlBreadcrumb } from '@gitlab/ui';
import { __ } from '~/locale';
import {
  ROUTE_STANDARDS_ADHERENCE,
  ROUTE_VIOLATIONS,
  ROUTE_FRAMEWORKS,
  ROUTE_PROJECTS,
  ROUTE_NEW_FRAMEWORK,
  ROUTE_NEW_FRAMEWORK_SUCCESS,
  ROUTE_EDIT_FRAMEWORK,
  i18n,
} from '../constants';

export default {
  name: 'ComplianceDashboardBreadcrumbs',
  components: {
    GlBreadcrumb,
  },
  props: {
    staticBreadcrumbs: {
      type: Array,
      required: true,
    },
  },
  computed: {
    rootRoute() {
      return {
        text: i18n.heading,
        to: '/',
      };
    },
    activeTabRoute() {
      if (this.$route.fullPath.includes(ROUTE_STANDARDS_ADHERENCE)) {
        return {
          text: i18n.standardsAdherenceTab,
          to: { name: ROUTE_STANDARDS_ADHERENCE },
        };
      }

      if (this.$route.fullPath.includes(ROUTE_VIOLATIONS)) {
        return {
          text: i18n.violationsTab,
          to: { name: ROUTE_VIOLATIONS },
        };
      }

      if (this.$route.fullPath.includes(ROUTE_FRAMEWORKS)) {
        return {
          text: i18n.frameworksTab,
          to: { name: ROUTE_FRAMEWORKS },
        };
      }

      if (this.$route.fullPath.includes(ROUTE_PROJECTS)) {
        return {
          text: i18n.projectsTab,
          to: { name: ROUTE_PROJECTS },
        };
      }

      return null;
    },
    actionRoute() {
      switch (this.$route.name) {
        case ROUTE_NEW_FRAMEWORK:
          return {
            text: __('New'),
            to: { name: ROUTE_NEW_FRAMEWORK },
          };
        case ROUTE_NEW_FRAMEWORK_SUCCESS:
          return {
            text: __('Success'),
            to: { name: ROUTE_NEW_FRAMEWORK_SUCCESS },
          };
        case ROUTE_EDIT_FRAMEWORK:
          return {
            text: __('Edit'),
            to: { name: ROUTE_EDIT_FRAMEWORK },
          };
        default:
          return null;
      }
    },
    breadcrumbs() {
      const breadCrumbs = [...this.staticBreadcrumbs, this.rootRoute];

      if (this.activeTabRoute) breadCrumbs.push(this.activeTabRoute);
      if (this.actionRoute) breadCrumbs.push(this.actionRoute);

      return breadCrumbs;
    },
  },
};
</script>
<template>
  <gl-breadcrumb :items="breadcrumbs" />
</template>

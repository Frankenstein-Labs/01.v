<script>
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { joinPaths } from '~/lib/utils/url_utility';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import FrameworkBadge from '../../compliance_dashboard/components/shared/framework_badge.vue';
import { statusesInfo } from '../../compliance_dashboard/components/standards_adherence_report/components/details_drawer/statuses_info';

export default {
  name: 'ViolationSection',
  components: {
    CrudComponent,
    FrameworkBadge,
  },
  props: {
    control: {
      type: Object,
      required: true,
    },
    complianceCenterPath: {
      type: String,
      required: true,
    },
  },
  computed: {
    viewDetailsUrl() {
      return joinPaths(
        gon?.gitlab_url || '',
        `${this.complianceCenterPath}?id=${getIdFromGraphQLId(this.framework.id)}`,
      );
    },
    framework() {
      return this.control.complianceRequirement?.framework || {};
    },
    requirement() {
      return this.control.complianceRequirement?.name || '';
    },
    controlTitle() {
      if (!this.control || !this.control.name) {
        return '';
      }

      const statusInfo = statusesInfo[this.control.name];
      return statusInfo?.title || this.control.name;
    },
  },
};
</script>
<template>
  <crud-component>
    <template #title>
      {{ s__('ComplianceViolation|Violation created based on associated framework') }}
    </template>

    <template #default>
      <div data-testid="violation-framework">
        {{ s__('ComplianceViolation|Framework') }}:
        <framework-badge
          :framework="framework"
          :view-details-url="viewDetailsUrl"
          popover-mode="details"
          class="gl-inline"
        />
      </div>

      <div data-testid="violation-requirement">
        {{ s__('ComplianceViolation|Requirement') }}:
        {{ requirement }}
      </div>

      <div data-testid="violation-control">
        {{ s__('ComplianceViolation|Control') }}:
        {{ controlTitle }}
      </div>
    </template>
  </crud-component>
</template>

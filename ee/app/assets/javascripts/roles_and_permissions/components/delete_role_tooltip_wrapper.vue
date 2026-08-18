<script>
import { GlPopover, GlLink, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';
import { isAdminRole } from '../utils';

export default {
  name: 'DeleteRoleTooltipWrapper',
  components: { GlPopover, GlLink },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    role: {
      type: Object,
      required: true,
    },
    containerId: {
      type: String,
      required: false,
      default: null,
    },
  },
  computed: {
    hasDependentSecurityPolicies() {
      return this.role.dependentSecurityPolicies?.length > 0;
    },
    deleteTooltip() {
      // We'll show a popover instead of a tooltip for dependent security policies.
      if (this.hasDependentSecurityPolicies) {
        return '';
      }
      if (this.role.usersCount > 0) {
        return isAdminRole(this.role)
          ? s__('MemberRole|To delete custom admin role, remove role from all users.')
          : s__(
              'MemberRole|To delete custom member role, remove role from all group and project members.',
            );
      }
      if (this.role.ldapAdminRoleLinks?.nodes?.length > 0) {
        return s__(
          "MemberRole|You can't delete this admin custom role until you delete all LDAP syncs that use it.",
        );
      }

      return '';
    },
  },
};
</script>

<template>
  <div ref="wrapper" v-gl-tooltip:[containerId].d0.left.viewport="deleteTooltip">
    <slot></slot>

    <gl-popover
      v-if="hasDependentSecurityPolicies"
      :target="() => $refs.wrapper"
      :title="s__('MemberRole|Security policy dependency')"
      :container="containerId"
      placement="left"
      boundary="viewport"
    >
      <p class="gl-mb-2 gl-min-w-[20em]">
        {{
          s__(
            'MemberRole|To delete custom member role, remove role from the following security policies:',
          )
        }}
      </p>
      <ul class="gl-mb-2 gl-pl-5">
        <li v-for="policy in role.dependentSecurityPolicies" :key="policy.name">
          <gl-link :href="policy.editPath" target="_blank">{{ policy.name }}</gl-link>
        </li>
      </ul>
    </gl-popover>
  </div>
</template>

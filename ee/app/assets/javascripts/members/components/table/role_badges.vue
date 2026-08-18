<script>
import { GlBadge, GlTooltipDirective } from '@gitlab/ui';
import { isNil } from 'lodash-es';
import { s__ } from '~/locale';

export default {
  name: 'RoleBadges',
  components: { GlBadge },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    member: {
      type: Object,
      required: true,
    },
    role: {
      type: Object,
      required: true,
    },
  },
  computed: {
    hasBadges() {
      return this.isCustomRole || this.isLdapRoleOverridden;
    },
    isCustomRole() {
      return !isNil(this.role.memberRoleId);
    },
    isLdapRoleOverridden() {
      // canOverride means this is an LDAP user, isOverridden is whether the role was changed to be different than the
      // role configured in the LDAP sync settings.
      return this.member.canOverride && this.member.isOverridden;
    },
  },
  ldapOverrideTooltip: s__(
    'MemberRole|This role has been manually selected and will not sync to the LDAP sync role.',
  ),
};
</script>

<template>
  <div v-if="hasBadges" class="gl-flex gl-flex-wrap gl-gap-2">
    <gl-badge
      v-if="isLdapRoleOverridden"
      v-gl-tooltip.bottom.viewport.d0="$options.ldapOverrideTooltip"
      variant="warning"
      data-testid="overridden-badge"
    >
      {{ s__('MemberRole|Overridden') }}
    </gl-badge>
    <gl-badge v-if="isCustomRole" data-testid="custom-role-badge">
      {{ s__('MemberRole|Custom role') }}
    </gl-badge>
  </div>
</template>

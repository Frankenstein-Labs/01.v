<script>
import { GlSprintf } from '@gitlab/ui';
import AccessSummary from '~/admin/users/components/user_type/access_summary.vue';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';

export default {
  name: 'AuditorAccessSummary',
  components: { AccessSummary, GlSprintf, HelpPageLink },
  mixins: [glSlotsMixin],
};
</script>

<template>
  <access-summary>
    <template v-if="glSlots().default" #admin-content>
      <slot></slot>
    </template>
    <template v-if="!glSlots().default" #admin-list>
      <li>{{ s__('AdminUsers|No access.') }}</li>
    </template>

    <template #group-list>
      <li>{{ s__('AdminUsers|Read access to all groups and projects.') }}</li>
      <li>
        <gl-sprintf
          :message="
            s__(
              'AdminUsers|May be directly added to groups and projects. %{linkStart}Learn more about auditor role.%{linkEnd}',
            )
          "
        >
          <template #link="{ content }">
            <help-page-link href="administration/auditor_users" target="_blank">
              {{ content }}
            </help-page-link>
          </template>
        </gl-sprintf>
      </li>
    </template>
    <template #settings-list>
      <li>
        {{ s__('AdminUsers|Requires at least Maintainer role in specific groups and projects.') }}
      </li>
    </template>
  </access-summary>
</template>

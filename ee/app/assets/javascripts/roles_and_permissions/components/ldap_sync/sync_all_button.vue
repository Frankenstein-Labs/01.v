<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import adminRolesLdapSyncMutation from '../../graphql/ldap_sync/admin_roles_ldap_sync.graphql';

export default {
  name: 'SyncAllButton',
  i18n: {
    scheduled: s__(
      'MemberRole|The LDAP sync has been scheduled. Refresh the page to view sync status.',
    ),
  },
  components: { GlButton },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  data() {
    return {
      alert: null,
      isSyncRunning: false,
      isSyncScheduled: false,
    };
  },
  computed: {
    icon() {
      return this.isSyncRunning ? '' : 'retry';
    },
    text() {
      return this.isSyncScheduled ? s__('MemberRole|Sync scheduled') : s__('MemberRole|Sync all');
    },
    tooltip() {
      return this.isSyncScheduled ? this.$options.i18n.scheduled : '';
    },
  },
  methods: {
    async startSync() {
      try {
        this.alert?.dismiss();
        this.isSyncRunning = true;

        const response = await this.$apollo.mutate({ mutation: adminRolesLdapSyncMutation });

        const error = response.data.adminRolesLdapSync.errors[0];
        if (error) {
          this.showSyncError();
        } else {
          this.isSyncScheduled = true;
          this.alert = createAlert({
            variant: 'info',
            message: this.$options.i18n.scheduled,
          });
        }
      } catch ({ message }) {
        this.showSyncError();
      } finally {
        this.isSyncRunning = false;
      }
    },
    showSyncError() {
      this.alert = createAlert({
        message: s__('MemberRole|Failed to schedule LDAP sync. Please retry syncing.'),
      });
    },
  },
};
</script>

<template>
  <div v-gl-tooltip.d0="tooltip">
    <gl-button :icon="icon" :loading="isSyncRunning" :disabled="isSyncScheduled" @click="startSync">
      {{ text }}
    </gl-button>
  </div>
</template>

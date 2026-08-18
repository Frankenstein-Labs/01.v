<script>
import { defineComponent } from 'vue';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__ } from '~/locale';
import { groupSettingsOrbitPath } from 'ee/lib/utils/path_helpers/group';
import ownerNamespacesQuery from '../graphql/queries/owner_namespaces.query.graphql';
import orbitUpdateMutation from '../graphql/mutations/orbit_update.mutation.graphql';
import ConfigureButtonBase from './configure_button_base.vue';

export default defineComponent({
  name: 'OrbitGroupsConfigureButton',
  compatConfig: { MODE: 3 },
  components: { ConfigureButtonBase },
  apollo: {
    namespaces: {
      query: ownerNamespacesQuery,
      variables() {
        return { first: 100 };
      },
      update(data) {
        return data.groups?.nodes || [];
      },
    },
  },
  data() {
    return {
      namespaces: [],
      pendingGroup: null,
      enabling: false,
    };
  },
  computed: {
    namespacesLoading() {
      return this.$apollo.queries.namespaces.loading;
    },
    licensedNamespaces() {
      return this.namespaces.filter((ns) => ns.knowledgeGraphEnabled || ns.knowledgeGraphAvailable);
    },
    hasGroups() {
      return this.licensedNamespaces.length > 0;
    },
    isVisible() {
      return this.namespacesLoading || this.hasGroups;
    },
    confirmModalVisible() {
      return Boolean(this.pendingGroup);
    },
  },
  methods: {
    onSelect(fullPath) {
      const ns = this.namespaces.find((n) => n.fullPath === fullPath);
      if (!ns) return;

      if (ns.knowledgeGraphEnabled) {
        window.location.assign(groupSettingsOrbitPath(fullPath));
        return;
      }

      this.pendingGroup = ns;
    },
    async onConfirmEnable() {
      if (!this.pendingGroup || this.enabling) return;
      this.enabling = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: orbitUpdateMutation,
          variables: {
            input: { groupPath: this.pendingGroup.fullPath, enabled: true },
          },
        });

        const result = data.orbitUpdate;
        if (result.errors.length) {
          throw new Error(result.errors.join(', '));
        }

        window.location.assign(groupSettingsOrbitPath(this.pendingGroup.fullPath));
      } catch (error) {
        Sentry.captureException(error);
        createAlert({
          message: s__('Orbit|Failed to enable Orbit. Please try again.'),
        });
      } finally {
        this.enabling = false;
      }
    },
    onModalHidden() {
      if (this.enabling) return;
      this.pendingGroup = null;
    },
  },
});
</script>

<template>
  <configure-button-base
    v-if="isVisible"
    :namespaces="licensedNamespaces"
    :namespaces-loading="namespacesLoading"
    :enabling="enabling"
    :pending-group="pendingGroup"
    :confirm-modal-visible="confirmModalVisible"
    @select="onSelect"
    @confirm-enable="onConfirmEnable"
    @modal-hidden="onModalHidden"
  />
</template>

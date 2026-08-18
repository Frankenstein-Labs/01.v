<script>
import { GlDisclosureDropdown, GlDisclosureDropdownItem, GlToastMixin } from '@gitlab/ui';
import { copyToClipboard } from '~/lib/utils/copy_to_clipboard';
import { s__, sprintf } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { buildRepositoryClientUrl } from '../../utils';
import DeleteRepositoryModal from '../components/delete_repository_modal.vue';
import SetupDrawer from './setup_instructions/setup_drawer.vue';

export default {
  name: 'ArtifactRegistryRepositoryActions',
  components: {
    DeleteRepositoryModal,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    SetupDrawer,
  },
  mixins: [GlToastMixin],
  inject: ['slug', 'clientBaseUrl'],
  props: {
    repository: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      showDeleteModal: false,
      showSetupDrawer: false,
    };
  },
  computed: {
    // The toggle renders as an icon, so its accessible name is all a screen reader
    // gets: it names the repository the actions belong to rather than saying only
    // "More actions".
    toggleText() {
      return sprintf(s__('ArtifactRegistry|More actions for %{name}'), {
        name: this.repository.name,
      });
    },
    clientUrl() {
      return buildRepositoryClientUrl({
        clientBaseUrl: this.clientBaseUrl,
        slug: this.slug,
        format: this.repository.format,
        name: this.repository.name,
      });
    },
    copyItem() {
      return {
        text: s__('ArtifactRegistry|Copy repository URL'),
        action: () => this.copyClientUrl(),
      };
    },
    setupItem() {
      return {
        text: s__('ArtifactRegistry|View setup instructions'),
        action: () => {
          this.showSetupDrawer = true;
        },
      };
    },
    deleteItem() {
      return {
        text: s__('ArtifactRegistry|Delete repository'),
        variant: 'danger',
        action: () => {
          this.showDeleteModal = true;
        },
      };
    },
  },
  methods: {
    // A menu item shows nothing once it is chosen, so the toast is what reports the
    // copy, and being a live region it is also what announces it. A failed write is
    // reported rather than swallowed: the user has no other signal that the clipboard
    // still holds what it held before.
    async copyClientUrl() {
      try {
        await copyToClipboard(this.clientUrl);
        this.$toast.show(s__('ArtifactRegistry|Repository URL copied to clipboard.'));
      } catch (error) {
        Sentry.captureException(error);
      }
    },
  },
};
</script>

<template>
  <div>
    <gl-disclosure-dropdown
      icon="ellipsis_v"
      :toggle-text="toggleText"
      text-sr-only
      category="tertiary"
      no-caret
      placement="bottom-end"
    >
      <!-- Left out rather than shown broken when the instance configures no Artifact
           Registry: there is no URL to hand over. -->
      <gl-disclosure-dropdown-item
        v-if="clientUrl"
        :item="copyItem"
        data-testid="copy-repository-url"
      />

      <gl-disclosure-dropdown-item
        v-if="clientUrl"
        :item="setupItem"
        data-testid="view-setup-instructions"
      />

      <!-- The destructive action is marked out by its variant alone, with no divider
           above it: the design groups every item in one list. -->
      <gl-disclosure-dropdown-item :item="deleteItem" data-testid="delete-repository" />
    </gl-disclosure-dropdown>

    <delete-repository-modal v-model="showDeleteModal" :repository="repository" />

    <setup-drawer
      :open="showSetupDrawer"
      :name="repository.name"
      :format="repository.format"
      @close="showSetupDrawer = false"
    />
  </div>
</template>

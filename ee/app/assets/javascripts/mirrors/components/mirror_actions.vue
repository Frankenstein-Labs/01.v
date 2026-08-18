<script>
import { s__ } from '~/locale';
import CeMirrorActions from '~/mirrors/components/mirror_actions.vue';

// This is a false violation of @gitlab/no-runtime-template-compiler, since it
// extends a valid Vue single file component.
// eslint-disable-next-line @gitlab/no-runtime-template-compiler
export default {
  name: 'MirrorActionsEE',
  extends: CeMirrorActions,
  computed: {
    // eslint-disable-next-line vue/no-unused-properties -- Overrides CE showSyncButton
    showSyncButton() {
      return this.mirror.enabled || this.isUpdating || (this.isPullMirror && this.mirror.archived);
    },
    // eslint-disable-next-line vue/no-unused-properties -- Overrides CE syncButtonDisabled
    syncButtonDisabled() {
      return this.isUpdating || (this.isPullMirror && this.mirror.archived);
    },
    // eslint-disable-next-line vue/no-unused-properties -- Overrides CE syncButtonTitle
    syncButtonTitle() {
      if (this.isUpdating) return this.$options.i18n.updating;
      if (this.isPullMirror && this.mirror.archived) return this.$options.i18n.archivedTooltip;
      return this.$options.i18n.updateNow;
    },
  },
  i18n: {
    ...CeMirrorActions.i18n,
    archivedTooltip: s__(
      'Mirror|This project is archived and read-only. To resume pull mirroring, unarchive the project.',
    ),
  },
};
</script>

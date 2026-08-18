<script>
import { s__ } from '~/locale';
import { cloneWithoutReferences } from '~/lib/utils/common_utils';
import CeMirrorTable from '~/mirrors/components/mirror_table.vue';
import { PULL_MIRROR_DELETED_EVENT } from '~/mirrors/constants';
import { syncPullMirror, deletePullMirror } from 'ee/api/pull_mirror_api';
import EeMirrorActions from './mirror_actions.vue';

// This is a false violation of @gitlab/no-runtime-template-compiler, since it
// extends a valid Vue single file component.
// eslint-disable-next-line @gitlab/no-runtime-template-compiler
export default {
  name: 'MirrorTableEE',
  components: {
    ...CeMirrorTable.components,
    MirrorActions: EeMirrorActions,
  },
  extends: CeMirrorTable,
  data() {
    return {
      pullMirror: this.initialPullMirror ? cloneWithoutReferences(this.initialPullMirror) : null,
    };
  },
  computed: {
    // eslint-disable-next-line vue/no-unused-properties -- Overrides CE tableItems
    tableItems() {
      return this.pullMirror ? [this.pullMirror, ...this.mirrors] : this.mirrors;
    },
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties -- Overrides CE onSync
    onSync({ id, direction }) {
      if (direction === 'pull') {
        this.handlePullSync();
        return;
      }
      CeMirrorTable.methods.onSync.call(this, { id, direction });
    },
    // eslint-disable-next-line vue/no-unused-properties -- Overrides CE onToggle
    onToggle({ id, direction }) {
      if (direction === 'pull') return;
      CeMirrorTable.methods.onToggle.call(this, { id, direction });
    },
    // eslint-disable-next-line vue/no-unused-properties -- Overrides CE onDelete
    onDelete({ id, direction }) {
      if (direction === 'pull') {
        this.handlePullDelete();
        return;
      }
      CeMirrorTable.methods.onDelete.call(this, { id, direction });
    },
    handlePullSync() {
      if (!this.pullMirror) return;
      const previousStatus = this.pullMirror.updateStatus;
      this.pullMirror.updateStatus = 'started';

      syncPullMirror(this.projectId).catch(() => {
        this.pullMirror.updateStatus = previousStatus;
        this.showAlertMessage(s__('Mirror|Failed to sync mirror.'));
      });
    },
    handlePullDelete() {
      if (!this.pullMirror) return;
      deletePullMirror(this.projectId)
        .then(() => {
          this.pullMirror = null;
          document.dispatchEvent(new CustomEvent(PULL_MIRROR_DELETED_EVENT));
        })
        .catch(() => {
          this.showAlertMessage(s__('Mirror|Failed to remove mirror.'));
        });
    },
  },
};
</script>

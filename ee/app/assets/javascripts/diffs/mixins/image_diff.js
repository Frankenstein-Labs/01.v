import { mapActions } from 'pinia';
import { useLegacyDiffs } from '~/diffs/stores/legacy_diffs';

export default {
  computed: {
    diffFileDiscussions() {
      return this.allDiscussions.filter((d) => !d.isDraft);
    },
  },
  methods: {
    ...mapActions(useLegacyDiffs, ['toggleFileDiscussion']),
    clickedToggle(discussion) {
      this.toggleFileDiscussion(discussion);
    },
    toggleText(discussion, index) {
      const count = index + 1;

      return discussion.isDraft ? count - this.diffFileDiscussions.length : count;
    },
  },
};
